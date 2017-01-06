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

@implementation UIApplication (UIInterfaceDirection)

+ (void)load
{
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(userInterfaceLayoutDirection)), class_getInstanceMethod(self, @selector(swizzled_userInterfaceLayoutDirection)));
}

- (UIUserInterfaceLayoutDirection) swizzled_userInterfaceLayoutDirection {
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if ([[userDefaults objectForKey:appLanguage] isEqualToString:@"ar"]) {
		return UIUserInterfaceLayoutDirectionRightToLeft;
	}
	return UIUserInterfaceLayoutDirectionLeftToRight;
}

@end

@implementation UIView (UIInterfaceDirection)

+ (void)load
{
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(semanticContentAttribute)), class_getInstanceMethod(self, @selector(swizzled_semanticContentAttribute)));
}

- (UISemanticContentAttribute) swizzled_semanticContentAttribute {
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if ([[userDefaults objectForKey:appLanguage] isEqualToString:@"ar"]) {
		return UISemanticContentAttributeForceRightToLeft;
	}
	return UISemanticContentAttributeForceLeftToRight;
}

@end


