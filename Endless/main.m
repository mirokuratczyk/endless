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
 *
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

#ifndef TRACE
extern void _NSSetLogCStringFunction(void(*)(const char*, unsigned, BOOL));
static void silentLogFunc(const char *string, unsigned length, BOOL withSyslogBanner) {}
#endif

int main(int argc, char * argv[]) {
	//disable NSLog in non-debug mode
#ifndef TRACE
	_NSSetLogCStringFunction(silentLogFunc);
#endif
	@autoreleasepool {
		//ignore SIGPIPE
		signal(SIGPIPE, SIG_IGN);
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
