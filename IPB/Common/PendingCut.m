//
//  PendingCut.m
//  IPB
//
//  Created by Riyad Anabtawi on 12/2/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import "PendingCut.h"

@implementation PendingCut
-(PendingCut *)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    
    if (self) {
        self.cut_id = replaceNSNullValue([dictionary objectForKey:@"id"]);
        self.cut_client = replaceNSNullValue([dictionary objectForKey:@"cliente"]);
        self.cut_estilo =  replaceNSNullValue([dictionary objectForKey:@"estilo"]);
        self.cut_cantidad = replaceNSNullValue([dictionary objectForKey:@"cantidad"]);
        self.cut_precio_unitario = [[dictionary objectForKey:@"precio_unitario"] floatValue];
        self.corte = replaceNSNullValue([dictionary objectForKey:@"corte"]);
        self.estado = replaceNSNullValue([dictionary objectForKey:@"status"]);
        self.cut_precio_final = [[dictionary objectForKey:@"precio_final"] floatValue];
        self.cut_fecha_ipb = replaceNSNullValue([dictionary objectForKey:@"fecha_ipb"]);
        self.cut_fecha_client = replaceNSNullValue([dictionary objectForKey:@"fecha_cliente"]);
        self.cut_list = replaceNSNullValue([dictionary objectForKey:@"lista"]);
        self.prenda = replaceNSNullValue([dictionary objectForKey:@"prenda"]);
        self.editadoPor = replaceNSNullValue([dictionary objectForKey:@"editado_por"]);
    }
    
    return self;
}

@end
