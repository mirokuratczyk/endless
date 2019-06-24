/*
 * Copyright (c) 2019, Psiphon Inc.
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


#import "JAHPSecTrustEvaluation.h"

@implementation JAHPSecTrustEvaluation {
	SecTrustRef trust;
	WebViewTab *wvt;
	NSURLSessionTask *task;
	NSURLAuthenticationChallenge *challenge;
	void (^logger)(NSString*);
	void (^completionHandler)(NSURLSessionAuthChallengeDisposition,
							  NSURLCredential *);
	OCSPCache *ocspCache;

}

- (instancetype)initWithTrust:(SecTrustRef)trust
						  wvt:(WebViewTab*)wvt
						 task:(NSURLSessionTask*)task
					challenge:(NSURLAuthenticationChallenge *)challenge
					   logger:(void (^)(NSString *))logger
			completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition,
										NSURLCredential *))completionHandler {
	self = [super init];

	if (self) {
		self->trust = trust;
		self->wvt = wvt;
		self->task = task;
		self->challenge = challenge;
		self->logger = logger;
		self->completionHandler = completionHandler;
		self->ocspCache = [AppDelegate sharedAppDelegate].ocspCache;
	}

	return self;
}

- (void)evaluate {
	BOOL completed;
	BOOL completedWithError;

	NSString *debugURLInfo =
	[NSString stringWithFormat:@"Got SSL certificate for %@, mainDocumentURL: %@, URL: %@",
	 challenge.protectionSpace.host,
	 [task.currentRequest mainDocumentURL],
	 [task.currentRequest URL]];

	logger(debugURLInfo);

	// Check if there is a pinned or cached OCSP response

	[self trySystemOCSPNoRemote:&completed completedWithError:&completedWithError];

	if (completed) {
		logger(@"Pinned or cached OCSP response found by the system");
		return;
	}

	// No pinned OCSP response, try fetching one

	logger(@"Fetching OCSP response through OCSPCache");

	OCSPCache *ocspCache = [[AppDelegate sharedAppDelegate] ocspCache];

	// Allow each URL to be loaded through JAHP
	NSURL* (^modifyOCSPURL)(NSURL *url) = ^NSURL*(NSURL *url) {
		[JAHPAuthenticatingHTTPProtocol temporarilyAllowURL:url
											  forWebViewTab:wvt
											  isOCSPRequest:YES];
		return nil;
	};

	OCSPCacheLookupResult *result = [ocspCache lookup:trust
										   andTimeout:0
										modifyOCSPURL:modifyOCSPURL];

	BOOL evictedResponse;

	[self evaluateOCSPCacheResult:result
						completed:&completed
			   completedWithError:&completedWithError
				  evictedResponse:&evictedResponse];

	if (completed) {
		logger(@"Completed with OCSP response");
		return;
	}

	// Check if check failed and a response was evicted from the cache
	if (!completed && result.cached) {

		// The response may have been evicted if it was expired or invalid. Retry once.

		OCSPCacheLookupResult *result = [ocspCache lookup:trust
											   andTimeout:0
											modifyOCSPURL:modifyOCSPURL];

		[self evaluateOCSPCacheResult:result
							completed:&completed
				   completedWithError:&completedWithError
					  evictedResponse:&evictedResponse];
		if (completed) {
			logger(@"Completed with OCSP response after evict and fetch");
			return;
		}
	}

	// Try system CRL check and require a positive response

	[self trySystemCRL:&completed completedWithError:&completedWithError];

	if (completed) {
		logger(@"Evaluate completed by successful system CRL check");
		return;
	}

	// Unfortunately relax our requirements

	[self tryFallback:&completed completedWithError:&completedWithError];

	if (completed) {
		logger(@"Completed with fallback system check");
		return;
	}

	// Reject the protection space.
	// Do not use NSURLSessionAuthChallengePerformDefaultHandling because it can trigger
	// plaintext OCSP requests.
	completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);

	return;
}

/// Uses default checking with no remote calls.
/// Succeeds if there is a pinned OCSP response or one was cached by the system.
- (void)trySystemOCSPNoRemote:(BOOL*)completed completedWithError:(BOOL*)completedWithError {
	SecPolicyRef policy = SecPolicyCreateRevocation(kSecRevocationOCSPMethod |
													kSecRevocationRequirePositiveResponse |
													kSecRevocationNetworkAccessDisabled);
	SecTrustSetPolicies(trust, policy);

	[JAHPSecTrustEvaluation evaluateTrust:trust
									 task:task
									  wvt:wvt
								challenge:challenge
								completed:completed
					   completedWithError:completedWithError
						completionHandler:completionHandler];

	return;
}

/// Evaluate response from OCSP cache
- (void)evaluateOCSPCacheResult:(OCSPCacheLookupResult*)result
					  completed:(BOOL*)completed
			 completedWithError:(BOOL*)completedWithError
				evictedResponse:(BOOL*)evictedResponse {

	*completed = FALSE;
	*completedWithError = FALSE;
	*evictedResponse = FALSE;

	if (result.err != nil) {
		logger([NSString stringWithFormat:@"Error from OCSPCache %@", result.err]);
		return;
	} else {

		if (result.cached) {
			logger(@"Got cached OCSP response");
		} else {
			logger(@"Fetched OCSP response from remote");
		}

		CFDataRef d = (__bridge CFDataRef)result.response.data;
		SecTrustSetOCSPResponse(trust, d);

		SecTrustResultType trustResultType;
		SecTrustEvaluate(trust, &trustResultType);

		[JAHPSecTrustEvaluation evaluateTrust:trust
										 task:task
										  wvt:wvt
									challenge:challenge
									completed:completed
						   completedWithError:completedWithError
							completionHandler:completionHandler];

		if (!completed || (completed && completedWithError)) {
			logger(@"Evaluate failed with OCSP response from cache");

			// Remove the cached value. There is no way to tell if it was the reason for
			// rejection since the iOS OCSP cache is a black box; so we should remove it
			// just incase the response was invalid or expired.
			NSInteger certCount = SecTrustGetCertificateCount(trust);
			if (certCount > 0) {
				*evictedResponse = YES;
				SecCertificateRef cert = SecTrustGetCertificateAtIndex(trust, 0);
				[ocspCache removeCacheValueForCert:cert];
			} else {
				logger(@"No certs in trust");
			}
		}

		return;
	}
}

/// Try default system CRL checking with a positive response required
- (void)trySystemCRL:(BOOL*)completed completedWithError:(BOOL*)completedWithError {
	SecPolicyRef policy = SecPolicyCreateRevocation(kSecRevocationCRLMethod |
													kSecRevocationRequirePositiveResponse);
	SecTrustSetPolicies(trust, policy);

	[JAHPSecTrustEvaluation evaluateTrust:trust
									 task:task
									  wvt:wvt
								challenge:challenge
								completed:completed
					   completedWithError:completedWithError
						completionHandler:completionHandler];

	if (completed) {
		logger(@"Evaluate completed by successful CRL check");
		return;
	}
}

/// Basic system check with positive response not required
- (void)tryFallback:(BOOL*)completed completedWithError:(BOOL*)completedWithError {
	SecPolicyRef policy = SecPolicyCreateRevocation(kSecRevocationCRLMethod);
	SecTrustSetPolicies(trust, policy);

	[JAHPSecTrustEvaluation evaluateTrust:trust
				   task:task
					wvt:wvt
			  challenge:challenge
			  completed:completed
	 completedWithError:completedWithError
	  completionHandler:completionHandler];

	if (completed) {
		logger(@"Evaluate completed by fallback revocation check");
		return;
	}
}

+ (void)evaluateTrust:(SecTrustRef)trust
				 task:(NSURLSessionTask *)task
				  wvt:(WebViewTab*)wvt
			challenge:(NSURLAuthenticationChallenge *)challenge
			completed:(BOOL*)completed
   completedWithError:(BOOL*)completedWithError
	completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {

	SecTrustResultType result;
	SecTrustEvaluate(trust, &result);

	if (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified) {
		if ([[task.currentRequest mainDocumentURL] isEqual:[task.currentRequest URL]]) {
			SSLCertificate *certificate = [[SSLCertificate alloc] initWithSecTrustRef:trust];
			if (certificate != nil) {
				[wvt setSSLCertificate:certificate];
				// Also cache the cert for displaying when
				// -URLSession:task:didReceiveChallenge: is not getting called
				// due to NSURLSession internal TLS caching
				// or UIWebView content caching
				[[[AppDelegate sharedAppDelegate] sslCertCache]
				 setObject:certificate
				 forKey:challenge.protectionSpace.host];
			}
		}

		NSURLCredential *credential = [NSURLCredential credentialForTrust:trust];
		assert(credential != nil);

		completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
		*completed = TRUE;
		*completedWithError = FALSE;
		return;
	}

	if (result != kSecTrustResultRecoverableTrustFailure) {
		*completed = TRUE;
		*completedWithError = TRUE;
		completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
		return;
	}

	*completed = FALSE;
	*completedWithError = FALSE;
	return;
}

@end
