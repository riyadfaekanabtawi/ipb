//
//  PendingCut.h
//  IPB
//
//  Created by Riyad Anabtawi on 12/2/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PendingCut : NSObject
-(PendingCut *)initWithDictionary:(NSDictionary *)dictionary;
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
@end
