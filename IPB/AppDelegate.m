//
//  AppDelegate.m
//  IPB
//
//  Created by Riyad Anabtawi on 11/28/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


static BOOL _isVideoPlaying = NO;

static BOOL _isClipping = NO;

+(void)setVideoPlaying:(BOOL)isPlaying {
    _isVideoPlaying = isPlaying;
    
}




+(BOOL)shouldAutorotate {
    return YES;
}

+(BOOL)isVideoPlaying {
    return _isVideoPlaying;
}

- (NSUInteger)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return [AppDelegate supportedInterfaceOrientations];
}
+(NSUInteger)supportedInterfaceOrientations {
    if (_isVideoPlaying) {
        return UIInterfaceOrientationMaskAll;
    }
    else {
        
        if (_isClipping){
            return UIInterfaceOrientationMaskLandscape;
            
        }else{
            if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
            {
                return UIInterfaceOrientationMaskLandscape;
                
            }else{
                return UIInterfaceOrientationMaskPortrait;
                
            }
            
        }
        
    }
}
+(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (_isVideoPlaying) {
        return YES;
    }
    else {
        
        if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
        {
            return UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
            
        }else{
            return UIInterfaceOrientationIsPortrait(toInterfaceOrientation);
            
        }
        
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
//        for (NSString *font in [UIFont familyNames]) {
//            NSLog(@"%@", [UIFont fontNamesForFamilyName:font]);
//        }
    
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
