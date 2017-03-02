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


#import "AppDelegate.h"
#import "OnboardingViewController.h"
#import "OnboardingChildViewController.h"

#define kNumOnboardingViews 3
#define kLogoToTitleSpacing 8.0f

@interface OnboardingViewController ()
@end

@implementation OnboardingViewController {
    NSLayoutConstraint *centreBannerConstraint;
    
    CGFloat bannerOffset;
    UIView *bannerView;
    UIImageView *bannerLogoView;
    UILabel *bannerTitleLabel;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    // Shrink bannerTitleLabel to the size of its content
    [bannerTitleLabel sizeToFit];
    [centreBannerConstraint setConstant:-((bannerLogoView.frame.size.width + bannerTitleLabel.frame.size.width + kLogoToTitleSpacing) / 2)];
    bannerOffset = bannerView.frame.origin.y + bannerView.frame.size.height;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view setBackgroundColor:[UIColor whiteColor]];
    [[UIApplication sharedApplication] setStatusBarHidden:YES]; // Full screen onboarding
    
    /* Customize UIPageControl */
    UIPageControl *pageControl = [UIPageControl appearance];
    pageControl.pageIndicatorTintColor = [UIColor colorWithRed:0.89 green:0.89 blue:0.89 alpha:1.0];
    pageControl.currentPageIndicatorTintColor = [UIColor colorWithRed:0.93 green:0.25 blue:0.21 alpha:1.0];
    pageControl.backgroundColor = [UIColor clearColor];
    pageControl.opaque = NO;
    
    /* Setup UIPageViewController */
    self.pageController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
    self.pageController.dataSource = self;
    self.pageController.view.frame = self.view.bounds;
    
    /* Setup and present initial OnboardingChildViewController */
    OnboardingChildViewController *initialViewController = [self viewControllerAtIndex:0];
    NSArray *viewControllers = [NSArray arrayWithObject:initialViewController];
    
    [self.pageController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    [self addChildViewController:self.pageController];
    
    [self.view addSubview:self.pageController.view];
    [self.pageController didMoveToParentViewController:self];
    
    /* Add static views to OnboardingViewController */
    
    /* Setup bannerTitleLabel */
    bannerTitleLabel = [[UILabel alloc] init];
    bannerTitleLabel.text = NSLocalizedString(@"PSIPHON", @"");
    bannerTitleLabel.textColor = [UIColor colorWithRed:0.27 green:0.27 blue:0.28 alpha:1.0];
    bannerTitleLabel.font = [UIFont fontWithName:@"HelveticaNeue " size:20.0f];
    bannerTitleLabel.numberOfLines = 0;
    bannerTitleLabel.adjustsFontSizeToFitWidth = YES;
    bannerTitleLabel.textAlignment = NSTextAlignmentRight;
    
    /* Setup bannerLogoView */
    UIImage *bannerLogo = [UIImage imageNamed:@"onboarding-logo"];
    bannerLogoView = [[UIImageView alloc] initWithImage:bannerLogo];
    
    // ChildViewController will call getBannerOffset to determine
    // how much space the banner consumes and layout accordingly.
    bannerOffset = 0;
    
    /* Setup skip button */
    UIButton *skipButton = [[UIButton alloc] init];
    [skipButton setTitle:NSLocalizedString(@"SKIP", @"") forState:UIControlStateNormal];
    [skipButton setTitleColor:[UIColor colorWithRed:0.56 green:0.57 blue:0.58 alpha:1.0] forState:UIControlStateNormal];
    [skipButton.titleLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:16.0f]];
    [skipButton.titleLabel setAdjustsFontSizeToFitWidth:YES];
    
    [skipButton addTarget:self
                   action:@selector(onboardingEnded)
         forControlEvents:UIControlEventTouchUpInside];
    
    /* Init banner view which will contain bannerLogoView and bannerTitleLabel */
    bannerView = [[UIView alloc] init];
    
    /* Add views */
    [self.view addSubview:skipButton];
    [self.view addSubview:bannerView];
    [bannerView addSubview:bannerLogoView];
    [bannerView addSubview:bannerTitleLabel];
    
    /* Setup autolayout */
    bannerView.translatesAutoresizingMaskIntoConstraints = NO;
    bannerLogoView.translatesAutoresizingMaskIntoConstraints = NO;
    bannerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    skipButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    id <UILayoutSupport> topLayoutGuide =  self.topLayoutGuide;
    
    NSDictionary *viewsDictionary = @{
                                     @"topLayoutGuide": topLayoutGuide,
                                     @"skipButton": skipButton,
                                     @"bannerLogoView": bannerLogoView,
                                     @"bannerTitleLabel": bannerTitleLabel
                                     };
    
    NSDictionary *metrics = @{
                              @"logoToTitleSpacing": [NSNumber numberWithFloat:kLogoToTitleSpacing]
                              };
    
    
    [bannerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[bannerLogoView]-logoToTitleSpacing-[bannerTitleLabel]" options:NSLayoutFormatAlignAllCenterY metrics:metrics views:viewsDictionary]];
    
    /* bannerLogoView constraints */
    [bannerView addConstraint:[NSLayoutConstraint constraintWithItem:bannerLogoView
                                                          attribute:NSLayoutAttributeCenterY
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:bannerView
                                                          attribute:NSLayoutAttributeCenterY
                                                         multiplier:1.f constant:0.f]];
    
    // This constraint will be updated in viewDidLayoutSubviews
    // once bannerTitleLabel's frame has been laid out.
    centreBannerConstraint = [NSLayoutConstraint constraintWithItem:bannerLogoView
                                                           attribute:NSLayoutAttributeLeft
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:bannerView
                                                           attribute:NSLayoutAttributeCenterX
                                                          multiplier:1.f constant:.0f];
    [bannerView addConstraint:centreBannerConstraint];
    
    [bannerView addConstraint:[NSLayoutConstraint constraintWithItem:bannerTitleLabel
                                                           attribute:NSLayoutAttributeCenterY
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:bannerView
                                                           attribute:NSLayoutAttributeCenterY
                                                          multiplier:1.f constant:0.f]];
    
    /* Skip button constraints */
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[topLayoutGuide]-[skipButton]" options:0 metrics:nil views:viewsDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[skipButton]-|" options:0 metrics:nil views:viewsDictionary]];

    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:skipButton
                                                          attribute:NSLayoutAttributeHeight
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeHeight
                                                         multiplier:.04f
                                                           constant:0]];
    
    /* Banner view autolayout */
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:bannerView
                                                          attribute:NSLayoutAttributeWidth
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeWidth
                                                         multiplier:1.f
                                                           constant:0]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:bannerView
                                                          attribute:NSLayoutAttributeHeight
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeHeight
                                                         multiplier:.10f
                                                           constant:0]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:bannerView
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeCenterX
                                                         multiplier:1.f constant:0.f]];
    
    // Banner view's top flush with bottom of skip button's frame
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:bannerView
                                                          attribute:NSLayoutAttributeTop
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:skipButton
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1.f
                                                           constant:0]];
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (BOOL)prefersStatusBarHidden{
    return YES;
}

