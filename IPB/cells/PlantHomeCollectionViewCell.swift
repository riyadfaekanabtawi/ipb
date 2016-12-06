//
//  PlantHomeCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/5/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class PlantHomeCollectionViewCell: UICollectionViewCell {
    @IBOutlet var plantused: UILabel!
    @IBOutlet var plantName: UILabel!
    @IBOutlet var firstWebView: UIWebView!
    override func awakeFromNib() {
        
        self.firstWebView.layer.cornerRadius = 4
        self.firstWebView.layer.masksToBounds = true
        self.plantName.font = UIFont(name: FONT_BOLD, size: self.plantName.font.pointSize)
        self.plantused.font = UIFont(name: FONT_BOLD, size: self.plantused.font.pointSize)
    }
    
    
    
    func displayPlants(plant:Planta){
        self.plantName.text = plant.planta_nombre
            self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.anabtatec-mobile.com/plants_graph?plant_id=\(plant.planta_id!)")! as URL) as URLRequest)
    
        
        
        let available = plant.planta_capacidadMax.int32Value - plant.planta_capacidadUsada.int32Value
        
        
        
        self.plantused.text = "Capacidad Disponible: \(available) $MXN"
        
        
    }
}
