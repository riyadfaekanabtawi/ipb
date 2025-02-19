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

@property NSArray *cortes;

@property float january_used;
@property float febuary_used;
@property float march_used;
@property float april_used;
@property float may_used;
@property float june_used;
@property float july_used;
@property float august_used;
@property float september_used;
@property float october_used;
@property float november_used;
@property float december_used;

@end
