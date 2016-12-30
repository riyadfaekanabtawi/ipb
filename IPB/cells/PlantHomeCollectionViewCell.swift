//
//  PlantHomeCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/5/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit
protocol plantdelegateHome {
   
    func refreshFather()
}
class PlantHomeCollectionViewCell: UICollectionViewCell {
    @IBOutlet var plantused: UILabel!
    @IBOutlet var plantName: UILabel!
    var controller:UIViewController!
    var delegate:plantdelegateHome!
    var selectedPlant:Planta!
    @IBOutlet var firstWebView: UIWebView!
    @IBOutlet var closeButton: UIButton!
    
    override func awakeFromNib() {
        
        if self.closeButton != nil{
         self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        }
       
        self.firstWebView.layer.cornerRadius = 4
        self.firstWebView.layer.masksToBounds = true
        self.plantName.font = UIFont(name: FONT_BOLD, size: self.plantName.font.pointSize)
        self.plantused.font = UIFont(name: FONT_BOLD, size: self.plantused.font.pointSize)
    }
    
    
    
    func displayPlants(plant:Planta){
        
        self.selectedPlant = plant
        self.plantName.text = plant.planta_nombre
            self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.anabtatec-mobile.com/plants_graph?plant_id=\(plant.planta_id!)")! as URL) as URLRequest)
    
        
        
        
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        
    
        
        let available = plant.planta_capacidadMax.int32Value - plant.planta_capacidadUsada.int32Value
        
        
        
        
        let resultavailable = formatter.string(from: NSNumber(value:Int(available)))
        
        
        self.plantused.text = "Capacidad Disponible: \(resultavailable!) $MXN"
        
        
    }
    
    
    
  
    @IBAction func eliminarTouchUpInside(){
        
        let alertController = UIAlertController(title: "Atencion!", message: "Estas seguro que quiere eliminar esta planta?", preferredStyle: .alert)
        
        
        
        let OKAction = UIAlertAction(title: "Si Estoy Seguro", style: .default) { (action) in
            
            Services.eliminarPlanta(self.selectedPlant.planta_id, andHandler: { (response) in
                
                
                
                
                
                let alertController = UIAlertController(title: "Atencion!", message: "Has eliminado la planta", preferredStyle: .alert)
                
                
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    
                    
                }
                alertController.addAction(OKAction)
                
                self.controller.present(alertController, animated: true) {
                    // ...
                }
                
                
                self.delegate.refreshFather()
            }, orErrorHandler: { (err) in
                
                
            })
        }
        
        let cancelarAction = UIAlertAction(title: "Cancelar", style: .default) { (action) in
            
            
        }
        alertController.addAction(OKAction)
        alertController.addAction(cancelarAction)
     
        
        self.controller.present(alertController, animated: true) {
            // ...
        }
        
        
        
        
        
    }

}
