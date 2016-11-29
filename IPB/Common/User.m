//
//  User.m
//  IPB
//
//  Created by Riyad Anabtawi on 11/28/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import "User.h"

@implementation User
-(User *)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    
    if (self) {

        self.nombre = [dictionary objectForKey:@"nombre"];
        self.apellido = [dictionary objectForKey:@"apellido"];
        self.email = [dictionary objectForKey:@"email"];
        self.puesto = [dictionary objectForKey:@"puesto"];
        self.telefono = [dictionary objectForKey:@"telefono"];
        self.avatar_url = [dictionary objectForKey:@"photo"];
    }
    
    return self;
}




- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.nombre forKey:@"user_nombre"];
    [coder encodeObject:self.apellido forKey:@"user_apellido"];
    [coder encodeObject:self.email forKey:@"user_email"];
    [coder encodeObject:self.puesto forKey:@"user_puesto"];
    [coder encodeObject:self.telefono forKey:@"user_telefono"];
    [coder encodeObject:self.avatar_url forKey:@"user_avatar_url"];
    
    
}



- (id)initWithCoder:(NSCoder *)aDecoder {
    
    self.nombre = [aDecoder decodeObjectForKey:@"user_nombre"];
    self.apellido = [aDecoder decodeObjectForKey:@"user_apellido"];
    self.email = [aDecoder decodeObjectForKey:@"user_email"];
    self.puesto = [aDecoder decodeObjectForKey:@"user_puesto"];
    self.telefono = [aDecoder decodeObjectForKey:@"user_telefono"];
    self.avatar_url = [aDecoder decodeObjectForKey:@"user_avatar_url"];
    
   return self;
}
@end
