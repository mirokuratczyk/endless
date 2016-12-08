/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>
#import "IASKAppSettingsViewController.h"
#import "SettingsViewController.h"
#import "WebViewTab.h"

@interface WebViewController : UIViewController <UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, SettingsViewControllerDelegate>

- (NSMutableArray *)webViewTabs;
- (__strong WebViewTab *)curWebViewTab;

- (id)settingsButton;

- (void)viewIsVisible;

- (WebViewTab *)addNewTabForURL:(NSURL *)url;
- (void)removeTab:(NSNumber *)tabNumber andFocusTab:(NSNumber *)toFocus;
- (void)removeTab:(NSNumber *)tabNumber;
- (void)removeAllTabs;

- (void)webViewTouched;
- (void)updateProgress;
- (void)updateSearchBarDetails;
- (void)refresh;
- (void)forceRefresh;
- (void)prepareForNewURLFromString:(NSString *)url;

- (void) showPsiphonConnectionState:(PsiphonConnectionState)state;
- (void) stopLoading;
@end
