//
//  ESWeakObjectWatcher.h
//  WeakArray
//
//  Created by Doug Russell on 9/14/12.
//  Copyright (c) 2012 ES. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ESWeakObjectWatcherDelegate <NSObject>

- (void)objectDidZero;

@end

@interface ESWeakObjectWatcher : NSObject

+ (instancetype)watcherForObject:(id)object delegate:(id<ESWeakObjectWatcherDelegate>)delegate;

@end
