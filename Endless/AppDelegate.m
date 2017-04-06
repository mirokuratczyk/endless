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

#import <arpa/inet.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <AudioToolbox/AudioServices.h>
#import <CoreFoundation/CFSocket.h>

#import "AppDelegate.h"
#import "Bookmark.h"
#import "HTTPSEverywhere.h"
#import "PsiphonData.h"
#import "RegionAdapter.h"
#import "UpstreamProxySettings.h"
#import "URLInterceptor.h"


@implementation AppDelegate {
    BOOL _needsResume;
    BOOL _shouldOpenHomePages;
    NSMutableArray *_homePages;

    SystemSoundID _notificationSound;
	Reachability *_reachability;

    BOOL isOnboarding;
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
#ifdef USE_DUMMY_URLINTERCEPTOR
    [NSURLProtocol registerClass:[DummyURLInterceptor class]];
#else
    [NSURLProtocol registerClass:[URLInterceptor class]];
#endif

    [self initializeDefaults];

    self.hstsCache = [HSTSCache retrieve];
    self.cookieJar = [[CookieJar alloc] init];
    [Bookmark retrieveList];

    NSURL *audioPath = [[NSBundle mainBundle] URLForResource:@"blip1" withExtension:@"wav"];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)audioPath, &_notificationSound);

    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    isOnboarding = ![[NSUserDefaults standardUserDefaults] boolForKey:@"hasBeenOnBoarded"];

    if (isOnboarding) {
        self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

        OnboardingViewController *onboarding = [[OnboardingViewController alloc] init];
        onboarding.delegate = self;

        self.window.rootViewController = onboarding;
        self.window.rootViewController.restorationIdentifier = @"OnBoardingViewController";
        self.window.rootViewController.modalPresentationCapturesStatusBarAppearance = YES;
        [self.window makeKeyAndVisible];
    } else {
        [self startTunnelAndOpenBrowser];
    }
    return YES;
}

-(void)onboardingEnded {
    isOnboarding = NO;
    [self startTunnelAndOpenBrowser];
    self.webViewController.showTutorial = YES;
    [[self webViewController] viewIsVisible];
}

-(void)startTunnelAndOpenBrowser {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[WebViewController alloc] init];
    self.window.rootViewController.restorationIdentifier = @"WebViewController";
    [self.window makeKeyAndVisible];
    
    self.socksProxyPort = 0;
    self.psiphonTunnel = [PsiphonTunnel newPsiphonTunnel:self];
    
    _needsResume = false;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetReachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    _reachability = [Reachability reachabilityForInternetConnection];
    [_reachability startNotifier];
}


- (void) startPsiphon {
    dispatch_async(dispatch_get_main_queue(), ^{
		[_homePages removeAllObjects];
		_shouldOpenHomePages = true;
        if( ! [self.psiphonTunnel start:nil] ) {
            self.psiphonConectionState = PsiphonConnectionStateDisconnected;
			[self notifyPsiphonConnectionState];
        }
    });
}

- (void) stopAndWaitForInternetConnection {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.psiphonConectionState = PsiphonConnectionStateWaitingForNetwork;
        [self notifyPsiphonConnectionState];
        [self.psiphonTunnel stop];
    });
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	[application ignoreSnapshotOnNextApplicationLaunch];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	if (![self areTesting]) {
		[HostSettings persist];
		[[self hstsCache] persist];
	}
	
	if ([userDefaults boolForKey:@"clearAllWhenBackgrounded"]) {
		[[self webViewController] removeAllTabs];
		[[self cookieJar] clearAllNonWhitelistedData];
	}
	else
		[[self cookieJar] clearAllOldNonWhitelistedData];
	
	[application ignoreSnapshotOnNextApplicationLaunch];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (!isOnboarding) {
        [self startIfNeeded];
    }
}

