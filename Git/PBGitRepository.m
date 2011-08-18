//
//  PBGitRepository.m
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRepository.h"
#import "PBGitCommit.h"
#import "PBGitWindowController.h"
#import "PBGitBinary.h"

#import "NSFileHandleExt.h"
#import "GitXScriptingConstants.h"
#import "PBEasyPipe.h"
#import "PBGitDefaults.h"
#import "PBGitRef.h"
#import "PBGitResetController.h"
#import "PBGitRevList.h"
#import "PBGitRevSpecifier.h"
#import "PBHistorySearchController.h"
#import "PBRemoteProgressSheet.h"
#import "PBStashController.h"
#import "PBSubmoduleController.h"

#import "PBGitStash.h"
#import "PBGitSubmodule.h"

NSString* PBGitRepositoryErrorDomain = @"GitXErrorDomain";

@interface PBGitRepository()
@end



@implementation PBGitRepository
@synthesize stashController;
@synthesize submoduleController;
@synthesize resetController;
@synthesize revisionList, branches, currentBranch, refs, hasChanged, config;
@synthesize currentBranchFilter;
@synthesize headRef = _headRef;
@synthesize headSha = _headSha;

- (NSMenu *)menu
{
	NSMenu *menu = [[NSMenu alloc] init];
	NSMutableArray *items = [[NSMutableArray alloc] init];
	[items addObjectsFromArray:[self.submoduleController menuItems]];
	[items addObject:[NSMenuItem separatorItem]];
	[items addObjectsFromArray:[self.stashController menu]];
	[items addObject:[NSMenuItem separatorItem]];
	[items addObjectsFromArray:[self.resetController menuItems]];
	
	for (NSMenuItem *item in items) {
		[menu addItem:item];
	}
	
	[menu setAutoenablesItems:YES];
	return menu;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	if (outError) {
		*outError = [NSError errorWithDomain:PBGitRepositoryErrorDomain
                                      code:0
                                  userInfo:[NSDictionary dictionaryWithObject:@"Reading files is not supported." forKey:NSLocalizedFailureReasonErrorKey]];
	}
	return NO;
}

+ (BOOL) isBareRepository: (NSString*) path
{
	return [[PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:[NSArray arrayWithObjects:@"rev-parse", @"--is-bare-repository", nil] inDir:path] isEqualToString:@"true"];
}

+ (NSURL *)gitDirForURL:(NSURL *)repositoryURL;
{
	if (![PBGitBinary path])
		return nil;

	NSString* repositoryPath = [repositoryURL path];

	if ([self isBareRepository:repositoryPath])
		return repositoryURL;

	// Use rev-parse to find the .git dir for the repository being opened
	int retValue = 1;
	NSString *newPath = [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:[NSArray arrayWithObjects:@"rev-parse", @"--git-dir", nil] inDir:repositoryPath retValue:&retValue];
	if (retValue) {
		// The current directory does not contain a git repository
		return nil;
	}

	if ([newPath isEqualToString:@".git"])
		return [NSURL fileURLWithPath:[repositoryPath stringByAppendingPathComponent:@".git"]];
	if ([newPath isEqualToString:@"."])
		return [NSURL fileURLWithPath:repositoryPath];
	if ([newPath length] > 0)
		return [NSURL fileURLWithPath:newPath];

	return nil;
}

// For a given path inside a repository, return either the .git dir
// (for a bare repo) or the directory above the .git dir otherwise
+ (NSURL*)baseDirForURL:(NSURL*)repositoryURL;
{
	NSURL* gitDirURL         = [self gitDirForURL:repositoryURL];
	NSString* repositoryPath = [gitDirURL path];

	if (![self isBareRepository:repositoryPath]) {
		repositoryURL = [NSURL fileURLWithPath:[[repositoryURL path] stringByDeletingLastPathComponent]];
	}

	return repositoryURL;
}

// NSFileWrapper is broken and doesn't work when called on a directory containing a large number of directories and files.
//because of this it is safer to implement readFromURL than readFromFileWrapper.
//Because NSFileManager does not attempt to recursively open all directories and file when fileExistsAtPath is called
//this works much better.
- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	@try
    {
        if (![PBGitBinary path])
        {
            if (outError) {
                NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[PBGitBinary notFoundError]
                                                                     forKey:NSLocalizedRecoverySuggestionErrorKey];
                *outError = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0 userInfo:userInfo];
            }
		return NO;
	}

	BOOL isDirectory = FALSE;
	[[NSFileManager defaultManager] fileExistsAtPath:[absoluteURL path] isDirectory:&isDirectory];
	if (!isDirectory) {
		if (outError) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObject:@"Reading files is not supported."
																 forKey:NSLocalizedRecoverySuggestionErrorKey];
			*outError = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0 userInfo:userInfo];
		}
		return NO;
	}


	NSURL* gitDirURL = [PBGitRepository gitDirForURL:[self fileURL]];
	if (!gitDirURL) {
		if (outError) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%@ does not appear to be a git repository.", [self fileURL]]
																 forKey:NSLocalizedRecoverySuggestionErrorKey];
			*outError = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0 userInfo:userInfo];
		}
		return NO;
	}

	[self setFileURL:gitDirURL];
	[self setup];
	return YES;
	} @catch(id x) {
		if (outError) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"An error occured while trying to open %@.\n%@", [self fileURL],x]
																 forKey:NSLocalizedRecoverySuggestionErrorKey];
			*outError = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0 userInfo:userInfo];
		}
		return NO;
	}
}

