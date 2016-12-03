//
//  PendingCutCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/2/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class PendingCutCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var lista_label: UILabel!
    @IBOutlet var corte_label: UILabel!
    @IBOutlet var estilo_cliente_label: UILabel!
    @IBOutlet var cantidad_label: UILabel!
    @IBOutlet var precio_total_label: UILabel!
    @IBOutlet var fecha_ipb_label: UILabel!
    @IBOutlet var fecha_cliente_label: UILabel!
    @IBOutlet var editado_por_label: UILabel!
    @IBOutlet var status_label: UILabel!
    
    
    
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
        
        
        
        self.editado_por_label.isHidden = true
    }
    
    
    
    
    
    func displayPendingCut(cut:PendingCut){
    
    
    
    self.lista_label.text = "Lista: \(cut.cut_list!)"
    self.corte_label.text = "Corte: \(cut.cut_id!)"
    self.estilo_cliente_label.text = "Estilo cliente: \(cut.cut_estilo!)"
    self.cantidad_label.text = "Cantidad: \(cut.cut_cantidad!)"
    self.precio_total_label.text = "Precio Total: \(cut.cut_precio_final!)"
    self.fecha_ipb_label.text = "Fecha IPB: \(cut.cut_fecha_ipb!)"
    self.fecha_cliente_label.text = "Fecha Cliente: \(cut.cut_fecha_client!)"
    //self.editado_por_label.text = "Editado por: \()"
    self.status_label.text = "ASIGNAR"
    
    }
}
