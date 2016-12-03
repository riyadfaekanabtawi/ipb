//
//  CookBookServices.m
//  
//
//  Created by Riyad Anabtawi on 7/9/15.
//
//

#import "Services.h"
#import "User.h"
#import "PendingCut.h"
@implementation Services


+(void)Loginwith:(NSString *)username andPassword:(NSString *)password andHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    NSDictionary *p;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"token_push"]){
    p = @{@"email" : username,@"mobile_provider":@"ios",@"password" : password,@"device_token":[[NSUserDefaults standardUserDefaults] objectForKey:@"token_push"]};
    }else{
    
    p = @{@"email" : username,@"password" : password,@"device_token":@"0",@"mobile_provider":@"ios"};
    }
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    
    
    [manager POST:[NSString stringWithFormat:@"%@user/login",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
     
 
     
     
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
     
        
        
        if ([[responseObject objectForKey:@"Result"] isEqualToString:@"Error"]){
            
            if ([[responseObject objectForKey:@"Description"] isEqualToString:@"Email does not match password"]){
            
                        handler(@"Email does not match password");
            
            }else{
             
                            handler(@"We could not find any users with that email.");
            
            
            }
            
            

        }else{
            
            
            User *user = [[User alloc] initWithDictionary:responseObject];
            
            
            handler(user);
        }
        
     
     
     
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
     
 
        
        errorHandler(error);
    
    
    }];

}



+(void)GetPendingCutsWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
 
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    
    
    [manager GET:[NSString stringWithFormat:@"%@getPendingCuts",BASE_URL] parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        
        NSMutableArray *mutableArray = [NSMutableArray new];
        
        for(NSDictionary *dict in [responseObject objectForKey:@"api"]){
        
            PendingCut *user = [[PendingCut alloc] initWithDictionary:dict];
            
            
            [mutableArray addObject:user];
        
        }
        
          handler(mutableArray);
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
}



@end
