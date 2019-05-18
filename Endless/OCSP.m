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

#import "OCSP.h"
#import "openssl/ocsp.h"
#import "openssl/safestack.h"
#import "openssl/x509.h"
#import "openssl/x509v3.h"

NSErrorDomain _Nonnull const OCSPErrorDomain = @"OCSPErrorDomain";

typedef NS_ERROR_ENUM(OCSPErrorDomain, OCSPErrorCode) {
	OCSPErrorCodeUnknown = -1,
	OCSPErrorCodeInvalidNumCerts = 1,
	OCSPErrorCodeNoLeafCert,
	OCSPErrorCodeNoIssuerCert,
	OCSPErrorCodeNoOCSPURLs,
	OCSPErrorCodeEVPAllocFailed,
	OCSPErrorCodeCertToIdFailed,
	OCSPErrorCodeReqAllocFailed,
	OCSPErrorCodeAddCertsToReqFailed,
	OCSPErrorCodeFailedToSerializeOCSPReq,
	OCSPErrorCodeConstructedInvalidURL
};

@implementation OCSP

+ (NSArray<NSURLRequest*>*_Nullable)ocspRequests:(SecTrustRef)secTrustRef error:(NSError**)error {

	NSMutableArray <void(^)(void)> *cleanup = [[NSMutableArray alloc] init];
	
	CFIndex certificateCount = SecTrustGetCertificateCount(secTrustRef);
	if (certificateCount < 2) {
		NSString *errorString = [NSString stringWithFormat:@"Expected 2 or more certificates "
								                            "(at least leaf and issuer) in the "
															"trust chain but only found %ld",
								                           (long)certificateCount];
		*error = [NSError errorWithDomain:OCSPErrorDomain
									 code:OCSPErrorCodeInvalidNumCerts
								 userInfo:@{NSLocalizedDescriptionKey:errorString}];
		return nil;
	}
	
	X509 *leaf = [OCSP certAtIndex:secTrustRef withIndex:0];
	if (leaf == NULL) {
		*error = [NSError errorWithDomain:OCSPErrorDomain
									 code:OCSPErrorCodeNoLeafCert
								 userInfo:@{NSLocalizedDescriptionKey:@"Failed to get leaf "
																	   "certficate"}];
		return nil;
	}
	
	[cleanup addObject:^(){
		X509_free(leaf);
	}];

	X509 *issuer = [OCSP certAtIndex:secTrustRef withIndex:1];
	if (issuer == NULL) {
		*error = [NSError errorWithDomain:OCSPErrorDomain
									 code:OCSPErrorCodeNoIssuerCert
								 userInfo:@{NSLocalizedDescriptionKey:@"Failed to get issuer "
																	   "certificate"}];
		[OCSP execCleanupTasks:cleanup];
		return nil;
	}

	[cleanup addObject:^(){
		X509_free(issuer);
	}];

	NSArray<NSString*>* ocspURLs = [OCSP OCSPURLs:leaf];
	if ([ocspURLs count] == 0) {
		*error = [NSError errorWithDomain:OCSPErrorDomain
									 code:OCSPErrorCodeNoOCSPURLs
								 userInfo:@{NSLocalizedDescriptionKey:@"Found 0 OCSP URLs in leaf "
																	   "certificate"}];
		[OCSP execCleanupTasks:cleanup];
		return nil;
	}
	
	const EVP_MD *cert_id_md = EVP_sha1();
	if (cert_id_md == NULL) {
		*error = [NSError errorWithDomain:OCSPErrorDomain
									 code:OCSPErrorCodeEVPAllocFailed
								 userInfo:@{NSLocalizedDescriptionKey:@"Failed to allocate new EVP "
																	   "sha1"}];
		[OCSP execCleanupTasks:cleanup];
		return nil;
	}
	
	OCSP_CERTID *id_t = OCSP_cert_to_id(cert_id_md, leaf, issuer);
	if (id_t == NULL) {
		*error = [NSError errorWithDomain:OCSPErrorDomain
									 code:OCSPErrorCodeCertToIdFailed
								 userInfo:@{NSLocalizedDescriptionKey:@"Failed to create "
																	   "OCSP_CERTID structure"}];
		[OCSP execCleanupTasks:cleanup];
		return nil;
	}
	
	// Construct OCSP request
	//
	// https://www.ietf.org/rfc/rfc2560.txt
	//
	// An OCSP request using the GET method is constructed as follows:
	//
	// GET {url}/{url-encoding of base-64 encoding of the DER encoding of
	//	   the OCSPRequest}
	
	OCSP_REQUEST *req = OCSP_REQUEST_new();
	if (req == NULL) {
		*error = [NSError errorWithDomain:OCSPErrorDomain
									 code:OCSPErrorCodeReqAllocFailed
								 userInfo:@{NSLocalizedDescriptionKey:@"Failed to allocate new "
																	   "OCSP request"}];
		[OCSP execCleanupTasks:cleanup];
		return nil;
	}
	
	[cleanup addObject:^(){
		OCSP_REQUEST_free(req);
	}];

	if (OCSP_request_add0_id(req, id_t) == NULL) {
		*error = [NSError errorWithDomain:OCSPErrorDomain
									 code:OCSPErrorCodeAddCertsToReqFailed
								 userInfo:@{NSLocalizedDescriptionKey:@"Failed to add certs to "
																	   "OCSP request"}];
		[OCSP execCleanupTasks:cleanup];
		return nil;
	}
	
	unsigned char *ocspReq = NULL;

	int len = i2d_OCSP_REQUEST(req, &ocspReq);
	
	if (ocspReq == NULL) {
		*error = [NSError errorWithDomain:OCSPErrorDomain
									 code:OCSPErrorCodeFailedToSerializeOCSPReq
								 userInfo:@{NSLocalizedDescriptionKey:@"Failed to serialize OCSP "
																	   "request"}];
		[OCSP execCleanupTasks:cleanup];
		return nil;
	}
	
	[cleanup addObject:^(){
		free(ocspReq);
	}];

	NSData *ocspReqData = [NSData dataWithBytes:ocspReq length:len];
	NSString *encodedOCSPReqData = [ocspReqData base64EncodedStringWithOptions:kNilOptions];
	NSString *escapedAndEncodedOCSPReqData = [encodedOCSPReqData
											  stringByAddingPercentEncodingWithAllowedCharacters:
											  NSCharacterSet.URLFragmentAllowedCharacterSet];

	NSMutableArray<NSURLRequest*>* reqs = [[NSMutableArray alloc] initWithCapacity:[ocspURLs count]];

	for (NSString *ocspURL in ocspURLs) {

		NSString *reqURL = [NSString stringWithFormat:@"%@/%@",
							                          ocspURL,
													  escapedAndEncodedOCSPReqData];

		NSURL *url = [NSURL URLWithString:reqURL];
		if (url == nil) {
			NSString *localizedDescription = [NSString stringWithFormat:@"Constructed invalid URL "
																		 "for OCSP request: %@",
											                            reqURL];
			*error = [NSError errorWithDomain:OCSPErrorDomain
										 code:OCSPErrorCodeConstructedInvalidURL
									 userInfo:@{NSLocalizedDescriptionKey:localizedDescription}];
			[OCSP execCleanupTasks:cleanup];
			return nil;
		}

		NSURLRequest *req = [NSURLRequest requestWithURL:url];

		[reqs addObject:req];
	}
	
	[OCSP execCleanupTasks:cleanup];
	
	return reqs;
}

