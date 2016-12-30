//
//  Cliente.h
//  IPB
//
//  Created by Riyad Anabtawi on 12/12/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Cliente : NSObject
-(Cliente *)initWithDictionary:(NSDictionary *)dictionary;
@property NSNumber *client_id;
@property NSString *client_name;

@property NSString *nombrecontacto1;
@property NSString *nombrecontacto2;
@property NSString *nombrecontacto3;
@property NSString *emailcontacto1;
@property NSString *emailcontacto2;
@property NSString *emailcontacto3;
@property NSString *telefonocontacto1;
@property NSString *telefonocontacto2;
@property NSString *telefonocontacto3;


@property NSString *puestocontacto1;
@property NSString *puestocontacto2;
@property NSString *puestocontacto3;


@end
