//
//  PlantCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/3/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class PlantCollectionViewCell: UICollectionViewCell {
    
    
    @IBOutlet var graphview: UIWebView!
    @IBOutlet var cantidad_por_asignar_textViewlabel: UITextField!
    @IBOutlet var cantidad_por_asignar_label: UILabel!
    
    
    override func awakeFromNib() {
        
        
        self.cantidad_por_asignar_label.font = UIFont(name: FONT_REGULAR, size: self.cantidad_por_asignar_label.font.pointSize)
        self.cantidad_por_asignar_textViewlabel.font = UIFont(name: FONT_REGULAR, size: self.cantidad_por_asignar_textViewlabel.font.pointSize)
        
    }
}
