//
//  Functions.h
//  EstadioCDF
//
//  Created by SmartboxTV on 30-12-13.
//  Copyright (c) 2013 CDF. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

#define DEFAULTS_CREATED_REMINDER_KEY @"reminders"
#define DEFAULTS_REMINDERS_CALENDAR_KEY @"reminders_calendar"

#define CALENDAR_IDENTIFIER_KEY @"calendarIdentifier"
#define CALENDAR_TITLE @"FireSport"

@interface Functions : NSObject
+ (void) runSpinAnimationOnView:(UIView*)view duration:(CGFloat)duration rotations:(CGFloat)rotations repeat:(float)repeat;


+(void)isChoosingImage:(BOOL)value;


+(NSDate *)stringToDate:(NSString *)string;
+(NSDate *)stringToDate:(NSString *)string WithFormat:(NSString *)format;
+(NSString *)dateToString:(NSDate *)date WithFormat:(NSString *)format;
+(UIColor*)colorWithHexString:(NSString*)hex andAlpha:(CGFloat)alpha;
+ (BOOL) validateEmail: (NSString *) email;

+(BOOL)isDate:(NSDate *)date inRangeFirstDate:(NSDate *)firstDate lastDate:(NSDate *)lastDate;

+(void)buttonBounceAnimation:(UIView *)view;

+ (UIImage *) applyMonoChromeWithRandColor: (UIImage *)uIImage andColor:(CGColorRef )color;
+(CAGradientLayer *)CreateGradientInView:(UIView *)view withStartColor:(UIColor *)startColor andEndColor:(UIColor *)endColor;
+(void)deleteUserInfo;
+ (UIImage *)imageWithColor:(UIColor *)color;
+(void)fillContainerView:(UIView *)container WithView:(UIView *)view;


+(BOOL)reminderExistsForMedia:(NSString *)mediaId;
+(NSString *)getUUID;


+ (BOOL) validateUrl: (NSString *) candidate;
+(void) doLogout;
+(UIEdgeInsets )makeinsetForTableView:(UITableView *)tableView;
+(NSLayoutConstraint *)addView:(UIView *)view ToContainer:(UIView *)container WithTopMargin:(NSNumber *)topMargin LeftMargin:(NSNumber *)leftMargin BottomMargin:(NSNumber *)bottomMargin RightMargin:(NSNumber *)rightMargin Width:(NSNumber *)width Height:(NSNumber *)height;


+(CGFloat )calculatePixelsWithSize:(CGFloat )size andSeconds:(NSInteger )seconds;
+(void)fillContainerView:(UIView *)container WithView:(UIView *)view  andBottom:(NSInteger )bottom andTop:(NSInteger )top andRight:(NSInteger )right andLeft:(NSInteger )left;
@end
