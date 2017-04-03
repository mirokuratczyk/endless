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
    // method must be implemented by subclass and not used directly
    [self doesNotRecognizeSelector:_cmd];
}

-(void) updateViews {
    //do animated transition of views
    [self setupViewsForState:_connectionState];
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

-(void) setupViewsForState:(PsiphonConnectionState)state {
    
    NSString *title = @"";
    NSString *message = @"";
    UIView *contentView = nil;
    
    if (state == PsiphonConnectionStateConnecting || state == PsiphonConnectionStateWaitingForNetwork) {
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
        [NSLayoutConstraint constraintsWithVisualFormat:@"V:[contentView(80)]-(<=1)-[activityIndicator]"
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
        
        if (state == PsiphonConnectionStateConnecting) {
            title = NSLocalizedString(@"Psiphon",
                                      @"Connection status initial splash modal dialog title for 'Connecting...' state");
            message = NSLocalizedString(@"Connecting...",
                                        @"Connection status initial splash modal dialog message for 'Connecting...' state");

            // TODO: display region it is connecting to
        } else {
            title = NSLocalizedString(@"Psiphon",
                                      @"Connection status initial splash modal dialog title for 'Waiting for network...' state");
            message = NSLocalizedString(@"Waiting for network...",
                                        @"Connection status initial splash modal dialog message for 'Waiting for network...' state");
            
        }
    } else if(state == PsiphonConnectionStateConnected){
        title = NSLocalizedString(@"Psiphon",
                                  @"Connection status initial splash modal dialog title for 'Connected' state");
        message = NSLocalizedString(@"Connected!",
                                    @"Connection status initial splash modal dialog message for 'Connected' state");
        // TODO: display region it is connected to
        contentView = [[UIView alloc] initWithFrame:CGRectZero];
    } else if(state == PsiphonConnectionStateDisconnected) {
        title = NSLocalizedString(@"Psiphon",
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


-(void) setupViewsForState:(PsiphonConnectionState)state {
    NSString *title = @"";
    NSString *message = @"";
    UIView *contentView = nil;
    
    if (state == PsiphonConnectionStateConnecting || state == PsiphonConnectionStateWaitingForNetwork) {
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
        [NSLayoutConstraint constraintsWithVisualFormat:@"V:[contentView(80)]-(<=1)-[activityIndicator]"
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
        if (state == PsiphonConnectionStateConnecting) {
            title = NSLocalizedString(@"Psiphon",
                                      @"Connection status initial splash modal dialog title for 'Connecting...' state");
            message = NSLocalizedString(@"Connecting...",
                                        @"Connection status initial splash modal dialog message for 'Connecting...' state");
            
            // TODO: display region it is connecting to
        } else {
            title = NSLocalizedString(@"Psiphon",
                                      @"Connection status initial splash modal dialog title for 'Waiting for network...' state");
            message = NSLocalizedString(@"Waiting for network...",
                                        @"Connection status initial splash modal dialog message for 'Waiting for network...' state");
            
        }
    } else if(state == PsiphonConnectionStateConnected){
        title = NSLocalizedString(@"Psiphon",
                                  @"Connection status initial splash modal dialog title for 'Connected' state");
        message = NSLocalizedString(@"Connected!",
                                    @"Connection status initial splash modal dialog message for 'Connected' state");
        // TODO: display region it is connected to
        contentView = [[UIView alloc] initWithFrame:CGRectZero];
        NSDictionary *variables = NSDictionaryOfVariableBindings(contentView);

        NSArray *constraints =
        [NSLayoutConstraint constraintsWithVisualFormat:@"V:[contentView(0)]"
                                                options: NSLayoutFormatAlignAllCenterX
                                                metrics:nil
                                                  views:variables];
        [contentView addConstraints:constraints];


    } else if(state == PsiphonConnectionStateDisconnected) {
        title = NSLocalizedString(@"Psiphon",
                                  @"Connection status initial splash modal dialog title for 'Psiphon can not start due to an internal error' state");
        message = NSLocalizedString(@"Psiphon can not start due to an internal error, please send feedback.",
                                    @"Connection status initial splash modal dialog message for 'Psiphon can not start due to an internal error' state");
        // TODO: display 'can't start' icon in the contentView
        contentView = [[UIView alloc] initWithFrame:CGRectZero];
        contentView = [[UIView alloc] initWithFrame:CGRectZero];
        NSDictionary *variables = NSDictionaryOfVariableBindings(contentView);
        
        NSArray *constraints =
        [NSLayoutConstraint constraintsWithVisualFormat:@"V:[contentView(0)]"
                                                options: NSLayoutFormatAlignAllCenterX
                                                metrics:nil
                                                  views:variables];
        [contentView addConstraints:constraints];
    }
    
    
    self.title = title;
    self.message = message;
    self.alertViewContentView = contentView;
}
@end
