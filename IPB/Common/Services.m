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
#import "Cliente.h"
#import "Style.h"
#import "Report.h"
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





+(void)getStyleImage:(NSString *)style_name AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    
    
    [manager GET:[NSString stringWithFormat:@"%@getStyleImage?name=%@",BASE_URL,style_name] parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
   
        
        handler([[responseObject objectForKey:@"imagen"] description]);
        
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


+(void)GetClientsWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    
    
    [manager GET:[NSString stringWithFormat:@"%@getClients",BASE_URL] parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        
        NSMutableArray *mutableArray = [NSMutableArray new];
        
        for(NSDictionary *dict in [responseObject objectForKey:@"api"]){
            
            Cliente *cliente = [[Cliente alloc] initWithDictionary:dict];
            
            
            [mutableArray addObject:cliente];
            
        }
        
        handler(mutableArray);
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
}

+(void)GetUsersWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    
    
    [manager GET:[NSString stringWithFormat:@"%@getUsers",BASE_URL] parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        
        NSMutableArray *mutableArray = [NSMutableArray new];
        
        for(NSDictionary *dict in [responseObject objectForKey:@"api"]){
            
            User *cliente = [[User alloc] initWithDictionary:dict];
            
            
            [mutableArray addObject:cliente];
            
        }
        
        handler(mutableArray);
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
}


+(void)GetStylesWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    
    
    [manager GET:[NSString stringWithFormat:@"%@getStyles",BASE_URL] parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        
        NSMutableArray *mutableArray = [NSMutableArray new];
        
        for(NSDictionary *dict in [responseObject objectForKey:@"api"]){
            
            Styles *cliente = [[Styles alloc] initWithDictionary:dict];
            
            
            [mutableArray addObject:cliente];
            
        }
        
        handler(mutableArray);
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
}





+(void)getReportsForCut:(NSNumber *)cut_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    
    
    [manager GET:[NSString stringWithFormat:@"%@getReportsForCut?cut_id=%@",BASE_URL,cut_id] parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        
        NSMutableArray *mutableArray = [NSMutableArray new];
        
        for(NSDictionary *dict in [responseObject objectForKey:@"api"]){
            
            Report *user = [[Report alloc] initWithDictionary:dict];
            
            
            [mutableArray addObject:user];
            
        }
        
        handler(mutableArray);
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
    
}



+(void)getCutsForReportAndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{


    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    
    
    [manager GET:[NSString stringWithFormat:@"%@getCutsForReports",BASE_URL] parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
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
+(void)updateReport:(NSString *)lista andReportID:(NSNumber *)report_id andCut:(NSString *)corte andStyle:(NSString *)estilo andCantidad:(NSString *)cantidad andFechaIPB:(NSString *)fecha_ipb andRealizadas:(NSString *)realizadas andOperarios:(NSNumber *)operarios andFaltas:(NSNumber *)faltas andProducidas:(NSNumber *)produciad andPlancha:(NSNumber *)en_plancha andEmpaque:(NSNumber *)en_empaque andBodega:(NSNumber *)bodega AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    NSDictionary *p = @{@"report":@{@"id":report_id,@"cut_id":corte,@"lista":lista,@"corte":corte,@"estilo":estilo,@"cantidad":cantidad,@"fecha_ipb":fecha_ipb,@"realizadas":realizadas,@"operarios":operarios,@"faltas":faltas,@"produciad":produciad,@"en_plancha":en_plancha,@"en_empaque":en_empaque,@"bodega":bodega}};
    
    [manager POST:[NSString stringWithFormat:@"%@updateReport",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        
        if ([responseObject objectForKey:@"Result"]){
            
            handler(@"NO");
        }else{
            Report *corte = [[Report alloc] initWithDictionary:[responseObject objectForKey:@"report"]];
            
            
            
            handler(corte);
            
        }
        
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
    
}

+(void)createReport:(NSString *)lista andCut:(NSString *)corte andStyle:(NSString *)estilo andCantidad:(NSString *)cantidad andFechaIPB:(NSString *)fecha_ipb andRealizadas:(NSString *)realizadas andOperarios:(NSNumber *)operarios andFaltas:(NSNumber *)faltas andProducidas:(NSNumber *)produciad andPlancha:(NSNumber *)en_plancha andEmpaque:(NSNumber *)en_empaque andBodega:(NSNumber *)bodega AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{


    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    NSDictionary *p = @{@"report":@{@"cut_id":corte,@"lista":lista,@"corte":corte,@"estilo":estilo,@"cantidad":cantidad,@"fecha_ipb":fecha_ipb,@"realizadas":realizadas,@"operarios":operarios,@"faltas":faltas,@"produciad":produciad,@"en_plancha":en_plancha,@"en_empaque":en_empaque,@"bodega":bodega}};
    
    [manager POST:[NSString stringWithFormat:@"%@createReport",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        
        if ([responseObject objectForKey:@"Result"]){
            
            handler(@"NO");
        }else{
            Report *corte = [[Report alloc] initWithDictionary:[responseObject objectForKey:@"report"]];
            
            
            
            handler(corte);
            
        }
        
        
        
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


+(void)createPlantForIPB:(NSString *)plant_name andCapacityMax:(NSNumber *)capacidad_maxima AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    NSDictionary *p = @{@"plant":@{@"name":plant_name,@"max_capacity":capacidad_maxima}};
    
    [manager POST:[NSString stringWithFormat:@"%@createPlant",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
          handler(@"YES");
      
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
}

+(void)createClientForIPB:(NSString *)client_name andContactName1:(NSString *)nombre1 andContactEmail1:(NSString *)email1 andContactTelefone1:(NSString *)telefone1 andContactName2:(NSString *)nombre2 andContactEmail2:(NSString *)email2 andContactTelefone2:(NSString *)telefone2 andContactName3:(NSString *)nombre3 andContactEmail3:(NSString *)email3 andContactTelefone3:(NSString *)telefone3 AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    NSDictionary *p = @{@"client":@{@"nombre":client_name,@"nombre_contacto1":nombre1,@"nombre_contacto2":nombre2,@"nombre_contacto3":nombre3,@"telefono_contacto1":telefone1,@"telefono_contacto2":telefone2,@"telefono_contacto3":telefone3,@"email_contacto1":email1,@"email_contacto2":email2,@"email_contacto3":email3}};
    
    [manager POST:[NSString stringWithFormat:@"%@createClient",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        handler(@"YES");
        
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
}

+(void)createUserForIPB:(NSString *)user_name andUserSurname:(NSString *)surname andTelefone:(NSString *)telefono andEmail:(NSString *)email andPassword:(NSString *)password andPuesto:(NSString *)puesto andbase64String:(NSString *)base64String andDeviceToken:(NSString *)token AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    int i = arc4random() % 1000;
    NSNumber *numbeer = [NSNumber numberWithInt:i];
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    NSDictionary *p = @{@"user":@{@"nombre":user_name,@"device_token":token,@"apellido":surname,@"email":email,@"password":password,@"passwprd_confirmation":password,@"mobile_provider":@"ios",@"puesto":puesto,@"telefono":telefono},@"image":@{@"photo_file_name" :[NSString stringWithFormat:@"User-%@.jpg",numbeer],@"photo_updated_at" :[NSDate date],@"photo_file_size" :[NSString stringWithFormat:@"User-%@.jpg",numbeer],@"photo_content_type" :@"image/jpg", @"image_url":base64String}};
    
    [manager POST:[NSString stringWithFormat:@"%@registerUser",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        if ([responseObject objectForKey:@"Result"]){
        
            if ([[responseObject objectForKey:@"Result"] isEqualToString:@"Error user already exists"]){
              handler(@"USER EXISTS");
            
            }else{
              handler(@"ERROR");
            
            }
        }else{
        
            handler(@"YES");
        }
    
        
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
}


+(void)createStyleForIPB:(NSString *)style_name andbase64String:(NSString *)base64String AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{

    int i = arc4random() % 1000;
    NSNumber *numbeer = [NSNumber numberWithInt:i];
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    NSDictionary *p = @{@"style":@{@"name":style_name},@"image":@{@"photo_file_name" :[NSString stringWithFormat:@"User-%@.jpg",numbeer],@"photo_updated_at" :[NSDate date],@"photo_file_size" :[NSString stringWithFormat:@"User-%@.jpg",numbeer],@"photo_content_type" :@"image/jpg", @"image_url":base64String}};
    
    [manager POST:[NSString stringWithFormat:@"%@createStyle",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
          handler(@"YES");
        
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    


}

+(void)eliminarEstilo:(NSNumber *)style_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    NSDictionary *p = @{@"style_id":style_id};
    
    [manager POST:[NSString stringWithFormat:@"%@deleteStyle",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        handler(@"YES");
        
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];

}




+(void)eliminarCliente:(NSNumber *)client_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    NSDictionary *p = @{@"client_id":client_id};
    
    [manager POST:[NSString stringWithFormat:@"%@deleteClient",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        handler(@"YES");
        
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
}
+(void)eliminarUsuario:(NSNumber *)usuario_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    NSDictionary *p = @{@"user_id":usuario_id};
    
    [manager POST:[NSString stringWithFormat:@"%@deleteUser",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        handler(@"YES");
        
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];
    
}
+(void)eliminarPlanta:(NSNumber *)plant_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler{

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    
    NSDictionary *p = @{@"plant_id":plant_id};
    
    [manager POST:[NSString stringWithFormat:@"%@deletePlant",BASE_URL] parameters:p progress:^(NSProgress * _Nonnull downloadProgress) {
        
        
        
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        
        handler(@"YES");
        
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        
        
        errorHandler(error);
        
        
    }];

}


@end
