/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "Bookmark.h"
#import "HTTPSEverywhere.h"
#import "URLInterceptor.h"
#import "NSBundle+Language.h"
#import <CoreFoundation/CFSocket.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

@implementation AppDelegate

NSThread *psiphonThread;

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
#ifdef USE_DUMMY_URLINTERCEPTOR
	[NSURLProtocol registerClass:[DummyURLInterceptor class]];
#else
	[NSURLProtocol registerClass:[URLInterceptor class]];
#endif
	
	self.hstsCache = [HSTSCache retrieve];
	self.cookieJar = [[CookieJar alloc] init];
	[Bookmark retrieveList];
	
	[self initializeDefaults];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[NSBundle setLanguage:[userDefaults objectForKey:appLanguage]];

    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[WebViewController alloc] init];
    self.window.rootViewController.restorationIdentifier = @"WebViewController";
	[self.window makeKeyAndVisible];
    
    self.socksProxyPort = 0;
    self.psiphonTunnel = [PsiphonTunnel newPsiphonTunnel : self];
    
	return YES;
}

- (void) startPsiphon {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.psiphonConectionState = PsiphonConnectionStateConnecting;
        [self.webViewController showPsiphonConnectionState:self.psiphonConectionState];
        
        if( ! [self.psiphonTunnel start : nil] ) {
            self.psiphonConectionState = PsiphonConnectionStateDisconnected;
            [self.webViewController showPsiphonConnectionState:self.psiphonConectionState];
        }
        [self postConnectivityChangedNotification];
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
    if (self.socksProxyPort > 0) {
        //check if SOCKS local proxy is still accessible
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
            [self startPsiphon];
            
        }
        CFSocketInvalidate(sockfd);
        CFRelease(sockfd);
        
    } else {
        [self startPsiphon];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	/* this definitely ends our sessions */
	[[self cookieJar] clearAllNonWhitelistedData];
    [_psiphonTunnel stop];
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
    [self initializeDefaultsFor:@"Security.plist"];
    _searchEngines = [NSMutableDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"SearchEngines.plist"]];
}

- (BOOL)areTesting
{
	return (NSClassFromString(@"XCTestProbe") != nil);
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
    
    mutableConfigCopy[@"X-Test-Flag"] = @"X-Test-Value";
    
    
    jsonData = [NSJSONSerialization dataWithJSONObject:mutableConfigCopy
                                               options:0 // non-pretty printing
                                                 error:&e];
    if(e) {
        NSLog(@"Failed to create JSON data from config object. Aborting now.");
        abort();
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (void) onDiagnosticMessage : (NSString*) message {
    NSLog(@"onDiagnosticMessage: %@", message);
}

- (void) onListeningSocksProxyPort:(NSInteger)port {
    self.socksProxyPort = port;
}

- (void) onConnecting {
	self.socksProxyPort = 0;
	[_homePages removeAllObjects];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.psiphonConectionState = PsiphonConnectionStateConnecting;
		[self.webViewController showPsiphonConnectionState:self.psiphonConectionState];
        [self.webViewController stopLoading];
        [self postConnectivityChangedNotification];

    });
}

- (void) onConnected {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.psiphonConectionState = PsiphonConnectionStateConnected;
        [self.webViewController showPsiphonConnectionState:self.psiphonConectionState];
        [self postConnectivityChangedNotification];

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
    });
 
}

- (void) onExiting {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_homePages removeAllObjects];
        [self.webViewController stopLoading];
        [self postConnectivityChangedNotification];
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


- (void) setAppLanguageAndReloadSettings:(NSString *)language {
	[NSBundle setLanguage:language];

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
    [self.webViewController showPsiphonConnectionState:self.psiphonConectionState];
	[self.webViewController.settingsButton sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void) postConnectivityChangedNotification {
    [[NSNotificationCenter defaultCenter]
     postNotificationName:kPsiphonConnectivityChanged
     object:self
     userInfo:@{@"PsiphonConnectionState": @(self.psiphonConectionState)}];
}

@end

