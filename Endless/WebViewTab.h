/*
 * Copyright (c) 2017, Psiphon Inc.
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
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>
#import <UIKit/UIKit.h>

#import "DownloadHelper.h"
#import "SSLCertificate.h"

#define ZOOM_OUT_SCALE 0.6
#define UNIVERSAL_LINKS_WORKAROUND_KEY @"universalLinksWorkaroundKey"

#define MAX_EQUIVALENT_URLS 5

typedef NS_ENUM(NSInteger, WebViewTabSecureMode) {
	WebViewTabSecureModeInsecure,
	WebViewTabSecureModeMixed,
	WebViewTabSecureModeSecure,
	WebViewTabSecureModeSecureEV,
};

@protocol FinalPageObserver;

@interface WebViewTab : NSObject <DownloadTaskDelegate, UIWebViewDelegate, UIGestureRecognizerDelegate, UIDocumentInteractionControllerDelegate, QLPreviewControllerDataSource, QLPreviewControllerDelegate>

@property (strong, atomic) UIView *viewHolder;
@property (strong, atomic) UIWebView *webView;
@property (strong, atomic) UIRefreshControl *refresher;
@property (strong, atomic) NSURL *url;
@property BOOL isDownloadingFile;
@property BOOL isRestoring;
@property BOOL shouldReloadOnConnected;
@property (strong, atomic) NSNumber *tabIndex;
@property (strong, atomic) UIView *titleHolder;
@property (strong, atomic) UILabel *title;
@property (strong, atomic) UILabel *closer;
@property (strong, nonatomic) NSNumber *progress;

@property WebViewTabSecureMode secureMode;
@property (strong, nonatomic) SSLCertificate *SSLCertificate;
@property NSMutableDictionary *applicableHTTPSEverywhereRules;

/* for javascript IPC */
@property (strong, atomic) NSNumber *openedByTabHash;

@property (nonatomic, weak) id <FinalPageObserver> finalPageObserverDelegate;

- (id)initWithFrame:(CGRect)frame;
- (id)initWithFrame:(CGRect)frame withRestorationIdentifier:(NSString *)rid;
- (void)close;
- (void)updateFrame:(CGRect)frame;
- (void)loadURL:(NSURL *)u;
- (void)searchFor:(NSString *)query;
- (BOOL)canGoBack;
- (BOOL)canGoForward;
- (void)goBack;
- (void)goForward;
- (void)refresh;
- (void)forceRefresh;
- (void)zoomOut;
- (void)zoomNormal;
- (void)clearEquivalentURLs;
- (void)initLocalizables;

@end

@protocol FinalPageObserver <NSObject>
- (void) seenFinalPage: (NSArray*)equivalentURLs;
@end