-(void)startIfNeeded {
    BOOL needStart = false;

    // Auto start if not connected
    if (self.psiphonConectionState != PsiphonConnectionStateConnected) {
        needStart = true;
    } else if (self.socksProxyPort > 0) {
        // check if SOCKS local proxy is still accessible

        CFSocketRef sockfd;
        sockfd = CFSocketCreate(NULL, AF_INET, SOCK_STREAM, IPPROTO_TCP,0, NULL,NULL);
        struct sockaddr_in servaddr;
        memset(&servaddr, 0, sizeof(servaddr));
        servaddr.sin_len = sizeof(servaddr);
        servaddr.sin_family = AF_INET;
        servaddr.sin_port = htons([self socksProxyPort]);
        inet_pton(AF_INET, [@"127.0.0.1" cStringUsingEncoding:NSUTF8StringEncoding], &servaddr.sin_addr);
        CFDataRef connectAddr = CFDataCreate(NULL, (unsigned char *)&servaddr, sizeof(servaddr));
        if (CFSocketConnectToAddress(sockfd, connectAddr, 1) != kCFSocketSuccess) {
            needStart = true;
        }
        CFSocketInvalidate(sockfd);
        CFRelease(sockfd);
        CFRelease(connectAddr);

    } else {
        needStart = true;
    }

    if(needStart) {
        if (_reachability.currentReachabilityStatus == NotReachable) {
            self.psiphonConectionState = PsiphonConnectionStateWaitingForNetwork;
        } else {
            self.psiphonConectionState = PsiphonConnectionStateConnecting;
        }
        [self notifyPsiphonConnectionState];
        [self startPsiphon];
    }

    [[self webViewController] viewIsVisible];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	/* this definitely ends our sessions */
	[[self cookieJar] clearAllNonWhitelistedData];
    [_psiphonTunnel stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
	[application ignoreSnapshotOnNextApplicationLaunch];
    
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
#ifdef DEBUG
	NSLog(@"request to open url \"%@\"", url);
#endif
	if ([[[url scheme] lowercaseString] isEqualToString:@"endlesshttp"])
		url = [NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"endlesshttp" length]) withString:@"http"]];
	else if ([[[url scheme] lowercaseString] isEqualToString:@"endlesshttps"])
		url = [NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"endlesshttps" length]) withString:@"https"]];

	[[self webViewController] dismissViewControllerAnimated:YES completion:nil];
	[[self webViewController] addNewTabForURL:url];
	
	return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
	if ([self areTesting])
		return NO;
	
	/* if we tried last time and failed, the state might be corrupt */
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if ([userDefaults objectForKey:STATE_RESTORE_TRY_KEY] != nil) {
		NSLog(@"previous startup failed, not restoring application state");
		[userDefaults removeObjectForKey:STATE_RESTORE_TRY_KEY];
		return NO;
	}
	else
		[userDefaults setBool:YES forKey:STATE_RESTORE_TRY_KEY];
	
	[userDefaults synchronize];

	return YES;
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
	if ([self areTesting])
		return NO;
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if ([userDefaults boolForKey:@"clearAllWhenBackgrounded"])
		return NO;

	return YES;
}

-(void)initializeDefaultsFor:(NSString*)plist
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    NSString *plistPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"InAppSettings.bundle"] stringByAppendingPathComponent:plist];
    NSDictionary *settingsDictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];

    for (NSDictionary *pref in [settingsDictionary objectForKey:@"PreferenceSpecifiers"]) {
        NSString *key = [pref objectForKey:@"Key"];
        if (key == nil)
            continue;

        if ([userDefaults objectForKey:key] == NULL) {
            NSObject *val = [pref objectForKey:@"DefaultValue"];
            if (val == nil)
                continue;

            [userDefaults setObject:val forKey:key];
#ifdef TRACE
            NSLog(@"initialized default preference for %@ to %@", key, val);
#endif
        }
    }
    [userDefaults synchronize];
}

- (void)initializeDefaults
{
    [self initializeDefaultsFor:@"Root.inApp.plist"];
    [self initializeDefaultsFor:@"Feedback.plist"];
    [self initializeDefaultsFor:@"Security.plist"];
    [self initializeDefaultsFor:@"Privacy.plist"];
    [self initializeDefaultsFor:@"PsiphonSettings.plist"];
    [self initializeDefaultsFor:@"Notifications~iphone.plist"];
    [self initializeDefaultsFor:@"Notifications~ipad.plist"];
    
    _searchEngines = [NSMutableDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"SearchEngines.plist"]];
}

- (BOOL)areTesting
{
	return (NSClassFromString(@"XCTestProbe") != nil);
}

- (void)scheduleRunningTunnelServiceRestart {
    self.psiphonConectionState = PsiphonConnectionStateConnecting;
    [self notifyPsiphonConnectionState];
    [self startPsiphon];
}

// MARK: TunneledAppDelegate protocol implementation

