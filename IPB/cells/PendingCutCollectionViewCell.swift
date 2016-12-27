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
    @IBOutlet var estilo_cliente_label: UILabel!
    @IBOutlet var cantidad_label: UILabel!
    @IBOutlet var precio_total_label: UILabel!
    @IBOutlet var fecha_ipb_label: UILabel!
    @IBOutlet var fecha_cliente_label: UILabel!
    @IBOutlet var editado_por_label: UILabel!
    @IBOutlet var status_label: UILabel!
    @IBOutlet var prenda_label: UILabel!
    @IBOutlet var style_iamge: UIImageView!
    @IBOutlet var ingreso_label: UILabel!
    var stringImage:String!
    override func awakeFromNib() {
    
        
        self.lista_label.font = UIFont(name: FONT_REGULAR, size: self.lista_label.font.pointSize)
        self.corte_label.font = UIFont(name: FONT_REGULAR, size: self.corte_label.font.pointSize)
        self.estilo_cliente_label.font = UIFont(name: FONT_REGULAR, size: self.estilo_cliente_label.font.pointSize)
        self.cantidad_label.font = UIFont(name: FONT_REGULAR, size: self.cantidad_label.font.pointSize)
        self.precio_total_label.font = UIFont(name: FONT_REGULAR, size: self.precio_total_label.font.pointSize)
        self.fecha_ipb_label.font = UIFont(name: FONT_REGULAR, size: self.fecha_ipb_label.font.pointSize)
        self.fecha_cliente_label.font = UIFont(name: FONT_REGULAR, size: self.fecha_cliente_label.font.pointSize)
        self.editado_por_label.font = UIFont(name: FONT_REGULAR, size: self.editado_por_label.font.pointSize)
        self.status_label.font = UIFont(name: FONT_BOLD, size: self.status_label.font.pointSize)
        
         self.prenda_label.font = UIFont(name: FONT_REGULAR, size: self.prenda_label.font.pointSize)
        self.ingreso_label.font = UIFont(name: FONT_REGULAR, size: self.ingreso_label.font.pointSize)
        
        self.editado_por_label.isHidden = true
    }
    
    
    
    
    
    func displayPendingCut(cut:PendingCut){
        
        
   
        let ingreso = cut.cut_cantidad.int32Value * cut.cut_precio_unitario.int32Value
        
   
        self.ingreso_label.text = "Ingresos: \(ingreso) $MXN"
        self.prenda_label.text = "Prenda: \(cut.prenda!)"
        self.lista_label.text = "Lista: \(cut.cut_list!)"
        self.corte_label.text = "Corte: \(cut.cut_id!)"
        self.estilo_cliente_label.text = "Estilo cliente: \(cut.cut_estilo!)"
        self.cantidad_label.text = "Cantidad: \(cut.cut_cantidad!)"
        self.precio_total_label.text = "Precio Unitario: \(cut.cut_precio_unitario!)"
        self.fecha_ipb_label.text = "Fecha IPB: \(cut.cut_fecha_ipb!)"
        self.fecha_cliente_label.text = "Fecha Cliente: \(cut.cut_fecha_client!)"
        //self.editado_por_label.text = "Editado por: \()"
        self.status_label.text = "ASIGNAR"
        
    Services.getStyleImage(cut.cut_estilo!, andHandler: { (response) in
        
        
        
               self.style_iamge.sd_setImage(with: NSURL(string:"\(BASE_URL)\(response as! String)") as URL!)
        
        self.stringImage = "\(BASE_URL)\(response as! String)"
        

    }, orErrorHandler: { (err) in
    
    
    
    })
    
  
        
    }
    
    
     @IBAction func showImageTouchUpInside(){
        
        self.delegate.showImage(image: self.stringImage)
    }
}