- (void) setup
{
	config = [[PBGitConfig alloc] initWithRepositoryPath:[[self fileURL] path]];
	self.branches = [NSMutableArray array];
	[self reloadRefs];
	currentBranchFilter = [PBGitDefaults branchFilter];
	revisionList = [[PBGitHistoryList alloc] initWithRepository:self];
	
	resetController = [[PBGitResetController alloc] initWithRepository:self];
	stashController = [[PBStashController alloc] initWithRepository:self];
	submoduleController = [[PBSubmoduleController alloc] initWithRepository:self];
}

- (void)close
{
	[revisionList cleanup];

	[super close];
}

- (id) initWithURL: (NSURL*) path
{
	if (![PBGitBinary path])
		return nil;

	NSURL* gitDirURL = [PBGitRepository gitDirForURL:path];
	if (!gitDirURL)
		return nil;

	self = [self init];
	[self setFileURL: gitDirURL];

	[self setup];
	
	// We don't want the window controller to display anything yet..
	// We'll leave that to the caller of this method.
#ifndef CLI
	[self addWindowController:[[PBGitWindowController alloc] initWithRepository:self displayDefault:NO]];
#endif

	[self showWindows];

	return self;
}

- (void) forceUpdateRevisions
{
	[revisionList forceUpdate];
}

- (BOOL)isDocumentEdited
{
	return NO;
}

// The fileURL the document keeps is to the .git dir, but that’s pretty
// useless for display in the window title bar, so we show the directory above
- (NSString *) displayName
{
	if (![[PBGitRef refFromString:[[self headRef] simpleRef]] type])
		return [NSString stringWithFormat:@"%@ (detached HEAD)", [self projectName]];

	return [NSString stringWithFormat:@"%@ (branch: %@)", [self projectName], [[self headRef] description]];
}

- (NSString *) projectName
{
	NSString *projectPath = [[self fileURL] path];

	if ([[projectPath lastPathComponent] isEqualToString:@".git"])
		projectPath = [projectPath stringByDeletingLastPathComponent];

	return [projectPath lastPathComponent];
}

// Get the .gitignore file at the root of the repository
- (NSString*)gitIgnoreFilename
{
	return [[self workingDirectory] stringByAppendingPathComponent:@".gitignore"];
}

- (BOOL)isBareRepository
{
	if([self workingDirectory]) {
		return [PBGitRepository isBareRepository:[self workingDirectory]];
	} else {
		return true;
	}
}

// Overridden to create our custom window controller
- (void)makeWindowControllers
{
#ifndef CLI
	[self addWindowController: [[PBGitWindowController alloc] initWithRepository:self displayDefault:YES]];
#endif
}

- (PBGitWindowController *)windowController
{
	if ([[self windowControllers] count] == 0)
		return NULL;
	
	return [[self windowControllers] objectAtIndex:0];
}

- (void) addRef: (PBGitRef *) ref fromParameters: (NSArray *) components
{
	NSString* type = [components objectAtIndex:1];

	NSString *sha;
	if ([type isEqualToString:@"tag"] && [components count] == 4)
		sha = [components objectAtIndex:3];
	else
		sha = [components objectAtIndex:2];

	if(!sha) {
		NSLog(@"sha was nil...? ref=%@, components=%@",ref,components);
		return;
	}

	NSMutableArray* curRefs;
	if ( (curRefs = [refs objectForKey:sha]) != nil )
		[curRefs addObject:ref];
	else
		[refs setObject:[NSMutableArray arrayWithObject:ref] forKey:sha];
}

// Returns the remote's fetch and pull URLs as an array of two strings.
- (NSArray*) URLsForRemote:(NSString*)remoteName
{
	NSArray *arguments = [NSArray arrayWithObjects:@"remote", @"show", @"-n", remoteName, nil];
	NSString *output = [self outputForArguments:arguments];

	NSArray *remoteLines = [output componentsSeparatedByString:@"\n"];
	NSString *fetchURL = [remoteLines objectAtIndex:1];
	NSString *pushURL = [remoteLines objectAtIndex:2];

	if ([fetchURL hasPrefix:@"  Fetch URL: "] && [pushURL hasPrefix:@"  Push  URL: "])
		return [NSArray arrayWithObjects:
				[fetchURL substringFromIndex:13],
				[pushURL substringFromIndex:13],
				nil];
	return nil;
}

