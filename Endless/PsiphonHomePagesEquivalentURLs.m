/*
 * Copyright (c) 2017, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "PsiphonHomePagesEquivalentURLs.h"

@implementation PsiphonHomePagesEquivalentURLs {
	
	// A dictionary of all previously received via handshake
	// home pages mapped to their equivalent URLs.
	// We will perform a lookup against this object when we
	// need to determine whether there's an open tab with a home page
	// or its equivalent URL open or we need to open a new tab.
	// Equivalent URLs get populated by a callback from a browser tab.
	//
	// OrderedDictionary is used here for circular FIFO queue like
	// functionality in order to limit the size of this object.
	MutableOrderedDictionary *_homePagesEquivalentURLs;
}

- (id)init {
	self = [super init];
	
	if (self) {
		_homePagesEquivalentURLs = [MutableOrderedDictionary new];
	}
	return self;
}

+ (instancetype)sharedInstance
{
	static dispatch_once_t once;
	static id sharedInstance;
	dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

- (void)addNewHomePagesEquivalentURLKey:(NSString*) key {
	@synchronized (_homePagesEquivalentURLs) {
		// if the size of this object exceeds MAX_HOMEPAGES_EQUIVALENT_URLS
		// then remove entries starting with the oldest
		while([_homePagesEquivalentURLs count] >= MAX_HOMEPAGES_EQUIVALENT_URLS) {
			[_homePagesEquivalentURLs removeObjectAtIndex:0];
		}
		[_homePagesEquivalentURLs insertObject:[NSMutableArray new] forKey:key atIndex:[_homePagesEquivalentURLs count ]];
	}
}

- (id)objectForKey:(id) key {
	@synchronized (_homePagesEquivalentURLs) {
		return[_homePagesEquivalentURLs objectForKey:key];
	}
}

- (void)setObject:(id)object forKey:(id)key {
	@synchronized (_homePagesEquivalentURLs) {
		[_homePagesEquivalentURLs setObject:(id)object forKey:(id)key];
	}
}
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
	@synchronized (_homePagesEquivalentURLs) {
		[_homePagesEquivalentURLs encodeWithCoder:coder];
	}
}
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
	_homePagesEquivalentURLs = [[MutableOrderedDictionary new] initWithCoder:coder];
}


@end
