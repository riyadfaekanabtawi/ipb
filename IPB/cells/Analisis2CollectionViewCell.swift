//
//  Analisis2CollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 2/14/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

import UIKit

class Analisis2CollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var corte_label: UILabel!
    @IBOutlet var cantidad_label: UILabel!
    @IBOutlet var cliente_label: UILabel!

    @IBOutlet var cortadas_label: UILabel!
    override func awakeFromNib() {
        self.cliente_label.font = UIFont(name: FONT_REGULAR, size: self.cliente_label.font.pointSize)
        self.cantidad_label.font = UIFont(name: FONT_REGULAR, size: self.cantidad_label.font.pointSize)
        self.corte_label.font = UIFont(name: FONT_REGULAR, size: self.corte_label.font.pointSize)
        if (self.cortadas_label != nil){
        self.cortadas_label.font = UIFont(name: FONT_REGULAR, size: self.cortadas_label.font.pointSize)
            
        }
    }
    func showcuts(corte:Corte){
    
    self.corte_label.text = "\(corte.corte!)"
    self.cantidad_label.text = "\(corte.cut_cantidad!)"
    self.cliente_label.text = "\(corte.cut_client!)"
        
        if (self.cortadas_label != nil){
         
            self.cortadas_label.text = "\(corte.cantidad_real_envio!)"
        }
    
    }
}
