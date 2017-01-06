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

#import <objc/runtime.h>

@interface AppLanguageHelper : NSObject
+ (BOOL) isRTLLanguage:(NSString*)language;
@end

@implementation AppLanguageHelper

+ (BOOL) isRTLLanguage:(NSString*)language {
	static NSArray *rtlLanguages;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		rtlLanguages = @[@"ar", @"fa", @"he"];
	});
	
	BOOL ret = [rtlLanguages containsObject:language];
	return ret;
}
@end

@implementation UIApplication (UIInterfaceDirection)

+ (void)load
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(userInterfaceLayoutDirection)), class_getInstanceMethod(self, @selector(swizzled_userInterfaceLayoutDirection)));
	});
}

- (UIUserInterfaceLayoutDirection) swizzled_userInterfaceLayoutDirection {
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSString* language = [userDefaults objectForKey:appLanguage];
	if (language == nil) {
		return [self swizzled_userInterfaceLayoutDirection];
	}
	
	if ([AppLanguageHelper isRTLLanguage:language]) {
		return UIUserInterfaceLayoutDirectionRightToLeft;
	}
	
	return UIUserInterfaceLayoutDirectionLeftToRight;
}

@end

@implementation UIView (UIInterfaceDirection)

+ (void)load
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(semanticContentAttribute)), class_getInstanceMethod(self, @selector(swizzled_semanticContentAttribute)));
	});
}

- (UISemanticContentAttribute) swizzled_semanticContentAttribute {
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSString* language = [userDefaults objectForKey:appLanguage];
	
	if (language == nil) {
		return [self swizzled_semanticContentAttribute];
	}
	
	// override if in-app language is RTL
	if ([AppLanguageHelper isRTLLanguage:language]) {
		return UISemanticContentAttributeForceRightToLeft;
	}
	UISemanticContentAttribute originalSemanticAttribute = [self swizzled_semanticContentAttribute];
	if (originalSemanticAttribute == UISemanticContentAttributeForceLeftToRight)
	{
		// override if in-app language is RTL
		if ([AppLanguageHelper isRTLLanguage:language]) {
			return UISemanticContentAttributeForceRightToLeft;
		}
	}
	
	return originalSemanticAttribute;
}

@end

// See http://stackoverflow.com/a/20257557
@implementation NSBundle (Language)

+ (void)load
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		method_exchangeImplementations(class_getInstanceMethod(self, @selector(localizedStringForKey:value:table:)), class_getInstanceMethod(self, @selector(swizzled_localizedStringForKey:value:table:)));
	});
}

- (NSString *)swizzled_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName NS_FORMAT_ARGUMENT(1);
{
	NSBundle *currentBundle = nil;
	NSBundle *languageBundle  = nil;
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSString* language = [userDefaults objectForKey:appLanguage];
	if([[language stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""]) {
		language = nil;
	}
	
	
	// Use default localization if language is not set
	if( language == nil) {
		return [self swizzled_localizedStringForKey:key value:value table:tableName];
	} else {
		// Determine if self bundle is one of our own, either main or IASK
		if ([[self bundlePath] isEqualToString:[[NSBundle mainBundle] bundlePath]] ||
			[[self bundlePath] isEqualToString:([[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"InAppSettings.bundle"])]) {
			currentBundle = [NSBundle mainBundle];
		} else {
			currentBundle = self;
		}
	}
	
	languageBundle = [NSBundle bundleWithPath:[currentBundle pathForResource:language ofType:@"lproj"]];
	if (languageBundle == nil) {
		languageBundle = currentBundle;
	}
	
	return [languageBundle swizzled_localizedStringForKey:key value:value table:tableName];
}
@end



