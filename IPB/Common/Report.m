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
        self.faltas = [dictionary objectForKey:@"faltas"];
        self.produciad = [dictionary objectForKey:@"produciad"];
        self.en_plancha = [dictionary objectForKey:@"en_plancha"];
        self.en_empaque = [dictionary objectForKey:@"en_empaque"];
        self.bodega = [dictionary objectForKey:@"bodega"];
        
        
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
        self.status_report = [dictionary objectForKey:@"status"];
        self.type_report = [dictionary objectForKey:@"tipo"];
        self.cantidad_de_envio = [dictionary objectForKey:@"cantidad_de_envio"];
        self.numero_de_envio = [dictionary objectForKey:@"numero_de_envio"];
        self.cantidad_por_enviar = [dictionary objectForKey:@"cantidad_por_enviar"];
        self.cantidad_enviada = [dictionary objectForKey:@"cantidad_enviada"];
        self.cantidad_real_envio = [dictionary objectForKey:@"cantidad_real_envio"];
        
        self.cut_name = [dictionary objectForKey:@"cut_name"];
    }
    
    return self;
}




@end