// Extracts the text that should be shown in a help tag.
- (NSString*) helpTextForRef:(PBGitRef*)ref
{
	NSString *output = nil;
	NSString *name = [ref shortName];
	NSArray *arguments = nil;

	if ([ref isTag]) {
		arguments = [NSArray arrayWithObjects:@"tag", @"-ln", name, nil];
		output = [self outputForArguments:arguments];
		if (![output hasPrefix:name])
			return nil;
		return [[output substringFromIndex:[name length]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	}
	return nil;
}

- (void) reloadRefs
{
	_headRef = nil;
	_headSha = nil;

	refs = [NSMutableDictionary dictionary];
	NSMutableArray *oldBranches = [branches mutableCopy];

	NSArray *arguments = [NSArray arrayWithObjects:@"for-each-ref", @"--format=%(refname) %(objecttype) %(objectname) %(*objectname)", @"refs", nil];
	NSString *output = [self outputForArguments:arguments];
	NSArray *lines = [output componentsSeparatedByString:@"\n"];

	if([output hasPrefix:@"fatal: "]) {
		NSLog(@"Unable to read refs!");
		NSLog(@"arguments=%@",arguments);
		NSLog(@"output=%@",output);
		@throw output;
	}

	for (NSString *line in lines) {
		// If its an empty line, skip it (e.g. with empty repositories)
		if ([line length] == 0)
			continue;

		NSArray *components = [line componentsSeparatedByString:@" "];

		PBGitRef *newRef = [PBGitRef refFromString:[components objectAtIndex:0]];
		PBGitRevSpecifier *revSpec = [[PBGitRevSpecifier alloc] initWithRef:newRef];

		[revSpec setHelpText:[self helpTextForRef:newRef]];
		[self addBranch:revSpec];
		[self addRef:newRef fromParameters:components];
		[oldBranches removeObject:revSpec];
	}

	for (PBGitRevSpecifier *branch in oldBranches)
		if ([branch isSimpleRef] && ![branch isEqual:[self headRef]])
			[self removeBranch:branch];

	[self willChangeValueForKey:@"refs"];
	[self didChangeValueForKey:@"refs"];
	
	[self.stashController reload];
	[self.submoduleController reload];

	[[[self windowController] window] setTitle:[self displayName]];
}

+(bool)isLocalBranch:(NSString *)branch branchNameInto:(NSString **)name
{
	NSScanner *scanner=[NSScanner scannerWithString:branch];
	bool is=[scanner scanString:@"refs/heads/" intoString:NULL];
	if(is && (name)){
		*name=[branch substringFromIndex:[scanner scanLocation]];
	}
	return is;
}

- (void) lazyReload
{
	if (!hasChanged)
		return;

	[self.revisionList updateHistory];
	hasChanged = NO;
}

- (PBGitRevSpecifier *)headRef
{
	if (_headRef)
		return _headRef;

	NSString* branch = [self parseSymbolicReference: @"HEAD"];
	if (branch && [branch hasPrefix:@"refs/heads/"])
		_headRef = [[PBGitRevSpecifier alloc] initWithRef:[PBGitRef refFromString:branch]];
	else
		_headRef = [[PBGitRevSpecifier alloc] initWithRef:[PBGitRef refFromString:@"HEAD"]];

	_headSha = [self shaForRef:[_headRef ref]];

	return _headRef;
}

- (NSString *)headSHA
{
	if (! _headSha)
		[self headRef];

	return _headSha;
}

- (PBGitCommit *)headCommit
{
	return [self commitForSHA:[self headSHA]];
}

- (NSString *)shaForRef:(PBGitRef *)ref
{
	if (!ref)
		return nil;

	for (NSString *sha in refs)
		for (PBGitRef *existingRef in [refs objectForKey:sha])
			if ([existingRef isEqualToRef:ref])
				return sha;

	int retValue = 1;
	NSArray *args = [NSArray arrayWithObjects:@"rev-list", @"-1", [ref ref], nil];
	NSString *shaForRef = [self outputInWorkdirForArguments:args retValue:&retValue];
	if (retValue || [shaForRef isEqualToString:@""])
		return nil;

	return shaForRef;
}

- (PBGitCommit *)commitForRef:(PBGitRef *)ref
{
	if (!ref)
		return nil;

	return [self commitForSHA:[self shaForRef:ref]];
}

- (PBGitCommit *)commitForSHA:(NSString *)sha
{
	if (!sha)
		return nil;
	NSArray *revList = revisionList.projectCommits;

    if (!revList) {
        [revisionList forceUpdate];
        revList = revisionList.projectCommits;
    }
	for (PBGitCommit *commit in revList)
		if ([[commit sha] isEqual:sha])
			return commit;

	// The commit has not been loaded, but it may exist anyway
	NSArray *args = [NSArray arrayWithObjects:
			@"show", sha,
			@"--pretty=format:"
					"%P%n"         // parents
					"%aN <%aE>%n"  // author name
					"%cN <%cE>%n"  // committer name
					"%ct%n"        // commit date
					"%s",          // subject
			nil];
	int retValue = 1;
	NSString *output = [self outputInWorkdirForArguments:args retValue:&retValue];

	if ((retValue != 0) || [output hasPrefix:@"fatal:"])
		return nil;

	NSArray *lines = [output componentsSeparatedByString:@"\n"];
	PBGitCommit *commit = [PBGitCommit commitWithRepository:self andSha:sha];
	
	commit.parents = [[lines objectAtIndex:0] componentsSeparatedByString:@" "];
	commit.author = [lines objectAtIndex:1];
	commit.committer = [lines objectAtIndex:2];
	commit.timestamp = [[lines objectAtIndex:3] intValue];
	commit.subject = [lines objectAtIndex:4];
	return commit;
}

- (BOOL)isOnSameBranch:(NSString *)branchSHA asSHA:(NSString *)testSHA
{
	if (!branchSHA || !testSHA)
		return NO;

	if ([testSHA isEqual:branchSHA])
		return YES;

	NSArray *revList = revisionList.projectCommits;

	NSMutableSet *searchSHAs = [NSMutableSet setWithObject:branchSHA];

	for (PBGitCommit *commit in revList) {
		NSString *commitSHA = [commit sha];
		if ([searchSHAs containsObject:commitSHA]) {
			if ([testSHA isEqual:commitSHA])
				return YES;
			[searchSHAs removeObject:commitSHA];
			[searchSHAs addObjectsFromArray:commit.parents];
		}
		else if ([testSHA isEqual:commitSHA])
			return NO;
	}

	return NO;
}

- (BOOL)isSHAOnHeadBranch:(NSString *)testSHA
{
	if (!testSHA)
		return NO;

	NSString *headSHA = [self headSHA];

	if ([testSHA isEqual:headSHA])
		return YES;

	return [self isOnSameBranch:headSHA asSHA:testSHA];
}

- (BOOL)isRefOnHeadBranch:(PBGitRef *)testRef
{
	if (!testRef)
		return NO;

	return [self isSHAOnHeadBranch:[self shaForRef:testRef]];
}

- (BOOL) checkRefFormat:(NSString *)refName
{
	int retValue = 1;
	[self outputInWorkdirForArguments:[NSArray arrayWithObjects:@"check-ref-format", refName, nil] retValue:&retValue];
	if (retValue)
		return NO;
	return YES;
}

- (BOOL) refExists:(PBGitRef *)ref
{
	int retValue = 1;
    NSString *output = [self outputInWorkdirForArguments:[NSArray arrayWithObjects:@"for-each-ref", [ref ref], nil] retValue:&retValue];
    if (retValue || [output isEqualToString:@""])
        return NO;
    return YES;
}

// useful for getting the full ref for a user entered name
// EX:  name: master
//       ref: refs/heads/master
- (PBGitRef *)refForName:(NSString *)name
{
	if (!name)
		return nil;

	int retValue = 1;
    NSString *output = [self outputInWorkdirForArguments:[NSArray arrayWithObjects:@"show-ref", name, nil] retValue:&retValue];
	if (retValue)
		return nil;

	// the output is in the format: <SHA-1 ID> <space> <reference name>
	// with potentially multiple lines if there are multiple matching refs (ex: refs/remotes/origin/master)
	// here we only care about the first match
	NSArray *refList = [output componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([refList count] > 1) {
		NSString *refName = [refList objectAtIndex:1];
		return [PBGitRef refFromString:refName];
	}

	return nil;
}
		
// Returns either this object, or an existing, equal object
- (PBGitRevSpecifier*) addBranch:(PBGitRevSpecifier*)branch
{
	if ([[branch parameters] count] == 0)
		branch = [self headRef];

	// First check if the branch doesn't exist already
	for (PBGitRevSpecifier *rev in branches)
		if ([branch isEqual: rev])
			return rev;

	NSIndexSet *newIndex = [NSIndexSet indexSetWithIndex:[branches count]];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:newIndex forKey:@"branches"];

	[branches addObject:branch];

	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:newIndex forKey:@"branches"];
	return branch;
}

- (BOOL) removeBranch:(PBGitRevSpecifier *)branch
{
	for (PBGitRevSpecifier *rev in branches) {
		if ([branch isEqual:rev]) {
			NSIndexSet *oldIndex = [NSIndexSet indexSetWithIndex:[branches indexOfObject:rev]];
			[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:oldIndex forKey:@"branches"];

			[branches removeObject:rev];

			[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:oldIndex forKey:@"branches"];
			return YES;
		}
	}
	return NO;
}
	
- (void) readCurrentBranch
{
		self.currentBranch = [self addBranch: [self headRef]];
}

- (NSString *) workingDirectory
{
	if ([self.fileURL.path hasSuffix:@"/.git"])
		return [self.fileURL.path substringToIndex:[self.fileURL.path length] - 5];
	else if ([[self outputForCommand:@"rev-parse --is-inside-work-tree"] isEqualToString:@"true"])
		return [PBGitBinary path];
	
	return nil;
}

#pragma mark Remotes

- (NSArray *) remotes
{
	int retValue = 1;
	NSString *remotes = [self outputInWorkdirForArguments:[NSArray arrayWithObject:@"remote"] retValue:&retValue];
	if (retValue || [remotes isEqualToString:@""])
		return nil;

	return [remotes componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

- (BOOL) hasRemotes
{
	return ([self remotes] != nil);
}

- (PBGitRef *) remoteRefForBranch:(PBGitRef *)branch error:(NSError **)error
{
	if ([branch isRemote])
		return [branch remoteRef];

	NSString *branchName = [branch branchName];
	if (branchName) {
		NSString *remoteName = [[self config] valueForKeyPath:[NSString stringWithFormat:@"branch.%@.remote", branchName]];
		if (remoteName && ([remoteName isKindOfClass:[NSString class]] && ![remoteName isEqualToString:@""])) {
			PBGitRef *remoteRef = [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:remoteName]];
			// check that the remote is a valid ref and exists
			if ([self checkRefFormat:[remoteRef ref]] && [self refExists:remoteRef])
				return remoteRef;
		}
	}

	if (error != NULL) {
		NSString *info = [NSString stringWithFormat:@"There is no remote configured for the %@ '%@'.\n\nPlease select a branch from the popup menu, which has a corresponding remote tracking branch set up.\n\nYou can also use a contextual menu to choose a branch by right clicking on its label in the commit history list.", [branch refishType], [branch shortName]];
		*error = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0
								 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
										   @"No remote configured for branch", NSLocalizedDescriptionKey,
										   info, NSLocalizedRecoverySuggestionErrorKey,
										   nil]];
	}
	return nil;
}

