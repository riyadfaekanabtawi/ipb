//
//  User.h
//  IPB
//
//  Created by Riyad Anabtawi on 11/28/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface User : NSObject
-(User *)initWithDictionary:(NSDictionary *)dictionary;
@property NSNumber *user_id;
@property NSString *nombre;
@property NSString *apellido;
@property NSString *device_token;
@property NSString *email;
@property NSString *avatar_url;
@property NSString *puesto;
@property NSString *telefono;
@property NSString *plant_name;

- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)aDecoder ;
@end
