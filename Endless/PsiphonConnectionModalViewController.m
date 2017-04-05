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
 */

#import "PsiphonConnectionModalViewController.h"
#import "RegionAdapter.h"
#import "RegionSelectionViewController.h"

@implementation PsiphonConnectionModalViewController {
    PsiphonConnectionState _connectionState;
}

- (id) initWithState:(PsiphonConnectionState)state {
    self = [super initWithNibName:nil bundle:nil];
    if(self) {
        self.dismissOnConnected = NO;
        [self setupViewsForState: state];
    }
    return self;
}

-(void) viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(psiphonConnectionStateNotified:)
                                                 name:kPsiphonConnectionStateNotification object:nil];
    [super viewWillAppear:animated];
}

-(void) viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kPsiphonConnectionStateNotification object:nil];
    [super viewWillDisappear:animated];
}

- (void) psiphonConnectionStateNotified:(NSNotification *)notification
{
    PsiphonConnectionState state = [[notification.userInfo objectForKey:kPsiphonConnectionState] unsignedIntegerValue];
    
    if (state == _connectionState) {
        //Nothing has changed
        return;
    }
    
    _connectionState = state;
    
    if(state == PsiphonConnectionStateConnected && self.dismissOnConnected == YES) {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    [self updateViews];
}

-(void) setupViewsForState:(PsiphonConnectionState)state {
    
    NSString *title = @"";
    NSString *message = @"";
    UIView *contentView = nil;
    
    if (state == PsiphonConnectionStateConnecting) {
        contentView = [[UIView alloc] initWithFrame:CGRectZero];
        
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc]
                                                      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        CGAffineTransform transform = CGAffineTransformMakeScale(2.5f, 2.5f);
        activityIndicator.transform = transform;
        [activityIndicator setTranslatesAutoresizingMaskIntoConstraints:NO];
        [activityIndicator startAnimating];
        
        [contentView addSubview:activityIndicator];
        
        UILabel *connectionRegionLabel = [[UILabel alloc] init];
        [connectionRegionLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
        connectionRegionLabel.numberOfLines = 0;
        connectionRegionLabel.textAlignment = NSTextAlignmentCenter;
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(connectionRegionLabelTapped)];
        tapGestureRecognizer.numberOfTapsRequired = 1;
        [connectionRegionLabel addGestureRecognizer:tapGestureRecognizer];
        connectionRegionLabel.userInteractionEnabled = YES;

        [contentView addSubview:connectionRegionLabel];
        
        Region *selectedRegion = [[RegionAdapter sharedInstance] getSelectedRegion];
        NSString *regionTitle = [[RegionAdapter sharedInstance] getLocalizedRegionTitle:selectedRegion.code];
        
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        textAttachment.image = [UIImage imageNamed:selectedRegion.flagResourceId];
        NSAttributedString *attrStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachment];
        textAttachment.bounds = CGRectMake(0, connectionRegionLabel.font.descender - 5, textAttachment.image.size.width, textAttachment.image.size.height);
        
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"Currently selected region:", @"")];
        [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\n"]];
        [attributedString appendAttributedString:attrStringWithImage];
        [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
        [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:regionTitle]];
        
        connectionRegionLabel.attributedText = attributedString;
        
        [contentView addConstraints:@[[NSLayoutConstraint constraintWithItem:activityIndicator
                                                                   attribute:NSLayoutAttributeTop
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:contentView
                                                                   attribute:NSLayoutAttributeTop
                                                                  multiplier:1.0
                                                                    constant:15],
                                      [NSLayoutConstraint constraintWithItem:activityIndicator
                                                                   attribute:NSLayoutAttributeCenterX
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:contentView
                                                                   attribute:NSLayoutAttributeCenterX
                                                                  multiplier:1.0
                                                                    constant:0],
                                      
                                      [NSLayoutConstraint constraintWithItem:connectionRegionLabel
                                                                   attribute:NSLayoutAttributeCenterX
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:contentView
                                                                   attribute:NSLayoutAttributeCenterX
                                                                  multiplier:1.0
                                                                    constant:0],
                                      [NSLayoutConstraint constraintWithItem:connectionRegionLabel
                                                                   attribute:NSLayoutAttributeTop
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:activityIndicator
                                                                   attribute:NSLayoutAttributeBottom
                                                                  multiplier:1.0
                                                                    constant:30],
                                      
                                      [NSLayoutConstraint constraintWithItem:connectionRegionLabel
                                                                   attribute:NSLayoutAttributeBottom
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:contentView
                                                                   attribute:NSLayoutAttributeBottom
                                                                  multiplier:1.0
                                                                    constant:-10],
                                      ]];
        
        
        title = NSLocalizedString(@"Connecting...",
                                  @"Connection status initial splash modal dialog title for 'Connecting...' state");
        message = nil;
    } else if (state == PsiphonConnectionStateWaitingForNetwork) {
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc]
                                                      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        CGAffineTransform transform = CGAffineTransformMakeScale(2.5f, 2.5f);
        activityIndicator.transform = transform;
        [activityIndicator startAnimating];
        
        contentView = [[UIView alloc] initWithFrame:CGRectZero];
        
        [activityIndicator setTranslatesAutoresizingMaskIntoConstraints:NO];
        
        [contentView addSubview:activityIndicator];
        
        NSDictionary *variables = NSDictionaryOfVariableBindings(activityIndicator, contentView);
        
        NSArray *constraints =
        [NSLayoutConstraint constraintsWithVisualFormat:@"V:[contentView(65)]-(<=1)-[activityIndicator]"
                                                options: NSLayoutFormatAlignAllCenterX
                                                metrics:nil
                                                  views:variables];
        [contentView addConstraints:constraints];
        
        constraints =
        [NSLayoutConstraint constraintsWithVisualFormat:@"H:[contentView]-(<=1)-[activityIndicator]"
                                                options: NSLayoutFormatAlignAllCenterY
                                                metrics:nil
                                                  views:variables];
        [contentView addConstraints:constraints];
        
        title = NSLocalizedString(@"Waiting for network...",
                                  @"Connection status initial splash modal dialog title for 'Waiting for network...' state");
        message = nil;
    } else if(state == PsiphonConnectionStateConnected){
        contentView = [[UIView alloc] initWithFrame:CGRectZero];
        
        UILabel *connectionRegionLabel = [[UILabel alloc] init];
        [connectionRegionLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
        connectionRegionLabel.numberOfLines = 0;
        connectionRegionLabel.textAlignment = NSTextAlignmentCenter;
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(connectionRegionLabelTapped)];
        tapGestureRecognizer.numberOfTapsRequired = 1;
        [connectionRegionLabel addGestureRecognizer:tapGestureRecognizer];
        connectionRegionLabel.userInteractionEnabled = YES;
        
        [contentView addSubview:connectionRegionLabel];
        
        Region *selectedRegion = [[RegionAdapter sharedInstance] getSelectedRegion];
        NSString *regionTitle = [[RegionAdapter sharedInstance] getLocalizedRegionTitle:selectedRegion.code];
                
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        textAttachment.image = [UIImage imageNamed:selectedRegion.flagResourceId];
        NSAttributedString *attrStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachment];
        textAttachment.bounds = CGRectMake(0, connectionRegionLabel.font.descender - 5, textAttachment.image.size.width, textAttachment.image.size.height);
        
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"Current connection region:", @"")];
        [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\n"]];
        [attributedString appendAttributedString:attrStringWithImage];
        [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
        [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:regionTitle]];
        
        connectionRegionLabel.attributedText = attributedString;
        
        [contentView addConstraints:@[[NSLayoutConstraint constraintWithItem:connectionRegionLabel
                                                                   attribute:NSLayoutAttributeCenterX
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:contentView
                                                                   attribute:NSLayoutAttributeCenterX
                                                                  multiplier:1.0
                                                                    constant:0],
                                      [NSLayoutConstraint constraintWithItem:connectionRegionLabel
                                                                   attribute:NSLayoutAttributeTop
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:contentView
                                                                   attribute:NSLayoutAttributeTop
                                                                  multiplier:1.0
                                                                    constant:10],
                                      
                                      [NSLayoutConstraint constraintWithItem:connectionRegionLabel
                                                                   attribute:NSLayoutAttributeBottom
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:contentView
                                                                   attribute:NSLayoutAttributeBottom
                                                                  multiplier:1.0
                                                                    constant:-10],
                                      ]];
        
        title = NSLocalizedString(@"Connected!",
                                  @"Connection status initial splash modal dialog title for 'Connected' state");
        message = nil;
    } else if(state == PsiphonConnectionStateDisconnected) {
        title = NSLocalizedString(@"Disconnected!",
                                  @"Connection status initial splash modal dialog title for 'Psiphon can not start due to an internal error' state");
        message = NSLocalizedString(@"Psiphon can not start due to an internal error, please send feedback.",
                                    @"Connection status initial splash modal dialog message for 'Psiphon can not start due to an internal error' state");
        // TODO: display 'can't start' icon in the contentView
        contentView = [[UIView alloc] initWithFrame:CGRectZero];
    }
    
    self.title = title;
    self.message = message;
    self.alertViewContentView = contentView;
}

