/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "BookmarkController.h"
#import "HostSettings.h"
#import "HTTPSEverywhereRuleController.h"
#import "IASKSettingsReader.h"
#import "IASKSpecifierValuesViewController.h"
#import "RegionAdapter.h"
#import "SettingsViewController.h"
#import "SSLCertificateViewController.h"
#import "UpstreamProxySettings.h"
#import "URLInterceptor.h"
#import "WebViewController.h"
#import "WebViewTab.h"
#import "PsiphonConnectionIndicator.h"
#import "PsiphonConnectionModalViewController.h"
#import "Tutorial.h"

#define TOOLBAR_HEIGHT 44
#define TOOLBAR_PADDING 6
#define TOOLBAR_BUTTON_SIZE 30
#define kLetsGoButtonHeight 60

@implementation UIColor (DefaultNavigationControllerColor)
+ (UIColor *)defaultNavigationControllerColor {
	return [UIColor colorWithRed:(247/255.0f) green:(247/255.0f) blue:(247/255.0f) alpha:1];
}
@end

@interface UIViewController (Top)
+ (UIViewController *)topViewController;
@end


@implementation UIViewController (Top)
+ (UIViewController *)topViewController
{
	UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
	return [rootViewController topVisibleViewController];
}
- (UIViewController *)topVisibleViewController
{
	if ([self isKindOfClass:[UITabBarController class]])
	{
		UITabBarController *tabBarController = (UITabBarController *)self;
		return [tabBarController.selectedViewController topVisibleViewController];
	}
	else if ([self isKindOfClass:[UINavigationController class]])
	{
		UINavigationController *navigationController = (UINavigationController *)self;
		return [navigationController.visibleViewController topVisibleViewController];
	}
	else if (self.presentedViewController)
	{
		return [self.presentedViewController topVisibleViewController];
	}
	else if (self.childViewControllers.count > 0)
	{
		return [self.childViewControllers.lastObject topVisibleViewController];
	}
	return self;
}

@end


@interface WebViewController (RegionSelectionControllerDelegate) <RegionSelectionControllerDelegate>
@end

@implementation WebViewController {
	
	UIScrollView *tabScroller;
	UIPageControl *tabChooser;
	int curTabIndex;
	NSMutableArray *webViewTabs;
	
	PsiphonConnectionIndicator *psiphonConnectionIndicator;
	UIView *navigationBar;
	UITextField *urlField;
	UIButton *lockIcon;
	UIButton *brokenLockIcon;
	UIButton *refreshButton;
	UIProgressView *progressBar;
	UIToolbar *tabToolbar;
	UILabel *tabCount;
	int keyboardHeight;
	
	UIToolbar *bottomToolBar;
	
	UIButton *backButton;
	UIButton *forwardButton;
	UIButton *tabsButton;
	UIButton *settingsButton;
	UIButton *bookmarksButton;
	
	UIBarButtonItem *tabAddButton;
	UIBarButtonItem *tabDoneButton;
	UIBarButtonItem *bookmarkAddButton;
	
	float currentWebViewScrollOffsetY;
	BOOL isShowingToolBars;
	
	BOOL showingTabs;
	BOOL webViewScrollIsDecelerating;
	BOOL webViewScrollIsDragging;
	
	SettingsViewController *appSettingsViewController;
	
	BookmarkController *bookmarks;
	
	BOOL isRTL;
	
	NSMutableDictionary *preferencesSnapshot;
	
	Tutorial *tutorial;
	
}

