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

@import MediaPlayer;
@import AVFoundation.AVAsset;
@import AVFoundation.AVTime;
@import AVFoundation.AVAssetImageGenerator;

#import "AppDelegate.h"
#import "OnboardingChildViewController.h"

#define kLetsGoButtonHeight 40.0f

@interface OnboardingChildViewController ()

@end

@implementation OnboardingChildViewController {
    AppDelegate *appDelegate;
    
    UIView *contentView;
    UIView *movieView;
    UIImageView *thumbnailView;
    UILabel *titleView;
    UILabel *textView;
    UIButton *letsGoButton;
    
    MPMoviePlayerController *moviePlayer;
    
    NSLayoutConstraint *contentViewYOffsetConstraint;
}

-(void)viewDidLayoutSubviews {
    CGFloat bannerOffset = 0;
    
    id<OnboardingChildViewControllerDelegate> strongDelegate = self.delegate;
    
    if ([strongDelegate respondsToSelector:@selector(getBannerOffset)]) {
        bannerOffset = [strongDelegate getBannerOffset];
    }
    
    [contentViewYOffsetConstraint setConstant:bannerOffset+4];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (moviePlayer != nil) {
        [moviePlayer play];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    if (moviePlayer != nil) {
        [moviePlayer stop];
    }
    [super viewDidDisappear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
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
    moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:videoURL];
    moviePlayer.controlStyle = MPMovieControlStyleNone;
    moviePlayer.scalingMode = MPMovieScalingModeAspectFit;
    moviePlayer.view.backgroundColor = [UIColor whiteColor];
    moviePlayer.backgroundView.backgroundColor = [UIColor whiteColor];
    moviePlayer.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    /* Add thumbnail to act as a placeholder until movie loads and starts playing */
    thumbnailView = [[UIImageView alloc] initWithImage:[self getFirstFrameThumbnail:videoURL]];
    thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    [moviePlayer.view addSubview:thumbnailView];
    
    /* Loop onboarding movie */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loopVideo) name:MPMoviePlayerPlaybackDidFinishNotification object:moviePlayer];
    
    /* Remove thumbnail when movie starts */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(MPMoviePlayerPlaybackStateDidChange:) name:MPMoviePlayerPlaybackStateDidChangeNotification object:moviePlayer];
    
    /* Constrain thumbnail view to fit within movieplayer frame */
    NSDictionary *views = @{@"thumbnailView":thumbnailView};
    [moviePlayer.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[thumbnailView]|" options:0 metrics:nil views:views]];
    [moviePlayer.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[thumbnailView]|" options:0 metrics:nil views:views]];
    
    movieView = moviePlayer.view;
    
    movieView.contentMode = UIViewContentModeScaleAspectFit;
    [movieView setBackgroundColor:[UIColor whiteColor]];
    
    /* Setup contentView and its subviews */
    contentView = [[UIView alloc] init];
    [contentView addSubview:movieView];
    [contentView addSubview:titleView];
    [contentView addSubview:textView];
    [self.view addSubview:contentView];
    
    /* Setup autolayout */
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    movieView.translatesAutoresizingMaskIntoConstraints = NO;
    titleView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    letsGoButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSDictionary *viewsDictionary = @{
                                      @"contentView": contentView,
                                      @"movieView": movieView,
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
    
    /* movieView's constraints */
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:movieView
                                                            attribute:NSLayoutAttributeTop
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:contentView
                                                            attribute:NSLayoutAttributeTop
                                                           multiplier:1.f
                                                             constant:0]];
    
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:movieView
                                                            attribute:NSLayoutAttributeWidth
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:contentView
                                                            attribute:NSLayoutAttributeWidth
                                                           multiplier:1.2f
                                                             constant:0]];
    
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:movieView
                                                            attribute:NSLayoutAttributeHeight
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:movieView
                                                            attribute:NSLayoutAttributeWidth
                                                           multiplier:1.f
                                                             constant:0]];
    
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:movieView
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
    [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[movieView]-16-[titleView]-[textView]-(>=0)-|" options:0 metrics:metrics views:viewsDictionary]];
    
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

- (UIImage*)getFirstFrameThumbnail:(NSURL *)videoURL {
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];

    CGImageRef frameRef = [generator copyCGImageAtTime:kCMTimeZero actualTime:nil error:nil];
    UIImage *thumbnail = [UIImage imageWithCGImage:frameRef];
    CGImageRelease(frameRef);
    
    return thumbnail;
}

- (void)loopVideo {
    [moviePlayer play];
}

- (void)MPMoviePlayerPlaybackStateDidChange:(NSNotification *)notification
{
    MPMoviePlayerController *player = (MPMoviePlayerController*)notification.object;
    if (player.playbackState == MPMoviePlaybackStatePlaying) {
        // Remove placeholder thumbnail if movie has started playing
        if (thumbnailView.superview != nil) {
            [thumbnailView removeFromSuperview];
        }
    }
}

-(void)onboardingEnded {
    id<OnboardingChildViewControllerDelegate> strongDelegate = self.delegate;
    
    if ([strongDelegate respondsToSelector:@selector(onboardingEnded)]) {
        [strongDelegate onboardingEnded];
    }
}

@end
