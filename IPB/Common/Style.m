//
//  Style.m
//  IPB
//
//  Created by Riyad Anabtawi on 12/13/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import "Style.h"

@implementation Styles



-(Styles *)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    
    if (self) {
        self.style_name = [dictionary objectForKey:@"name"];
        self.style_id = [dictionary objectForKey:@"id"];
        self.style_image = [NSString stringWithFormat:@"%@%@",BASE_URL,[dictionary objectForKey:@"photo"]];
    }
    
    return self;
}
@end
