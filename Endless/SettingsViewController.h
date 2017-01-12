/*
 * Copyright (c) 2016, Psiphon Inc.
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

#import <UIKit/UIKit.h>
#import "IASKAppSettingsViewController.h"

//app language key
#define appLanguage              @"appLanguage"

// Globally used specifier keys
#define kRegionSelectionSpecifierKey @"regionSelection"
// Upstream proxy settings keys (found in PsiphonSettings.plist)
#define kDisableTimeouts          @"disableTimeouts"
#define kMinTlsVersion            @"minTlsVersion"
#define kUseUpstreamProxy         @"useUpstreamProxy"
#define kUseProxyAuthentication   @"useProxyAuthentication"
#define kProxyUsername            @"proxyUsername"
#define kProxyPassword            @"proxyPassword"
#define kProxyDomain              @"proxyDomain"
#define kUpstreamProxyHostAddress @"upstreamProxyHostAddress"
#define kUpstreamProxyPort        @"upstreamProxyPort"
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
