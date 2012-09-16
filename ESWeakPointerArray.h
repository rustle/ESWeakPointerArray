//
//  ESWeakPointerArray.h
//
//  Created by Doug Russell
//  Copyright (c) 2012 Doug Russell. All rights reserved.
//  
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//  
//  http://www.apache.org/licenses/LICENSE-2.0
//  
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//  

#import <Foundation/Foundation.h>

/**
 * 
 */

@interface ESWeakPointerArray : NSMutableArray

/**
 * Inserts a given object at the end of the array.
 * @param object The object to add to the array's content. This value can be nil.
 */
- (void)addObject:(id)object;
/**
 * Inserts a given object into the array's contents at a given index.
 * @param object The object to add to the array's content. This value can be nil.
 * @param index The index in the array at which to insert anObject. This value must not be greater than the count of elements in the array.
 * @warning Important: Raises an NSRangeException if index is greater than the number of elements in the array.
 */
- (void)insertObject:(id)object atIndex:(NSUInteger)index;
/**
 * 
 */
- (__weak id)objectAtIndex:(NSUInteger)index;
/**
 * 
 */
- (void)removeObject:(id)object;
/**
 * 
 */
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)object;
/**
 * 
 */
- (__weak id)lastObject;
/**
 * 
 */
- (void)removeObjectAtIndex:(NSUInteger)index;
/**
 * 
 */
- (NSUInteger)indexOfObject:(id)object;
/**
 * 
 */
- (BOOL)containsObject:(id)object;
/**
 * 
 */
- (NSString *)componentsJoinedByString:(NSString *)separator;

@end