- (void)loadView
{
	isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
	
	[[AppDelegate sharedAppDelegate] setWebViewController:self];
	
	[[AppDelegate sharedAppDelegate] setDefaultUserAgent:[self buildDefaultUserAgent]];
	
	webViewTabs = [[NSMutableArray alloc] initWithCapacity:10];
	curTabIndex = 0;
	
	self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].applicationFrame.size.width, [UIScreen mainScreen].applicationFrame.size.height)];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
	
	tabScroller = [[UIScrollView alloc] init];
	[tabScroller setScrollEnabled:NO];
	[[self view] addSubview:tabScroller];
	
	navigationBar = [[UIView alloc] init];
	[navigationBar setClipsToBounds:YES];
	[[self view] addSubview:navigationBar];
	
	
	bottomToolBar = [[UIToolbar alloc] init];
	[bottomToolBar setClipsToBounds:YES];
	[[self view] addSubview:bottomToolBar];
	
	
	keyboardHeight = 0;
	
	progressBar = [[UIProgressView alloc] init];
	[progressBar setTrackTintColor:[UIColor clearColor]];
	[progressBar setTintColor:self.view.window.tintColor];
	[progressBar setProgress:0.0];
	[navigationBar addSubview:progressBar];
	
	urlField = [[UITextField alloc] init];
	[urlField.layer setCornerRadius:6.0f];
	[urlField.layer setBorderWidth:0.0f];
	[urlField setKeyboardType:UIKeyboardTypeWebSearch];
	[urlField setFont:[UIFont systemFontOfSize:15]];
	[urlField setReturnKeyType:UIReturnKeyGo];
	[urlField setClearButtonMode:UITextFieldViewModeWhileEditing];
	[urlField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
	[urlField setLeftViewMode:UITextFieldViewModeAlways];
	[urlField setRightViewMode:UITextFieldViewModeAlways];
	[urlField setSpellCheckingType:UITextSpellCheckingTypeNo];
	[urlField setAutocorrectionType:UITextAutocorrectionTypeNo];
	[urlField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
	[urlField setDelegate:self];
	[navigationBar addSubview:urlField];
	
	psiphonConnectionIndicator = [[PsiphonConnectionIndicator alloc]
								  initWithFrame: [self frameForConnectionIndicator]];
	[psiphonConnectionIndicator addTarget:self action:@selector(showPsiphonConnectionStatusAlert)
						 forControlEvents:UIControlEventTouchUpInside];
	
	[navigationBar addSubview:psiphonConnectionIndicator];
	
	
	lockIcon = [UIButton buttonWithType:UIButtonTypeCustom];
	[lockIcon setFrame:CGRectMake(0, 0, 24, 16)];
	[lockIcon setImage:[UIImage imageNamed:@"lock"] forState:UIControlStateNormal];
	[[lockIcon imageView] setContentMode:UIViewContentModeScaleAspectFit];
	[lockIcon addTarget:self action:@selector(showSSLCertificate) forControlEvents:UIControlEventTouchUpInside];
	
	brokenLockIcon = [UIButton buttonWithType:UIButtonTypeCustom];
	[brokenLockIcon setFrame:CGRectMake(0, 0, 24, 16)];
	[brokenLockIcon setImage:[UIImage imageNamed:@"broken_lock"] forState:UIControlStateNormal];
	[[brokenLockIcon imageView] setContentMode:UIViewContentModeScaleAspectFit];
	[brokenLockIcon addTarget:self action:@selector(showSSLCertificate) forControlEvents:UIControlEventTouchUpInside];
	
	refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[refreshButton setFrame:CGRectMake(0, 0, 24, 16)];
	[refreshButton setImage:[UIImage imageNamed:@"refresh"] forState:UIControlStateNormal];
	[[refreshButton imageView] setContentMode:UIViewContentModeScaleAspectFit];
	[refreshButton addTarget:self action:@selector(forceRefresh) forControlEvents:UIControlEventTouchUpInside];
	
	backButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *backImage = [[UIImage imageNamed: isRTL ? @"arrow_right" : @"arrow_left"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[backButton setImage:backImage forState:UIControlStateNormal];
	[backButton addTarget:self action:@selector(goBack:) forControlEvents:UIControlEventTouchUpInside];
	[backButton setFrame:CGRectMake(0, 0, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE)];
	
	forwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *forwardImage = [[UIImage imageNamed: isRTL ? @"arrow_left" : @"arrow_right"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[forwardButton setImage:forwardImage forState:UIControlStateNormal];
	[forwardButton addTarget:self action:@selector(goForward:) forControlEvents:UIControlEventTouchUpInside];
	[forwardButton setFrame:CGRectMake(0, 0, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE)];
	
	
	tabsButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *tabsImage = [[UIImage imageNamed:@"tabs"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[tabsButton setImage:tabsImage forState:UIControlStateNormal];
	[tabsButton setTintColor:[progressBar tintColor]];
	[tabsButton addTarget:self action:@selector(showTabs:) forControlEvents:UIControlEventTouchUpInside];
	[tabsButton setFrame:CGRectMake(0, 0, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE)];
	
	tabCount = [[UILabel alloc] init];
	[tabCount setText:@""];
	[tabCount setTextAlignment:NSTextAlignmentCenter];
	[tabCount setFont:[UIFont systemFontOfSize:11]];
	[tabCount setTextColor:[progressBar tintColor]];
	[tabCount setFrame:CGRectMake(7, 11, 12, 12)];
	[tabsButton addSubview:tabCount];
	
	settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *settingsImage = [[UIImage imageNamed:@"settings"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[settingsButton setImage:settingsImage forState:UIControlStateNormal];
	[settingsButton setTintColor:[progressBar tintColor]];
	[settingsButton addTarget:self action:@selector(openSettingsMenu:) forControlEvents:UIControlEventTouchUpInside];
	[settingsButton setFrame:CGRectMake(0, 0, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE)];
	
	bookmarksButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *bookmarksImage = [[UIImage imageNamed:@"bookmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[bookmarksButton setImage:bookmarksImage forState:UIControlStateNormal];
	[bookmarksButton setTintColor:[progressBar tintColor]];
	[bookmarksButton addTarget:self action:@selector(addBookmarkFromBottomToolbar:) forControlEvents:UIControlEventTouchUpInside];
	[bookmarksButton setFrame:CGRectMake(0, 0, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE)];
	
	bookmarkAddButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:@selector(addBookmarkFromBottomToolbar:)];
	
	
	
	bottomToolBar.items = [NSArray arrayWithObjects:
						   [[UIBarButtonItem alloc] initWithCustomView:backButton ],
						   [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						   [[UIBarButtonItem alloc] initWithCustomView:forwardButton],
						   [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						   [[UIBarButtonItem alloc] initWithCustomView:settingsButton],
						   [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						   [[UIBarButtonItem alloc] initWithCustomView:bookmarksButton],
						   [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						   [[UIBarButtonItem alloc] initWithCustomView:tabsButton],
						   nil];
	
	
	[tabScroller setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
	[tabScroller setAutoresizesSubviews:NO];
	[tabScroller setShowsHorizontalScrollIndicator:NO];
	[tabScroller setShowsVerticalScrollIndicator:NO];
	[tabScroller setScrollsToTop:NO];
	[tabScroller setDelaysContentTouches:NO];
	[tabScroller setDelegate:self];
	
	tabChooser = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, TOOLBAR_HEIGHT)];
	[tabChooser setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin)];
	[tabChooser addTarget:self action:@selector(slideToCurrentTab:) forControlEvents:UIControlEventValueChanged];
	[tabChooser setNumberOfPages:0];
	[self.view insertSubview:tabChooser aboveSubview:navigationBar];
	[tabChooser setHidden:true];
	
	tabToolbar = [[UIToolbar alloc] init];
	[tabToolbar setClipsToBounds:YES];
	[tabToolbar setHidden:true];
	[self.view insertSubview:tabToolbar aboveSubview:navigationBar];
	
	tabAddButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addNewTabFromToolbar:)];
	tabDoneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneWithTabsButton:)];
	tabDoneButton.title = NSLocalizedString(@"Done", @"Done button title, dismisses the tab chooser");
	
	tabToolbar.items = [NSArray arrayWithObjects:
						[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						tabAddButton,
						[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
						tabDoneButton,
						nil];
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[center addObserver:self selector:@selector(psiphonConnectionStateNotified:) name:kPsiphonConnectionStateNotification object:nil];
	
	[self adjustLayout];
	[self updateSearchBarDetails];
	
	[self.view.window makeKeyAndVisible];
}

- (void)dealloc {
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
	[center removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
	[center removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	[center removeObserver:self name:UIKeyboardWillHideNotification object:nil];
	[center removeObserver:self name:kPsiphonConnectionStateNotification object:nil];
}

- (id)settingsButton
{
	return settingsButton;
}

- (BOOL)prefersStatusBarHidden
{
	return NO;
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
	[super encodeRestorableStateWithCoder:coder];
	
	if (webViewTabs.count > 0) {
		NSMutableArray *wvtd = [[NSMutableArray alloc] initWithCapacity:webViewTabs.count - 1];
		for (WebViewTab *wvt in webViewTabs) {
			if (wvt.url == nil)
				continue;
			
			[wvtd addObject:@{ @"url" : wvt.url, @"title" : wvt.title.text }];
			[[wvt webView] setRestorationIdentifier:[wvt.url absoluteString]];
			
#ifdef TRACE
			NSLog(@"encoded restoration state for tab %@ with %@", wvt.tabIndex, wvtd[wvtd.count - 1]);
#endif
		}
		[coder encodeObject:wvtd forKey:@"webViewTabs"];
		[coder encodeObject:[NSNumber numberWithInt:curTabIndex] forKey:@"curTabIndex"];
	}
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
	[super decodeRestorableStateWithCoder:coder];
	
	NSMutableArray *wvt = [coder decodeObjectForKey:@"webViewTabs"];
	for (int i = 0; i < wvt.count; i++) {
		NSDictionary *params = wvt[i];
#ifdef TRACE
		NSLog(@"restoring tab %d with %@", i, params);
#endif
		WebViewTab *wvt = [self addNewTabForURL:[params objectForKey:@"url"] forRestoration:YES withCompletionBlock:nil];
		[[wvt title] setText:[params objectForKey:@"title"]];
	}
	
	NSNumber *cp = [coder decodeObjectForKey:@"curTabIndex"];
	if (cp != nil) {
		if ([cp intValue] <= [webViewTabs count] - 1)
			[self setCurTabIndex:[cp intValue]];
		
		[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:tabChooser.currentPage].origin.x, 0) animated:NO];
		
		/* wait for the UI to catch up */
		[[self curWebViewTab] performSelector:@selector(refresh) withObject:nil afterDelay:0.5];
	}
	
	[self updateSearchBarDetails];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	/* we made it this far, remove lock on previous startup */
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults removeObjectForKey:STATE_RESTORE_TRY_KEY];
	[userDefaults synchronize];
	
	if (self.showTutorial) {
		self.showTutorial = NO;
		[self overlayTutorial];
	}
}

/* called when we've become visible and after the overlaid tutorial has ended (possibly again, from app delegate applicationDidBecomeActive) */
- (void)viewIsVisible
{
	if (webViewTabs.count == 0 && ![[AppDelegate sharedAppDelegate] areTesting] && !self.showTutorial) {
		static dispatch_once_t onceToken;

		dispatch_once(&onceToken, ^{

			PsiphonConnectionSplashViewController *connectionSplashViewController = [[PsiphonConnectionSplashViewController alloc]
																					 initWithState:[[AppDelegate sharedAppDelegate] psiphonConectionState]];
			connectionSplashViewController.delegate = self;
			[connectionSplashViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Go to Settings", nil)
																			   style:UIAlertActionStyleDefault
																			 handler:^(NYAlertAction *action) {
																				 [self openSettingsMenu:nil];
																			 }]];

			[[UIViewController topViewController] presentViewController:connectionSplashViewController animated:NO
															 completion:^(){[[AppDelegate sharedAppDelegate] notifyPsiphonConnectionState];}];
		});
	}

	/* in case our orientation changed, or the status bar changed height (which can take a few millis for animation) */
	[self performSelector:@selector(adjustLayout) withObject:nil afterDelay:0.5];
}

- (void)keyboardWillShow:(NSNotification *)notification {
	CGRect keyboardStart = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
	CGRect keyboardEnd = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	
	/* on devices with a bluetooth keyboard attached, both values should be the same for a 0 height */
	keyboardHeight = keyboardStart.origin.y - keyboardEnd.origin.y;
	
	[self adjustLayout];
}

- (void)keyboardWillHide:(NSNotification *)notification {
	keyboardHeight = 0;
	[self adjustLayout];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
	
	[coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
		if (showingTabs)
			[self showTabsWithCompletionBlock:nil];
		
		[self adjustLayout];
	} completion:nil];
}


- (void) showToolBars:(BOOL) show {
	CGFloat navBarOffsetY  = 0.0;
	CGFloat bottomBarOffsetY = 0.0;
	CGRect navBarFrame = navigationBar.frame;
	CGRect bottomToolBarFrame = bottomToolBar.frame;
	float statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
	
	if (isShowingToolBars == show) {
		return;
	}
	
	if(show) {
		navBarOffsetY = statusBarHeight ;
		bottomBarOffsetY = self.view.frame.size.height - TOOLBAR_HEIGHT;
		isShowingToolBars = YES;
	}
	else {
		navBarOffsetY = statusBarHeight - TOOLBAR_HEIGHT;
		bottomBarOffsetY = self.view.frame.size.height;
		isShowingToolBars = NO;
	}
	
	navBarFrame.origin.y = navBarOffsetY;
	bottomToolBarFrame.origin.y = bottomBarOffsetY;
	
	CGFloat toolBarAlpha = show ? 1.0f : 0.0f;
	[UIView animateWithDuration: 0.1 animations:^{
		navigationBar.frame = navBarFrame;
		bottomToolBar.frame = bottomToolBarFrame;
		navigationBar.alpha = toolBarAlpha;
		bottomToolBar.alpha = toolBarAlpha;
		
		tabScroller.frame = CGRectMake(0, navigationBar.frame.origin.y + navigationBar.frame.size.height, navigationBar.frame.size.width, self.view.frame.size.height - (navigationBar.frame.origin.y + navigationBar.frame.size.height) - (self.view.frame.size.height - bottomBarOffsetY));
		[self adjustWebViewTabsLayout];
	}];
	[self.view setBackgroundColor:[UIColor defaultNavigationControllerColor]];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
	
	[tabScroller setBackgroundColor:[UIColor defaultNavigationControllerColor]];
	[tabToolbar setBarTintColor:[UIColor defaultNavigationControllerColor]];
	[urlField setBackgroundColor:[UIColor whiteColor]];
	
	[tabAddButton setTintColor:[progressBar tintColor]];
	[tabDoneButton setTintColor:[progressBar tintColor]];
	[settingsButton setTintColor:[progressBar tintColor]];
	[tabsButton setTintColor:[progressBar tintColor]];
	[tabCount setTextColor:[progressBar tintColor]];
	
	[tabChooser setPageIndicatorTintColor:[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0]];
	[tabChooser setCurrentPageIndicatorTintColor:[UIColor grayColor]];
	
	/* tabScroller.frame is now our actual webview viewing area */
}

- (void)adjustLayout
{
	float statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
	CGSize size = [[UIScreen mainScreen] applicationFrame].size;
	
	/* main background view starts at 0,0, but actual content starts at 0,(app frame origin y to account for status bar/location warning) */
	self.view.frame = CGRectMake(0, 0, size.width, size.height + statusBarHeight);
	
	tabChooser.frame = CGRectMake(0, TOOLBAR_HEIGHT + 20, self.view.frame.size.width, 24);
	
	UIWebView *wv = [[self curWebViewTab] webView];
	currentWebViewScrollOffsetY = wv.scrollView.contentOffset.y;
	
	
	navigationBar.frame = tabToolbar.frame = CGRectMake(0, statusBarHeight, self.view.frame.size.width, TOOLBAR_HEIGHT);
	bottomToolBar.frame = CGRectMake(0, self.view.frame.size.height - TOOLBAR_HEIGHT - keyboardHeight, size.width, TOOLBAR_HEIGHT + keyboardHeight);
	
	
	progressBar.frame = CGRectMake(0, navigationBar.frame.size.height - 2, navigationBar.frame.size.width, 2);
	
	tabScroller.frame = CGRectMake(0, navigationBar.frame.origin.y + navigationBar.frame.size.height, navigationBar.frame.size.width, self.view.frame.size.height - navigationBar.frame.size.height - bottomToolBar.frame.size.height - statusBarHeight);
	
	[self.view setBackgroundColor:[UIColor defaultNavigationControllerColor]];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
	
	[tabScroller setBackgroundColor:[UIColor defaultNavigationControllerColor]];
	[tabToolbar setBarTintColor:[UIColor defaultNavigationControllerColor]];
	[navigationBar setBackgroundColor:[UIColor defaultNavigationControllerColor]];
	[urlField setBackgroundColor:[UIColor whiteColor]];
	[bottomToolBar setBarTintColor:[UIColor defaultNavigationControllerColor]];
	
	[tabAddButton setTintColor:[progressBar tintColor]];
	[tabDoneButton setTintColor:[progressBar tintColor]];
	[settingsButton setTintColor:[progressBar tintColor]];
	[tabsButton setTintColor:[progressBar tintColor]];
	[tabCount setTextColor:[progressBar tintColor]];
	
	[tabChooser setPageIndicatorTintColor:[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0]];
	[tabChooser setCurrentPageIndicatorTintColor:[UIColor grayColor]];
	
	if(!showingTabs) {
		[self adjustWebViewTabsLayout];
	}
	
	
	tabScroller.contentSize = CGSizeMake(size.width * tabChooser.numberOfPages, tabScroller.frame.size.height);
	[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0) animated:NO];
	
	urlField.frame = [self frameForUrlField];
	psiphonConnectionIndicator.frame = [self frameForConnectionIndicator];
	[self updateSearchBarDetails];
	[self.view setNeedsDisplay];
}

- (CGRect)frameForTabIndex:(NSUInteger)number
{
	return CGRectMake((self.view.frame.size.width * number), 0, self.view.frame.size.width, tabScroller.frame.size.height);
}

- (CGRect) frameForConnectionIndicator {
	CGSize size = [[UIScreen mainScreen] applicationFrame].size;
	CGRect frame;
	if(isRTL) {
		frame = CGRectMake(size.width - TOOLBAR_HEIGHT + TOOLBAR_PADDING,
									TOOLBAR_PADDING,
									TOOLBAR_HEIGHT - 2 * TOOLBAR_PADDING,
									TOOLBAR_HEIGHT - 2 * TOOLBAR_PADDING);
	} else {
		frame = CGRectMake(TOOLBAR_PADDING,
									TOOLBAR_PADDING,
									TOOLBAR_HEIGHT - 2 * TOOLBAR_PADDING,
									TOOLBAR_HEIGHT - 2 * TOOLBAR_PADDING);
	}
	return frame;
	
}

- (CGRect)frameForUrlField
{
	float x;
	if(isRTL) {
		x = TOOLBAR_PADDING;
	} else {
		x = 2 * TOOLBAR_PADDING + TOOLBAR_BUTTON_SIZE;
	}
	float y = TOOLBAR_PADDING;
	float w = navigationBar.frame.size.width - 3 * TOOLBAR_PADDING - TOOLBAR_BUTTON_SIZE;
	float h = TOOLBAR_HEIGHT - 2 * TOOLBAR_PADDING;
	return CGRectMake(x, y, w, h);
}

- (NSMutableArray *)webViewTabs
{
	return webViewTabs;
}

- (__strong WebViewTab *)curWebViewTab
{
	if (webViewTabs.count > 0)
		return webViewTabs[curTabIndex];
	else
		return nil;
}

- (long)curWebViewTabHttpsRulesCount
{
	return [[[self curWebViewTab] applicableHTTPSEverywhereRules] count];
}

- (void)setCurTabIndex:(int)tab
{
	if (curTabIndex == tab)
		return;
	
	curTabIndex = tab;
	tabChooser.currentPage = tab;
	
	for (int i = 0; i < webViewTabs.count; i++) {
		WebViewTab *wvt = [webViewTabs objectAtIndex:i];
		[[[wvt webView] scrollView] setScrollsToTop:(i == tab)];
	}
	
	if ([[self curWebViewTab] needsRefresh]) {
		[[self curWebViewTab] refresh];
	}
}

- (WebViewTab *)addNewTabForURL:(NSURL *)url
{
	return [self addNewTabForURL:url forRestoration:NO withCompletionBlock:nil];
}

- (WebViewTab *)addNewTabForURL:(NSURL *)url forRestoration:(BOOL)restoration withCompletionBlock:(void(^)(BOOL))block
{
	WebViewTab *wvt = [[WebViewTab alloc] initWithFrame:[self frameForTabIndex:webViewTabs.count] withRestorationIdentifier:(restoration ? [url absoluteString] : nil)];
	[wvt.webView.scrollView setDelegate:self];
	
	[webViewTabs addObject:wvt];
	[tabChooser setNumberOfPages:webViewTabs.count];
	[wvt setTabIndex:[NSNumber numberWithLong:(webViewTabs.count - 1)]];
	
	[tabCount setText:[NSString stringWithFormat:@"%lu", tabChooser.numberOfPages]];
	
	[tabScroller setContentSize:CGSizeMake(wvt.viewHolder.frame.size.width * tabChooser.numberOfPages, wvt.viewHolder.frame.size.height)];
	[tabScroller addSubview:wvt.viewHolder];
	[tabScroller bringSubviewToFront:navigationBar];
	
	if (showingTabs)
		[wvt zoomOut];
	
	void (^swapToTab)(BOOL) = ^(BOOL finished) {
		[self setCurTabIndex:(int)webViewTabs.count - 1];
		
		[self slideToCurrentTabWithCompletionBlock:^(BOOL finished) {
			if (url != nil)
				[wvt loadURL:url];
			
			[self showTabsWithCompletionBlock:block];
		}];
	};
	
	if (!restoration) {
		/* animate zooming out (if not already), switching to the new tab, then zoom back in */
		if (showingTabs) {
			swapToTab(YES);
		}
		else if (webViewTabs.count > 1) {
			[self showTabsWithCompletionBlock:swapToTab];
		}
		else if (url != nil) {
			[wvt loadURL:url];
		}
	}
	
	// Send "Tab loaded" notification
	[[NSNotificationCenter defaultCenter] postNotificationName:kPsiphonWebTabLoadedNotification object:nil];
	
	return wvt;
}

- (void)addNewTabFromToolbar:(id)_id
{
	//avoid capturing 'self'
	UITextField *localURLField = urlField;
	
	[self addNewTabForURL:nil forRestoration:NO withCompletionBlock:^(BOOL finished) {
		[localURLField becomeFirstResponder];
	}];
}

- (void)removeTab:(NSNumber *)tabNumber
{
	[self removeTab:tabNumber andFocusTab:[NSNumber numberWithInt:-1]];
}

- (void)removeTab:(NSNumber *)tabNumber andFocusTab:(NSNumber *)toFocus
{
	if (tabNumber.intValue > [webViewTabs count] - 1)
		return;
	
	WebViewTab *wvt = (WebViewTab *)webViewTabs[tabNumber.intValue];
	
#ifdef TRACE
	NSLog(@"removing tab %@ (%@) and focusing %@", tabNumber, wvt.title.text, toFocus);
#endif
	int futureFocusNumber = toFocus.intValue;
	if (futureFocusNumber > -1) {
		if (futureFocusNumber == tabNumber.intValue) {
			futureFocusNumber = -1;
		}
		else if (futureFocusNumber > tabNumber.intValue) {
			futureFocusNumber--;
		}
	}
	
	long wvtHash = [wvt hash];
	[[wvt viewHolder] removeFromSuperview];
	[webViewTabs removeObjectAtIndex:tabNumber.intValue];
	[wvt close];
	wvt = nil;
	
	[[[AppDelegate sharedAppDelegate] cookieJar] clearNonWhitelistedDataForTab:wvtHash];
	
	[tabChooser setNumberOfPages:webViewTabs.count];
	[tabCount setText:[NSString stringWithFormat:@"%lu", tabChooser.numberOfPages]];
	
	if (futureFocusNumber == -1) {
		if (curTabIndex == tabNumber.intValue) {
			if (webViewTabs.count > tabNumber.intValue && webViewTabs[tabNumber.intValue]) {
				/* keep currentPage pointing at the page that shifted down to here */
			}
			else if (tabNumber.intValue > 0 && webViewTabs[tabNumber.intValue - 1]) {
				/* removed last tab, keep the previous one */
				[self setCurTabIndex:tabNumber.intValue - 1];
			}
			else {
				/* no tabs left, add one and zoom out */
				
				//avoid capturing 'self'
				UITextField *localURLField = urlField;
				
				[self addNewTabForURL:nil forRestoration:false withCompletionBlock:^(BOOL finished) {
					[localURLField becomeFirstResponder];
				}];
				return;
			}
		}
	}
	else {
		[self setCurTabIndex:futureFocusNumber];
	}
	[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
		tabScroller.contentSize = CGSizeMake(self.view.frame.size.width * tabChooser.numberOfPages, tabScroller.frame.size.height);
		
		for (int i = 0; i < webViewTabs.count; i++) {
			WebViewTab *wvt = webViewTabs[i];
			
			wvt.viewHolder.transform = CGAffineTransformIdentity;
			wvt.viewHolder.frame = [self frameForTabIndex:i];
			wvt.viewHolder.transform = CGAffineTransformMakeScale(ZOOM_OUT_SCALE, ZOOM_OUT_SCALE);
		}
	} completion:^(BOOL finished) {
		[self setCurTabIndex:curTabIndex];
	}];
}

- (void)removeAllTabs
{
	curTabIndex = 0;
	
	for (int i = 0; i < webViewTabs.count; i++) {
		WebViewTab *wvt = (WebViewTab *)webViewTabs[i];
		[[wvt viewHolder] removeFromSuperview];
		[wvt close];
	}
	
	[webViewTabs removeAllObjects];
	[tabChooser setNumberOfPages:0];
	
	[self updateSearchBarDetails];
}

- (void)updateSearchBarDetails
{
	/* TODO: cache curURL and only do anything here if it changed, these changes might be expensive */
	
	[urlField setTextColor:[UIColor darkTextColor]];
	
	if (urlField.isFirstResponder) {
		/* focused, don't muck with the URL while it's being edited */
		[urlField setTextAlignment:NSTextAlignmentNatural];
		[urlField setLeftView:nil];
		[urlField setRightView:nil];
	}
	else {
		[urlField setTextAlignment:NSTextAlignmentCenter];
		[urlField setRightView:refreshButton];
		BOOL isEV = NO;
		if (self.curWebViewTab && self.curWebViewTab.secureMode >= WebViewTabSecureModeSecure) {
			[urlField setLeftView:lockIcon];
			
			if (self.curWebViewTab.secureMode == WebViewTabSecureModeSecureEV) {
				/* wait until the page is done loading */
				if ([progressBar progress] >= 1.0) {
					[urlField setTextColor:[UIColor colorWithRed:0 green:(183.0/255.0) blue:(82.0/255.0) alpha:1.0]];
					
					if ([self.curWebViewTab.SSLCertificate evOrgName] == nil)
						[urlField setText:NSLocalizedString(@"Unknown Organization", nil)];
					else
						[urlField setText:self.curWebViewTab.SSLCertificate.evOrgName];
					
					isEV = YES;
				}
			}
		}
		else if (self.curWebViewTab && self.curWebViewTab.secureMode == WebViewTabSecureModeMixed) {
			[urlField setLeftView:brokenLockIcon];
		}
		else {
			[urlField setLeftView:nil];
		}
		
		if (!isEV) {
			NSString *host;
			if (self.curWebViewTab.url == nil)
				host = @"";
			else {
				host = [self.curWebViewTab.url host];
				if (host == nil)
					host = [self.curWebViewTab.url absoluteString];
			}
			
			NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^www\\d*\\." options:NSRegularExpressionCaseInsensitive error:nil];
			NSString *hostNoWWW = [regex stringByReplacingMatchesInString:host options:0 range:NSMakeRange(0, [host length]) withTemplate:@""];
			
			[urlField setText:hostNoWWW];
			
			if ([urlField.text isEqualToString:@""]) {
				[urlField setTextAlignment:NSTextAlignmentLeft];
			}
		}
	}
	
	backButton.enabled = (self.curWebViewTab && self.curWebViewTab.canGoBack);
	if (backButton.enabled) {
		[backButton setTintColor:[progressBar tintColor]];
	}
	else {
		[backButton setTintColor:[UIColor grayColor]];
	}
	
	forwardButton.enabled = (self.curWebViewTab && self.curWebViewTab.canGoForward);
	if (forwardButton.enabled) {
		[forwardButton setTintColor:[progressBar tintColor]];
	}
	else {
		[forwardButton setTintColor:[UIColor grayColor]];
	}
	
	[urlField setFrame:[self frameForUrlField]];
	[self showToolBars:YES];
}

- (void)updateProgress
{
	BOOL animated = YES;
	float fadeAnimationDuration = 0.15;
	float fadeOutDelay = 0.3;
	
	float progress = [[[self curWebViewTab] progress] floatValue];
	if (progressBar.progress == progress) {
		return;
	}
	else if (progress == 0.0) {
		/* reset without animation, an actual update is probably coming right after this */
		progressBar.progress = 0.0;
		return;
	}
	
#ifdef TRACE
	NSLog(@"[Tab %@] loading progress of %@ at %f", self.curWebViewTab.tabIndex, [self.curWebViewTab.url absoluteString], progress);
#endif
	
	[self updateSearchBarDetails];
	
	if (progress >= 1.0) {
		[progressBar setProgress:progress animated:NO];
		
		[UIView animateWithDuration:fadeAnimationDuration delay:fadeOutDelay options:UIViewAnimationOptionCurveLinear animations:^{
			progressBar.alpha = 0.0;
		} completion:^(BOOL finished) {
			[self updateSearchBarDetails];
		}];
	}
	else {
		[UIView animateWithDuration:(animated ? fadeAnimationDuration : 0.0) delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
			[progressBar setProgress:progress animated:YES];
			
			if (showingTabs)
				progressBar.alpha = 0.0;
			else
				progressBar.alpha = 1.0;
		} completion:nil];
	}
}

- (void)webViewTouched
{
	if ([urlField isFirstResponder]) {
		[urlField resignFirstResponder];
	}
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	if (textField != urlField)
		return;
	
#ifdef TRACE
	NSLog(@"started editing");
#endif
	
	[urlField setText:[self.curWebViewTab.url absoluteString]];
	
	if (bookmarks == nil) {
		bookmarks = [[BookmarkController alloc] init];
		bookmarks.embedded = true;
		bookmarks.view.frame = CGRectMake(0, navigationBar.frame.size.height + navigationBar.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height);
		[self addChildViewController:bookmarks];
		[self.view insertSubview:[bookmarks view] belowSubview:navigationBar];
	}
	
	[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
		[urlField setTextAlignment:NSTextAlignmentNatural];
		[urlField setFrame:[self frameForUrlField]];
	} completion:^(BOOL finished) {
		[urlField performSelector:@selector(selectAll:) withObject:nil afterDelay:0.1];
	}];
	
	[self updateSearchBarDetails];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	if (textField != nil && textField != urlField)
		return;
	
#ifdef TRACE
	NSLog(@"ended editing with: %@", [textField text]);
#endif
	if (bookmarks != nil) {
		[[bookmarks view] removeFromSuperview];
		[bookmarks removeFromParentViewController];
		bookmarks = nil;
	}
	
	[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
		[urlField setTextAlignment:NSTextAlignmentCenter];
		[urlField setFrame:[self frameForUrlField]];
	} completion:nil];
	
	[self updateSearchBarDetails];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if (textField != urlField) {
		return YES;
	}
	
	[self prepareForNewURLFromString:urlField.text];
	
	return NO;
}

- (void)prepareForNewURLFromString:(NSString *)url
{
	/* user is shifting to a new place, probably a good time to clear old data */
	[[[AppDelegate sharedAppDelegate] cookieJar] clearAllOldNonWhitelistedData];
	
	NSURL *enteredURL = [NSURL URLWithString:url];
	
	/* for some reason NSURL thinks "example.com:9091" should be "example.com" as the scheme with no host, so fix up first */
	if ([enteredURL host] == nil && [enteredURL scheme] != nil && [enteredURL resourceSpecifier] != nil)
		enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", url]];
	
	if (![enteredURL scheme] || [[enteredURL scheme] isEqualToString:@""]) {
		/* no scheme so if it has a space or no dots, assume it's a search query */
		if ([url containsString:@" "] || ![url containsString:@"."]) {
			[[self curWebViewTab] searchFor:url];
			enteredURL = nil;
		}
		else
			enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", url]];
	}
	
	[urlField resignFirstResponder]; /* will unfocus and call textFieldDidEndEditing */
	
	if (enteredURL != nil)
		[[self curWebViewTab] loadURL:enteredURL];
}

- (void) adjustWebViewTabsLayout {
	for (int i = 0; i < webViewTabs.count; i++) {
		WebViewTab *wvt = webViewTabs[i];
		[wvt updateFrame:[self frameForTabIndex:i]];
	}
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView == tabScroller) {
		return;
	}
	
	CGFloat contentOffsetY = scrollView.contentOffset.y;
	CGFloat scrollViewHeight = scrollView.frame.size.height;
	CGFloat scrollContentSizeHeight = scrollView.contentSize.height;
	
	if(scrollViewHeight >= scrollContentSizeHeight && isShowingToolBars) {
		return;
	}
	
	if (contentOffsetY < 0.0) {
		return;
	}
	
	if (self->currentWebViewScrollOffsetY >= contentOffsetY) {
		[self showToolBars:YES];
	}
	else {
		[self showToolBars:NO];
	}
	
	// check if scrolled beyond the scrollView bounds
	if(contentOffsetY + scrollViewHeight < scrollContentSizeHeight) {
		self->currentWebViewScrollOffsetY = contentOffsetY;
	}
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	if (scrollView != tabScroller)
		return;
	
	int page = round(scrollView.contentOffset.x / scrollView.frame.size.width);
	if (page < 0) {
		page = 0;
	}
	else if (page > tabChooser.numberOfPages) {
		page = (int)tabChooser.numberOfPages;
	}
	[self setCurTabIndex:page];
}

- (void)goBack:(id)_id
{
	[self.curWebViewTab goBack];
}

- (void)goForward:(id)_id
{
	[self.curWebViewTab goForward];
}

- (void)refresh
{
	[[self curWebViewTab] refresh];
}

- (void)forceRefresh
{
	[[self curWebViewTab] forceRefresh];
}

- (void)openSettingsMenu:(id)_id
{
	// Take a snapshot of current user settings
	preferencesSnapshot = [[NSMutableDictionary alloc] initWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
	
	if (appSettingsViewController == nil) {
		appSettingsViewController = [[SettingsViewController alloc] init];
		appSettingsViewController.delegate = appSettingsViewController;
		appSettingsViewController.showCreditsFooter = NO;
		appSettingsViewController.showDoneButton = YES;
		appSettingsViewController.webViewController = self;
		appSettingsViewController.neverShowPrivacySettings = YES;
	}
	
	// These keys correspond to settings in PsiphonOptions.plist
	BOOL upstreamProxyEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kUseUpstreamProxy];
	BOOL useUpstreamProxyAuthentication = upstreamProxyEnabled && [[NSUserDefaults standardUserDefaults] boolForKey:kUseProxyAuthentication];
	
	NSArray *upstreamProxyKeys = [NSArray arrayWithObjects:kUpstreamProxyHostAddress, kUpstreamProxyPort, kUseProxyAuthentication, nil];
	NSArray *proxyAuthenticationKeys = [NSArray arrayWithObjects:kProxyUsername, kProxyPassword, kProxyDomain, nil];
	
	// Hide configurable fields until user chooses to use upstream proxy
	NSMutableSet *hiddenKeys = upstreamProxyEnabled ? nil : [NSMutableSet setWithArray:upstreamProxyKeys];
	
	// Hide authentication fields until user chooses to use upstream proxy with authentication
	if (!useUpstreamProxyAuthentication) {
		if (hiddenKeys == nil) {
			hiddenKeys = [NSMutableSet setWithArray:proxyAuthenticationKeys];
		} else {
			[hiddenKeys addObjectsFromArray:proxyAuthenticationKeys];
		}
	}
	
	appSettingsViewController.hiddenKeys = hiddenKeys;
	
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:appSettingsViewController];
	[[UIViewController topViewController] presentViewController:navController animated:YES completion:nil];
}

