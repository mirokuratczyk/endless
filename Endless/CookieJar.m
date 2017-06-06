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
@implementation CookieJar

+(void)migrateOldValuesForVersion:(int)version {
	if(version <= 1013) {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *cookiePolicy = [defaults stringForKey:kCookiePolicyKey];

		if([cookiePolicy isEqualToString:@"BlockAll"]) {
			[defaults setObject:kAlwaysBlock forKey:kCookiePolicyKey];
		} else if ([cookiePolicy isEqualToString:@"BlockThirdPartyCookies"]) {
			[defaults setObject:kAllowWebsitesIVisit forKey:kCookiePolicyKey];

		} else if ([cookiePolicy isEqualToString:@"BlockNone"]) {
			[defaults setObject:kAlwaysAllow forKey:kCookiePolicyKey];
		}
	}
}

+ (NSString*) cookiePolicy {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	NSString *cookiePolicy = [defaults stringForKey:kCookiePolicyKey];

	if(!cookiePolicy || cookiePolicy.length == 0) {
		// our default cookie policy
		cookiePolicy = kAllowWebsitesIVisit;
		[defaults setObject:cookiePolicy forKey:kCookiePolicyKey];
	}
	return cookiePolicy;
}

+ (void)syncCookieAcceptPolicy {
	NSString *cookiePolicy = [[self class] cookiePolicy];
	if ([cookiePolicy isEqualToString:kAllowWebsitesIVisit] || [cookiePolicy isEqualToString:kAllowCurrentWebsiteOnly]) {
		// Block storing third party
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];
	} else if ([cookiePolicy isEqualToString:kAlwaysBlock]) {
		// Block storing all cookies
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyNever];
	} else if ([cookiePolicy isEqualToString:kAlwaysAllow]) {
		// Allow storig all cookies
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
#ifdef TRACE_COOKIES
		NSString *fhost = [files objectForKey:file];
		NSLog(@"[CookieJar] deleting local storage for %@: %@", fhost, file);
#endif
		NSError *error;

		[[NSFileManager defaultManager] removeItemAtPath:file error:&error];

		if (error) {
#ifdef TRACE_COOKIES
			NSLog(@"[CookieJar] Error removing local storage file %@ for %@: %@", file, fhost, error.localizedDescription);
#endif
		}
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

+ (NSArray<NSHTTPCookie *> *)cookiesForURL:(NSURL *)URL {
	return [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:URL];
}

+ (void)setCookies:(NSArray<NSHTTPCookie *> *)cookies forURL:(NSURL *)URL mainDocumentURL:(NSURL *)mainDocumentURL {
	[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookies:cookies forURL:URL mainDocumentURL:mainDocumentURL];
}

+ (BOOL)isSameOrigin:(NSURL *)aURL toURL:(NSURL *)bURL{

	if ([[aURL scheme] caseInsensitiveCompare:[bURL scheme]] != NSOrderedSame) return NO;
	if ([[aURL host] caseInsensitiveCompare:[bURL host]] != NSOrderedSame) return NO;

	if ([aURL port] || [bURL port]) {
		// TODO: should we match ports 80 and 443 to nil for http and https respectively?
		if (![[aURL port] isEqual:[bURL port]]) return NO;
	}

	return YES;
}

@end
