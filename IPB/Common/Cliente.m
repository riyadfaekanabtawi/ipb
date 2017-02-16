//
//  Cliente.m
//  IPB
//
//  Created by Riyad Anabtawi on 12/12/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import "Cliente.h"

@implementation Cliente
-(Cliente *)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    
    if (self) {
        self.client_name = [dictionary objectForKey:@"nombre"];
        self.client_id = [dictionary objectForKey:@"id"];
        self.nombrecontacto1 = replaceNSNullValue([dictionary objectForKey:@"nombre_contacto1"]);
        
        self.nombrecontacto2 = replaceNSNullValue([dictionary objectForKey:@"nombre_contacto2"]);
        self.nombrecontacto3 = replaceNSNullValue([dictionary objectForKey:@"nombre_contacto3"]);
        self.emailcontacto1 = replaceNSNullValue([dictionary objectForKey:@"email_contacto1"]);
        self.emailcontacto2 = replaceNSNullValue([dictionary objectForKey:@"email_contacto2"]);
        self.emailcontacto3 = replaceNSNullValue([dictionary objectForKey:@"email_contacto3"]);
        self.telefonocontacto1 = replaceNSNullValue([dictionary objectForKey:@"telefono_contacto1"]);
        self.telefonocontacto2 = replaceNSNullValue([dictionary objectForKey:@"telefono_contacto2"]);
        self.telefonocontacto3 = replaceNSNullValue([dictionary objectForKey:@"telefono_contacto3"]);
        self.direccion = replaceNSNullValue([dictionary objectForKey:@"direccion"]);
        self.puestocontacto1 = replaceNSNullValue([dictionary objectForKey:@"puesto_contacto1"]);
        self.puestocontacto2 = replaceNSNullValue([dictionary objectForKey:@"puesto_contacto2"]);
        self.puestocontacto3 = replaceNSNullValue([dictionary objectForKey:@"puesto_contacto3"]);
    }
    
    return self;
}
@end
