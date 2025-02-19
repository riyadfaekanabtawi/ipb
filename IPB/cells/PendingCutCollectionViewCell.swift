//
//  PendingCutCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/2/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit
protocol pendingCutdelegate {
    func showImage(image:String)
    
}
class PendingCutCollectionViewCell: UICollectionViewCell {
    var delegate:pendingCutdelegate!
    @IBOutlet var lista_label: UILabel!
    @IBOutlet var corte_label: UILabel!
    @IBOutlet var status_view: UIView!
    @IBOutlet var plantaLabel: UILabel!
    @IBOutlet var estilo_cliente_label: UILabel!
    @IBOutlet var cantidad_label: UILabel!
    @IBOutlet var precio_total_label: UILabel!
    @IBOutlet var fecha_ipb_label: UILabel!
    @IBOutlet var fecha_cliente_label: UILabel!
   
    @IBOutlet var status_label: UILabel!
    @IBOutlet var prenda_label: UILabel!
    @IBOutlet var style_iamge: UIImageView!
    @IBOutlet var ingreso_label: UILabel!
    @IBOutlet var prendas_producidas: UILabel!
    @IBOutlet var prendas_enviadas: UILabel!
    
    
    
    @IBOutlet var enPlancha: UILabel!
    @IBOutlet var enEmpaque: UILabel!
    @IBOutlet var enBodega: UILabel!
    @IBOutlet var prendasPorenviar: UILabel!
    @IBOutlet var cantidadRealcorte: UILabel!
    
    @IBOutlet var client_label: UILabel!
    var stringImage:String!
    override func awakeFromNib() {
    
        if self.enPlancha != nil{
            
            self.enPlancha.font = UIFont(name: FONT_REGULAR, size: self.enPlancha.font.pointSize)
        }
        if self.enEmpaque != nil{
            
            self.enEmpaque.font = UIFont(name: FONT_REGULAR, size: self.enEmpaque.font.pointSize)
        }
        if self.enBodega != nil{
            
            self.enBodega.font = UIFont(name: FONT_REGULAR, size: self.enBodega.font.pointSize)
        }
        if self.prendasPorenviar != nil{
            
            self.prendasPorenviar.font = UIFont(name: FONT_REGULAR, size: self.prendasPorenviar.font.pointSize)
        }
        if self.cantidadRealcorte != nil{
            
            self.cantidadRealcorte.font = UIFont(name: FONT_REGULAR, size: self.cantidadRealcorte.font.pointSize)
        }
        
        if self.status_view != nil{
        
            self.status_view.layer.cornerRadius = self.status_view.frame.size.width/2
            self.status_view.clipsToBounds = true
        
        
        
        }
        if self.plantaLabel != nil{
        
         self.plantaLabel.font = UIFont(name: FONT_REGULAR, size: self.plantaLabel.font.pointSize)
        }
        
        if self.prendas_enviadas != nil{
            
            self.prendas_enviadas.font = UIFont(name: FONT_REGULAR, size: self.prendas_enviadas.font.pointSize)
        }
        
        if self.prendas_producidas != nil{
            
            self.prendas_producidas.font = UIFont(name: FONT_REGULAR, size: self.prendas_producidas.font.pointSize)
        }
        self.client_label.font = UIFont(name: FONT_REGULAR, size: self.client_label.font.pointSize)
         if self.lista_label != nil{
        self.lista_label.font = UIFont(name: FONT_REGULAR, size: self.lista_label.font.pointSize)
        }
        self.corte_label.font = UIFont(name: FONT_REGULAR, size: self.corte_label.font.pointSize)
        
        if self.estilo_cliente_label != nil{
        
        self.estilo_cliente_label.font = UIFont(name: FONT_REGULAR, size: self.estilo_cliente_label.font.pointSize)
        }
        
        self.cantidad_label.font = UIFont(name: FONT_REGULAR, size: self.cantidad_label.font.pointSize)
        
        if self.precio_total_label != nil{
        self.precio_total_label.font = UIFont(name: FONT_REGULAR, size: self.precio_total_label.font.pointSize)
        
        }
        
        self.fecha_ipb_label.font = UIFont(name: FONT_REGULAR, size: self.fecha_ipb_label.font.pointSize)
        self.fecha_cliente_label.font = UIFont(name: FONT_REGULAR, size: self.fecha_cliente_label.font.pointSize)
       // self.editado_por_label.font = UIFont(name: FONT_REGULAR, size: self.editado_por_label.font.pointSize)
        
        if self.status_label != nil{
          self.status_label.font = UIFont(name: FONT_REGULAR, size: self.status_label.font.pointSize)
        
        }
      
        
         self.prenda_label.font = UIFont(name: FONT_REGULAR, size: self.prenda_label.font.pointSize)
       
        if self.ingreso_label != nil{
         self.ingreso_label.font = UIFont(name: FONT_REGULAR, size: self.ingreso_label.font.pointSize)
        }
       // self.editado_por_label.isHidden = true
    }
    
    
    
    
    