#pragma mark - UIPageViewControllerDataSource methods and helper functions

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {

    NSUInteger index = [(OnboardingChildViewController *)viewController index];
    
    if (index == 0) {
        return nil;
    }
    
    index--;
    
    return [self viewControllerAtIndex:index];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    
    NSUInteger index = [(OnboardingChildViewController *)viewController index];
    
    index++;
    
    if (index == kNumOnboardingViews) {
        return nil;
    }
    
    return [self viewControllerAtIndex:index];
}

- (OnboardingChildViewController *)viewControllerAtIndex:(NSUInteger)index {
    OnboardingChildViewController *childViewController = [[OnboardingChildViewController alloc] init];
    childViewController.index = index;
    childViewController.delegate = self;
    
    return childViewController;
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController {
    // The number of items in the UIPageControl
    return kNumOnboardingViews;
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController {
    // The selected dot in the UIPageControl
    return 0;
}

#pragma mark - OnboardingChildViewController delegate methods

- (CGFloat)getBannerOffset {
    return bannerOffset;
}

- (void)onboardingEnded {
    [self.pageController.view removeFromSuperview];
    [self dismissViewControllerAnimated:NO completion:nil];
    
    id<OnboardingViewControllerDelegate> strongDelegate = self.delegate;
    
    if ([strongDelegate respondsToSelector:@selector(onboardingEnded)]) {
        [strongDelegate onboardingEnded];
    }
}

@end
