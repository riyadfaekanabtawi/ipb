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
        self.cut_id = [dictionary objectForKey:@"id"];
        self.cut_client = [dictionary objectForKey:@"cliente"];
        self.cut_estilo = [dictionary objectForKey:@"estilo"];
        self.cut_cantidad = [dictionary objectForKey:@"cantidad"];
        self.cut_precio_unitario = [NSNumber numberWithFloat:[[dictionary objectForKey:@"precio_unitario"] floatValue]];
        self.corte = replaceNSNullValue([dictionary objectForKey:@"corte"]);
        self.estado = [dictionary objectForKey:@"status"];
        self.cut_precio_final = [NSNumber numberWithFloat:[[dictionary objectForKey:@"precio_final"] floatValue]];
        self.cut_fecha_ipb = [dictionary objectForKey:@"fecha_ipb"];
        self.cut_fecha_client = [dictionary objectForKey:@"fecha_cliente"];
        self.cut_list = [dictionary objectForKey:@"lista"];
        self.prenda = [dictionary objectForKey:@"prenda"];
        self.editadoPor = [dictionary objectForKey:@"editado_por"];
    }
    
    return self;
}

@end