- (NSString *) infoForRemote:(NSString *)remoteName
{
	int retValue = 1;
	NSString *output = [self outputInWorkdirForArguments:[NSArray arrayWithObjects:@"remote", @"show", remoteName, nil] retValue:&retValue];
	if (retValue)
		return nil;

	return output;
}

#pragma mark Repository commands

- (void) cloneRepositoryToPath:(NSString *)path bare:(BOOL)isBare
{
	if (!path || [path isEqualToString:@""])
		return;

	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"clone", @"--no-hardlinks", @"--", @".", path, nil];
	if (isBare)
		[arguments insertObject:@"--bare" atIndex:1];

	NSString *description = [NSString stringWithFormat:@"Cloning the repository %@ to %@", [self projectName], path];
	NSString *title = @"Cloning Repository";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:arguments title:title description:description inRepository:self];
}

- (void) beginAddRemote:(NSString *)remoteName forURL:(NSString *)remoteURL
{
	NSArray *arguments = [NSArray arrayWithObjects:@"remote",  @"add", @"-f", remoteName, remoteURL, nil];

	NSString *description = [NSString stringWithFormat:@"Adding the remote %@ and fetching tracking branches", remoteName];
	NSString *title = @"Adding a remote";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:arguments title:title description:description inRepository:self];
}

