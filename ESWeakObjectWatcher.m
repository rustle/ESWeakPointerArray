//
//  ESWeakObjectWatcher.m
//  WeakArray
//
//  Created by Doug Russell on 9/14/12.
//  Copyright (c) 2012 ES. All rights reserved.
//

#import "ESWeakObjectWatcher.h"
#import <objc/runtime.h>

@interface ESWeakObjectWatcher ()
@property (weak, nonatomic) id <ESWeakObjectWatcherDelegate> delegate;
@end

@implementation ESWeakObjectWatcher

+ (instancetype)watcherForObject:(id)object delegate:(id<ESWeakObjectWatcherDelegate>)delegate
{
	ESWeakObjectWatcher *objectWatcher = [[self class] new];
	objectWatcher.delegate = delegate;
const void *key = @"object";
	objc_setAssociatedObject(object, key, objectWatcher, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return objectWatcher;
}

- (void)dealloc
{
	[self.delegate objectDidZero];
}

@end
