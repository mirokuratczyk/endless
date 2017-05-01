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

// Based on http://stackoverflow.com/questions/2844397/how-to-adjust-font-size-of-label-to-fit-the-rectangle/33657604#33657604


#import "AdjustableLabel.h"

@interface AdjustableLabel ()
@property(nonatomic) BOOL fontSizeAdjusted;
@end

// The size found S satisfies: S fits in the frame and and S+DELTA doesn't.
#define DELTA 0.5
#define MIN_FONT_SIZE 5.0f

@implementation AdjustableLabel

- (id)initWithDesiredFontSize:(CGFloat)fontSize {
	self = [super init];

	if (self) {
		self.desiredFontSize = fontSize;
	}

	return self;
}

- (void)setAdjustsFontSizeToFitFrame:(BOOL)adjustsFontSizeToFitFrame
{
	_adjustsFontSizeToFitFrame = adjustsFontSizeToFitFrame;

	if (adjustsFontSizeToFitFrame) {
		self.numberOfLines = 0; // because boundingRectWithSize works like this was 0 anyway
	}
}

- (void)layoutSubviews
{
	[super layoutSubviews];

	if (self.adjustsFontSizeToFitFrame)
	{
		[self adjustFontSizeToFrame];
	}
}

- (void)adjustFontSizeToFrame
{
	AdjustableLabel* label = self;

	if (label.text.length == 0) return;

	// Necessary or single-char texts won't be correctly adjusted
	BOOL checkWidth = label.text.length == 1;

	CGSize labelSize = label.frame.size;

	// Fit label width-wise
	CGSize constraintSize = CGSizeMake(checkWidth ? MAXFLOAT : labelSize.width, MAXFLOAT);

	// Try all font sizes from desired to smallest font size
	CGFloat maxFontSize = label.desiredFontSize;
	CGFloat minFontSize = MIN_FONT_SIZE;

	UIFont *font = label.font;

	// Do a binary search to find the largest font size that
	// will fit within the label's frame.
	while (true)
	{
		CGFloat fontSize = (maxFontSize + minFontSize) / 2;

		if (fontSize - minFontSize < DELTA / 2) {
			font = [UIFont fontWithName:font.fontName size:minFontSize];
			break; // Exit because we reached the biggest font size that fits
		} else {
			font = [UIFont fontWithName:font.fontName size:fontSize];
		}

		NSMutableAttributedString* attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:label.attributedText];
		[attributedString addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, label.attributedText.length)];

		CGRect rect = [attributedString boundingRectWithSize:constraintSize options:NSStringDrawingUsesLineFragmentOrigin context:nil];

		// Now we discard a half
		if(rect.size.height <= labelSize.height && (!checkWidth || rect.size.width <= labelSize.width)) {
			minFontSize = fontSize; // the best size is in the bigger half
		} else {
			maxFontSize = fontSize; // the best size is in the smaller half
		}
	}

	label.font = font;
}

@end