- (void)settingsViewControllerDidEnd
{
	// Allow ARC to dealloc appSettingsViewController
	appSettingsViewController = nil;
	
	// Update relevant ivars to match current settings
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[URLInterceptor setSendDNT:[userDefaults boolForKey:@"sendDoNotTrack"]];
	[[[AppDelegate sharedAppDelegate] cookieJar] setOldDataSweepTimeout:[NSNumber numberWithInteger:[userDefaults integerForKey:@"oldDataSweepMins"]]];
	
	// Check if settings which have changed require a tunnel service restart to take effect
	if ([self isSettingsRestartRequired]) {
		[[AppDelegate sharedAppDelegate] scheduleRunningTunnelServiceRestart];
	}
}

- (BOOL)isSettingsRestartRequired
{
	UpstreamProxySettings *proxySettings = [UpstreamProxySettings sharedInstance];
	
	if (preferencesSnapshot) {
		// Cannot use isEqualToString becase strings may be nil
		BOOL (^safeStringsEqual)(NSString *, NSString *) = ^BOOL(NSString *a, NSString *b) {
			return (([a length] == 0) && ([b length] == 0)) || ([a isEqualToString:b]);
		};
		
		// Check if "disable timeouts" has changed
		BOOL disableTimeouts = [[preferencesSnapshot objectForKey:kDisableTimeouts] boolValue];
		
		if (disableTimeouts != [[NSUserDefaults standardUserDefaults] boolForKey:kDisableTimeouts]) {
			return YES;
		}
		
		// Check if the selected region has changed
		NSString *region = [preferencesSnapshot objectForKey:kRegionSelectionSpecifierKey];
		
		if (!safeStringsEqual(region, [[RegionAdapter sharedInstance] getSelectedRegion].code)) {
			return YES;
		}
		
		// Check if "use proxy" has changed
		BOOL useUpstreamProxy = [[preferencesSnapshot objectForKey:kUseUpstreamProxy] boolValue];
		
		if (useUpstreamProxy != [proxySettings getUseCustomProxySettings]) {
			return YES;
		}
		
		// No further checking if "use proxy" is off and has not
		// changed
		if (!useUpstreamProxy) {
			return NO;
		}
		
		// If "use proxy" is selected, check if host || port have changed
		NSString *hostAddress = [preferencesSnapshot objectForKey:kUpstreamProxyHostAddress];
		NSString *proxyPort = [preferencesSnapshot objectForKey:kUpstreamProxyPort];
		
		if (!safeStringsEqual(hostAddress, [proxySettings getCustomProxyHost]) || !safeStringsEqual(proxyPort, [proxySettings getCustomProxyPort])) {
			return YES;
		}
		
		// Check if "use proxy authentication" has changed
		BOOL useProxyAuthentication = [[preferencesSnapshot objectForKey:kUseProxyAuthentication] boolValue];
		
		if (useProxyAuthentication != [proxySettings getUseProxyAuthentication]) {
			return YES;
		}
		
		// No further checking if "use proxy authentication" is off
		// and has not changed
		if (!useProxyAuthentication) {
			return NO;
		}
		
		// "use proxy authentication" is checked, check if
		// username || password || domain have changed
		NSString *username = [preferencesSnapshot objectForKey:kProxyUsername];
		NSString *password = [preferencesSnapshot objectForKey:kProxyPassword];
		NSString *domain = [preferencesSnapshot objectForKey:kProxyDomain];
		
		if (!safeStringsEqual(username,[proxySettings getProxyUsername]) ||
			!safeStringsEqual(password, [proxySettings getProxyPassword]) ||
			!safeStringsEqual(domain, [proxySettings getProxyDomain])) {
			return YES;
		}
	}
	return NO;
}

