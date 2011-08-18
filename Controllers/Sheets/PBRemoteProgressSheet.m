//
//  PBRemoteProgressSheetController.m
//  GitX
//
//  Created by Nathan Kinsinger on 12/6/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import "PBRemoteProgressSheet.h"
#import "PBGitWindowController.h"
#import "PBGitRepository.h"
#import "PBGitBinary.h"
#import "PBEasyPipe.h"



NSString * const kGitXProgressDescription        = @"PBGitXProgressDescription";
NSString * const kGitXProgressSuccessDescription = @"PBGitXProgressSuccessDescription";
NSString * const kGitXProgressSuccessInfo        = @"PBGitXProgressSuccessInfo";
NSString * const kGitXProgressErrorDescription   = @"PBGitXProgressErrorDescription";
NSString * const kGitXProgressErrorInfo          = @"PBGitXProgressErrorInfo";



@interface PBRemoteProgressSheet ()

- (void) beginRemoteProgressSheetForArguments:(NSArray *)args title:(NSString *)theTitle description:(NSString *)theDescription inDir:(NSString *)dir windowController:(NSWindowController *)windowController;
- (void) showSuccessMessage;
- (void) showErrorMessage;

- (NSString *) progressTitle;
- (NSString *) successTitle;
- (NSString *) successDescription;
- (NSString *) errorTitle;
- (NSString *) errorDescription;
- (NSString *) commandDescription;
- (NSString *) standardOutputDescription;
- (NSString *) standardErrorDescription;

@end



@implementation PBRemoteProgressSheet


@synthesize progressDescription;
@synthesize progressIndicator;



#pragma mark -
#pragma mark PBRemoteProgressSheet

+ (void) beginRemoteProgressSheetForArguments:(NSArray *)args title:(NSString *)theTitle description:(NSString *)theDescription inDir:(NSString *)dir windowController:(NSWindowController *)windowController
{
	PBRemoteProgressSheet *sheet = [[self alloc] initWithWindowNibName:@"PBRemoteProgressSheet"];
	[sheet beginRemoteProgressSheetForArguments:args title:theTitle description:theDescription inDir:dir windowController:windowController];
}


+ (void) beginRemoteProgressSheetForArguments:(NSArray *)args title:(NSString *)theTitle description:(NSString *)theDescription  inRepository:(PBGitRepository *)repo
{
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:args title:theTitle description:theDescription inDir:[repo workingDirectory] windowController:repo.windowController];
}


- (void) beginRemoteProgressSheetForArguments:(NSArray *)args title:(NSString *)theTitle description:(NSString *)theDescription inDir:(NSString *)dir windowController:(NSWindowController *)windowController
{
	controller  = windowController;
	arguments   = args;
	title       = theTitle;
	description = theDescription;

	[self window]; // loads the window (if it wasn't already)

	// resize window if the description is larger than the default text field
	NSRect originalFrame = [self.progressDescription frame];
	[self.progressDescription setStringValue:[self progressTitle]];
	NSAttributedString *attributedTitle = [self.progressDescription attributedStringValue];
	NSSize boundingSize = originalFrame.size;
	boundingSize.height = 0.0f;
	NSRect boundingRect = [attributedTitle boundingRectWithSize:boundingSize options:NSStringDrawingUsesLineFragmentOrigin];
	CGFloat heightDelta = boundingRect.size.height - originalFrame.size.height;
	if (heightDelta > 0.0f) {
		NSRect windowFrame = [[self window] frame];
		windowFrame.size.height += heightDelta;
		[[self window] setFrame:windowFrame display:NO];
	}

	[self.progressIndicator startAnimation:nil];
	[NSApp beginSheet:[self window] modalForWindow:[controller window] modalDelegate:self didEndSelector:nil contextInfo:nil];

	gitTask = [PBEasyPipe taskForCommand:[PBGitBinary path] withArgs:arguments inDir:dir];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskCompleted:) name:NSTaskDidTerminateNotification object:gitTask];

	// having intermittent problem with long running git tasks not sending a termination notice, so periodically check whether the task is done
	taskTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(checkTask:) userInfo:nil repeats:YES];

	[gitTask launch];
}



