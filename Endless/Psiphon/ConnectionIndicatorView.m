//
//  ConnectionIndicatorView.m
//  Endless
//
//  Created by eugene-imac on 2016-10-26.
//  Copyright © 2016 jcs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionIndicatorView.h"

@implementation ConnectionIndicatorView

UIImageView * imageView;
UIActivityIndicatorView * activityIndicator;



- (id) initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"broken_lock"]];
        
        
        activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        activityIndicator.frame = CGRectMake(0, 0, 44, 44);
        activityIndicator.color = [UIColor blackColor];
        /*    [navigationBar addSubview:connectionActivityIndicator];
         
         
         [connectionActivityIndicator addSubview:navImageView];
         navImageView.frame = CGRectMake(0, 0, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
         
         [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
         navImageView.alpha = 0.0f;
         } completion:^(BOOL finished){
         navImageView.animationImages =  [NSArray arrayWithObjects: [UIImage imageNamed:@"lock"], nil];
         [navImageView startAnimating];
         [UIView animateWithDuration:0.5 animations:^{
         navImageView.alpha = 0.2f;
         }];
         [connectionActivityIndicator startAnimating];
         }];
         */
    }
    
    return self;
}

- (void) connectingState {

}

- (void) connectedState {

}

- (void) disconnectedState {
    
}

@end

