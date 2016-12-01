//
//  Planta.m
//  IPB
//
//  Created by Riyad Anabtawi on 11/29/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import "Planta.h"

@implementation Planta
-(Planta *)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    
    if (self) {
        self.planta_id = [dictionary objectForKey:@"id"];
        self.planta_nombre = [dictionary objectForKey:@"name"];
        self.planta_capacidadMax = [dictionary objectForKey:@"max_capacity"];
        self.planta_capacidadUsada = [dictionary objectForKey:@"used_capacity"];

    }
    
    return self;
}

@end
