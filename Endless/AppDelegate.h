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
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

#import "CookieJar.h"
#import "HSTSCache.h"
#import <PsiphonTunnel/PsiphonTunnel.h>
#import "WebViewController.h"


#define STATE_RESTORE_TRY_KEY @"state_restore_lock"

@interface AppDelegate : UIResponder <UIApplicationDelegate, TunneledAppDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (strong, nonatomic) WebViewController *webViewController;
@property (strong, atomic) CookieJar *cookieJar;
@property (strong, atomic) HSTSCache *hstsCache;

@property (readonly, strong, nonatomic) NSMutableDictionary *searchEngines;

@property (strong, atomic) NSString *defaultUserAgent;

- (BOOL)areTesting;


@property(strong, nonatomic) PsiphonTunnel* psiphonTunnel;
@property NSInteger socksProxyPort;
@property BOOL shouldOpenHomePages;
@property BOOL needsResume;
@property PsiphonConnectionState psiphonConectionState;
@property (strong, nonatomic) NSMutableArray *homePages;

- (void) reloadAndOpenSettings;
- (NSString *) getPsiphonConfig;
- (void) scheduleRunningTunnelServiceRestart;

@end

