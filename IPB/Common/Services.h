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

+(void)updatePlantForIPB:(NSString *)plant_name andPlantID:(NSNumber *)plant_id andCapacityMax:(NSNumber *)capacidad_maxima AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)updateProjectForIPB:(NSString *)cantidad andID:(NSNumber *)idproject andPrecio:(NSString *)precio andTotal:(NSString *)total andMinutaje:(NSString *)minutaje andStatus:(NSString *)status andCliente:(NSString *)cliente andTela:(NSString *)tela andbase64String:(NSString *)base64String andFechaEntrega:(NSString *)fecha_entrega AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)createReportEnvio:(NSNumber *)cantidad_envio andCutName:(NSString *)cut_name andCutID:(NSNumber *)cut_id andNumeroDeEnvio:(NSString *)numero_envio AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)FilterCuts:(NSString *)planta andLista:(NSString *)lista andCorte:(NSString *)corte andEstilo:(NSString *)estilo andStatus:(NSString *)status andfechaIPB:(NSString *)fecha_ipb andFechaCliente:(NSString *)fecha_cliente andCliente:(NSString *)cliente andHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)getCutsForPlant:(NSString *)plant_name AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)getStyle:(NSString *)style_name AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)getPlantName:(NSString *)plant_id andHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)getTotals:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)updateReportEnvio:(NSNumber *)cantidad_envio andReportID:(NSNumber *)report_id andCutName:(NSString *)cut_name andCutID:(NSNumber *)cut_id andNumeroDeEnvio:(NSString *)numero_envio AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)createReport:(NSString *)lista andCut:(NSNumber *)corte andStyle:(NSString *)estilo andCantidad:(NSString *)cantidad andFechaIPB:(NSString *)fecha_ipb andRealizadas:(NSString *)realizadas andOperarios:(NSNumber *)operarios andFaltas:(NSNumber *)faltas andProducidas:(NSNumber *)produciad andPlancha:(NSNumber *)en_plancha andEmpaque:(NSNumber *)en_empaque andBodega:(NSNumber *)bodega andCutName:(NSString *)cut_name AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)updateReport:(NSString *)lista andReportID:(NSNumber *)report_id andCut:(NSString *)corte andStyle:(NSString *)estilo andCantidad:(NSString *)cantidad andFechaIPB:(NSString *)fecha_ipb andRealizadas:(NSString *)realizadas andOperarios:(NSNumber *)operarios andFaltas:(NSNumber *)faltas andProducidas:(NSNumber *)produciad andPlancha:(NSNumber *)en_plancha andEmpaque:(NSNumber *)en_empaque andCutName:(NSString *)cut_name andCutID:(NSNumber *)cut_id andBodega:(NSNumber *)bodega AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)updateReportCorte:(NSNumber *)cant_real_corte andstatus:(NSString *)status andCutName:(NSString *)cut_name andCutID:(NSNumber *)cut_id andReportID:(NSNumber *)report_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)createReportCorte:(NSNumber *)cant_real_corte andstatus:(NSString *)status andCutName:(NSString *)cut_name andCutID:(NSNumber *)cut_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;



+(void)Loginwith:(NSString *)username andPassword:(NSString *)password andHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)assignCutToPlantWithQuantity:(NSNumber *)quantity andCliente:(NSString *)cliente fecha:(NSString *)fecha andPrecioTotal:(NSNumber *)precio_total andPrecioUnitario:(NSNumber *)precio_unitario andstyleImage:(NSString *)style_image andStyle:(NSString *)style AndPlantID:(NSNumber *)plant_id andPendingCutID:(NSNumber *)cut_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


+(void)createPlantForIPB:(NSString *)lista andCapacityMax:(NSNumber *)capacidad_maxima AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)createReport:(NSString *)lista andCutID:(NSNumber *)cut_id andCut:(NSString *)corte andStyle:(NSString *)estilo andCantidad:(NSString *)cantidad andFechaIPB:(NSString *)fecha_ipb andRealizadas:(NSString *)realizadas andOperarios:(NSNumber *)operarios andFaltas:(NSNumber *)faltas andProducidas:(NSNumber *)produciad andPlancha:(NSNumber *)en_plancha andEmpaque:(NSNumber *)en_empaque andBodega:(NSNumber *)bodega AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


//+(void)eliminarReporte:(NSNumber *)reporte_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


