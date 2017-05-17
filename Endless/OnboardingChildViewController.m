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

@import AVKit.AVPlayerViewController;
@import AVFoundation.AVPlayer;
@import AVFoundation.AVPlayerItem;

#import "OnboardingChildViewController.h"

#define kLetsGoButtonHeight 40.0f

@interface OnboardingChildViewController ()

@end

@implementation OnboardingChildViewController {
	UIView *contentView;
	UIView *avpView;
	UIImageView *thumbnailView;
	UILabel *titleView;
	UILabel *textView;
	UIButton *letsGoButton;

	AVPlayerViewController *avp;

	NSLayoutConstraint *contentViewYOffsetConstraint;
}

- (void)viewDidLayoutSubviews {
	CGFloat bannerOffset = 0;

	id<OnboardingChildViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(getBannerOffset)]) {
		bannerOffset = [strongDelegate getBannerOffset];
	}

	[contentViewYOffsetConstraint setConstant:bannerOffset+4];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (avp != nil && avp.player != nil) {
		if (avp.player.rate == 0) {
			[avp.player play];
		}
	}
}

- (void)onboardingReappeared {
	if (avp != nil && avp.player != nil) {
		if (avp.player.rate == 0) {
			[avp.player play];
		}
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onboardingReappeared) name:UIApplicationDidBecomeActiveNotification object:nil];

	CGFloat bannerOffset = 0;

	/* Setup title view */
	titleView = [[UILabel alloc] init];
	titleView.numberOfLines = 0;
	titleView.adjustsFontSizeToFitWidth = YES;
	titleView.userInteractionEnabled = NO;
	titleView.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:19.0f];
	titleView.textColor = [UIColor colorWithRed:0.27 green:0.27 blue:0.28 alpha:1.0];
	titleView.textAlignment = NSTextAlignmentCenter;

	/* Setup text view */
	textView = [[UILabel alloc] init];
	textView.numberOfLines = 0;
	textView.adjustsFontSizeToFitWidth = YES;
	textView.userInteractionEnabled = NO;
	textView.font = [UIFont fontWithName:@"HelveticaNeue" size:18.0f];
	textView.textColor = [UIColor colorWithRed:0.56 green:0.57 blue:0.58 alpha:1.0];
	textView.textAlignment = NSTextAlignmentCenter;

	/* Setup lets go button */
	letsGoButton = [[UIButton alloc] init];
	letsGoButton.backgroundColor = [UIColor colorWithRed:0.83 green:0.25 blue:0.16 alpha:1.0];
	letsGoButton.hidden = false;
	[letsGoButton setTitle:NSLocalizedString(@"LET'S GO!", @"") forState:UIControlStateNormal];
	letsGoButton.layer.cornerRadius = kLetsGoButtonHeight / 2;
	letsGoButton.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16.0f];
	letsGoButton.titleLabel.adjustsFontSizeToFitWidth = YES;

	[letsGoButton addTarget:self
					 action:@selector(onboardingEnded)
		   forControlEvents:UIControlEventTouchUpInside];

	/* Setup movie player */
	NSString *onboardingVideoName = [NSString stringWithFormat:@"onboarding%ld", (long)self.index+1];
	NSURL *videoURL = [[NSBundle mainBundle]   URLForResource:onboardingVideoName withExtension:@"mov"];
	avp = [[AVPlayerViewController alloc] init];
	avp.player = [[AVPlayer alloc] initWithURL:videoURL];
	avp.showsPlaybackControls = NO;
	avp.view.backgroundColor = [UIColor whiteColor];

	/* Loop onboarding movie */
	avp.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(playerItemDidReachEnd:)
												 name:AVPlayerItemDidPlayToEndTimeNotification
											   object:[avp.player currentItem]];
	[avp.player play];

	avpView = avp.view;

	avpView.contentMode = UIViewContentModeScaleAspectFit;
	[avpView setBackgroundColor:[UIColor whiteColor]];

	/* Setup contentView and its subviews */
	contentView = [[UIView alloc] init];
	[contentView addSubview:avpView];
	[contentView addSubview:titleView];
	[contentView addSubview:textView];
	[self.view addSubview:contentView];

	/* Setup autolayout */
	contentView.translatesAutoresizingMaskIntoConstraints = NO;
	avpView.translatesAutoresizingMaskIntoConstraints = NO;
	titleView.translatesAutoresizingMaskIntoConstraints = NO;
	textView.translatesAutoresizingMaskIntoConstraints = NO;
	letsGoButton.translatesAutoresizingMaskIntoConstraints = NO;

	NSDictionary *viewsDictionary = @{
									  @"contentView": contentView,
									  @"avpView": avpView,
									  @"titleView": titleView,
									  @"textView": textView,
									  @"letsGoButton": letsGoButton
									  };

	id<OnboardingChildViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(getBannerOffset)]) {
		bannerOffset = [strongDelegate getBannerOffset];
	}

	NSDictionary *metrics = @{
							  @"bannerOffset": [NSNumber numberWithFloat:bannerOffset],
							  @"letsGoButtonHeight": [NSNumber numberWithFloat:kLetsGoButtonHeight]
							  };

	contentViewYOffsetConstraint = [NSLayoutConstraint constraintWithItem:contentView
																attribute:NSLayoutAttributeTop
																relatedBy:NSLayoutRelationEqual
																   toItem:self.view
																attribute:NSLayoutAttributeTop
															   multiplier:1.f
																 constant:0];
	[self.view addConstraint:contentViewYOffsetConstraint];

	/* contentView's constraints */
	CGFloat contentViewWidthRatio = 0.7f;
	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:contentView
														  attribute:NSLayoutAttributeWidth
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeWidth
														 multiplier:contentViewWidthRatio
														   constant:0]];

	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[contentView]|" options:0 metrics:metrics views:viewsDictionary]];

	[self.view addConstraint:[NSLayoutConstraint constraintWithItem:contentView
														  attribute:NSLayoutAttributeCenterX
														  relatedBy:NSLayoutRelationEqual
															 toItem:self.view
														  attribute:NSLayoutAttributeCenterX
														 multiplier:1.f constant:0.f]];

	/* avpView's constraints */
	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:avpView
															attribute:NSLayoutAttributeTop
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeTop
														   multiplier:1.f
															 constant:0]];

	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:avpView
															attribute:NSLayoutAttributeWidth
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeWidth
														   multiplier:1.2f
															 constant:0]];

	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:avpView
															attribute:NSLayoutAttributeHeight
															relatedBy:NSLayoutRelationEqual
															   toItem:avpView
															attribute:NSLayoutAttributeWidth
														   multiplier:1.f
															 constant:0]];

	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:avpView
															attribute:NSLayoutAttributeCenterX
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeCenterX
														   multiplier:1.f constant:0.f]];

	/* titleView's constraints */
	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:titleView
															attribute:NSLayoutAttributeWidth
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeWidth
														   multiplier:1.f
															 constant:0]];

	titleView.preferredMaxLayoutWidth = contentViewWidthRatio * self.view.frame.size.width;
	[titleView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	[titleView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:titleView
															attribute:NSLayoutAttributeHeight
															relatedBy:NSLayoutRelationLessThanOrEqual
															   toItem:contentView
															attribute:NSLayoutAttributeHeight
														   multiplier:0.2f
															 constant:0]];

	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:titleView
															attribute:NSLayoutAttributeCenterX
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeCenterX
														   multiplier:1.f constant:0.f]];

	/* textView's constraints */
	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:textView
															attribute:NSLayoutAttributeWidth
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeWidth
														   multiplier:.9f
															 constant:0]];

	textView.preferredMaxLayoutWidth = 0.9 * contentViewWidthRatio * self.view.frame.size.width;
	[textView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	[textView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:textView
															attribute:NSLayoutAttributeHeight
															relatedBy:NSLayoutRelationLessThanOrEqual
															   toItem:contentView
															attribute:NSLayoutAttributeHeight
														   multiplier:0.3f
															 constant:0]];

	[contentView addConstraint:[NSLayoutConstraint constraintWithItem:textView
															attribute:NSLayoutAttributeCenterX
															relatedBy:NSLayoutRelationEqual
															   toItem:contentView
															attribute:NSLayoutAttributeCenterX
														   multiplier:1.f constant:0.f]];

	/* add vertical constraints for contentView's subviews */
	[contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[avpView]-16-[titleView]-[textView]-(>=0)-|" options:0 metrics:metrics views:viewsDictionary]];

	/* Set page specific content */
	switch (self.index) {
		case 0: {
			/* add letsGoButton to view */
			[contentView addSubview:letsGoButton];

			/* letsGoButton.width = 0.5 * contentView.width */
			[self.view addConstraint:[NSLayoutConstraint constraintWithItem:letsGoButton
																  attribute:NSLayoutAttributeWidth
																  relatedBy:NSLayoutRelationEqual
																	 toItem:contentView
																  attribute:NSLayoutAttributeWidth
																 multiplier:.5f
																   constant:0]];

			[contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[textView]-(>=0)-[letsGoButton(==letsGoButtonHeight)]|" options:NSLayoutFormatAlignAllCenterX metrics:metrics views:viewsDictionary]];

			titleView.text = NSLocalizedString(@"Psiphon opens all the wonders of the web to you, no matter where you are", @"");
			//textView.text = ...
			break;
		}
		default:
			[self onboardingEnded];
			break;
	}
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
	AVPlayerItem *player = [notification object];
	[player seekToTime:kCMTimeZero];
}

- (void)onboardingEnded {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	id<OnboardingChildViewControllerDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(onboardingEnded)]) {
		[strongDelegate onboardingEnded];
	}
}

@end
