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

    
    
    func showcuts(corte:Corte){
    
    self.corte_label.text = "\(corte.corte!)"
    self.cantidad_label.text = "\(corte.cut_cantidad!)"
    self.cliente_label.text = "\(corte.cut_client!)"
    
    }
}
