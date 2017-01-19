//
//  Functions.m
//  EstadioCDF
//
//  Created by SmartboxTV on 30-12-13.
//  Copyright (c) 2013 CDF. All rights reserved.
//
#import "AppDelegate.h"
#import "Functions.h"



@implementation Functions{

    

}

+(void)isChoosingImage:(BOOL)value{


    [AppDelegate setVideoPlaying:value];

}

+(NSDate *)stringToDate:(NSString *)string {
    return [Functions stringToDate:string WithFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
}

+(NSDate *)stringToDate:(NSString *)string WithFormat:(NSString *)format {

    if (string == nil || [string isKindOfClass:[NSNull class]]) {
        return nil;
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];


    return [formatter dateFromString:string];
}

+(NSString *)dateToString:(NSDate *)date WithFormat:(NSString *)format {
    if (date == nil || [date isKindOfClass:[NSNull class]]) {
        return nil;
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];

    return [formatter stringFromDate:date];
}






+(BOOL)isDate:(NSDate *)date inRangeFirstDate:(NSDate *)firstDate lastDate:(NSDate *)lastDate {
    return [date compare:firstDate] == NSOrderedDescending &&
           [date compare:lastDate]  == NSOrderedAscending;
}


+(void)buttonBounceAnimation:(UIView *)view {
    view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1, 1);

    [UIView animateWithDuration:0.3 / 1.3 animations:^{
        view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.6, 1.6);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3/2 animations:^{
            view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.9, 0.9);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3/2 animations:^{
                view.transform = CGAffineTransformIdentity;
            }];
        }];
    }];
}



+(void)deleteUserInfo {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"user-data"];
    [defaults synchronize];
}






+(BOOL)reminderExistsForMedia:(NSString *)mediaId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *createdReminders = [defaults arrayForKey:@"reminders"];

    return [createdReminders containsObject:mediaId];
}


+(NSString *)getUUID
{
    CFUUIDRef newUniqueId = CFUUIDCreate(kCFAllocatorDefault);
    NSString * uuidString = (__bridge_transfer NSString*)CFUUIDCreateString(kCFAllocatorDefault, newUniqueId);
    CFRelease(newUniqueId);

    return uuidString;
}
+(void)fillContainerView:(UIView *)container WithView:(UIView *)view  andBottom:(NSInteger )bottom andTop:(NSInteger )top andRight:(NSInteger )right andLeft:(NSInteger )left{


    NSLayoutConstraint *constraintTop = [NSLayoutConstraint constraintWithItem:view
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:container
                                                                     attribute:NSLayoutAttributeTop
                                                                    multiplier:1.0f constant:top];
    
    NSLayoutConstraint *constraintRight = [NSLayoutConstraint constraintWithItem:view
                                                                       attribute:NSLayoutAttributeLeading
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:container
                                                                       attribute:NSLayoutAttributeLeading
                                                                      multiplier:1.0f constant:right];
    
    
    NSLayoutConstraint *constraintBottom = [NSLayoutConstraint constraintWithItem:view
                                                                        attribute:NSLayoutAttributeBottom
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:container
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0f constant:bottom];
    
    
    NSLayoutConstraint *constraintLeft = [NSLayoutConstraint constraintWithItem:view
                                                                      attribute:NSLayoutAttributeTrailing
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:container
                                                                      attribute:NSLayoutAttributeTrailing
                                                                     multiplier:1.0f constant:left];
    
    
    
    view.translatesAutoresizingMaskIntoConstraints = NO;
    
    [container addSubview:view];
    
    [container addConstraint:constraintTop];
    [container addConstraint:constraintRight];
    [container addConstraint:constraintBottom];
    [container addConstraint:constraintLeft];


}
+(void)fillContainerView:(UIView *)container WithView:(UIView *)view {
    NSLayoutConstraint *constraintTop = [NSLayoutConstraint constraintWithItem:view
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:container
                                                                     attribute:NSLayoutAttributeTop
                                                                    multiplier:1.0f constant:0.0f];

    NSLayoutConstraint *constraintRight = [NSLayoutConstraint constraintWithItem:view
                                                                       attribute:NSLayoutAttributeLeading
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:container
                                                                       attribute:NSLayoutAttributeLeading
                                                                      multiplier:1.0f constant:0.0f];


    NSLayoutConstraint *constraintBottom = [NSLayoutConstraint constraintWithItem:view
                                                                        attribute:NSLayoutAttributeBottom
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:container
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0f constant:0.0f];


    NSLayoutConstraint *constraintLeft = [NSLayoutConstraint constraintWithItem:view
                                                                      attribute:NSLayoutAttributeTrailing
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:container
                                                                      attribute:NSLayoutAttributeTrailing
                                                                     multiplier:1.0f constant:0.0f];



    view.translatesAutoresizingMaskIntoConstraints = NO;

    [container addSubview:view];

    [container addConstraint:constraintTop];
    [container addConstraint:constraintRight];
    [container addConstraint:constraintBottom];
    [container addConstraint:constraintLeft];
}
+(UIColor*)colorWithHexString:(NSString*)hex andAlpha:(CGFloat)alpha
{
    NSString *cString = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

    // String should be 6 or 8 characters
    if ([cString length] < 6) return [UIColor grayColor];

    // strip 0X if it appears
    if ([cString hasPrefix:@"0X"]) cString = [cString substringFromIndex:2];

    if ([cString length] != 6) return  [UIColor grayColor];

    // Separate into r, g, b substrings
    NSRange range;
    range.location = 0;
    range.length = 2;
    NSString *rString = [cString substringWithRange:range];

    range.location = 2;
    NSString *gString = [cString substringWithRange:range];

    range.location = 4;
    NSString *bString = [cString substringWithRange:range];

    // Scan values
    unsigned int r, g, b;
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    [[NSScanner scannerWithString:gString] scanHexInt:&g];
    [[NSScanner scannerWithString:bString] scanHexInt:&b];

    return [UIColor colorWithRed:((float) r / 255.0f)
                           green:((float) g / 255.0f)
                            blue:((float) b / 255.0f)
                           alpha:alpha];
}