- (NSString *) getPsiphonConfig {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *bundledConfigPath = [[[ NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"psiphon_config"];
    if(![fileManager fileExistsAtPath:bundledConfigPath]) {
        NSLog(@"Config file not found. Aborting now.");
        abort();
    }

    //Read in psiphon_config JSON
    NSData *jsonData = [fileManager contentsAtPath:bundledConfigPath];
    NSError *e = nil;
    NSDictionary *readOnly = [NSJSONSerialization JSONObjectWithData: jsonData options: kNilOptions error: &e];

    NSMutableDictionary *mutableConfigCopy = [readOnly mutableCopy];

    if(e) {
        NSLog(@"Failed to parse config JSON. Aborting now.");
        abort();
    }

    NSString *selectedRegionCode = [[RegionAdapter sharedInstance] getSelectedRegion].code;
    mutableConfigCopy[@"EgressRegion"] = selectedRegionCode;

    NSString *upstreamProxyUrl = [[UpstreamProxySettings sharedInstance] getUpstreamProxyUrl];
    mutableConfigCopy[@"UpstreamProxyUrl"] = upstreamProxyUrl;

    BOOL disableTimeouts = [[NSUserDefaults standardUserDefaults] boolForKey:kDisableTimeouts];
    if (disableTimeouts) {
        mutableConfigCopy[@"TunnelConnectTimeoutSeconds"] = 0;
        mutableConfigCopy[@"TunnelPortForwardDialTimeoutSeconds"] = 0;
        mutableConfigCopy[@"TunnelSshKeepAliveProbeTimeoutSeconds"] = 0;
        mutableConfigCopy[@"TunnelSshKeepAlivePeriodicTimeoutSeconds"] = 0;
        mutableConfigCopy[@"FetchRemoteServerListTimeoutSeconds"] = 0;
        mutableConfigCopy[@"PsiphonApiServerTimeoutSeconds"] = 0;
        mutableConfigCopy[@"FetchRoutesTimeoutSeconds"] = 0;
        mutableConfigCopy[@"HttpProxyOriginServerTimeoutSeconds"] = 0;
    }

    mutableConfigCopy[@"ClientVersion"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    
    mutableConfigCopy[@"ClientPlatform"] = [NSString stringWithFormat:@"%@_%@",
                                            [[UIDevice currentDevice] systemName],
                                            [[UIDevice currentDevice]systemVersion]];
    
    mutableConfigCopy[@"EmitDiagnosticNotices"] = [NSNumber numberWithBool:TRUE];

    jsonData = [NSJSONSerialization dataWithJSONObject:mutableConfigCopy
                                               options:0 // non-pretty printing
                                                 error:&e];
    if(e) {
        NSLog(@"Failed to create JSON data from config object. Aborting now.");
        abort();
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (void) onAvailableEgressRegions:(NSArray *)regions {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[RegionAdapter sharedInstance] onAvailableEgressRegions:regions];
    });
}

- (void) onDiagnosticMessage : (NSString*) message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"onDiagnosticMessage: %@", message);
        DiagnosticEntry *newDiagnosticEntry = [[DiagnosticEntry alloc] init:message];
        [[PsiphonData sharedInstance] addDiagnosticEntry:newDiagnosticEntry];
    });
}

- (void) onListeningSocksProxyPort:(NSInteger)port {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.socksProxyPort = port;
    });
}

- (void) onConnecting {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_reachability.currentReachabilityStatus == NotReachable) {
            self.psiphonConectionState = PsiphonConnectionStateWaitingForNetwork;
        } else {
            self.psiphonConectionState = PsiphonConnectionStateConnecting;
        }
        [self notifyPsiphonConnectionState];
    });
}

- (void) onConnected {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.psiphonConectionState = PsiphonConnectionStateConnected;
		[self notifyPsiphonConnectionState];
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        
        if ([userDefaults boolForKey:@"vibrate_notification"]) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        }
        if ([userDefaults boolForKey:@"sound_notification"]) {
			AudioServicesPlaySystemSound (_notificationSound);
        }
        
		
		if(_shouldOpenHomePages) {
			NSMutableArray * openURLs = [NSMutableArray new];
			NSArray * wvTabs = [self.webViewController webViewTabs];
			
			for (WebViewTab *wvt in wvTabs) {
				if ( wvt.url != nil) {
					[openURLs addObject:wvt.url];
				}
			}
			
			NSArray *homepages = [self getHomePages];
			for (NSString* page in homepages) {
				NSURL *url = [NSURL URLWithString:page];
				if(! [openURLs containsObject:url]) {
					[self.webViewController addNewTabForURL: url];
				}
			}
			_shouldOpenHomePages = false;
		}
    });

}

- (void) onHomepage:(NSString *)url {
	if (!_homePages) {
		_homePages = [NSMutableArray new];
	}
    if(![_homePages containsObject:url]) {
        [_homePages addObject:url];
    }
}

- (NSArray*) getHomePages {
	return [_homePages copy];	
}


- (void) reloadAndOpenSettings {
    [[RegionAdapter sharedInstance] reloadTitlesForNewLocalization];

    NSMutableArray * reloadURLS = [NSMutableArray new];
    NSArray * wvTabs = [self.webViewController webViewTabs];
    
    for (WebViewTab *wvt in wvTabs) {
        if ( wvt.url != nil) {
            [reloadURLS addObject:wvt.url];
        }
    }
    self.window.rootViewController = [[WebViewController alloc] init];

    for (NSURL* url in reloadURLS) {
        [self.webViewController addNewTabForURL: url];
    }
    [self notifyPsiphonConnectionState];
	[self.webViewController.settingsButton sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void) notifyPsiphonConnectionState {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
         postNotificationName:kPsiphonConnectionStateNotification
         object:self
         userInfo:@{kPsiphonConnectionState: @(self.psiphonConectionState)}];
    });
}

- (void) internetReachabilityChanged:(NSNotification *)note
{
	Reachability* currentReachability = [note object];
	if([currentReachability currentReachabilityStatus] == NotReachable) {
        if(self.psiphonConectionState != PsiphonConnectionStateDisconnected) {
            _needsResume = true;
            [self stopAndWaitForInternetConnection];
        }
    } else {
        if(_needsResume){
            [self startPsiphon];
        }
    }
}

+ (AppDelegate *)sharedAppDelegate{
    return (AppDelegate *)[UIApplication sharedApplication].delegate;
}

@end

