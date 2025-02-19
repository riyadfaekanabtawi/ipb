//
//  Style.h
//  IPB
//
//  Created by Riyad Anabtawi on 12/13/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Styles : NSObject




-(Styles *)initWithDictionary:(NSDictionary *)dictionary;
@property NSNumber *style_id;
@property NSString *style_name;
@property NSString *style_image;

@property NSArray *plants_array;
@end