- (void)showTabs:(id)_id
{
	return [self showTabsWithCompletionBlock:nil];
}

- (void)showTabsWithCompletionBlock:(void(^)(BOOL))block
{
	if (showingTabs == false) {
		/* zoom out */
		
		/* make sure no text is selected */
		[urlField resignFirstResponder];
		
		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < webViewTabs.count; i++) {
				[(WebViewTab *)webViewTabs[i] zoomOut];
			}
			
			tabChooser.hidden = false;
			navigationBar.hidden = true;
			tabToolbar.hidden = false;
			progressBar.alpha = 0.0;
		} completion:block];
		
		tabScroller.contentOffset = CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0);
		tabScroller.scrollEnabled = YES;
		tabScroller.pagingEnabled = YES;
		
		UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedOnWebViewTab:)];
		singleTapGestureRecognizer.numberOfTapsRequired = 1;
		singleTapGestureRecognizer.enabled = YES;
		singleTapGestureRecognizer.cancelsTouchesInView = NO;
		[tabScroller addGestureRecognizer:singleTapGestureRecognizer];
	}
	else {
		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < webViewTabs.count; i++) {
				[(WebViewTab *)webViewTabs[i] zoomNormal];
			}
			
			tabChooser.hidden = true;
			navigationBar.hidden = false;
			tabToolbar.hidden = true;
			progressBar.alpha = (progressBar.progress > 0.0 && progressBar.progress < 1.0 ? 1.0 : 0.0);
		} completion:block];
		
		tabScroller.scrollEnabled = NO;
		tabScroller.pagingEnabled = NO;
		
		[self updateSearchBarDetails];
	}
	
	showingTabs = !showingTabs;
}

