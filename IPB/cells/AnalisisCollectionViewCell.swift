//
//  AnalisisCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 1/17/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

import UIKit

class AnalisisCollectionViewCell: UICollectionViewCell {
    
    
    @IBOutlet var corte_label: UILabel!
    @IBOutlet var cantidad_label: UILabel!
    @IBOutlet var cliente_label: UILabel!
    @IBOutlet var cortadas_label: UILabel!
    
    @IBOutlet var statusView: UIView!
    override func awakeFromNib() {
        
        
        self.corte_label.font = UIFont(name: FONT_REGULAR, size: self.corte_label.font.pointSize)
        self.cantidad_label.font = UIFont(name: FONT_REGULAR, size: self.cantidad_label.font.pointSize)
        self.cliente_label.font = UIFont(name: FONT_REGULAR, size: self.cliente_label.font.pointSize)
        self.cortadas_label.font = UIFont(name: FONT_REGULAR, size: self.cortadas_label.font.pointSize)
        
        
        self.statusView.layer.cornerRadius = self.statusView.frame.size.width/2
        self.statusView.clipsToBounds = true
    }
    
    
    
   func displayAnalisisCuts(cuts:Corte){
    
    self.corte_label.text = cuts.corte!
    self.cliente_label.text = cuts.cut_client!
    self.cortadas_label.text = "\(cuts.cantidad_real_envio!)"
    self.cantidad_label.text = "\(cuts.cut_cantidad!)"
    
    
    if cuts.status.lowercased() == "en espera"{
    self.statusView.alpha = 1
    
      self.statusView.backgroundColor = Functions.color(withHexString: "FF3B27", andAlpha: 1)
    }
    
    if cuts.status.lowercased() == "en mesa de corte"{
            self.statusView.alpha = 1
        self.statusView.backgroundColor = Functions.color(withHexString: "FFF53C", andAlpha: 1)
        
    }
    
    if cuts.status.lowercased() == "listo para confeccionar"{
            self.statusView.alpha = 1
        self.statusView.backgroundColor = Functions.color(withHexString: "5FBA56", andAlpha: 1)
        
    }

}
}
