//
//  Project.h
//  IPB
//
//  Created by Riyad Anabtawi on 2/14/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Project : NSObject
-(Project *)initWithDictionary:(NSDictionary *)dictionary;
@property NSNumber *project_id;
@property NSString *cantidad;
@property NSString *precio;
@property NSString *total;
@property NSString *cliente;
@property NSString *status;
@property NSString *fecha_entrega;
@property NSString *tela;
@property NSString *minutaje;
@property NSString *photo;
@end
