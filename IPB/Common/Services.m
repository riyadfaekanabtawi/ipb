//
//  CookBookServices.m
//  
//
//  Created by Riyad Anabtawi on 7/9/15.
//
//

#import "Services.h"
#import "User.h"
@implementation Services


+(void)Loginwith:(NSDate *)username andPassword:(NSDate *)password andHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{


    NSDictionary *p = @{@"day" : username,@"time" : password};
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    [manager GET:@"" parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
     
 
     
     
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
     
        if ([[responseObject objectForKey:@"Status"] isEqualToString:@"OK"]){
            handler(@"YES");
        }else{
            
            handler(@"NO");
        }
        
     
     
     
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
     
 
        
        errorHandler(error);
    
    
    }];

}



@end
