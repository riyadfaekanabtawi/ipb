//
//  Planta.m
//  IPB
//
//  Created by Riyad Anabtawi on 11/29/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import "Planta.h"
#import "Corte.h"
@implementation Planta
-(Planta *)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    
    if (self) {
        self.planta_id = [dictionary objectForKey:@"id"];
        self.planta_nombre = [dictionary objectForKey:@"name"];
        self.planta_capacidadMax = replaceNSNullValue([dictionary objectForKey:@"max_capacity"]);
        self.planta_capacidadUsada = replaceNSNullValue([dictionary objectForKey:@"used_capacity"]);
        
        
    
        if (![[dictionary objectForKey:@"january_min"] isKindOfClass:[NSNull class]]){
            self.january_used = [[dictionary objectForKey:@"january_min"] floatValue];
        }else{
            self.january_used = 0.0;
            
        }
        
        
        
          if (![[dictionary objectForKey:@"febuary_min"] isKindOfClass:[NSNull class]]){
            self.febuary_used = [[dictionary objectForKey:@"febuary_min"] floatValue];
        }else{
            self.febuary_used = 0.0;
            
        }
        
        
        
        if (![[dictionary objectForKey:@"march_min"] isKindOfClass:[NSNull class]]){
         self.march_used = [[dictionary objectForKey:@"march_min"] floatValue];
        }else{
            self.march_used = 0.0;
        
        }
        
        
       if (![[dictionary objectForKey:@"april_min"] isKindOfClass:[NSNull class]]){
            self.april_used = [[dictionary objectForKey:@"april_min"] floatValue];
        }else{
            self.april_used = 0.0;
            
        }
        
     if (![[dictionary objectForKey:@"may_min"] isKindOfClass:[NSNull class]]){
            self.may_used = [[dictionary objectForKey:@"may_min"] floatValue];
        }else{
            self.may_used = 0.0;
            
        }
        
       if (![[dictionary objectForKey:@"june_min"] isKindOfClass:[NSNull class]]){
            self.june_used = [[dictionary objectForKey:@"june_min"] floatValue];
        }else{
            self.june_used = 0.0;
            
        }
        
      if (![[dictionary objectForKey:@"july_min"] isKindOfClass:[NSNull class]]){
            self.july_used = [[dictionary objectForKey:@"july_min"] floatValue];
        }else{
            self.july_used = 0.0;
            
        }
        
            if (![[dictionary objectForKey:@"august_min"] isKindOfClass:[NSNull class]]){
            self.august_used = [[dictionary objectForKey:@"august_min"] floatValue];
        }else{
            self.august_used = 0.0;
            
        }
        
      if (![[dictionary objectForKey:@"september_min"] isKindOfClass:[NSNull class]]){
            self.september_used = [[dictionary objectForKey:@"september_min"] floatValue];
        }else{
            self.september_used = 0.0;
            
        }
        
         if (![[dictionary objectForKey:@"october_min"] isKindOfClass:[NSNull class]]){
            self.october_used = [[dictionary objectForKey:@"october_min"] floatValue];
        }else{
            self.october_used = 0.0;
            
        }
        
         if (![[dictionary objectForKey:@"november_min"] isKindOfClass:[NSNull class]]){
            self.november_used = [[dictionary objectForKey:@"november_min"] floatValue];
        }else{
            self.november_used = 0.0;
            
        }
        
   if (![[dictionary objectForKey:@"december_min"] isKindOfClass:[NSNull class]]){
            self.december_used = [[dictionary objectForKey:@"december_min"] floatValue];
        }else{
            self.december_used = 0.0;
            
        }
    
        
       
        if ([[dictionary objectForKey:@"cortes"] description]){
        
            NSMutableArray *cortesmut = [NSMutableArray new];
        
            
            for(NSDictionary *dict in [dictionary objectForKey:@"cortes"]){
            
                Corte *corte = [[Corte alloc] initWithDictionary:dict];
                
                [cortesmut addObject:corte];
            
            }
            
            self.cortes = [NSArray arrayWithArray:cortesmut];
        }
    
       
    }
    
    return self;
}

@end
