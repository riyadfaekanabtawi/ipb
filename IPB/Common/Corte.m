//
//  Corte.m
//  IPB
//
//  Created by Riyad Anabtawi on 1/5/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

#import "Corte.h"

@implementation Corte
-(Corte *)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    
    if (self) {
        self.cut_id = replaceNSNullValue([dictionary objectForKey:@"id"]);
        self.cut_client = replaceNSNullValue([dictionary objectForKey:@"cliente"]);
        self.cut_estilo =  replaceNSNullValue([dictionary objectForKey:@"estilo_cliente"]);
        self.cut_cantidad = replaceNSNullValue([dictionary objectForKey:@"cantidad"]);
        self.plant_id = replaceNSNullValue([dictionary objectForKey:@"plant_id"]);
      
        
        self.cut_precio_unitario = [[dictionary objectForKey:@"precio_unitario"] floatValue];
        self.corte = replaceNSNullValue([dictionary objectForKey:@"corte"]);
        self.estado = replaceNSNullValue([dictionary objectForKey:@"status"]);
        self.cut_precio_final = [[dictionary objectForKey:@"precio_final"] floatValue];
        self.cut_fecha_ipb = replaceNSNullValue([dictionary objectForKey:@"fecha_ipb"]);
        self.cut_fecha_client = replaceNSNullValue([dictionary objectForKey:@"fecha_cliente"]);
        self.cut_list = replaceNSNullValue([dictionary objectForKey:@"lista"]);
        self.prenda = replaceNSNullValue([dictionary objectForKey:@"prenda"]);
        self.editadoPor = replaceNSNullValue([dictionary objectForKey:@"editado_por"]);
        
        
        self.planta = [[Planta alloc] initWithDictionary:[dictionary objectForKey:@"plant"]];
        
        
            if (![[dictionary objectForKey:@"bodega"] isKindOfClass:[NSNull class]]){
             
                 self.bodega = [dictionary objectForKey:@"bodega"];
            }else{
                  self.bodega = @0;
            }
    
        if (![[dictionary objectForKey:@"cantidad_de_envio"] isKindOfClass:[NSNull class]]){
          
            
               self.cantidad_de_envio = [dictionary objectForKey:@"cantidad_de_envio"];
        }else{
           self.cantidad_de_envio = @0;
        }
        
        
        if (![[dictionary objectForKey:@"cantidad_enviada"] isKindOfClass:[NSNull class]]){
             self.cantidad_enviada = [dictionary objectForKey:@"cantidad_enviada"];
        }else{
            self.cantidad_enviada = @0;

        }
        
        if (![[dictionary objectForKey:@"cantidad_por_enviar"] isKindOfClass:[NSNull class]]){
           
             self.cantidad_por_enviar = [dictionary objectForKey:@"cantidad_por_enviar"];
        }else{
            self.cantidad_por_enviar = @0;
        }
        
        if (![[dictionary objectForKey:@"cantidad_real_envio"] isKindOfClass:[NSNull class]]){
            
              self.cantidad_real_envio = [dictionary objectForKey:@"cantidad_real_envio"];
        }else{
          self.cantidad_real_envio = @0;
        }
        
        if (![[dictionary objectForKey:@"en_empaque"] isKindOfClass:[NSNull class]]){
           
            
             self.en_empaque = [dictionary objectForKey:@"en_empaque"];
        }else{
            self.en_empaque = @0;
        }
        
        if (![[dictionary objectForKey:@"en_plancha"] isKindOfClass:[NSNull class]]){
           
            self.en_plancha = [dictionary objectForKey:@"en_plancha"];
        }else{
             self.en_plancha = @0;
        }
        
        if (![[dictionary objectForKey:@"faltas"] isKindOfClass:[NSNull class]]){
         
             self.faltas = [dictionary objectForKey:@"faltas"];
        }else{
              self.faltas = @0;
        }
        
        if (![[dictionary objectForKey:@"numero_de_envio"] isKindOfClass:[NSNull class]]){
          
            
             self.numero_de_envio = [dictionary objectForKey:@"numero_de_envio"];
        }else{
             self.numero_de_envio = @0;
        }
        
        if (![[dictionary objectForKey:@"operarios"] isKindOfClass:[NSNull class]]){
            
            
            self.operarios = [dictionary objectForKey:@"operarios"];
        }else{
           self.operarios = @0;
        }
        
        if (![[dictionary objectForKey:@"produciad"] isKindOfClass:[NSNull class]]){
          
            self.produciad = [dictionary objectForKey:@"produciad"];
        }else{
              self.produciad = @0;
        }
        
        
        if (![[dictionary objectForKey:@"realizadas"] isKindOfClass:[NSNull class]]){
          
              self.realizadas = [dictionary objectForKey:@"realizadas"];
        }else{
            self.realizadas = @0;
        }
        
        if (![[dictionary objectForKey:@"status"] isKindOfClass:[NSNull class]]){
         
                self.status = [dictionary objectForKey:@"status"];
        }else{
           self.status = @"";
        }
    }
    
    

    
    return self;
}
@end
