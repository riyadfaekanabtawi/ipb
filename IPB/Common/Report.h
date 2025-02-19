//
//  Report.h
//  IPB
//
//  Created by Riyad Anabtawi on 12/19/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Report : NSObject
-(Report *)initWithDictionary:(NSDictionary *)dictionary;
@property NSNumber *reporte_id;
@property NSString *lista;
@property NSString *corte;
@property NSString *estilo;
@property NSString *cantidad;
@property NSString *fecha_ipb;
@property NSString *realizadas;
@property NSNumber *operarios;
@property NSNumber *faltas;
@property NSNumber *produciad;
@property NSNumber *en_plancha;
@property NSNumber *en_empaque;
@property NSNumber *bodega;

@property NSString *dayString;
@property NSString *dayNumbers;
@property NSString *hour;

@property NSString *type_report;
@property NSString *cut_name;


@property NSString *status_report;
@property NSNumber *cantidad_de_envio;
@property NSNumber *numero_de_envio;
@property NSNumber *cantidad_por_enviar;
@property NSNumber *cantidad_enviada;
@property NSNumber *cantidad_real_envio;

@end