- (void)doneWithTabsButton:(id)_id
{
	[self showTabs:nil];
}

- (void) addBookmarkFromBottomToolbar:(id)_id {
	BookmarkController *bc = [[BookmarkController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bc];
	[[[AppDelegate sharedAppDelegate] webViewController] presentViewController:navController animated:YES completion:nil];
}


- (void)showSSLCertificate
{
	if ([[self curWebViewTab] SSLCertificate] == nil)
		return;
	
	SSLCertificateViewController *scvc = [[SSLCertificateViewController alloc] initWithSSLCertificate:[[self curWebViewTab] SSLCertificate]];
	scvc.title = [[[self curWebViewTab] url] host];
	
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:scvc];
	[self presentViewController:navController animated:YES completion:nil];
}

- (void)tappedOnWebViewTab:(UITapGestureRecognizer *)gesture
{
	if (!showingTabs) {
		if ([urlField isFirstResponder]) {
			[urlField resignFirstResponder];
		}
		
		return;
	}
	
	CGPoint point = [gesture locationInView:self.curWebViewTab.viewHolder];
	
	/* fuzz a bit to make it easier to tap */
	int fuzz = 8;
	CGRect closerFrame = CGRectMake(self.curWebViewTab.closer.frame.origin.x - fuzz, self.curWebViewTab.closer.frame.origin.y - fuzz, self.curWebViewTab.closer.frame.size.width + (fuzz * 2), self.curWebViewTab.closer.frame.size.width + (fuzz * 2));
	if (CGRectContainsPoint(closerFrame, point)) {
		[self removeTab:[NSNumber numberWithLong:curTabIndex]];
	}
	else {
		[self showTabs:nil];
	}
}

