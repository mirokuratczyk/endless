/*
 * Copyright (c) 2016, Psiphon Inc.
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

// See http://stackoverflow.com/a/20257557

#import <objc/runtime.h>

@implementation NSBundle (Language)

static NSBundle *languageBundle = nil;

+ (void)load
{
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(localizedStringForKey:value:table:)), class_getInstanceMethod(self, @selector(swizzled_localizedStringForKey:value:table:)));
}

+(void)setLanguage:(NSString*)language
{
	languageBundle = language ? [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:language ofType:@"lproj"]] : nil;
    if (languageBundle == nil) {
        languageBundle = [NSBundle mainBundle];
    }
}

- (NSString *)swizzled_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName NS_FORMAT_ARGUMENT(1);
{
	if (languageBundle)
	{
		return [languageBundle swizzled_localizedStringForKey:key value:value table:tableName];
	}
	
	return [self swizzled_localizedStringForKey:key value:value table:tableName];
}

@end
