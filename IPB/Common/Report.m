//
//  Report.m
//  IPB
//
//  Created by Riyad Anabtawi on 12/19/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

#import "Report.h"

@implementation Report{


    NSDateFormatter *dateformatter;
}


-(Report *)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    
    if (self) {
        self.reporte_id = [dictionary objectForKey:@"id"];
        self.lista = [dictionary objectForKey:@"lista"];
        self.corte = [dictionary objectForKey:@"corte"];
        self.estilo = [dictionary objectForKey:@"estilo"];
        self.cantidad = [dictionary objectForKey:@"cantidad"];
        self.fecha_ipb = [dictionary objectForKey:@"fecha_ipb"];
        self.realizadas = [dictionary objectForKey:@"realizadas"];
        self.operarios = [dictionary objectForKey:@"operarios"];
        self.faltas = [NSNumber numberWithInteger:[[dictionary objectForKey:@"faltas"] integerValue]];
        self.produciad = [NSNumber numberWithInteger:[[dictionary objectForKey:@"produciad"] integerValue]];
        self.en_plancha = [NSNumber numberWithInteger:[[dictionary objectForKey:@"en_plancha"] integerValue]];
        self.en_empaque = [NSNumber numberWithInteger:[[dictionary objectForKey:@"en_empaque"] integerValue]];
        self.bodega = [NSNumber numberWithInteger:[[dictionary objectForKey:@"bodega"] integerValue]];
        
        
        NSString *created_at = [dictionary objectForKey:@"created_at"];
        
        
        dateformatter = [[NSDateFormatter alloc] init];
        
        dateformatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZ";
        
        
        NSDate *date = [dateformatter dateFromString:created_at];
        
        dateformatter.dateFormat = @"HH:mm";
        self.hour = [dateformatter stringFromDate:date];
        
        dateformatter.dateFormat = @"dd-MM-YYYY";
        self.dayNumbers = [dateformatter stringFromDate:date];
        
        
        dateformatter.dateFormat = @"EEEE";
        self.dayString = [dateformatter stringFromDate:date];
        
    }
    
    return self;
}




@end
