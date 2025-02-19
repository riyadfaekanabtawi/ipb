//
//  AppDelegate.h
//  IPB
//
//  Created by Riyad Anabtawi on 11/28/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <UIKit/UIKit.h>
@protocol AppiShit

-(void)displayMatchFromDeepLink:(NSNumber *)match_id;
-(void)displayVideoFromDeepLink:(NSDictionary *)video;
-(void)displayVideoFromDeepLinkFB:(NSNumber *)video_id;
@end



@interface AppDelegate : UIResponder <UIApplicationDelegate>
+(void)setVideoPlaying:(BOOL)isPlaying;
@property (strong, nonatomic) UIWindow *window;
@property (nonatomic,retain) id<AppiShit> delegate;
+(BOOL)isVideoPlaying;
+(BOOL)shouldAutorotate;
+(NSUInteger)supportedInterfaceOrientations;
+(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation;
@end

