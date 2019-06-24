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


#import <Foundation/Foundation.h>

#import "OCSPCache.h"
#import "JAHPAuthenticatingHTTPProtocol.h"
#import "WebViewTab.h"

NS_ASSUME_NONNULL_BEGIN

@interface JAHPSecTrustEvaluation : NSObject

- (instancetype)initWithTrust:(SecTrustRef)trust
						  wvt:(WebViewTab*)wvt
						 task:(NSURLSessionTask*)task
					challenge:(NSURLAuthenticationChallenge *)challenge
					   logger:(void (^)(NSString *))logger
			completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition,
										NSURLCredential *))completionHandler;

/// Evaluate trust and call completion handler.
/// Must only be called once.
- (void)evaluate;

@end

NS_ASSUME_NONNULL_END
