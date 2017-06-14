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

#import "Tutorial.h"


@implementation Tutorial {
	NSArray<NSString*>* _headerText;
	NSArray<NSString*>* _titleText;
	NSArray<NSAttributedString*>* _bodyText;
}

- (id)init {
	self = [super init];

	if (self) {
		_step = -1;

		/* Setup text */
		_headerText = @[NSLocalizedString(@"Welcome! Here is how to use Psiphon", @"")];

		_titleText = @[
					   NSLocalizedString(@"Status Indicator", @""),
					   NSLocalizedString(@"Settings", @""),
					   NSLocalizedString(@"You're all set!", @"")
					   ];

		NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"This is where you can find information about the status of your connection", @"")];
		NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
		textAttachment.image = [UIImage imageNamed:@"small-status-connected"];
		NSAttributedString *attrStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachment];
		[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\n"]];
		[attributedString appendAttributedString:attrStringWithImage];
		[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
		[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"The green checkmark indicates everything is working beautifully and you're good to go!", @"")]];

		_bodyText = @[
					  attributedString,
					  [[NSAttributedString alloc] initWithString:NSLocalizedString(@"This is where you can access Browser and Proxy Settings, find Help, change the VPN server country, and more!", @"")],
					  [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Happy browsing!\nExplore beyond your borders.", @"")]
					  ];

		[self initViews];
	}

	return self;
}

- (void)initViews {
	[self setupTransparentBackground];
	[self setupSkipButton];
	[self setupHeaderView];
	[self setupTitleView];
	[self setupTextView];
	[self setupArrowView];
	[self setupLetsGo];

	// Turn on autolayout
	_arrowView.translatesAutoresizingMaskIntoConstraints = NO;
	_skipButton.translatesAutoresizingMaskIntoConstraints = NO;
	_headerView.translatesAutoresizingMaskIntoConstraints = NO;
	_titleView.translatesAutoresizingMaskIntoConstraints = NO;
	_textView.translatesAutoresizingMaskIntoConstraints = NO;
	_letsGo.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)addToView:(UIView*)view {
	[view.layer addSublayer:_fillLayer];
	[self.contentView addSubview:_headerView];
	[self.contentView addSubview:_titleView];
	[self.contentView addSubview:_textView];
	[view addSubview:self.contentView];
	[view addSubview:_arrowView];
	[view addSubview:_skipButton];
}

- (void)constructViewsDictionaryForAutoLayout:(NSDictionary*)yourViews {
	NSDictionary *defaultViews = @{
								   @"arrowView": _arrowView,
								   @"skipButton": _skipButton,
								   @"contentView": _contentView,
								   @"headerView": _headerView,
								   @"titleView": _titleView,
								   @"textView": _textView,
								   @"letsGo": _letsGo
								   };

	NSMutableDictionary *viewsDictionary = [[NSMutableDictionary alloc] initWithDictionary:defaultViews];
	[viewsDictionary addEntriesFromDictionary:yourViews];

	_viewsDictionary = [NSDictionary dictionaryWithDictionary:viewsDictionary];
}

- (void)setSpotlightFrame:(CGRect)frame withView:(UIView*)view {
	int spotlightRadius = frame.size.width /2 ;

	UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:view.bounds cornerRadius:0];

	if (!CGRectEqualToRect(frame, CGRectNull)) {
		UIBezierPath *circlePath = [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:spotlightRadius];

		[path appendPath:circlePath];
	}

	[self setBackground:path.CGPath];
}

- (void)setBackground:(CGPathRef)path {
	_fillLayer.path = path;
}

- (void)setupTransparentBackground {
	_fillLayer = [CAShapeLayer layer];
	_fillLayer.fillRule = kCAFillRuleEvenOdd;
	_fillLayer.fillColor = [UIColor blackColor].CGColor;
	_fillLayer.opacity = 0.85;
}

- (void)setupSkipButton {
	_skipButton = [[UIButton alloc] init];

	[_skipButton setTitle:NSLocalizedString(@"SKIP TUTORIAL", @"") forState:UIControlStateNormal];
	[_skipButton setTitleColor:[UIColor colorWithRed:0.56 green:0.57 blue:0.58 alpha:1.0] forState:UIControlStateNormal];

	[_skipButton.titleLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:17.0f]];
	[_skipButton.titleLabel setAdjustsFontSizeToFitWidth:YES];

	[_skipButton addTarget:self
					action:@selector(tutorialEnded)
		  forControlEvents:UIControlEventTouchUpInside];
}

