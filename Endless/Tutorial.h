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

#import <Foundation/Foundation.h>
#import "AdjustableLabel.h"

@protocol TutorialDelegate;

@interface Tutorial : NSObject

@property (nonatomic, weak) id<TutorialDelegate> delegate;

@property (readonly, nonatomic) int step;

@property (readonly, strong, nonatomic) CAShapeLayer *fillLayer;
@property (strong, nonatomic) UIView *blockingView;
@property (strong, nonatomic) UIView *contentView;
@property (strong, nonatomic) UIImageView *arrowView;
@property (strong, nonatomic) UIButton *skipButton;
@property (strong, nonatomic) UILabel *headerView;
@property (strong, nonatomic) UILabel *titleView;
@property (strong, nonatomic) AdjustableLabel *textView;
@property (strong, nonatomic) UIButton *letsGo;

@property (strong, nonatomic) NSArray<NSLayoutConstraint*> *removeBeforeNextStep;
@property (strong, nonatomic) NSMutableDictionary<NSString*, NSLayoutConstraint*> *constraintsDictionary;
@property (readonly, strong, nonatomic) NSDictionary *viewsDictionary;

-(void)addToView:(UIView*)view;
-(void)constructViewsDictionaryForAutoLayout:(NSDictionary*)yourViews;
-(void)startTutorial;
-(void)nextStep;
-(void)setSpotlightFrame:(CGRect)frame withView:(UIView*)view;
-(void)setBackground:(CGPathRef)path;
-(void)animateArrow:(CGAffineTransform)transform;

@end

@protocol TutorialDelegate <NSObject>
-(BOOL)drawStep:(int)step;
-(void)tutorialEnded;
@end
