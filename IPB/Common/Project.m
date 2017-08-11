//
//  Project.m
//  IPB
//
//  Created by Riyad Anabtawi on 2/14/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

#import "Project.h"

@implementation Project
-(Project *)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    
    if (self) {
        
        self.project_id = [dictionary  objectForKey:@"id"];
        self.cantidad = [dictionary  objectForKey:@"cantidad"];
        self.total = [dictionary objectForKey:@"total"];
        self.precio = [dictionary objectForKey:@"precio"];
        self.status = [dictionary  objectForKey:@"status"];
        self.cliente = [dictionary  objectForKey:@"cliente"];
        self.notes = [dictionary  objectForKey:@"notes"];
        self.photo = [dictionary objectForKey:@"photo"];
        self.minutaje = [dictionary objectForKey:@"minutaje"];
        self.tela = [dictionary objectForKey:@"tela"];
        self.fecha_entrega = [dictionary objectForKey:@"fecha_entrega"];
        self.fecha_entrega = [dictionary objectForKey:@"fecha_entrega"];
    }
    
    return self;
}

@end
