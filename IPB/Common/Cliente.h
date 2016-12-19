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
@end