- (void) beginFetchFromRemoteForRef:(PBGitRef *)ref
{
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"fetch"];

	if (![ref isRemote]) {
		NSError *error = nil;
		ref = [self remoteRefForBranch:ref error:&error];
		if (!ref) {
			if (error)
				[self.windowController showErrorSheet:error];
			return;
		}
	}
	NSString *remoteName = [ref remoteName];
	[arguments addObject:remoteName];

	NSString *description = [NSString stringWithFormat:@"Fetching all tracking branches from %@", remoteName];
	NSString *title = @"Fetching from remote";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:arguments title:title description:description inRepository:self];
}

- (void) beginPullFromRemote:(PBGitRef *)remoteRef forRef:(PBGitRef *)ref
{
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"pull"];

	// a nil remoteRef means lookup the ref's default remote
	if (!remoteRef || ![remoteRef isRemote]) {
		NSError *error = nil;
		remoteRef = [self remoteRefForBranch:ref error:&error];
		if (!remoteRef) {
			if (error)
				[self.windowController showErrorSheet:error];
			return;
		}
	}
	NSString *remoteName = [remoteRef remoteName];
	[arguments addObject:remoteName];

	NSString *description = [NSString stringWithFormat:@"Pulling all tracking branches from %@", remoteName];
	NSString *title = @"Pulling from remote";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:arguments title:title description:description inRepository:self];
}

- (void) beginPushRef:(PBGitRef *)ref toRemote:(PBGitRef *)remoteRef
{
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"push"];

	// a nil remoteRef means lookup the ref's default remote
	if (!remoteRef || ![remoteRef isRemote]) {
		NSError *error = nil;
		remoteRef = [self remoteRefForBranch:ref error:&error];
		if (!remoteRef) {
			if (error)
				[self.windowController showErrorSheet:error];
			return;
		}
	}
	NSString *remoteName = [remoteRef remoteName];
	[arguments addObject:remoteName];
	
	NSString *branchName = nil;
	NSString *actionType = nil;

	if ([config valueForKeyPath:[NSString stringWithFormat:@"remote.%@.mirror", remoteName]]) {
		// we must check for mirror parameter in config.
		// if we push branch name in this case to the arguments, push failed
		actionType = @"Mirroring";
	} else {
		
		if ([ref isRemote] || !ref) {
			branchName = @"all updates";
		}
		else if ([ref isTag]) {
			branchName = [NSString stringWithFormat:@"tag '%@'", [ref tagName]];
			[arguments addObject:@"tag"];
			[arguments addObject:[ref tagName]];
		}
		else {
			branchName = [ref shortName];
			[arguments addObject:branchName];
		}

		actionType = [NSString stringWithFormat:@"Pushing %@", branchName];
		
	}

	NSString *description = [actionType stringByAppendingFormat:@" to %@", remoteName];
	NSString *title = @"Pushing to remote";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:arguments title:title description:description inRepository:self];
}

- (BOOL) checkoutRefish:(id <PBGitRefish>)ref
{
	NSString *refName = nil;
	if ([ref refishType] == kGitXBranchType)
		refName = [ref shortName];
	else
		refName = [ref refishName];

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"checkout", refName, nil];
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error checking out the %@ '%@'.\n\nPerhaps your working directory is not clean?", [ref refishType], [ref shortName]];
		[self.windowController showErrorSheetTitle:@"Checkout failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) checkoutFiles:(NSArray *)files fromRefish:(id <PBGitRefish>)ref
{
	if (!files || ([files count] == 0))
		return NO;

	NSString *refName = nil;
	if ([ref refishType] == kGitXBranchType)
		refName = [ref shortName];
	else
		refName = [ref refishName];

	int retValue = 1;
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"checkout", refName, @"--", nil];
	[arguments addObjectsFromArray:files];
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error checking out the file(s) from the %@ '%@'.\n\nPerhaps your working directory is not clean?", [ref refishType], [ref shortName]];
		[self.windowController showErrorSheetTitle:@"Checkout failed!" message:message arguments:arguments output:output];
		return NO;
	}

	return YES;
}


