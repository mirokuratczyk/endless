/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "CookieJar.h"
#import "HTTPSEverywhere.h"

/*
 * local storage is found in NSCachesDirectory and can be a file or directory:
 *
 * ./AppData/Library/Caches/https_m.imgur.com_0.localstorage
 * ./AppData/Library/Caches/https_m.youtube.com_0.localstorage
 * ./AppData/Library/Caches/http_samy.pl_0
 * ./AppData/Library/Caches/http_samy.pl_0/.lock
 * ./AppData/Library/Caches/http_samy.pl_0/0000000000000001.db
 * ./AppData/Library/Caches/http_samy.pl_0.localstorage
 */

#define LOCAL_STORAGE_REGEX @"/(https?_(.+)_\\d+|_*IndexedDB)"
#define kCookiePolicyKey @"cookiePolicy"
#define kBlockThirdPartyCookies @"BlockThirdPartyCookies"
#define kBlockAll @"BlockAll"
#define kBlockNone @"BlockNone"

@implementation CookieJar

+ (void)syncCookieAcceptPolicy {
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSString *cookiePolicy = [userDefaults stringForKey:kCookiePolicyKey];

	if ([cookiePolicy isEqualToString:kBlockThirdPartyCookies]) {
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];
	} else if ([cookiePolicy isEqualToString:kBlockAll]) {
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyNever];
	} else if ([cookiePolicy isEqualToString:kBlockNone]) {
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
	}
}

+ (void)clearAllData
{
	[self clearAllCookies];
	[self clearAllLocalStorage];
}

+ (void)clearAllCookies
{
	for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
#ifdef TRACE_COOKIES
		NSLog(@"[CookieJar] deleting cookie: %@", cookie);
#endif
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
	}
}

+ (void)clearAllLocalStorage
{
	NSDictionary *files = [self localStorageFiles];
	for (NSString *file in [files allKeys]) {

		NSString *fhost = [files objectForKey:file];

#ifdef TRACE_COOKIES
		NSLog(@"[CookieJar] deleting local storage for %@: %@", fhost, file);
#endif
		NSError *error;

		[[NSFileManager defaultManager] removeItemAtPath:file error:&error];

		if (error)
#ifdef TRACE_COOKIES
			NSLog(@"[CookieJar] Error removing local storage file %@ for %@: %@", file, fhost, error.localizedDescription);
#endif
	}
}

+ (NSDictionary *)localStorageFiles
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];

	NSMutableDictionary *files = [[NSMutableDictionary alloc] init];

	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:LOCAL_STORAGE_REGEX options:0 error:nil];

	for (NSString *file in [fm contentsOfDirectoryAtPath:cacheDir error:nil]) {
		NSString *absFile = [NSString stringWithFormat:@"%@/%@", cacheDir, file];

		NSArray *matches = [regex matchesInString:absFile options:0 range:NSMakeRange(0, [absFile length])];
		if (!matches || ![matches count]) {
			continue;
		}

		for (NSTextCheckingResult *match in matches) {
			if ([match numberOfRanges] >= 1) {
				NSString *host = [absFile substringWithRange:[match rangeAtIndex:1]];
				[files setObject:host forKey:absFile];
			}
		}
	}

	return files;
}

@end