+(void)createClientForIPB:(NSString *)client_name andContactName1:(NSString *)nombre1 andContactEmail1:(NSString *)email1 andContactTelefone1:(NSString *)telefone1 andContactName2:(NSString *)nombre2 andContactEmail2:(NSString *)email2 andContactTelefone2:(NSString *)telefone2 andContactName3:(NSString *)nombre3 andContactEmail3:(NSString *)email3 andContactTelefone3:(NSString *)telefone3 andContactPuesto1:(NSString *)puesto1 andContactPuesto2:(NSString *)puesto2 andContactPuesto3:(NSString *)puesto3 andDireccion:(NSString *)direccion AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)filterCortesByName:(NSString *)corte_name AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)createProveedorForIPB:(NSString *)client_name andContactName1:(NSString *)nombre1 andContactEmail1:(NSString *)email1 andContactTelefone1:(NSString *)telefone1 andContactName2:(NSString *)nombre2 andContactEmail2:(NSString *)email2 andContactTelefone2:(NSString *)telefone2 andContactName3:(NSString *)nombre3 andContactEmail3:(NSString *)email3 andContactTelefone3:(NSString *)telefone3 andContactPuesto1:(NSString *)puesto1 andContactPuesto2:(NSString *)puesto2 andContactPuesto3:(NSString *)puesto3 andDireccion:(NSString *)direccion AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)eliminarPlanta:(NSNumber *)plant_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)eliminarCliente:(NSNumber *)client_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)eliminarProveedor:(NSNumber *)client_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


+(void)eliminarUsuario:(NSNumber *)usuario_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)eliminarProyecto:(NSNumber *)project_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


+(void)createUserForIPB:(NSString *)user_name andUserSurname:(NSString *)surname andTelefone:(NSString *)telefono andEmail:(NSString *)email andPassword:(NSString *)password andPuesto:(NSString *)puesto andbase64String:(NSString *)base64String andDeviceToken:(NSString *)token andPlantName:(NSString *)plant_name AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)getPlantsforStyle:(NSNumber *)style_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)eliminarEstilo:(NSNumber *)style_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)updateProject:(NSNumber *)project_id andStatus:(NSString *)status AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)updateClient:(NSString *)client_name andID:(NSNumber *)client_id andContactName1:(NSString *)nombre1 andContactEmail1:(NSString *)email1 andContactTelefone1:(NSString *)telefone1 andContactName2:(NSString *)nombre2 andContactEmail2:(NSString *)email2 andContactTelefone2:(NSString *)telefone2 andContactName3:(NSString *)nombre3 andContactEmail3:(NSString *)email3 andContactTelefone3:(NSString *)telefone3 andContactPuesto1:(NSString *)puesto1 andContactPuesto2:(NSString *)puesto2 andContactPuesto3:(NSString *)puesto3 andDireccion:(NSString *)direccion AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;



+(void)updateProveedorForIPB:(NSString *)client_name andID:(NSNumber *)client_id andContactName1:(NSString *)nombre1 andContactEmail1:(NSString *)email1 andContactTelefone1:(NSString *)telefone1 andContactName2:(NSString *)nombre2 andContactEmail2:(NSString *)email2 andContactTelefone2:(NSString *)telefone2 andContactName3:(NSString *)nombre3 andContactEmail3:(NSString *)email3 andContactTelefone3:(NSString *)telefone3 andContactPuesto1:(NSString *)puesto1 andContactPuesto2:(NSString *)puesto2 andContactPuesto3:(NSString *)puesto3 andDireccion:(NSString *)direccion AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;



+(void)createStyleForIPB:(NSString *)style_name andbase64String:(NSString *)base64String AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)createProjectForIPB:(NSString *)cantidad andPrecio:(NSString *)precio andTotal:(NSString *)total andMinutaje:(NSString *)minutaje andStatus:(NSString *)status andCliente:(NSString *)cliente andTela:(NSString *)tela andbase64String:(NSString *)base64String andFechaEntrega:(NSString *)fecha_entrega andNote:(NSString *)note AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)updateProjectForIPB:(NSString *)cantidad andID:(NSNumber *)idproject andPrecio:(NSString *)precio andTotal:(NSString *)total andMinutaje:(NSString *)minutaje andStatus:(NSString *)status andCliente:(NSString *)cliente andTela:(NSString *)tela andbase64String:(NSString *)base64String andFechaEntrega:(NSString *)fecha_entrega andNotes:(NSString *)notes AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

//GET
+(void)getStyleImage:(NSString *)style_name AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)getCutsForReportAndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetPendingCutsWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetPlantsWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetClientsWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetProveedoresWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetUsersWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetStylesWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)getReportsForCut:(NSNumber *)cut_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetEnviosUrgentesWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
+(void)GetReportsWithandHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)getAllcuts:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)getCutDetail:(NSNumber *)cut_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;

+(void)getAllProjects:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;


+(void)getPlantName:(NSNumber *)plant_id AndHandler:(void (^)(id))handler orErrorHandler:(void (^)(NSError *))errorHandler;
@end
