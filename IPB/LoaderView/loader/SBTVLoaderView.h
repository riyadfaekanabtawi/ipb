//
//  SBTVLoaderView.h
//  CDF
//
//  Created by SmartboxTV on 15-12-14.
//  Copyright (c) 2014 Smartbox TV. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol SBTVLoaderViewDelegate <NSObject,UIScrollViewDelegate>

@optional
-(void)closeLoaderView;

@end
@interface SBTVLoaderView : UIView
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activity;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic,retain) id<SBTVLoaderViewDelegate> delegate;
@property (weak, nonatomic) IBOutlet UIImageView *popcornUIImage;
@property (weak, nonatomic) IBOutlet UIImageView *blurOverlay;
@property (weak, nonatomic)    CABasicAnimation *animation;
@property (retain, nonatomic)NSArray *images;
@property (weak, nonatomic) IBOutlet UIButton *cerrarButton;
@property (retain,nonatomic)IBOutlet UIView *mainView;
@property (retain,nonatomic)IBOutlet UILabel *cargandoLabel;
@property (nonatomic) BOOL		isAnimating;
@property (nonatomic) int			status;
@property (retain,nonatomic)IBOutlet NSLayoutConstraint *constraintWidth;
-(void)endAnimationAndRemoveView;
+(SBTVLoaderView *)create;
-(void)startAnimation;
-(void)endAnimation;
@end
