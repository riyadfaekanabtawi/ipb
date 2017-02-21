//
//  PlantStyleCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 2/17/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

import UIKit

class PlantStyleCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var plant_label: UILabel!
    
    override func awakeFromNib() {
        self.plant_label.font = UIFont(name: FONT_REGULAR, size: self.plant_label.font.pointSize)
    
    }
    
    func showcuts(corte:NSDictionary){
        
        self.plant_label.text = "\(corte.object(forKey: "plant")!): \(corte.object(forKey: "count")!)"
    
        
    }
}
