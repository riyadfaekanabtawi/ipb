//
//  Corte.h
//  IPB
//
//  Created by Riyad Anabtawi on 1/5/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Planta.h"
@interface Corte : NSObject
-(Corte *)initWithDictionary:(NSDictionary *)dictionary;
@property NSNumber *cut_id;
@property NSString *cut_client;
@property NSString *cut_list;
@property NSString *cut_estilo;
@property NSNumber *cut_cantidad;
@property float cut_precio_unitario;
@property float cut_precio_final;
@property NSString *cut_fecha_ipb;
@property NSString *cut_fecha_client;
@property NSString *cut_lista;
@property NSString *editadoPor;
@property NSString *estado;
@property NSString *prenda;
@property NSString *corte;
@property NSNumber *plant_id;

@property NSNumber *bodega;
@property NSNumber *cantidad_enviada;
@property NSNumber *cantidad_de_envio;
@property NSNumber *cantidad_por_enviar;
@property NSNumber *cantidad_real_envio;
@property NSNumber *en_empaque;
@property NSNumber *en_plancha;
@property NSNumber *faltas;
@property NSNumber *numero_de_envio;
@property NSNumber *operarios;
@property NSNumber *produciad;
@property NSNumber *realizadas;
@property NSString *status;


@property Planta *planta;
@end
