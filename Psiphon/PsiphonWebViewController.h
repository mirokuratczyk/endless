//
//  PsiphonViewController.h
//  Endless
//
//  Created by eugene-imac on 2016-11-15.
//  Copyright © 2016 jcs. All rights reserved.
//

#import <PsiphonTunnel/PsiphonTunnel.h>
#import "WebViewController.h"

@interface PsiphonWebViewController : WebViewController <TunneledAppDelegate>

@property(strong, nonatomic) PsiphonTunnel* psiphonTunnel;
@property int socksProxyPort;
@property BOOL isPsiphonConnected;

@end

