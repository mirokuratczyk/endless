//
//  SettingsViewController.m
//  Endless
//
//  Created by Miro Kuratczyk on 2016-11-11.
//

#import <UIKit/UIKit.h>
#import "IASKAppSettingsViewController.h"

// Upstream proxy settings keys (found in PsiphonSettings.plist)
#define minTlsVersion            @"minTlsVersion"
#define useUpstreamProxy         @"useUpstreamProxy"
#define useProxyAuthentication   @"useProxyAuthentication"
#define proxyUsername            @"proxyUsername"
#define proxyPassword            @"proxyPassword"
#define proxyDomain              @"proxyDomain"
#define upstreamProxyHostAddress @"upstreamProxyHostAddress"
#define upstreamProxyPort        @"upstreamProxyPort"
// These numbers correspond to the option's index in MinTLSSettings.plist
// `minTLSVersion` is set to the index of the chosen option in Security.plist
#define SETTINGS_TLS_12       0
#define SETTINGS_TLS_11       1
#define SETTINGS_TLS_10       2
#define SETTINGS_TLS_AUTO     3

@protocol SettingsViewControllerDelegate <NSObject>
- (long)curWebViewTabHttpsRulesCount;
- (void)settingsViewControllerDidEnd;
@end

@interface SettingsViewController : IASKAppSettingsViewController <UITableViewDelegate, IASKSettingsDelegate>

@property (assign) id <SettingsViewControllerDelegate> webViewController;

@end