#pragma mark - Internal Helpers

+ (X509*)certAtIndex:(SecTrustRef)trust withIndex:(int)index {
	if (SecTrustGetCertificateCount(trust) < index) {
		return nil;
	}
	
	SecCertificateRef cert = SecTrustGetCertificateAtIndex(trust, index);
	
	NSData *data = (__bridge_transfer NSData *)SecCertificateCopyData(cert);
	
	const unsigned char *p = [data bytes];
	X509 *x = d2i_X509(NULL, &p, [data length]);
	
	return x;
}

+ (NSArray<NSString*>*)OCSPURLs:(X509*)x {
	STACK_OF(OPENSSL_STRING) *ocspURLs = X509_get1_ocsp(x);
	
	NSMutableArray *URLs = [[NSMutableArray alloc]
							initWithCapacity:sk_OPENSSL_STRING_num(ocspURLs)];
	
	for (int i = 0; i < sk_OPENSSL_STRING_num(ocspURLs); i++) {
		[URLs addObject:[NSString stringWithCString:sk_OPENSSL_STRING_value(ocspURLs, i)
										   encoding:NSUTF8StringEncoding]];
	}
	
	sk_OPENSSL_STRING_free(ocspURLs);
	
	return URLs;
}

+ (void)execCleanupTasks:(NSArray<void(^)(void)> *)cleanupTasks {
	for (void (^cleanupTask)(void) in cleanupTasks) {
		cleanupTask();
	}
}

@end
