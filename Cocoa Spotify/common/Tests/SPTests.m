//
//  SPTests.m
//  CocoaLibSpotify Mac Framework
//
//  Created by Daniel Kennett on 10/05/2012.
/*
 Copyright (c) 2011, Spotify AB
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of Spotify AB nor the names of its contributors may 
 be used to endorse or promote products derived from this software 
 without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL SPOTIFY AB BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
 OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SPTests.h"
#import <objc/runtime.h>

@interface SPTests ()
@property (nonatomic, readwrite, copy) NSArray *testSelectorNames;
@property (nonatomic, readwrite, copy) void (^completionBlock)(NSUInteger, NSUInteger);
@end

@implementation SPTests {
	NSUInteger nextTestIndex;
	NSUInteger passCount;
	NSUInteger failCount;
}

@synthesize testSelectorNames;
@synthesize completionBlock;

-(void)passTest:(SEL)testSelector {
	printf(" Passed.\n");
	passCount++;
	[self runNextTest];
}

-(void)failTest:(SEL)testSelector format:(NSString *)format, ... {
	
	va_list src, dest;
	va_start(src, format);
	va_copy(dest, src);
	va_end(src);
	NSString *msg = [[NSString alloc] initWithFormat:format arguments:dest];
	
	printf(" Failed. Reason: %s\n", msg.UTF8String);
	failCount++;
	[self runNextTest];
}

-(NSString *)prettyNameForTestSelector:(SEL)selector {
	
	NSString *selString = NSStringFromSelector(selector);
	
	if ([selString hasPrefix:@"test"])
		selString = [selString stringByReplacingCharactersInRange:NSMakeRange(0, @"test".length) withString:@""];
	
	// Skip leading digits
	NSScanner *scanner = [NSScanner scannerWithString:selString];
	[scanner scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
	return [selString substringFromIndex:[scanner scanLocation]];
}

#pragma mark - Automatic Running

-(void)runTests:(void (^)(NSUInteger passCount, NSUInteger failCount))block {
	
	if (self.testSelectorNames != nil) {
		self.testSelectorNames = nil;
	}
	
	self.completionBlock = block;
	
	unsigned int methodCount = 0;
	Method *testList = class_copyMethodList([self class], &methodCount);
	
	NSMutableArray *testMethods = [NSMutableArray arrayWithCapacity:methodCount];
	
	for (unsigned int currentMethodIndex = 0; currentMethodIndex < methodCount; currentMethodIndex++) {
		Method method = testList[currentMethodIndex];
		SEL methodSel = method_getName(method);
		NSString *methodName = NSStringFromSelector(methodSel);
		if ([methodName hasPrefix:@"test"])
			[testMethods addObject:methodName];
	}
	
	self.testSelectorNames = [testMethods sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	nextTestIndex = 0;
	passCount = 0;
	failCount = 0;
	free(testList);
	
	printf("---- Starting %lu tests in %s ----\n", (unsigned long)self.testSelectorNames.count, NSStringFromClass([self class]).UTF8String);
	[self runNextTest];
}

-(void)runNextTest {
	
	if (self.testSelectorNames == nil)
		return; // Not part of auto-running
	
	if (nextTestIndex >= self.testSelectorNames.count) {
		
		self.testSelectorNames = nil;
		nextTestIndex = 0;
		
		[self testsCompleted];
		return;
	}
	
	SEL methodName = NSSelectorFromString([self.testSelectorNames objectAtIndex:nextTestIndex]);
	nextTestIndex++;
	
	if ([NSStringFromSelector(methodName) hasPrefix:@"test"]) {
		printf("Running test %s...", [self prettyNameForTestSelector:methodName].UTF8String);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[self performSelector:methodName];
#pragma clang diagnostic pop
	} else {
		[self runNextTest];
	}
}

-(void)testsCompleted {
	printf("---- Tests in %s complete with %lu passed, %lu failed ----\n", NSStringFromClass([self class]).UTF8String, (unsigned long)passCount, (unsigned long)failCount);
	if (self.completionBlock) self.completionBlock(passCount, failCount);
}

@end
