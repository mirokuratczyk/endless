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


// Based on: http://stackoverflow.com/questions/2844397/how-to-adjust-font-size-of-label-to-fit-the-rectangle/33657604#33657604


#import <UIKit/UIKit.h>

@interface AdjustableLabel : UILabel
/**
 If set to YES, font size will be automatically adjusted to frame.
 Note: numberOfLines can't be specified so it will be set to 0.
 */
@property(nonatomic) BOOL adjustsFontSizeToFitFrame;
@property(nonatomic) CGFloat desiredFontSize;
- (id)initWithDesiredFontSize:(CGFloat)fontSize;
@end