-(void) updateViews {
    //TODO: animated transition of views
    [self setupViewsForState:_connectionState];
}

-(void) connectionRegionLabelTapped {
    RegionSelectionViewController *regionSelectionViewController = [[RegionSelectionViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:regionSelectionViewController];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"Title of the button that dismisses region selection dialog")
                                                                   style:UIBarButtonItemStyleDone target:self
                                                                  action:@selector(regionSelectionDone)];
    regionSelectionViewController.navigationItem.rightBarButtonItem = doneButton;

    if ([self.delegate respondsToSelector:@selector(regionSelectionControllerWillStart)]) {
        [self.delegate regionSelectionControllerWillStart];
    }
    [self presentViewController:navController animated:YES completion:nil];
}

-(void) regionSelectionDone {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    if ([self.delegate respondsToSelector:@selector(regionSelectionControllerDidEnd)]) {
        [self.delegate regionSelectionControllerDidEnd];
    }
}

@end

@implementation PsiphonConnectionSplashViewController {
    BOOL _dismissImmediatelly;
}

- (id) initWithState:(PsiphonConnectionState)state {
    self = [super initWithState:state];
    if(self) {
        self.transitionStyle = NYAlertViewControllerTransitionStyleFade;
        self.backgroundTapDismissalGestureEnabled = NO;
        self.swipeDismissalGestureEnabled = NO;
        self.dismissOnConnected = YES;
        _dismissImmediatelly = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(psiphonWebTabLoaded)
                                                     name:kPsiphonWebTabLoadedNotification object:nil];
    }
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kPsiphonWebTabLoadedNotification object:nil];
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if(_dismissImmediatelly) {
        [self.presentingViewController dismissViewControllerAnimated:NO completion:nil];
    }
}

- (void) psiphonWebTabLoaded {
    _dismissImmediatelly = YES;
}

@end

@implementation PsiphonConnectionAlertViewController {
    
}

- (id) initWithState:(PsiphonConnectionState)state {
    self = [super initWithState:state];
    if(self) {
        self.transitionStyle = NYAlertViewControllerTransitionStyleFade;
        self.backgroundTapDismissalGestureEnabled = YES;
        self.swipeDismissalGestureEnabled = YES;
        self.dismissOnConnected = NO;
    }
    return self;
}

@end
