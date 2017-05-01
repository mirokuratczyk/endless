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

#import <Foundation/Foundation.h>
#import "OrderedDictionary.h"

#define MAX_HOMEPAGES_EQUIVALENT_URLS 10


@interface PsiphonHomePagesEquivalentURLs : NSObject
+ (instancetype)sharedInstance;
- (void)addNewHomePagesEquivalentURLKey:(NSString*) key;
- (id)objectForKey:(id) key;
- (void)setObject:(id)object forKey:(id)key;
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder;
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder;
@end
