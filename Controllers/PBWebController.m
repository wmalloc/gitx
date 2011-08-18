//
//  PBWebController.m
//  GitX
//
//  Created by Pieter de Bie on 08-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBWebController.h"
#import "PBGitRepository.h"
#import "PBGitXProtocol.h"
#import "PBGitDefaults.h"

#include <SystemConfiguration/SCNetworkReachability.h>

@interface PBWebController()
- (void)preferencesChangedWithNotification:(NSNotification *)theNotification;
@end

@implementation PBWebController

@synthesize startFile, repository;

- (void) awakeFromNib
{
	callbacks = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsObjectPointerPersonality|NSPointerFunctionsStrongMemory) valueOptions:(NSPointerFunctionsObjectPointerPersonality|NSPointerFunctionsStrongMemory)];

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
	       selector:@selector(preferencesChangedWithNotification:)
		   name:NSUserDefaultsDidChangeNotification
		 object:nil];

	finishedLoading = NO;
	[view setUIDelegate:self];
	[view setFrameLoadDelegate:self];
	[view setResourceLoadDelegate:self];

	NSURL *resourceURL = [[[NSBundle mainBundle] resourceURL] URLByStandardizingPath];
	NSURL *baseURL = [[resourceURL URLByAppendingPathComponent:@"html/views"] URLByAppendingPathComponent:startFile];
	
	NSURL *fileURL = [baseURL URLByAppendingPathComponent:@"index.html"];
	[[view mainFrame] loadRequest:[NSURLRequest requestWithURL:fileURL]];
}

- (WebScriptObject *) script
{
	return [view windowScriptObject];
}

- (void)closeView
{
	if (view) {
		[[self script] setValue:nil forKey:@"Controller"];
		[view close];
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

# pragma mark Delegate methods

- (void)webView:(WebView *)sender didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame
{
	id script = [view windowScriptObject];
	[script setValue: self forKey:@"Controller"];
}

- (void) webView:(id) v didFinishLoadForFrame:(id) frame
{
	finishedLoading = YES;
	if ([self respondsToSelector:@selector(didLoad)])
		[self performSelector:@selector(didLoad)];
}

- (void)webView:(WebView *)webView addMessageToConsole:(NSDictionary *)dictionary
{
	DLog(@"Error from webkit: %@", dictionary);
}

- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame
{
	DLog(@"Message from webkit: %@", message);
}

- (NSURLRequest *)webView:(WebView *)sender
                 resource:(id)identifier
          willSendRequest:(NSURLRequest *)request
         redirectResponse:(NSURLResponse *)redirectResponse
           fromDataSource:(WebDataSource *)dataSource
{
	if (!self.repository)
		return request;

	// TODO: Change this to canInitWithRequest
	NSString *scheme = [[[request URL] scheme] lowercaseString];
	if ([scheme isEqualToString:@"gitx"]) {
		NSMutableURLRequest *newRequest = [request mutableCopy];
		[newRequest setRepository:self.repository];
		return newRequest;
	}

	return request;
}


+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
	return NO;
}

#pragma mark Functions to be used from JavaScript

- (void) log: (NSString*) logMessage
{
	DLog(@"%@", logMessage);
}

- (BOOL) isReachable:(NSString *)hostname
{
    SCNetworkReachabilityRef target;
    SCNetworkConnectionFlags flags = 0;
    Boolean reachable;
    target = SCNetworkReachabilityCreateWithName(NULL, [hostname cStringUsingEncoding:NSASCIIStringEncoding]);
    reachable = SCNetworkReachabilityGetFlags(target, &flags);
	CFRelease(target);

	if (!reachable)
		return FALSE;

	// If a connection is required, then it's not reachable
	if (flags & (kSCNetworkFlagsConnectionRequired | kSCNetworkFlagsConnectionAutomatic | kSCNetworkFlagsInterventionRequired))
		return FALSE;

	return flags > 0;
}

- (BOOL) isFeatureEnabled:(NSString *)feature
{
	if([feature isEqualToString:@"gravatar"])
		return [PBGitDefaults isGravatarEnabled];
	else if([feature isEqualToString:@"gist"])
		return [PBGitDefaults isGistEnabled];
	else if([feature isEqualToString:@"confirmGist"])
		return [PBGitDefaults confirmPublicGists];
	else if([feature isEqualToString:@"publicGist"])
		return [PBGitDefaults isGistPublic];
	else
		return YES;
}

#pragma mark Using async function from JS

- (void) runCommand:(WebScriptObject *)arguments inRepository:(PBGitRepository *)repo callBack:(WebScriptObject *)callBack
{
	// The JS bridge does not handle JS Arrays, even though the docs say it does. So, we convert it ourselves.
	int length = [[arguments valueForKey:@"length"] intValue];
	NSMutableArray *realArguments = [NSMutableArray arrayWithCapacity:length];
	int i = 0;
	for (i = 0; i < length; i++)
		[realArguments addObject:[arguments webScriptValueAtIndex:i]];

	NSFileHandle *handle = [repo handleInWorkDirForArguments:realArguments];
	[callbacks setObject:callBack forKey:handle];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(JSRunCommandDone:) name:NSFileHandleReadToEndOfFileCompletionNotification object:handle]; 
	[handle readToEndOfFileInBackgroundAndNotify];
}

- (void) callSelector:(NSString *)selectorString onObject:(id)object callBack:(WebScriptObject *)callBack
{
	NSArray *arguments = [NSArray arrayWithObjects:selectorString, object, nil];
	NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(runInThread:) object:arguments];
	[callbacks setObject:callBack forKey:thread];
	[thread start];
}

- (void) runInThread:(NSArray *)arguments
{
	SEL selector = NSSelectorFromString([arguments objectAtIndex:0]);
	id object = [arguments objectAtIndex:1];
	id ret = [object performSelector:selector];
	NSArray *returnArray = [NSArray arrayWithObjects:[NSThread currentThread], ret, nil];
	[self performSelectorOnMainThread:@selector(threadFinished:) withObject:returnArray waitUntilDone:NO];
}


- (void) returnCallBackForObject:(id)object withData:(id)data
{
	WebScriptObject *a = [callbacks objectForKey: object];
	if (!a) {
		DLog(@"Could not find a callback for object: %@", object);
		return;
	}

	[callbacks removeObjectForKey:object];
	[a callWebScriptMethod:@"call" withArguments:[NSArray arrayWithObjects:@"", data, nil]];
}

- (void) threadFinished:(NSArray *)arguments
{
	[self returnCallBackForObject:[arguments objectAtIndex:0] withData:[arguments objectAtIndex:1]];
}

- (void) JSRunCommandDone:(NSNotification *)notification
{
	NSString *data = [[NSString alloc] initWithData:[[notification userInfo] valueForKey:NSFileHandleNotificationDataItem] encoding:NSUTF8StringEncoding];
	[self returnCallBackForObject:[notification object] withData:data];
}

- (void) preferencesChanged
{
}

- (void)preferencesChangedWithNotification:(NSNotification *)theNotification
{
	[self preferencesChanged];
}

@synthesize view;
@synthesize finishedLoading;
@synthesize callbacks;
@end
