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

#import "PsiphonConnectionIndicator.h"

@implementation PsiphonConnectionIndicator

UIImageView *imgConnected;
UIImageView *imgDisconnected;
UIActivityIndicatorView *activityIndicator;

- (id) initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	
	imgConnected = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"psiphon_connected"]];
	[self addSubview:imgConnected];

	imgDisconnected = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"psiphon_disconnected"]];
	imgDisconnected.alpha = 0.0;
	[self addSubview:imgDisconnected];
	
	activityIndicator = [[UIActivityIndicatorView alloc]
						 initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	activityIndicator.alpha = 0.0;
	[self addSubview:activityIndicator];
	
	imgConnected.alpha = imgDisconnected.alpha = activityIndicator.alpha = 0.0;
	imgConnected.center = imgDisconnected.center = activityIndicator.center = CGPointMake(self.bounds.size.width  / 2,
										 self.bounds.size.height / 2);
	[self displayConnectionState:PsiphonConnectionStateDisconnected];
	return self;
}

- (void) displayConnectionState:(PsiphonConnectionState)state {
	
	CGFloat activityIndicatorAlpha, imgConnectedAlpha, imgDisconnectedAlpha = 0.0f;
	void (^animationCompleted)(BOOL finished);
	
	switch (state) {
		case PsiphonConnectionStateConnected:
			activityIndicatorAlpha = 0.0f;
			imgConnectedAlpha = 1.0f;
			imgDisconnectedAlpha = 0.0f;
			animationCompleted = ^(BOOL finished){
				[activityIndicator stopAnimating];
			};
            break;
		case PsiphonConnectionStateConnecting:
			activityIndicatorAlpha = 1.0f;
			imgConnectedAlpha = 0.0f;
			imgDisconnectedAlpha = 0.2f;
			animationCompleted = ^(BOOL finished){
				[activityIndicator startAnimating];
			};
            break;
		case PsiphonConnectionStateDisconnected:
            activityIndicatorAlpha = 0.0f;
            imgConnectedAlpha = 0.0f;
            imgDisconnectedAlpha = 1.0f;
            animationCompleted = ^(BOOL finished){
                [activityIndicator stopAnimating];
            };
            break;
        default:
            break;
	}

	[UIView animateWithDuration:0.1
					 animations:^{
						 activityIndicator.alpha = activityIndicatorAlpha;
						 imgConnected.alpha = imgConnectedAlpha;
						 imgDisconnected.alpha = imgDisconnectedAlpha;
					 }
					 completion: animationCompleted];
	
}

@end
