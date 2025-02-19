//
//  LoaderView.m
//  EstadioCDF
//
//  Created by SmartboxTV on 13-01-14.
//  Copyright (c) 2014 CDF. All rights reserved.
//

#import "SBTVLoaderView.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
@implementation SBTVLoaderView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}
-(void)endAnimationAndRemoveView{}

+(SBTVLoaderView *)create
{

    static SBTVLoaderView *_sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[SBTVLoaderView alloc] init];
 
    

    _sharedInstance =[[[NSBundle mainBundle] loadNibNamed:@"SBTVLoaderView" owner:self options:nil] objectAtIndex: 0];
   
    _sharedInstance.popcornUIImage.image=  [UIImage imageWithContentsOfFile:[[[self class] frameworkBundle] pathForResource:@"1" ofType:@"png"]];
    _sharedInstance.cargandoLabel.font=[UIFont fontWithName:FONT_REGULAR size:_sharedInstance.cargandoLabel.font.pointSize];
    _sharedInstance.cerrarButton.hidden=YES;
        [_sharedInstance.activity startAnimating];




    [NSTimer scheduledTimerWithTimeInterval:.1 target:_sharedInstance selector:@selector(updateAnimation) userInfo:nil repeats:NO];

    
       });
  
    return _sharedInstance;


}

- (BOOL)isAnimating {
    return self.isAnimating;
}
- (void)updateAnimation
{


   dispatch_async(dispatch_get_main_queue(), ^{

self.status = self.status+1;


    if(self.status==   15){
        self.status=0;

    }
   });
}
-(void)startAnimation {
       dispatch_async(dispatch_get_main_queue(), ^{
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 1;
    } completion:^(BOOL finished) {
        [self.activityIndicator startAnimating];
    }];
       });

}
-(IBAction)cerrarLoader:(id)sender{

    [self.delegate closeLoaderView];
    
}
-(void)endAnimation {
    [self.activityIndicator stopAnimating];
    [self removeFromSuperview];
}
+ (NSBundle *)frameworkBundle {

    return [NSBundle mainBundle];
}
@end