- (BOOL) mergeWithRefish:(id <PBGitRefish>)ref
{
	NSString *refName = [ref refishName];

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"merge", refName, nil];
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *headName = [[[self headRef] ref] shortName];
		NSString *message = [NSString stringWithFormat:@"There was an error merging %@ into %@.", refName, headName];
		[self.windowController showErrorSheetTitle:@"Merge failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) cherryPickRefish:(id <PBGitRefish>)ref
{
	if (!ref)
		return NO;

	NSString *refName = [ref refishName];

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"cherry-pick", refName, nil];
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error cherry picking the %@ '%@'.\n\nPerhaps your working directory is not clean?", [ref refishType], [ref shortName]];
		[self.windowController showErrorSheetTitle:@"Cherry pick failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) rebaseBranch:(id <PBGitRefish>)branch onRefish:(id <PBGitRefish>)upstream
{
	if (!upstream)
		return NO;

	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"rebase", [upstream refishName], nil];

	if (branch)
		[arguments addObject:[branch refishName]];

	int retValue = 1;
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *branchName = @"HEAD";
		if (branch)
			branchName = [NSString stringWithFormat:@"%@ '%@'", [branch refishType], [branch shortName]];
		NSString *message = [NSString stringWithFormat:@"There was an error rebasing %@ with %@ '%@'.", branchName, [upstream refishType], [upstream shortName]];
		[self.windowController showErrorSheetTitle:@"Rebase failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) createBranch:(NSString *)branchName atRefish:(id <PBGitRefish>)ref
{
	if (!branchName || !ref)
		return NO;

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"branch", branchName, [ref refishName], nil];
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error creating the branch '%@' at %@ '%@'.", branchName, [ref refishType], [ref shortName]];
		[self.windowController showErrorSheetTitle:@"Create Branch failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	return YES;
}

- (BOOL) createTag:(NSString *)tagName message:(NSString *)message atRefish:(id <PBGitRefish>)target
{
	if (!tagName)
		return NO;

	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"tag"];

	// if there is a message then make this an annotated tag
	if (message && ![message isEqualToString:@""] && ([message length] > 3)) {
		[arguments addObject:@"-a"];
		[arguments addObject:[@"-m" stringByAppendingString:message]];
	}

	[arguments addObject:tagName];

	// if no refish then git will add it to HEAD
	if (target)
		[arguments addObject:[target refishName]];

	int retValue = 1;
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *targetName = @"HEAD";
		if (target)
			targetName = [NSString stringWithFormat:@"%@ '%@'", [target refishType], [target shortName]];
		NSString *message = [NSString stringWithFormat:@"There was an error creating the tag '%@' at %@.", tagName, targetName];
		[self.windowController showErrorSheetTitle:@"Create Tag failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	return YES;
}

- (BOOL) deleteRemote:(PBGitRef *)ref
{
	if (!ref || ([ref refishType] != kGitXRemoteType))
		return NO;

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"remote", @"rm", [ref remoteName], nil];
	NSString * output = [self outputForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error deleting the remote: %@\n\n", [ref remoteName]];
		[self.windowController showErrorSheetTitle:@"Delete remote failed!" message:message arguments:arguments output:output];
		return NO;
	}

	// remove the remote's branches
	NSString *remoteRef = [kGitXRemoteRefPrefix stringByAppendingString:[ref remoteName]];
	for (PBGitRevSpecifier *rev in [branches copy]) {
		PBGitRef *branch = [rev ref];
		if ([[branch ref] hasPrefix:remoteRef]) {
			[self removeBranch:rev];
			PBGitCommit *commit = [self commitForRef:branch];
			[commit removeRef:branch];
		}
	}

	[self reloadRefs];
	return YES;
}

- (BOOL) deleteRef:(PBGitRef *)ref
{
	if (!ref)
		return NO;

	if ([ref refishType] == kGitXRemoteType)
		return [self deleteRemote:ref];

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"update-ref", @"-d", [ref ref], nil];
	NSString * output = [self outputForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error deleting the ref: %@\n\n", [ref shortName]];
		[self.windowController showErrorSheetTitle:@"Delete ref failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self removeBranch:[[PBGitRevSpecifier alloc] initWithRef:ref]];
	PBGitCommit *commit = [self commitForRef:ref];
	[commit removeRef:ref];

	[self reloadRefs];
	return YES;
}

#pragma mark git svn commands

/**
 determines if the current repository has a git-svn configured remote
 */
- (BOOL) hasSvnRemote
{
    NSArray* remotes = [self svnRemotes];
    return remotes && [remotes count] > 0;
}

/**
 get a list of the svn remotes configured on this repository
 */
- (NSArray*) svnRemotes
{
    NSDictionary* configValues = [config listConfigValuesInDir:[self workingDirectory]];
    NSMutableArray* remotes = [NSMutableArray array];
    
    for (NSString* key in configValues) {
        NSArray* components = [key componentsSeparatedByString:@"."];
        if ([components count] == 3 && 
            [[components objectAtIndex:0] isEqualToString:@"svn-remote"] &&
            [[components objectAtIndex:2] isEqualToString:@"url"]) {
            
            NSString* remoteName = [components objectAtIndex:1];
            [remotes addObject:remoteName];
        }
    }
    return [NSArray arrayWithArray:remotes];
}

/**
 call `git svn fetch` with an optional remote name
 
 remoteName can be NULL
 */
- (BOOL) svnFetch:(NSString*)remoteName
{
    int retval = 1;
    NSArray* args = [NSArray arrayWithObjects:@"svn", @"fetch", remoteName, nil];
    
	NSString *description = [NSString stringWithFormat:@"Fetching all tracking branches from %@", remoteName ? remoteName : @"<default>"];
	NSString *title = @"Fetching from svn remote";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:args title:title description:description inRepository:self];
    retval = 0;
    
	return retval == 0;
}

/**
 call `git svn rebase` with an optional remote name
 
 remoteName can be NULL
 */
- (BOOL) svnRebase:(NSString*)remoteName
{
    int retval = 1;
    NSArray* args = [NSArray arrayWithObjects:@"svn", @"rebase", remoteName, nil];
    
	NSString *description = [NSString stringWithFormat:@"Rebasing all tracking branches from %@", remoteName ? remoteName : @"<default>"];
	NSString *title = @"Pulling from svn remote (Rebase)";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:args title:title description:description inRepository:self];
    retval = 0;
    
	return retval == 0;
}

/**
 call `git svn dcommit` with optional commitURL
 
 commitURL can be NULL
 */
- (BOOL) svnDcommit:(NSString*)commitURL
{
    int retval = 1;
    NSArray* args = [NSArray arrayWithObjects:@"svn", @"dcommit", commitURL, nil];
    
	NSString *description = [NSString stringWithFormat:@"Pushing commits to svn remote %@", commitURL ? commitURL : @"<default>"];
	NSString *title = @"Pushing to svn remote (Dcommit)";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:args title:title description:description inRepository:self];
    retval = 0;
    
	return retval == 0;
}