+ (BOOL) validateUrl: (NSString *) candidate {
    NSString *urlRegEx =
    @"(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+smil://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+";
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlRegEx];
    return [urlTest evaluateWithObject:candidate];
}


+ (BOOL) validateEmail: (NSString *) email {
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    
    return [emailTest evaluateWithObject:email];
}
+(NSLayoutConstraint *)addView:(UIView *)view ToContainer:(UIView *)container WithTopMargin:(NSNumber *)topMargin LeftMargin:(NSNumber *)leftMargin BottomMargin:(NSNumber *)bottomMargin RightMargin:(NSNumber *)rightMargin Width:(NSNumber *)width Height:(NSNumber *)height {

    view.translatesAutoresizingMaskIntoConstraints = NO;

    [container addSubview:view];

    NSLayoutConstraint *top;
    NSLayoutConstraint *bottom;
    NSLayoutConstraint *left;
    NSLayoutConstraint *right;

    NSLayoutConstraint *widthConstraint;
    NSLayoutConstraint *heightConstraint;

    if ( topMargin != nil ) {
        top = [NSLayoutConstraint constraintWithItem:view
                                           attribute:NSLayoutAttributeTop
                                           relatedBy:NSLayoutRelationEqual
                                              toItem:container
                                           attribute:NSLayoutAttributeTop
                                          multiplier:1.0
                                            constant:topMargin.floatValue];

        [container addConstraint:top];
    }

    if ( leftMargin != nil ) {
        left = [NSLayoutConstraint constraintWithItem:view
                                            attribute:NSLayoutAttributeLeading
                                            relatedBy:NSLayoutRelationEqual
                                               toItem:container
                                            attribute:NSLayoutAttributeLeading
                                           multiplier:1.0
                                             constant:leftMargin.floatValue];

        [container addConstraint:left];
    }

    if ( bottomMargin != nil ) {
        bottom = [NSLayoutConstraint constraintWithItem:view
                                              attribute:NSLayoutAttributeBottom
                                              relatedBy:NSLayoutRelationEqual
                                                 toItem:container
                                              attribute:NSLayoutAttributeBottom
                                             multiplier:1.0
                                               constant:bottomMargin.floatValue];

        [container addConstraint:bottom];
    }

    if ( rightMargin != nil ) {
        right = [NSLayoutConstraint constraintWithItem:view
                                             attribute:NSLayoutAttributeTrailing
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:container
                                             attribute:NSLayoutAttributeTrailing
                                            multiplier:1.0
                                              constant:rightMargin.floatValue];

        [container addConstraint:right];
    }

    if ( width != nil ) {
        widthConstraint = [NSLayoutConstraint constraintWithItem:view
                                                       attribute:NSLayoutAttributeWidth
                                                       relatedBy:NSLayoutRelationEqual
                                                          toItem:nil
                                                       attribute:NSLayoutAttributeNotAnAttribute
                                                      multiplier:1.0
                                                        constant:width.floatValue];

        [container addConstraint:widthConstraint];
    }

    if ( height != nil ) {
        heightConstraint = [NSLayoutConstraint constraintWithItem:view
                                                        attribute:NSLayoutAttributeHeight
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:nil
                                                        attribute:NSLayoutAttributeNotAnAttribute
                                                       multiplier:1.0
                                                         constant:height.floatValue];
        
        [container addConstraint:heightConstraint];
    }

    return top;
}


