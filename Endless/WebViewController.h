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

#import "Tutorial.h"

/* Psiphon tutorial steps */
typedef NS_ENUM(NSInteger, PsiphonTutorialStep)
{
	PsiphonTutorialStep1 = 0,
	PsiphonTutorialStep2,
	PsiphonTutorialStep3
};

@interface WebViewController : UIViewController <UITableViewDelegate, UITextFieldDelegate,
	UIGestureRecognizerDelegate, UIScrollViewDelegate, SettingsViewControllerDelegate,
		TutorialDelegate, FinalPageObserver, OnboardingViewControllerDelegate>

- (NSMutableArray *)webViewTabs;
- (__strong WebViewTab *)curWebViewTab;

- (id)settingsButton;

- (WebViewTab *)addTabForReload:(NSURL *)url;
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

- (void) stopLoading;

- (void) overlayTutorial;
- (void) focusTab:(WebViewTab *)tab andRefresh:(BOOL)refresh animated:(BOOL)animated;
- (void) openPsiphonHomePage:(NSString *) homePage;

@property (nonatomic) BOOL showTutorial;
@property (nonatomic) BOOL openSettingImmediatelyOnViewDidAppear;
@end