#pragma mark GitX Scripting

- (void)handleRevListArguments:(NSArray *)arguments inWorkingDirectory:(NSURL *)workingDirectory
{
	if (![arguments count])
		return;

	PBGitRevSpecifier *revListSpecifier = nil;

	// the argument may be a branch or tag name but will probably not be the full reference
	if ([arguments count] == 1) {
		PBGitRef *refArgument = [self refForName:[arguments lastObject]];
		if (refArgument) {
			revListSpecifier = [[PBGitRevSpecifier alloc] initWithRef:refArgument];
			revListSpecifier.workingDirectory = workingDirectory;
		}
	}

	if (!revListSpecifier) {
		revListSpecifier = [[PBGitRevSpecifier alloc] initWithParameters:arguments];
		revListSpecifier.workingDirectory = workingDirectory;
	}

	self.currentBranch = [self addBranch:revListSpecifier];
	[PBGitDefaults setShowStageView:NO];
	[self.windowController showHistoryView:self];
}

- (void)handleBranchFilterEventForFilter:(PBGitXBranchFilterType)filter additionalArguments:(NSMutableArray *)arguments inWorkingDirectory:(NSURL *)workingDirectory
{
	self.currentBranchFilter = filter;
	[PBGitDefaults setShowStageView:NO];
	[self.windowController showHistoryView:self];

	// treat any additional arguments as a rev-list specifier
	if ([arguments count] > 1) {
		[arguments removeObjectAtIndex:0];
		[self handleRevListArguments:arguments inWorkingDirectory:workingDirectory];
	}
}

- (void)handleGitXScriptingArguments:(NSAppleEventDescriptor *)argumentsList inWorkingDirectory:(NSURL *)workingDirectory
{
	NSMutableArray *arguments = [NSMutableArray array];
	uint argumentsIndex = 1; // AppleEvent list descriptor's are one based
	while(1) {
		NSAppleEventDescriptor *arg = [argumentsList descriptorAtIndex:argumentsIndex++];
		if (arg)
			[arguments addObject:[arg stringValue]];
		else
			break;
	}

	if (![arguments count])
		return;

	NSString *firstArgument = [arguments objectAtIndex:0];

	if ([firstArgument isEqualToString:@"-c"] || [firstArgument isEqualToString:@"--commit"]) {
		[PBGitDefaults setShowStageView:YES];
		[self.windowController showCommitView:self];
		return;
	}

	if ([firstArgument isEqualToString:@"--all"]) {
		[self handleBranchFilterEventForFilter:kGitXAllBranchesFilter additionalArguments:arguments inWorkingDirectory:workingDirectory];
		return;
	}

	if ([firstArgument isEqualToString:@"--local"]) {
		[self handleBranchFilterEventForFilter:kGitXLocalRemoteBranchesFilter additionalArguments:arguments inWorkingDirectory:workingDirectory];
		return;
	}

	if ([firstArgument isEqualToString:@"--branch"]) {
		[self handleBranchFilterEventForFilter:kGitXSelectedBranchFilter additionalArguments:arguments inWorkingDirectory:workingDirectory];
		return;
	}

	// if the argument is not a known command then treat it as a rev-list specifier
	[self handleRevListArguments:arguments inWorkingDirectory:workingDirectory];
}

// see if the current appleEvent has the command line arguments from the gitx cli
// this could be from an openApplication or an openDocument apple event
// when opening a repository this is called before the sidebar controller gets it's awakeFromNib: message
// if the repository is already open then this is also a good place to catch the event as the window is about to be brought forward
- (void)showWindows
{
	NSAppleEventDescriptor *currentAppleEvent = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];

	if (currentAppleEvent) {
		NSAppleEventDescriptor *eventRecord = [currentAppleEvent paramDescriptorForKeyword:keyAEPropData];

		// on app launch there may be many repositories opening, so double check that this is the right repo
		NSString *path = [[eventRecord paramDescriptorForKeyword:typeFileURL] stringValue];
		if (path) {
			NSURL *workingDirectory = [NSURL URLWithString:path];
			if ([[PBGitRepository gitDirForURL:workingDirectory] isEqual:[self fileURL]]) {
				NSAppleEventDescriptor *argumentsList = [eventRecord paramDescriptorForKeyword:kGitXAEKeyArgumentsList];
				[self handleGitXScriptingArguments:argumentsList inWorkingDirectory:workingDirectory];

				// showWindows may be called more than once during app launch so remove the CLI data after we handle the event
				[currentAppleEvent removeDescriptorWithKeyword:keyAEPropData];
			}
		}
	}

	[super showWindows];
}

