//
//  PBGitRevSpecifier.m
//  GitX
//
//  Created by Pieter de Bie on 12-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRevSpecifier.h"


@implementation PBGitRevSpecifier

@synthesize parameters, description, helpText, workingDirectory;
@synthesize isSimpleRef;
@synthesize behind,ahead;


// internal designated init
- (id) initWithParameters:(NSArray *)params description:(NSString *)descrip
{
	parameters = params;
	description = descrip;

	if (([parameters count] > 1) || ([parameters count] == 0))
		isSimpleRef =  NO;
	else {
		NSString *param = [parameters objectAtIndex:0];
		if ([param hasPrefix:@"-"] ||
			[param rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"^@{}~:"]].location != NSNotFound ||
			[param rangeOfString:@".."].location != NSNotFound)
			isSimpleRef =  NO;
		else
			isSimpleRef =  YES;
	}

	return self;
}

- (id) initWithParameters:(NSArray *)params
{
	[self initWithParameters:params description:nil];
	return self;
}

- (id) initWithRef:(PBGitRef *)ref
{
	[self initWithParameters:[NSArray arrayWithObject:ref.ref] description:ref.shortName];
	return self;
}

- (id) initWithCoder:(NSCoder *)coder
{
	[self initWithParameters:[coder decodeObjectForKey:@"Parameters"] description:[coder decodeObjectForKey:@"Description"]];
	return self;
}

+ (PBGitRevSpecifier *)allBranchesRevSpec
{
	return [[PBGitRevSpecifier alloc] initWithParameters:[NSArray arrayWithObject:@"--all"] description:@"All branches"];
}

+ (PBGitRevSpecifier *)localBranchesRevSpec
{
	return [[PBGitRevSpecifier alloc] initWithParameters:[NSArray arrayWithObject:@"--branches"] description:@"Local branches"];
}

- (NSString*) simpleRef
{
	if (![self isSimpleRef])
		return nil;
	return [parameters objectAtIndex:0];
}

- (PBGitRef *) ref
{
	if (![self isSimpleRef])
		return nil;

	return [PBGitRef refFromString:[self simpleRef]];
}

- (NSString *) description
{
	if (!description)
		description = [parameters componentsJoinedByString:@" "];

	return description;
}

- (NSString *) title
{
	NSString *title = nil;
	
	if ([self.description isEqualToString:@"HEAD"])
		title = @"detached HEAD";
	else if ([self isSimpleRef])
		title = [[self ref] shortName];
	else if ([self.description hasPrefix:@"-S"])
		title = [self.description substringFromIndex:[@"-S" length]];
	else if ([self.description hasPrefix:@"HEAD -- "])
		title = [self.description substringFromIndex:[@"HEAD -- " length]];
	else if ([self.description hasPrefix:@"-- "])
		title = [self.description substringFromIndex:[@"-- " length]];
	else if ([self.description hasPrefix:@"--left-right "])
		title = [self.description substringFromIndex:[@"--left-right " length]];
	else
		title = self.description;
	
	return [NSString stringWithFormat:@"\"%@\"", title];
}

- (BOOL) hasPathLimiter;
{
	for (NSString* param in parameters)
		if ([param isEqualToString:@"--"])
			return YES;
	return NO;
}

- (BOOL) hasLeftRight
{
	for (NSString* param in parameters)
		if ([param isEqualToString:@"--left-right"])
			return YES;
	return NO;
}

- (BOOL) isEqual:(PBGitRevSpecifier *)other
{
	if ([self isSimpleRef] ^ [other isSimpleRef])
		return NO;
	
	if ([self isSimpleRef])
		return [[[self parameters] objectAtIndex:0] isEqualToString:[other.parameters objectAtIndex:0]];

	return [self.description isEqualToString:other.description];
}

- (NSUInteger) hash
{
	if ([self isSimpleRef])
		return [[[self parameters] objectAtIndex:0] hash];

	return [self.description hash];
}

- (BOOL) isAllBranchesRev
{
	return [self isEqual:[PBGitRevSpecifier allBranchesRevSpec]];
}

- (BOOL) isLocalBranchesRev
{
	return [self isEqual:[PBGitRevSpecifier localBranchesRevSpec]];
}

- (void) encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:description forKey:@"Description"];
	[coder encodeObject:parameters forKey:@"Parameters"];
}

- (id)copyWithZone:(NSZone *)zone
{
    PBGitRevSpecifier *copy = [[[self class] allocWithZone:zone] initWithParameters:[self.parameters copy]];
    copy.description = [self.description copy];
	copy.workingDirectory = [self.workingDirectory copy];

    return copy;
}

@end
