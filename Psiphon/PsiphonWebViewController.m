//
//  PsiphonViewController.m
//  Endless
//
//  Created by eugene-imac on 2016-11-15.
//  Copyright © 2016 jcs. All rights reserved.
//

#import "PsiphonWebViewController.h"

@implementation PsiphonWebViewController

- (void) loadView {
    _isPsiphonConnected = FALSE;
    _socksProxyPort = -1;
    _psiphonTunnel = [PsiphonTunnel newPsiphonTunnel : self];
    [_psiphonTunnel start : nil];
    [super loadView];
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
    
    NSMutableDictionary *mutableCopy = [readOnly mutableCopy];
    
    if(e) {
        NSLog(@"Failed to parse config JSON. Aborting now.");
        abort();
    }
        
    [[NSFileManager defaultManager] createFileAtPath:mutableCopy[@"RemoteServerListDownloadFilename"]
                                            contents:nil
                                          attributes:nil];
    
    //add DeviceRegion
    mutableCopy[@"DeviceRegion"] = [self getDeviceRegion];
    
    //set indistinguishable TLS flag and add TrustedRootCA file path
    NSString * frameworkBundlePath = [[NSBundle bundleForClass:[PsiphonTunnel class]] resourcePath];
    NSString *bundledTrustedCAPath = [frameworkBundlePath stringByAppendingPathComponent:@"rootCAs.txt"];
    
    if(![fileManager fileExistsAtPath:bundledTrustedCAPath]) {
        NSLog(@"Trusted CAs file not found. Aborting now.");
        abort();
    }
    
    mutableCopy[@"UseIndistinguishableTLS"] = @YES;
    mutableCopy[@"TrustedCACertificatesFilename"] = bundledTrustedCAPath;
    
    
    jsonData = [NSJSONSerialization dataWithJSONObject:mutableCopy
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

- (NSString *)getDeviceRegion {
    NSString *region = @"";
    
    
    // Only use if class is loaded
    Class MGLTelephony = NSClassFromString(@"CTTelephonyNetworkInfo");
    if (MGLTelephony) {
        id telephonyNetworkInfo = [[MGLTelephony alloc] init];
        
        SEL selector = NSSelectorFromString(@"subscriberCellularProvider");
        IMP imp = [telephonyNetworkInfo methodForSelector:selector];
        id (*func)(id, SEL) = (void *)imp;
        
        id carrierVendor = func(telephonyNetworkInfo, selector);
        
        // Guard against simulator, iPod Touch, etc.
        if (carrierVendor) {
            selector = NSSelectorFromString(@"isoCountryCode");
            
            imp = [carrierVendor methodForSelector:selector];
            NSString *(*func)(id, SEL) = (void *)imp;
            region = func(carrierVendor, selector);
        }
    }
    // If country code is not available Telephony get it from the locale
    if(region == nil || region.length <= 0) {
        NSLocale *locale = [NSLocale currentLocale];
        if (locale != nil) {
            region = [locale objectForKey: NSLocaleCountryCode];
        }
    }
    
    return [region uppercaseString];
}



@end