// for the scripting bridge
- (void)findInModeScriptCommand:(NSScriptCommand *)command
{
	NSDictionary *arguments = [command arguments];
	NSString *searchString = [arguments objectForKey:kGitXFindSearchStringKey];
	if (searchString) {
		NSInteger mode = [[arguments objectForKey:kGitXFindInModeKey] integerValue];
		[PBGitDefaults setShowStageView:NO];
		[self.windowController showHistoryView:self];
		[self.windowController setHistorySearch:searchString mode:mode];
	}
}


#pragma mark low level

- (int) returnValueForCommand:(NSString *)cmd
{
	int i;
	[self outputForCommand:cmd retValue: &i];
	return i;
}

- (NSFileHandle*) handleForArguments:(NSArray *)args
{
	NSString* gitDirArg = [@"--git-dir=" stringByAppendingString:self.fileURL.path];
	NSMutableArray* arguments =  [NSMutableArray arrayWithObject: gitDirArg];
	[arguments addObjectsFromArray: args];
	return [PBEasyPipe handleForCommand:[PBGitBinary path] withArgs:arguments];
}

- (NSFileHandle*) handleInWorkDirForArguments:(NSArray *)args
{
	NSString* gitDirArg = [@"--git-dir=" stringByAppendingString:self.fileURL.path];
	NSMutableArray* arguments =  [NSMutableArray arrayWithObject: gitDirArg];
	[arguments addObjectsFromArray: args];
	return [PBEasyPipe handleForCommand:[PBGitBinary path] withArgs:arguments inDir:[self workingDirectory]];
}

- (NSFileHandle*) handleForCommand:(NSString *)cmd
{
	NSArray* arguments = [cmd componentsSeparatedByString:@" "];
	return [self handleForArguments:arguments];
}

- (NSString*) outputForCommand:(NSString *)cmd
{
	NSArray* arguments = [cmd componentsSeparatedByString:@" "];
	return [self outputForArguments: arguments];
}

- (NSString*) outputForCommand:(NSString *)str retValue:(int *)ret;
{
	NSArray* arguments = [str componentsSeparatedByString:@" "];
	return [self outputForArguments: arguments retValue: ret];
}

- (NSString*) outputForArguments:(NSArray*) arguments
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir: self.fileURL.path];
}

- (NSString*) outputInWorkdirForArguments:(NSArray*) arguments
{
	NSString *output = [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir: [self workingDirectory]];
	return [output length] > 0 ? output : nil;
}

- (NSString*) outputInWorkdirForArguments:(NSArray *)arguments retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir:[self workingDirectory] retValue: ret];
}

- (NSString*) outputForArguments:(NSArray *)arguments retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir: self.fileURL.path retValue: ret];
}

- (NSString*) outputForArguments:(NSArray *)arguments inputString:(NSString *)input retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path]
							   withArgs:arguments
								  inDir:[self workingDirectory]
							inputString:input
							   retValue: ret];
}

- (NSString *)outputForArguments:(NSArray *)arguments inputString:(NSString *)input byExtendingEnvironment:(NSDictionary *)dict retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path]
							   withArgs:arguments
								  inDir:[self workingDirectory]
				 byExtendingEnvironment:dict
							inputString:input
							   retValue: ret];
}

- (BOOL)executeHook:(NSString *)name output:(NSString **)output
{
	return [self executeHook:name withArgs:[NSArray array] output:output];
}

- (BOOL)executeHook:(NSString *)name withArgs:(NSArray *)arguments output:(NSString **)output
{
	NSString *hookPath = [[[[self fileURL] path] stringByAppendingPathComponent:@"hooks"] stringByAppendingPathComponent:name];
	if (![[NSFileManager defaultManager] isExecutableFileAtPath:hookPath])
		return TRUE;

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
		[self fileURL].path, @"GIT_DIR",
		[[self fileURL].path stringByAppendingPathComponent:@"index"], @"GIT_INDEX_FILE",
		nil
	];

	int ret = 1;
	NSString *_output =	[PBEasyPipe outputForCommand:hookPath withArgs:arguments inDir:[self workingDirectory] byExtendingEnvironment:info inputString:nil retValue:&ret];

	if (output)
		*output = _output;

	return ret == 0;
}

- (NSString *)parseReference:(NSString *)reference
{
	int ret = 1;
	NSString *ref = [self outputForArguments:[NSArray arrayWithObjects: @"rev-parse", @"--verify", reference, nil] retValue: &ret];
	if (ret)
		return nil;

	return ref;
}

- (NSString*) parseSymbolicReference:(NSString*) reference
{
	NSString* ref = [self outputForArguments:[NSArray arrayWithObjects: @"symbolic-ref", @"-q", reference, nil]];
	if ([ref hasPrefix:@"refs/"])
		return ref;

	return nil;
}

- (void) finalize
{
	//DLog(@"Dealloc of repository");
	[super finalize];
}
@end
