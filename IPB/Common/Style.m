//
//  Style.m
//  IPB
//
//  Created by Riyad Anabtawi on 12/13/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import "Style.h"
#import "Planta.h"
#import "Corte.h"
@implementation Styles



-(Styles *)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    
    if (self) {
        self.style_name = [dictionary objectForKey:@"name"];
        self.style_id = [dictionary objectForKey:@"id"];
        self.style_image = [NSString stringWithFormat:@"%@%@",BASE_URL,[dictionary objectForKey:@"photo"]];
        
        NSMutableArray *arrayMut = [NSMutableArray new];
        for (NSDictionary *plant in [dictionary objectForKey:@"plants"]){
        
            Corte *planta = [[Corte alloc] initWithDictionary:plant];
            [arrayMut addObject:planta];
        
        }
        
        self.plants_array = [NSArray arrayWithArray:arrayMut];
    }
    
    return self;
}
@end
