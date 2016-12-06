//
//  Planta.h
//  IPB
//
//  Created by Riyad Anabtawi on 11/29/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Planta : NSObject
-(Planta *)initWithDictionary:(NSDictionary *)dictionary;
@property NSNumber *planta_id;
@property NSString *planta_nombre;

@property NSNumber *planta_capacidadMax;
@property NSNumber *planta_capacidadUsada;
@end
