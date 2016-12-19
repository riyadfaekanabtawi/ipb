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

    }
    
    return self;
}
@end