- (void)slideToCurrentTabWithCompletionBlock:(void(^)(BOOL))block
{
	[self updateProgress];
	
	[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0) animated:NO];
	} completion:block];
}

- (IBAction)slideToCurrentTab:(id)_id
{
	[self slideToCurrentTabWithCompletionBlock:nil];
}

- (NSString *)buildDefaultUserAgent
{
	/*
	 * Some sites do mobile detection by looking for Safari in the UA, so make us look like Mobile Safari
	 *
	 * from "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H321"
	 * to   "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12H321 Safari/600.1.4"
	 */
	
	UIWebView *twv = [[UIWebView alloc] initWithFrame:CGRectZero];
	NSString *ua = [twv stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
	
	NSMutableArray *uapieces = [[NSMutableArray alloc] initWithArray:[ua componentsSeparatedByString:@" "]];
	NSString *uamobile = uapieces[uapieces.count - 1];
	
	/* assume safari major version will match ios major */
	NSArray *osv = [[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."];
	uapieces[uapieces.count - 1] = [NSString stringWithFormat:@"Version/%@.0", osv[0]];
	
	[uapieces addObject:uamobile];
	
	/* now tack on "Safari/XXX.X.X" from webkit version */
	for (id j in uapieces) {
		if ([(NSString *)j containsString:@"AppleWebKit/"]) {
			[uapieces addObject:[(NSString *)j stringByReplacingOccurrencesOfString:@"AppleWebKit" withString:@"Safari"]];
			break;
		}
	}
	
	return [uapieces componentsJoinedByString:@" "];
}

- (void) psiphonConnectionStateNotified:(NSNotification *)notification
{
	PsiphonConnectionState state = [[notification.userInfo objectForKey:kPsiphonConnectionState] unsignedIntegerValue];
	[psiphonConnectionIndicator displayConnectionState:state];
	if(state != PsiphonConnectionStateConnected) {
		[self stopLoading];
	}
}

- (void) stopLoading
{
	for (WebViewTab *wvt in webViewTabs) {
		if (wvt.webView.isLoading) {
			[wvt.webView stopLoading];
			[wvt setProgress:@(0.0f)];
		}
	}
	[self updateProgress];
}

#pragma mark - Tutorial Delegate Methods
// Draw the next tutorial step
// Add constraints and draw spotlight
-(BOOL)drawStep:(int)step
{
	[self drawSpotlight:step];
	
	[self.view removeConstraints:tutorial.removeBeforeNextStep];
	
	if (step == PsiphonTutorialStep1) {
		/* Hello from Psiphon. Also, highlight and describe psiphonConnectionIndicator */
		
		NSDictionary *metrics = @{ @"arrowHeight":[NSNumber numberWithFloat: tutorial.arrowView.image.size.height] };
		
		// Verticaly constrain arrowView to be centered to psiphonConnectionIndicator
		tutorial.removeBeforeNextStep = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[psiphonConnectionIndicator]-30-[arrowView(==arrowHeight)]" options:NSLayoutFormatAlignAllCenterX metrics:metrics views:tutorial.viewsDictionary];
		
		[self.view addConstraints:tutorial.removeBeforeNextStep];
		
		// Start arrow animation
		[tutorial animateArrow:CGAffineTransformMakeTranslation(0.0, 20.0)];
		
		return YES;
	} else if (step == PsiphonTutorialStep2) {
		[tutorial.headerView removeFromSuperview];
		
		// If we are not using iPad need to change alignment from
		// textView.top = contentView.centerY
		// to
		// textView.centerY = contentView.centerY
		if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
			NSLayoutConstraint *centreTextView = [tutorial.constraintsDictionary valueForKey:@"centreTextView"];
			if (centreTextView != nil) {
				[tutorial.contentView removeConstraint:centreTextView];
				centreTextView = [NSLayoutConstraint constraintWithItem:tutorial.textView
															  attribute: NSLayoutAttributeCenterY
															  relatedBy:NSLayoutRelationEqual
																 toItem:tutorial.contentView
															  attribute:NSLayoutAttributeCenterY
															 multiplier:1.f constant:0.f];
				centreTextView.constant = 10;
				[tutorial.contentView addConstraint:centreTextView];
			}
		}
		
		/* Highlight settings button and describe settings menu */
		
		tutorial.arrowView.image = [UIImage imageNamed:@"arrow-down"];
		NSDictionary *metrics = @{ @"arrowHeight":[NSNumber numberWithFloat: tutorial.arrowView.image.size.height] };
		
		// Vertically constrain arrowView to be placed above the settings button spotlight
		tutorial.removeBeforeNextStep = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[arrowView(==arrowHeight)]-50-[bottomToolBar]" options:NSLayoutFormatAlignAllCenterX metrics:metrics views:tutorial.viewsDictionary];
		
		// Vertically constrain the textView to be above arrowView to prevent unwanted overlap or cutoff
		tutorial.removeBeforeNextStep = [tutorial.removeBeforeNextStep arrayByAddingObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[textView]-(>=0)-[arrowView]" options:0 metrics:nil views:tutorial.viewsDictionary]];
		
		[self.view addConstraints:tutorial.removeBeforeNextStep];
		
		return YES;
	} else if (step == PsiphonTutorialStep3) {
		/* Tutorial goodbye with no spotlight */
		
		[tutorial.arrowView removeFromSuperview]; // arrowView not used on this screen
		[tutorial.contentView addSubview:tutorial.letsGo]; // add letsGo button
		
		if (tutorial.letsGo != nil) {
			CGFloat buttonWidth = (tutorial.contentView.frame.size.width) / 3;
			buttonWidth = buttonWidth > 120 ? buttonWidth : 120;
			CGFloat buttonHeight = 40;
			
			NSDictionary *metrics = @{
									  @"buttonWidth": [NSNumber numberWithFloat:buttonWidth],
									  @"buttonHeight": [NSNumber numberWithFloat:buttonHeight]
									  };
			
			// Horizontal constraints for letsGo button
			[tutorial.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[letsGo(==buttonWidth)]" options:0 metrics:metrics views:tutorial.viewsDictionary]];
			[tutorial.letsGo.layer setCornerRadius:buttonHeight/2];
			
			// textView to letsGo button vertical spacing
			tutorial.removeBeforeNextStep = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[textView]-32-[letsGo(==buttonHeight)]" options:NSLayoutFormatAlignAllCenterX metrics:metrics views:tutorial.viewsDictionary];
			
			[tutorial.contentView addConstraints:tutorial.removeBeforeNextStep];
		}
		
		return YES;
	}
	
	return NO;
}

-(void)tutorialEnded
{
	BOOL launchedFromOnboarding = ![[NSUserDefaults standardUserDefaults] boolForKey:@"hasBeenOnBoarded"];
 
	tutorial = nil;
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(psiphonConnectionStateNotified:) name:kPsiphonConnectionStateNotification object:nil];
	[center removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
	[center removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
	
	// Since we have modified the psiphonConnectionIndicator's state manually for the tutorial
	// we need to ensure it gets reset to display the correct state
	[[AppDelegate sharedAppDelegate] notifyPsiphonConnectionState];
	
	if (launchedFromOnboarding) {
		// Resume setup
		// User has been fully onboarded
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasBeenOnBoarded"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
		// Start psiphon and open homepage
		[[AppDelegate sharedAppDelegate] startIfNeeded];
	}

	[self viewIsVisible];
}

#pragma mark - Tutorial methods and helper functions

- (void)viewDidLayoutSubviews
{
	if (tutorial != nil) {
		[self drawSpotlight:tutorial.step];
	}
}

- (void)drawSpotlight:(int)step
{
	CGRect frame = [self getCurrentSpotlightFrame:step];
	[self wrappedTutorialCall:^(void){ [tutorial setSpotlightFrame:frame withView:self.view]; }];
}

- (CGRect)getCurrentSpotlightFrame:(int)step
{
	int radius = psiphonConnectionIndicator.frame.size.width * 1.2;
	
	if (step == 0) {
		return CGRectMake(psiphonConnectionIndicator.frame.origin.x - (radius - psiphonConnectionIndicator.frame.size.width / 2), psiphonConnectionIndicator.frame.origin.y + navigationBar.frame.origin.y - (radius - psiphonConnectionIndicator.frame.size.height / 2), radius * 2.0, radius * 2.0);
	} else if (step == 1) {
		return CGRectMake(bottomToolBar.frame.size.width / 2 - radius, self.view.frame.size.height - bottomToolBar.frame.size.height / 2 - radius, radius * 2.0, radius * 2.0);
	}
	return CGRectNull;
}

- (void)handleTutorialClick:(UITapGestureRecognizer *)recognizer {
	[self wrappedTutorialCall:^(void){ [tutorial nextStep]; }];
}

- (void)wrappedTutorialCall:(void (^)())f{
	if (tutorial != nil) {
		f();
	}
}

-(void)tutorialBackgrounded {
	[tutorial.arrowView.layer removeAllAnimations];
}

-(void)tutorialReappeared {
	[tutorial animateArrow:CGAffineTransformMakeTranslation(0.0, 20.0)];
}

-(void)overlayTutorial
{
	// Unsubscribe from psiphonConnectionState notifications
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver:self name:kPsiphonConnectionStateNotification object:nil];
	
	// We need to stop and start animations on app backgrounded and app became active
	[center addObserver:self selector:@selector(tutorialBackgrounded) name:UIApplicationDidEnterBackgroundNotification object:nil];
	[center addObserver:self selector:@selector(tutorialReappeared) name:UIApplicationDidBecomeActiveNotification object:nil];
	
	// Force connectionIndicator to show connected state
	[psiphonConnectionIndicator displayConnectionState:PsiphonConnectionStateConnected];
	
	// Init
	tutorial = [[Tutorial alloc] init];
	tutorial.delegate = self;
	
	/* Add completely clear background which prevents user clicking around */
	// We will not add any subviews to this view as we need to
	// layout against browser elements.
	tutorial.blockingView = [[UIView alloc] initWithFrame:self.view.bounds];
	tutorial.blockingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; // If this doesn't auto-resize on rotate we'll be able to click through
	tutorial.blockingView.backgroundColor = [UIColor clearColor];
	[self.view addSubview:tutorial.blockingView];
	
	// Created centred contentView which will hold tutorial
	// headerView, titleView and textView.
	tutorial.contentView = [[UIView alloc] init];
	tutorial.contentView.translatesAutoresizingMaskIntoConstraints = NO;
	tutorial.contentView.backgroundColor = [UIColor clearColor];
	
	/* Add tutorial views to self.view */
	[tutorial addToView:self.view];
	
	/* contentView's constraints */
	
	CGFloat contentViewWidthRatio = 0.68f;
	
	// contentView.width = contentViewWidthRatio * self.view.width
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.contentView
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeWidth
														 multiplier:contentViewWidthRatio
														   constant:0]];
	
	// contentView.height = self.view.height
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.contentView
														  attribute:NSLayoutAttributeHeight
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeHeight
														 multiplier:.5f
														   constant:0]];
	
	// contentView.centerX = self.view.centerX
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.contentView
														  attribute:NSLayoutAttributeCenterX
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeCenterX
														 multiplier:1.f constant:0.f]];
	
	// contentView.centerY = self.view.centerY (low-priority)
	NSLayoutConstraint *contentViewCentreY = [NSLayoutConstraint constraintWithItem:tutorial.contentView
																		  attribute:NSLayoutAttributeCenterY
																		  relatedBy:NSLayoutRelationEqual
																			 toItem:self.view
																		  attribute:NSLayoutAttributeCenterY
																		 multiplier:1.f constant:0.f];
	contentViewCentreY.priority = 10;
	[self.view addConstraint:contentViewCentreY];
	
	id <UILayoutSupport> topLayoutGuide =  self.topLayoutGuide;
	
	[tutorial constructViewsDictionaryForAutoLayout:NSDictionaryOfVariableBindings(topLayoutGuide, psiphonConnectionIndicator, bottomToolBar)];
	
	/* skipButton constraints */
	[tutorial.skipButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentRight];
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[skipButton]-30-|" options:0 metrics:nil views:tutorial.viewsDictionary]];
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[skipButton]-(>=0)-[headerView]" options:0 metrics:nil views:tutorial.viewsDictionary]];
	
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.skipButton
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeWidth
														 multiplier:.35f
														   constant:0]];
	
	// Centre skip button vertically in nav bar
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.skipButton
														  attribute:NSLayoutAttributeCenterY
														  relatedBy:NSLayoutRelationEqual
															 toItem:navigationBar
														  attribute:NSLayoutAttributeCenterY
														 multiplier:1.f constant:0.f]];
	
	/* Add constraints to contentViews's subviews */
	
	/* headerView's constraints */
	
	// headerView.top = contentView.top (low-priority)
	NSLayoutConstraint *headerViewToTop = [NSLayoutConstraint constraintWithItem:tutorial.headerView
																	   attribute:NSLayoutAttributeTop
																	   relatedBy:NSLayoutRelationEqual
																		  toItem:tutorial.contentView
																	   attribute:NSLayoutAttributeTop
																	  multiplier:1.f constant:0.f];
	headerViewToTop.priority = 10;
	[tutorial.contentView addConstraint:headerViewToTop];
	
	// headerView.centerX = contentView.centerX
	[tutorial.contentView addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.headerView
																	 attribute:NSLayoutAttributeCenterX
																	 relatedBy:NSLayoutRelationEqual
																		toItem:tutorial.contentView
																	 attribute:NSLayoutAttributeCenterX
																	multiplier:1.f constant:0.f]];
	
	// headerView.width = contentView.width
	[tutorial.contentView addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.headerView
																	 attribute:NSLayoutAttributeWidth
																	 relatedBy:NSLayoutRelationEqual
																		toItem:tutorial.contentView
																	 attribute:NSLayoutAttributeWidth
																	multiplier:1.f
																	  constant:0]];
	
	// headerView.height <= 0.25 * contentView.height
	[tutorial.contentView addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.headerView
																	 attribute:NSLayoutAttributeHeight
																	 relatedBy:NSLayoutRelationLessThanOrEqual
																		toItem:tutorial.contentView
																	 attribute:NSLayoutAttributeHeight
																	multiplier:.25f
																	  constant:0]];
	
	tutorial.headerView.preferredMaxLayoutWidth = self.view.frame.size.width * contentViewWidthRatio;
	[tutorial.headerView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	[tutorial.headerView setContentCompressionResistancePriority:999 forAxis:UILayoutConstraintAxisVertical];
	
	/* titleView's constraints */
	
	// titleView.centerX = contentView.centerX
	[tutorial.contentView addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.titleView
																	 attribute:NSLayoutAttributeCenterX
																	 relatedBy:NSLayoutRelationEqual
																		toItem:tutorial.contentView
																	 attribute:NSLayoutAttributeCenterX
																	multiplier:1.f constant:0.f]];
	
	// titleView.width = contentView.width
	[tutorial.contentView addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.titleView
																	 attribute:NSLayoutAttributeWidth
																	 relatedBy:NSLayoutRelationEqual
																		toItem:tutorial.contentView
																	 attribute:NSLayoutAttributeWidth
																	multiplier:1.f
																	  constant:0]];
	
	// titlteView.height <= 0.15 * contentView.height
	[tutorial.contentView addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.titleView
																	 attribute:NSLayoutAttributeHeight
																	 relatedBy:NSLayoutRelationLessThanOrEqual
																		toItem:tutorial.contentView
																	 attribute:NSLayoutAttributeHeight
																	multiplier:.15f
																	  constant:0]];
	
	tutorial.titleView.preferredMaxLayoutWidth = self.view.frame.size.width * contentViewWidthRatio;
	[tutorial.titleView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	[tutorial.titleView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	
	/* textView's constraints */
	
	CGFloat textViewWidthRatio = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? .8f : 1.f;
	
	// textView.centerX = contentView.centerX
	[tutorial.contentView addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.textView
																	 attribute:NSLayoutAttributeCenterX
																	 relatedBy:NSLayoutRelationEqual
																		toItem:tutorial.contentView
																	 attribute:NSLayoutAttributeCenterX
																	multiplier:1.f constant:0.f]];
	
	// textView.width = textViewWidthRatio * contentView.width
	[tutorial.contentView addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.textView
																	 attribute:NSLayoutAttributeWidth
																	 relatedBy:NSLayoutRelationEqual
																		toItem:tutorial.contentView
																	 attribute:NSLayoutAttributeWidth
																	multiplier:textViewWidthRatio
																	  constant:0]];
	
	// textView.top = contentView.centerX
	NSLayoutConstraint *centreTextView = [NSLayoutConstraint constraintWithItem:tutorial.textView
																	  attribute:UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? NSLayoutAttributeCenterY : NSLayoutAttributeTop
																	  relatedBy:NSLayoutRelationEqual
																		 toItem:tutorial.contentView
																	  attribute:NSLayoutAttributeCenterY
																	 multiplier:1.f constant:0.f];
	centreTextView.priority = 15; // we'll need to break this constraint on smaller screens
	[tutorial.contentView addConstraint:centreTextView];
	
	tutorial.textView.preferredMaxLayoutWidth = self.view.frame.size.width * contentViewWidthRatio * textViewWidthRatio;
	[tutorial.textView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	[tutorial.textView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	
	// textView.height <= 0.6 * contentView.height
	[tutorial.contentView addConstraint:[NSLayoutConstraint constraintWithItem:tutorial.textView
																	 attribute:NSLayoutAttributeHeight
																	 relatedBy:NSLayoutRelationLessThanOrEqual
																		toItem:tutorial.contentView
																	 attribute:NSLayoutAttributeHeight
																	multiplier:.6f
																	  constant:0]];
	
	/* Construct constraints dictionary */
	tutorial.constraintsDictionary = [[NSMutableDictionary alloc] init];
	[tutorial.constraintsDictionary addEntriesFromDictionary:NSDictionaryOfVariableBindings(centreTextView)];
	
	// Vertical constraints for contentView's subviews
	[tutorial.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[headerView]-(>=24)-[titleView]-(==24)-[textView]-(>=0)-|" options:0 metrics:nil views:tutorial.viewsDictionary]];

	/* Start tutorial */
	[tutorial startTutorial];

	UITapGestureRecognizer *tutorialBlockingViewPress =
	[[UITapGestureRecognizer alloc] initWithTarget:self
											action:@selector(handleTutorialClick:)];

	[tutorial.blockingView addGestureRecognizer:tutorialBlockingViewPress];

	UITapGestureRecognizer *tutorialContentViewPress =
	[[UITapGestureRecognizer alloc] initWithTarget:self
											action:@selector(handleTutorialClick:)];

	[tutorial.contentView addGestureRecognizer:tutorialContentViewPress];
}

- (void) showPsiphonConnectionStatusAlert {
	PsiphonConnectionAlertViewController *connectionAlertViewController = [[PsiphonConnectionAlertViewController alloc]
																		   initWithState:[[AppDelegate sharedAppDelegate] psiphonConectionState]];
	connectionAlertViewController.delegate = self;
	
	[connectionAlertViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Settings", nil)
																	  style:UIAlertActionStyleDefault
																	handler:^(NYAlertAction *action) {
																		[connectionAlertViewController.presentingViewController dismissViewControllerAnimated:YES                                                                                                                                                    completion:^(void){[self openSettingsMenu:nil];}];
																	}]];
	
	[connectionAlertViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Done", nil)
																	  style:UIAlertActionStyleDefault
																	handler:^(NYAlertAction *action) {
																		[connectionAlertViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
																	}]];
	
	[[UIViewController topViewController] presentViewController:connectionAlertViewController animated:NO
													 completion:^(){[[AppDelegate sharedAppDelegate] notifyPsiphonConnectionState];}];
}

#pragma mark RegionSelectionControllerDelegate method implementation
- (void) regionSelectionControllerWillStart {
	// Take a snapshot of current user settings
	preferencesSnapshot = [[NSMutableDictionary alloc] initWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
}

- (void) regionSelectionControllerDidEnd {
	if (preferencesSnapshot) {
		// Cannot use isEqualToString becase strings may be nil
		BOOL (^safeStringsEqual)(NSString *, NSString *) = ^BOOL(NSString *a, NSString *b) {
			return (([a length] == 0) && ([b length] == 0)) || ([a isEqualToString:b]);
		};
		// Check if the selected region has changed
		NSString *region = [preferencesSnapshot objectForKey:kRegionSelectionSpecifierKey];
		
		if (!safeStringsEqual(region, [[RegionAdapter sharedInstance] getSelectedRegion].code)) {
			[[AppDelegate sharedAppDelegate] scheduleRunningTunnelServiceRestart];
		}
	}
}

@end