    func displayPendingCut(cut:PendingCut){
        
   
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

      
        
        let ingreso = cut.cut_cantidad.floatValue * cut.cut_precio_unitario
        let resultIngreso = formatter.string(from: NSNumber(value:Float32(ingreso)))
        
        
         let resultCantidad = formatter.string(from: NSNumber(value:Int(cut.cut_cantidad.intValue)))
        self.client_label.text = "\(cut.cut_client!)"
        
        if self.ingreso_label != nil{
        
          self.ingreso_label.text = "Ingresos: $\(resultIngreso!)"
        }
      
        
        self.prenda_label.text = "\(cut.prenda!)"
         if self.lista_label != nil{
        self.lista_label.text = "Lista: \(cut.cut_list!)"
        }
        self.corte_label.text = "Corte: \(cut.corte!)"
        
        if self.estilo_cliente_label != nil{
         self.estilo_cliente_label.text = "Estilo cliente: \(cut.cut_estilo!)"
        }
       
        self.cantidad_label.text = "Cantidad \(resultCantidad!)"
        
         if self.precio_total_label != nil{
            
             self.precio_total_label.text = "Precio/U: $\(cut.cut_precio_unitario)"
            
        }
       
        self.fecha_ipb_label.text = "Fecha IPB \(cut.cut_fecha_ipb!)"
        self.fecha_cliente_label.text = "Fecha Cliente \(cut.cut_fecha_client!)"
        //self.editado_por_label.text = "Editado por: \()"
        
        if self.status_label != nil{
        
        self.status_label.text = "ASIGNAR"
        }
    Services.getStyleImage(cut.cut_estilo!, andHandler: { (response) in
        
        
        if (self.style_iamge != nil){
            
            self.style_iamge.sd_setImage(with: NSURL(string:"\(BASE_URL)\(response as! String)") as URL!)
            
            self.stringImage = "\(BASE_URL)\(response as! String)"
            
        }
        
    }, orErrorHandler: { (err) in
    
    
    
    })
//
  
        
    }
    
    
     @IBAction func showImageTouchUpInside(){
        
        self.delegate.showImage(image: self.stringImage)
    }
    
    
    
    func displayCorte(cut:Corte){
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        
        if self.enPlancha != nil{
            
            self.enPlancha.text = "En Plancha \(cut.en_plancha!)"
        }
        
        
        if self.enEmpaque != nil{
            
            self.enEmpaque.text = "En Empaque \(cut.en_empaque!)"
        }
        
        
        if self.enBodega != nil{
            
            self.enBodega.text = "En Bodega \(cut.bodega!)"
        }
        
        
        if self.prendasPorenviar != nil{
            
            self.prendasPorenviar.text = "Prendas Por Enviar \(cut.cantidad_por_enviar!)"
        }
        
        
        if self.cantidadRealcorte != nil{
            
            self.cantidadRealcorte.text = "Cantidad Real del Corte \(cut.cantidad_real_envio!)"
        }
        
        
        
        if self.prendas_enviadas != nil{
              let resultIngreso = formatter.string(from: NSNumber(value:Float32(cut.cantidad_enviada)))
            self.prendas_enviadas.text = "Prendas Enviadas \(resultIngreso!)"
        }
        
        if self.prendas_producidas != nil{
            
             let resultIngreso = formatter.string(from: NSNumber(value:Float32(cut.produciad)))
            
           self.prendas_producidas.text = "Prendas producidas \(resultIngreso!)"
        }
        
        
        
    
        
         if self.status_view != nil{
            
            if cut.status.lowercased() == "en espera"{
                
                self.status_label.text = cut.status!
                self.status_view.backgroundColor = Functions.color(withHexString: "FF3B27", andAlpha: 1)
            }
            
            if cut.status.lowercased() == "en mesa de corte"{
                
                self.status_view.backgroundColor = Functions.color(withHexString: "FFF53C", andAlpha: 1)
                self.status_label.text = cut.status!
            }
            
            if cut.status.lowercased() == "listo para confeccionar"{
                
                self.status_view.backgroundColor = Functions.color(withHexString: "5FBA56", andAlpha: 1)
              self.status_label.text = cut.status!
            }else{
            
               self.status_label.text = cut.status!.lowercased()
            }
        }
        
  
        
        if self.plantaLabel != nil{
            if cut.planta.planta_nombre != nil{
              self.plantaLabel.text = "\(cut.planta.planta_nombre!)"
            }else{
         
                Services.getPlantName(cut.plant_id, andHandler: { (response) in
                    
                    let string = response as? String
                    self.plantaLabel.text = string!
                }, orErrorHandler: { (err) in
                    
                })
            
            }
      
        }
        let ingreso = cut.cut_cantidad.floatValue * cut.cut_precio_unitario
   
        
        
        let resultCantidad = formatter.string(from: NSNumber(value:Int(cut.cut_cantidad.intValue)))
    
        
        
        let resultIngreso = formatter.string(from: NSNumber(value:Int(ingreso)))
        
        if self.ingreso_label != nil{
        self.ingreso_label.text = "Ingresos $\(resultIngreso!)"
        }
        
        self.prenda_label.text = "\(cut.prenda!)"
        if self.lista_label != nil{
        self.lista_label.text = "Lista: \(cut.cut_list!)"
        }
        
        self.corte_label.text = "Corte: \(cut.corte!)"
        
        if self.estilo_cliente_label != nil{
        self.estilo_cliente_label.text = "\(cut.cut_estilo!)"
        }
        
        self.cantidad_label.text = "Cantidad: \(resultCantidad!)"
        
        if self.precio_total_label != nil{
        self.precio_total_label.text = "Precio/U: $\(cut.cut_precio_unitario)"
        
        }
        
        self.fecha_ipb_label.text = "Fecha IPB \(cut.cut_fecha_ipb!)"
        self.fecha_cliente_label.text = "Fecha Cliente \(cut.cut_fecha_client!)"
        //self.editado_por_label.text = "Editado por: \()"
        self.client_label.text = cut.cut_client!
        
        
        
        Services.getStyleImage(cut.cut_estilo!, andHandler: { (response) in
            
            if (self.style_iamge != nil){
                
                self.style_iamge.sd_setImage(with: NSURL(string:"\(BASE_URL)\(response as! String)") as URL!)
                
                self.stringImage = "\(BASE_URL)\(response as! String)"
            
            }
      
            
            
        }, orErrorHandler: { (err) in
            
            
            
        })
        
        
        
    }

    
    
    
}
