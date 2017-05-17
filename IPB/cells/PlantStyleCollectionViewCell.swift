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
    
    var plantsArray:[Planta] = []
    override func awakeFromNib() {
        self.plant_label.font = UIFont(name: FONT_BOLD, size: self.plant_label.font.pointSize)
    
    }
    
    func showcuts(counts:[String:Int]){
        

        if (counts.description != "[:]"){
        
            
            var stringArray = [""]
            for (key, value) in counts {
                
                
                for plant in self.plantsArray{
                
                    if (plant.planta_id.stringValue == key){
                    
                      stringArray.append("\(plant.planta_nombre!) : \(value)")
                    
                    }
                
                
                }
              
            
            

            }
            
                self.plant_label.text = stringArray.joined(separator: ", ").replacingOccurrences(of: ",", with: " ")
            
        }else{
           self.plant_label.text = "Estilo no asignado a planta"
        
        }
 
    
        
    }
}
