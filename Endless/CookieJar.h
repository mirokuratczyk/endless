/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

#define kCookiePolicyKey @"cookiePolicy"

#define kAlwaysBlock @"AlwaysBlock"
// - Storing: Block all cookies.
// - Sending: Do not send any cookies.

#define kAllowCurrentWebsiteOnly @"AllowCurrentWebsiteOnly"
// - Storing: Allow all first-party cookies and block all third-party cookies.
// - Sending: Send cookies only for the requests that are of same origin as the main document request URL.

#define kAllowWebsitesIVisit @"AllowWebsitesIVisit"
// - Storing: Allow all first-party cookies and block all third-party cookies
// - Sending: Send cookies for the request URL if found in storage - current default for us and Safari

#define kAlwaysAllow @"AlwaysAllow"
// - Storing: Store all first-party cookies and all third-party cookies.
// - Sending: Send cookies for the request URL if found in storage.


@interface CookieJar : NSObject
+(void)migrateOldValuesForVersion:(int)version;
+ (NSString*) cookiePolicy;
+ (BOOL)isSameOrigin:(NSURL *)aURL toURL:(NSURL *)bURL;
+ (void)clearAllData;
+ (void)syncCookieAcceptPolicy;
+ (NSArray<NSHTTPCookie *> *)cookiesForURL:(NSURL *)URL;
+ (void)setCookies:(NSArray<NSHTTPCookie *> *)cookies forURL:(NSURL *)URL mainDocumentURL:(NSURL *)mainDocumentURL;
@end
