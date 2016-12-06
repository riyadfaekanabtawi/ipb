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
#import "Planta.h"
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




+(void)GetPlantsWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    
    
    [manager GET:[NSString stringWithFormat:@"%@getPlants",BASE_URL] parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        
        NSMutableArray *mutableArray = [NSMutableArray new];
        
        for(NSDictionary *dict in [responseObject objectForKey:@"api"]){
            
            Planta *plant = [[Planta alloc] initWithDictionary:dict];
            
            
            [mutableArray addObject:plant];
            
        }
        
        handler(mutableArray);
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
}



+(void)assignCutToPlantWithQuantity:(NSNumber *)quantity andCliente:(NSString *)cliente fecha:(NSString *)fecha andPrecioTotal:(NSNumber *)precio_total andPrecioUnitario:(NSNumber *)precio_unitario andstyleImage:(NSString *)style_image andStyle:(NSString *)style AndPlantID:(NSNumber *)plant_id andPendingCutID:(NSNumber *)cut_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    NSDictionary *p = @{@"cantidad":quantity,@"cliente":cliente,@"planta_id":plant_id,@"fecha":fecha,@"precio_total":precio_total,@"precio_unitario":precio_unitario,@"style_image":style_image,@"style":style,@"cut_id":cut_id};
    
    [manager POST:[NSString stringWithFormat:@"%@assignCutToPlant",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        
        if ([responseObject objectForKey:@"Result"]){
        
         handler(@"NO");
        }else{
            PendingCut *corte = [[PendingCut alloc] initWithDictionary:[responseObject objectForKey:@"pendingcut"]];
            
            
            
            handler(corte);
        
        }
            
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
}






@end