+ (UIImage *)imageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}





+ (UIImage *) applyMonoChromeWithRandColor: (UIImage *)uIImage andColor:(CGColorRef )color
{
    
    //  Convert UIColor to CIColor
    CGColorRef colorRef = color;
    NSString *colorString = [CIColor colorWithCGColor:colorRef].stringRepresentation;
    CIColor *coreColor = [CIColor colorWithString:colorString];
    
    CIContext *context = [CIContext contextWithOptions:nil];
    
    //  Convert UIImage to CIImage
    CIImage *ciImage = [[CIImage alloc] initWithImage:uIImage];
    
    //  Set values for CIColorMonochrome Filter
    CIFilter *filter = [CIFilter filterWithName:@"CIColorMonochrome"];
    [filter setValue:ciImage forKey:kCIInputImageKey];
    [filter setValue:@1.0 forKey:@"inputIntensity"];
    [filter setValue:coreColor forKey:@"inputColor"];
    
    CIImage *result = [filter valueForKey:kCIOutputImageKey];
    
    CGRect extent = [result extent];
    
    CGImageRef cgImage = [context createCGImage:result fromRect:extent];
    
    UIImage *filteredImage = [[UIImage alloc] initWithCGImage:cgImage];
    
    return filteredImage;
}
+(void) doLogout
{
    NSHTTPCookieStorage* cookies = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray* facebookCookies = [cookies cookiesForURL:[NSURL URLWithString:@"http://m.facebook.com"]];
    
    for (NSHTTPCookie* cookie in facebookCookies) {
        [cookies deleteCookie:cookie];
    }


}


+(UIEdgeInsets )makeinsetForTableView:(UITableView *)tableView{
    CGFloat dummyViewHeight3 = 40;
    UIView *dummyView3 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, dummyViewHeight3)];
    tableView.tableHeaderView = dummyView3;
    tableView.contentInset = UIEdgeInsetsMake(-dummyViewHeight3, 0, 0, 0);

    return tableView.contentInset;
    

}






+ (void) runSpinAnimationOnView:(UIView*)view duration:(CGFloat)duration rotations:(CGFloat)rotations repeat:(float)repeat
{
    CABasicAnimation* rotationAnimation;
    rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0 /* full rotation*/ * rotations * duration ];
    rotationAnimation.duration = duration;
    rotationAnimation.cumulative = YES;
    rotationAnimation.repeatCount = repeat;
    
    [view.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
}







+(CGFloat )calculatePixelsWithSize:(CGFloat )size andSeconds:(NSInteger )seconds{

    CGFloat result = size / seconds;

    return result;
}






+(CAGradientLayer *)CreateGradientInView:(UIView *)view withStartColor:(UIColor *)startColor andEndColor:(UIColor *)endColor{

    CAGradientLayer *gradient = [CAGradientLayer layer];
     gradient.frame = view.bounds;
     gradient.colors = @[(id)startColor.CGColor,
                        (id)endColor.CGColor];
    gradient.locations = @[@0.0, @0.77, @1.0];
   
    return gradient;


}




//+(NSString *)getColorForFavTeam{
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    
//     NSString *colorMain;
//[Services getMatchesForFavs:[defaults objectForKey:@"user_token"] andHandler:^(id data) {
//    Matches *match = data;
//    
//    NSArray *arrayOfFavs = [NSKeyedUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"user_fav_teams"]];
//    
//   
//    
//    
//    for ( Favoritos *team in arrayOfFavs){
//    
//        if( team.team.team_id == match.match_team_local.team_id){
//        
//            Main_BACK_COLOR = match.match_team_local.team_color;
//        
//        }else if( team.team.team_id == match.match_team_visit.team_id){
//              Main_BACK_COLOR = match.match_team_visit.team_color;
//            
//        }
//    
//        
//    }
//    
//} orErrorHandler:^(NSError *err) {
//    
//}];
//
//
//return colorMain;
//}






@end
