//
//  CookBookServices.h
//  
//
//  Created by Riyad Anabtawi on 7/9/15.
//
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFHTTPSessionManager.h>

@interface Services : NSObject

+(void)Loginwith:(NSDate *)username andPassword:(NSDate *)password andHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


@end