#pragma mark Notifications

- (void) taskCompleted:(NSNotification *)notification
{
	[taskTimer invalidate];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[self.progressIndicator stopAnimation:nil];
	[NSApp endSheet:[self window]];
	[[self window] orderOut:self];

	returnCode = [gitTask terminationStatus];
	if (returnCode)
		[self showErrorMessage];
	else
		[self showSuccessMessage];

	if ([controller respondsToSelector:@selector(repository)])
		[[(PBGitWindowController *)controller repository] reloadRefs];
}



#pragma mark taskTimer

- (void) checkTask:(NSTimer *)timer
{
	if (![gitTask isRunning]) {
		DLog(@"[%@ %@] gitTask terminated without notification", [self class], NSStringFromSelector(_cmd));
		[self taskCompleted:nil];
	}
}



#pragma mark Messages

- (void) showSuccessMessage
{
	NSMutableString *info = [NSMutableString string];
	[info appendString:[self successDescription]];
	[info appendString:[self commandDescription]];
	[info appendString:[self standardOutputDescription]];

	if ([controller respondsToSelector:@selector(showMessageSheet:infoText:)])
		[(PBGitWindowController *)controller showMessageSheet:[self successTitle] infoText:info];
}


- (void) showErrorMessage
{
	NSMutableString *info = [NSMutableString string];
	[info appendString:[self errorDescription]];
	[info appendString:[self commandDescription]];
	[info appendString:[self standardOutputDescription]];
	[info appendString:[self standardErrorDescription]];

	NSDictionary *errorUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   [self errorTitle], NSLocalizedDescriptionKey,
								   info, NSLocalizedRecoverySuggestionErrorKey,
								   nil];
	NSError *error = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0 userInfo:errorUserInfo];

	if ([controller respondsToSelector:@selector(showErrorSheet:)])
		[(PBGitWindowController *)controller showErrorSheet:error];
}



#pragma mark Display Strings

- (NSString *) progressTitle
{
	NSString *progress = description;
	if (!progress)
		progress = @"Operation in progress.";

	return progress;
}


- (NSString *) successTitle
{
	NSString *success = title;
	if (!success)
		success = @"Operation";

	return [success stringByAppendingString:@" completed."];
}


- (NSString *) successDescription
{
	NSString *info = description;
	if (!info)
		return @"";

	return [info stringByAppendingString:@" completed successfully.\n\n"];
}


- (NSString *) errorTitle
{
	NSString *error = title;
	if (!error)
		error = @"Operation";

	return [error stringByAppendingString:@" failed."];
}


- (NSString *) errorDescription
{
	NSString *info = description;
	if (!info)
		return @"";

	return [info stringByAppendingString:@" encountered an error.\n\n"];
}


- (NSString *) commandDescription
{
	if (!arguments || ([arguments count] == 0))
		return @"";

	return [NSString stringWithFormat:@"command: git %@", [arguments componentsJoinedByString:@" "]];
}


- (NSString *) standardOutputDescription
{
	if (!gitTask || [gitTask isRunning])
		return @"";

	NSData *data = [[[gitTask standardOutput] fileHandleForReading] readDataToEndOfFile];
	NSString *standardOutput = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	if ([standardOutput isEqualToString:@""])
		return @"";

	return [NSString stringWithFormat:@"\n\n%@", standardOutput];
}


- (NSString *) standardErrorDescription
{
	if (!gitTask || [gitTask isRunning])
		return @"";

	NSData *data = [[[gitTask standardError] fileHandleForReading] readDataToEndOfFile];
	NSString *standardError = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	if ([standardError isEqualToString:@""])
		return [NSString stringWithFormat:@"\nerror = %d", returnCode];

	return [NSString stringWithFormat:@"\n\n%@\nerror = %d", standardError, returnCode];
}


@synthesize controller;
@synthesize arguments;
@synthesize title;
@synthesize description;
@synthesize gitTask;
@synthesize returnCode;
@synthesize taskTimer;
@end