- (void)setupHeaderView {
	_headerView = [[UILabel alloc] init];
	_headerView.numberOfLines = 0;
	_headerView.textColor = [UIColor whiteColor];
	_headerView.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:25.0f];
	_headerView.backgroundColor = [UIColor clearColor];
	_headerView.textAlignment = NSTextAlignmentCenter;
	_headerView.adjustsFontSizeToFitWidth = YES;
}

- (void)setupTitleView {
	_titleView = [[UILabel alloc] init];
	_titleView.numberOfLines = 0;
	_titleView.textColor = [UIColor whiteColor];
	_titleView.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:19.0f];
	_titleView.backgroundColor = [UIColor clearColor];
	_titleView.textAlignment = NSTextAlignmentCenter;
	_titleView.adjustsFontSizeToFitWidth = YES;
}

- (void)setupTextView {
	_textView = [[AdjustableLabel alloc] initWithDesiredFontSize:16.0f];
}

- (void)setupArrowView {
	UIImage *arrow = [UIImage imageNamed:@"arrow"];
	_arrowView = [[UIImageView alloc] initWithImage:arrow];
}

- (void)setupLetsGo {
	_letsGo = [[UIButton alloc] init];

	[_letsGo setBackgroundColor:[UIColor colorWithRed:0.83 green:0.25 blue:0.16 alpha:1.0]];
	[_letsGo setTitle:NSLocalizedString(@"LET'S GO!", @"") forState:UIControlStateNormal];

	[_letsGo.titleLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:16.0f]];
	[_letsGo.titleLabel setAdjustsFontSizeToFitWidth:YES];

	[_letsGo addTarget:self
				action:@selector(tutorialEnded)
	  forControlEvents:UIControlEventTouchUpInside];
}

- (void)startTutorial {
	_step = 0;
	[self renderStep];
}

- (void)nextStep {
	_step++;
	[self renderStep];
}

- (void)renderStep {
	[self updateText];

	id<TutorialDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(drawStep:)]) {
		BOOL drewAStep = [strongDelegate drawStep:_step];

		if (!drewAStep) {
			[self tutorialEnded];
		}
	}
}

- (void)tutorialEnded {
	[self tearDown];

	id<TutorialDelegate> strongDelegate = self.delegate;

	if ([strongDelegate respondsToSelector:@selector(tutorialEnded)]) {
		[strongDelegate tutorialEnded];
	}
}

- (void)updateText {
	self.headerView.text = [self getHeaderTextForStep];
	self.titleView.text = [self getTitleTextForStep];

	// Set textView's text
	NSAttributedString *bodyText = [self getBodyTextForStep];
	NSMutableAttributedString* attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:bodyText];
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	[style setLineSpacing:5];
	[attributedString addAttribute:NSParagraphStyleAttributeName
							 value:style
							 range:NSMakeRange(0, [bodyText length])];
	self.textView.attributedText = attributedString;

	// Setting attributed text resets these options
	// Need to reapply
	_textView.textAlignment = NSTextAlignmentCenter;
	_textView.textColor = [UIColor whiteColor];
	_textView.font = [UIFont fontWithName:@"HelveticaNeue" size:16.0f];
	_textView.backgroundColor = [UIColor clearColor];
	_textView.adjustsFontSizeToFitFrame = YES;
}

- (NSString*)getHeaderTextForStep
{
	if (_step < _headerText.count) {
		return [_headerText objectAtIndex:_step];
	}
	return @"";
}

- (NSString*)getTitleTextForStep
{
	if (_step < _titleText.count) {
		return [_titleText objectAtIndex:_step];
	}
	return @"";
}

- (NSAttributedString*)getBodyTextForStep
{
	if (_step < _bodyText.count) {
		return [_bodyText objectAtIndex:_step];
	}
	return [[NSAttributedString alloc] initWithString:@""];
}

- (void)animateArrow:(CGAffineTransform)transform {
	[UIView animateWithDuration:0.6f
						  delay:0.0f
						options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionBeginFromCurrentState
					 animations:^{
						 [_arrowView setTransform:transform];
					 }
					 completion:^(BOOL finished){
						 _arrowView.transform = CGAffineTransformIdentity;
					 }];
}

- (void)tearDown {
	[self removeFromScreen:_arrowView];
	[self removeFromScreen:_skipButton];
	[self removeFromScreen:_headerView];
	[self removeFromScreen:_titleView];
	[self removeFromScreen:_textView];
	[self removeFromScreen:_letsGo];
	[self removeFromScreen:_blockingView];
	[self removeFromScreen:_contentView];

	if ([_fillLayer superlayer] != nil) {
		[_fillLayer removeFromSuperlayer];
	}
}

- (void)removeFromScreen:(UIView*)view {
	if (view != nil && [view superview] != nil) {
		[view removeFromSuperview];
		view = nil;
	}
}

@end
