//
//  ESWeakPointerArray.m
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

// Array structure based on Cocotron implementation of NSArray, original license included here:

/* Copyright (c) 2006-2007 Christopher J. W. Lloyd
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import "ESWeakPointerArray.h"
#import "ESWeakObjectWatcher.h"

#define uid __unsafe_unretained id

// Cast redeclaration of weak api
extern id objc_loadWeak(uid *location);
extern id objc_storeWeak(uid *location, uid obj);

// This is basically objc_moveWeak, which is documented in the LLVM ARC docs, but isn't public for some reason.
// It differs in that it makes sure from is zeroed after the move.
void es_moveWeak(uid *to, uid *from);

void es_moveWeak(uid *to, uid *from)
{
	__weak id val = objc_loadWeak(from);
	*to = 0;
	(void)objc_storeWeak(to, val);
	if (val != nil)
		(void)objc_storeWeak(from, nil);
}

#define ValidateRange(index) \
if (index >= self->_count) \
	[NSException raise:NSRangeException format:@"index %ld beyond count %lu", index, self->_count];

@interface ESWeakPointerArray () <ESWeakObjectWatcherDelegate>

@end

@implementation ESWeakPointerArray
{
@private
	NSUInteger _count;
	NSUInteger _capacity;
	uid * _objects;
	// Fast enumeration
	bool inFastEnumeration;
	uid * _strongObjects;
	NSUInteger _strongCount;
}

#pragma mark -
#pragma mark Inline Functions
static inline uid * mallocObjects(NSUInteger capacity)
{
	return (uid *)calloc(sizeof(id), capacity);
}

static inline void freeObjects(uid *objects)
{
	free(objects);
}

static inline void reallocObjects(ESWeakPointerArray *self, NSUInteger newCapacity)
{
	self->_capacity = newCapacity;
	
	// We always malloc new memory instead of realloc because when realloc returns new memory, it free the old memory
	// and we need the old memory if new memory is alloced to moved the weak storage.
	// Not very efficient, but it works.
	
	uid * newObjects = mallocObjects(self->_capacity);
	for (NSUInteger i = 0; i < self->_count; i++)
	{
		es_moveWeak(&newObjects[i], &self->_objects[i]);
	}
	freeObjects(self->_objects);
	self->_objects = newObjects;
}

static inline void removeObjectAtIndex(ESWeakPointerArray *self, NSUInteger index)
{
	ValidateRange(index)
	
	objc_storeWeak(&self->_objects[index], nil);
	self->_count--;
	for (NSUInteger i = index; i < self->_count; i++)
	{
		es_moveWeak(&self->_objects[i], &self->_objects[i + 1]);
	}
	
	if (self->_capacity > self->_count * 2)
		reallocObjects(self, self->_count);
}

static inline void storeObjectAtIndex(ESWeakPointerArray *self, id object, NSUInteger index)
{
	[ESWeakObjectWatcher watcherForObject:object delegate:self];
	objc_storeWeak(&self->_objects[index], object);
}

static inline void addObject(ESWeakPointerArray *self, id object)
{
	self->_count++;
	if (self->_count > self->_capacity)
		reallocObjects(self, self->_count * 2);
	storeObjectAtIndex(self, object, self->_count - 1);
}

static inline __weak id objectAtIndex(ESWeakPointerArray *self, NSUInteger index)
{
	return objc_loadWeak(&self->_objects[index]);
}

static inline NSUInteger indexOfObject(ESWeakPointerArray *self, id object)
{
	@autoreleasepool {
		for (NSUInteger i = 0; i < self->_count; i++)
		{
			__weak id objAtIndex = objectAtIndex(self, i);
			if ([objAtIndex isEqual:object])
				return i;
		}
	}
	return NSNotFound;
}

#pragma mark - Init/Dealloc

- (instancetype)init
{
	return [self initWithCapacity:1];
}

- (instancetype)initWithCapacity:(NSUInteger)numItems
{
	self = [super init];
	if (self)
	{
		_count = 0;
		_capacity = numItems;
		_objects = mallocObjects(_capacity);
	}
	return self;
}

- (instancetype)initWithArray:(NSArray *)array
{
	self = [self initWithCapacity:[array count]];
	if (self)
	{
		for (id object in array)
		{
			addObject(self, object);
		}
	}
	return self;
}

#define MethodNotImplementedException [NSException raise:@"MethodNotImplementedException" format:@"%@ not implemented", NSStringFromSelector(_cmd)]

- (instancetype)initWithArray:(NSArray *)array copyItems:(BOOL)flag
{
	MethodNotImplementedException;
	return nil;
}

- (instancetype)initWithContentsOfURL:(NSURL *)url
{
	MethodNotImplementedException;
	return nil;
}

- (instancetype)initWithContentsOfFile:(NSString *)path
{
	MethodNotImplementedException;
	return nil;
}

- (instancetype)initWithObjects:(const id [])objects count:(NSUInteger)cnt
{
	MethodNotImplementedException;
	return nil;
}

- (instancetype)initWithObjects:(id)firstObj, ...
{
	NSUInteger count = 0;
	va_list arguments;
	if (firstObj != nil)
	{
		va_start(arguments,firstObj);
		count = 1;
		while(va_arg(arguments,id) != nil)
			count++;
		va_end(arguments);
	}
	self = [self initWithCapacity:count];
	if (self)
	{
		if (firstObj != nil)
		{
			va_start(arguments,firstObj);
			_count++;
			storeObjectAtIndex(self, firstObj, 0);
			for (NSUInteger i = 1; i < count; i++)
			{
				_count++;
				storeObjectAtIndex(self, va_arg(arguments,id), i);
			}
			va_end(arguments);
		}
	}
	return self;
}

- (void)dealloc
{
	freeObjects(_objects);
	freeObjects(_strongObjects);
}

- (void)getObjects:(__unsafe_unretained id *)objects
{
	MethodNotImplementedException;
}

- (void)getObjects:(__unsafe_unretained id *)objects range:(NSRange)aRange
{
	MethodNotImplementedException;
}

#pragma mark - Get

- (__weak id)objectAtIndex:(NSUInteger)index 
{
	ValidateRange(index)
	
	return objectAtIndex(self, index);
}

- (__weak id)lastObject 
{
	if (_count == 0)
		return nil;
	return [self objectAtIndex:_count - 1];
}

- (NSUInteger)indexOfObject:(__weak id)object
{
	return indexOfObject(self, object);
}

- (BOOL)containsObject:(__weak id)object
{
	return (indexOfObject(self, object) != NSNotFound) ? YES : NO;
}

#pragma mark -
#pragma mark 
- (NSUInteger)count
{
	return _count;
}

- (NSString *)componentsJoinedByString:(NSString *)separator 
{
	NSMutableString *string = [NSMutableString stringWithCapacity:256];
	NSUInteger count = [self count];
	for (NSUInteger i = 0; i < count; i++)
	{
		NSString *description = [[self objectAtIndex:i] description];
		if (!description)
			description = @"(null)";
		[string appendString:description];
		if (i + 1 < count)
			[string appendString:separator];
	}
	return string;
}

- (NSString *)descriptionWithLocale:(id)locale
{
	return [NSString stringWithFormat:@"<%@ : %p> {\n\t%@\n}", NSStringFromClass([self class]), self, [self componentsJoinedByString:@", \n\t"]];
}

#pragma mark - Add

- (void)addObject:(__weak id)object
{
	_count++;
	if (_count > _capacity)
		reallocObjects(self, _count * 2);
	storeObjectAtIndex(self, object, self->_count - 1);
}

- (void)insertObject:(__weak id)object atIndex:(NSUInteger)index
{
	ValidateRange(index)
	
	_count++;
	if (_count > _capacity)
		reallocObjects(self, _count * 2);
	if (_count > 1)
	{
		for (NSInteger i = _count - 1; i > index && i > 0; i--)
		{
			_objects[i] = _objects[i - 1];
		}
	}
	storeObjectAtIndex(self, object, index);
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:object
{
	ValidateRange(index)
	storeObjectAtIndex(self, object, index);
}

#pragma mark - Remove

- (void)removeObjectAtIndex:(NSUInteger)index
{
	removeObjectAtIndex(self, index);
}

- (void)removeAllObjects
{
	_count = 0;
	if (self->_capacity > 8)
	{
		self->_capacity = 8;
		self->_objects = (uid *)NSZoneRealloc(NULL, self->_objects, sizeof(id) * self->_capacity);
	}
}

- (void)removeAllNil
{
	NSInteger count = [self count];
	while (--count >= 0)
	{
		id objectAtIndex = [self objectAtIndex:count];
		if (objectAtIndex == nil)
			removeObjectAtIndex(self, count);
	}
}

- (void)removeLastObject
{
	if (_count == 0)
		[NSException raise:NSRangeException format:@"index %d beyond count %lu", 1, _count];
	
	removeObjectAtIndex(self, _count - 1);
}

- (void)removeObject:(__weak id)object
{
	NSInteger count = [self count];
	while (--count >= 0)
	{
		id objectAtIndex = [self objectAtIndex:count];
		if ([objectAtIndex isEqual:object])
			removeObjectAtIndex(self, count);
	}
}

#pragma mark - Sorting

- (void)sortUsingFunction:(NSComparisonResult (*)(id, id, void *))compare context:(void *)context
{
	MethodNotImplementedException;
}

- (void)makeObjectsPerformSelector:(SEL)selector
{
	NSUInteger count = [self count];
	for (NSInteger i = 0; i < count; i++)
	{
#pragma GCC diagnostic ignored "-Warc-performSelector-leaks"
		[[self objectAtIndex:i] performSelector:selector];
#pragma GCC diagnostic warning "-Warc-performSelector-leaks"
	}
}

#pragma mark - Fast Enumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id [])buffer count:(NSUInteger)len
{
	if (!inFastEnumeration)
	{
		inFastEnumeration = true;
		_strongObjects = mallocObjects(_count);
		for (_strongCount = 0; _strongCount < _count; _strongCount++)
		{
			__strong id obj = [self objectAtIndex:_strongCount];
			if (obj)
				_strongObjects[_strongCount] = (__bridge id)CFBridgingRetain(obj);
		}
	}
	
	if (state->state >= _strongCount)
    {
		for (NSUInteger i = 0; i < _strongCount; i++)
		{
			CFRelease((__bridge CFTypeRef)(_strongObjects[i]));
		}
		freeObjects(_strongObjects);
		_strongObjects = nil;
		inFastEnumeration = false;
        return 0;
    }
	
	state->itemsPtr = _strongObjects;
	state->state = _count;
	CFTypeRef cfSelf = (__bridge CFTypeRef)self;
	state->mutationsPtr = (unsigned long *)cfSelf;
	
	return _strongCount;
}

#pragma mark - 

- (void)objectDidZero
{
	// This almost certainly has thread safety issues
	// when an array member is dealloced on a thread
	// other than the one using the array
	[self removeAllNil];
}

@end
