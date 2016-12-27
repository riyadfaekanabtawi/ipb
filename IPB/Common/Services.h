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



//POST

+(void)Loginwith:(NSString *)username andPassword:(NSString *)password andHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)assignCutToPlantWithQuantity:(NSNumber *)quantity andCliente:(NSString *)cliente fecha:(NSString *)fecha andPrecioTotal:(NSNumber *)precio_total andPrecioUnitario:(NSNumber *)precio_unitario andstyleImage:(NSString *)style_image andStyle:(NSString *)style AndPlantID:(NSNumber *)plant_id andPendingCutID:(NSNumber *)cut_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


+(void)createPlantForIPB:(NSString *)lista andCapacityMax:(NSNumber *)capacidad_maxima AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)createReport:(NSString *)lista andCut:(NSString *)corte andStyle:(NSString *)estilo andCantidad:(NSString *)cantidad andFechaIPB:(NSString *)fecha_ipb andRealizadas:(NSString *)realizadas andOperarios:(NSNumber *)operarios andFaltas:(NSNumber *)faltas andProducidas:(NSNumber *)produciad andPlancha:(NSNumber *)en_plancha andEmpaque:(NSNumber *)en_empaque andBodega:(NSNumber *)bodega AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)updateReport:(NSString *)lista andReportID:(NSNumber *)report_id andCut:(NSString *)corte andStyle:(NSString *)estilo andCantidad:(NSString *)cantidad andFechaIPB:(NSString *)fecha_ipb andRealizadas:(NSString *)realizadas andOperarios:(NSNumber *)operarios andFaltas:(NSNumber *)faltas andProducidas:(NSNumber *)produciad andPlancha:(NSNumber *)en_plancha andEmpaque:(NSNumber *)en_empaque andBodega:(NSNumber *)bodega AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
//+(void)eliminarReporte:(NSNumber *)reporte_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


+(void)createClientForIPB:(NSString *)client_name andContactName1:(NSString *)nombre1 andContactEmail1:(NSString *)email1 andContactTelefone1:(NSString *)telefone1 andContactName2:(NSString *)nombre2 andContactEmail2:(NSString *)email2 andContactTelefone2:(NSString *)telefone2 andContactName3:(NSString *)nombre3 andContactEmail3:(NSString *)email3 andContactTelefone3:(NSString *)telefone3 AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)eliminarPlanta:(NSNumber *)plant_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)eliminarCliente:(NSNumber *)client_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)eliminarUsuario:(NSNumber *)usuario_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


+(void)createUserForIPB:(NSString *)user_name andUserSurname:(NSString *)surname andTelefone:(NSString *)telefono andEmail:(NSString *)email andPassword:(NSString *)password andPuesto:(NSString *)puesto andbase64String:(NSString *)base64String andDeviceToken:(NSString *)token AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;



+(void)eliminarEstilo:(NSNumber *)style_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


+(void)createStyleForIPB:(NSString *)style_name andbase64String:(NSString *)base64String AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
//GET
+(void)getStyleImage:(NSString *)style_name AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)getCutsForReportAndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetPendingCutsWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetPlantsWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetClientsWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetUsersWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetStylesWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)getReportsForCut:(NSNumber *)cut_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


@end
