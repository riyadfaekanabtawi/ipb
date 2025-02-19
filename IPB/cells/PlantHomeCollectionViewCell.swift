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
        if(self.firstWebView != nil){
        self.firstWebView.layer.cornerRadius = 4
        self.firstWebView.layer.masksToBounds = true
        }
        self.plantName.font = UIFont(name: FONT_REGULAR, size: self.plantName.font.pointSize)
        
        if self.plantused != nil{
        self.plantused.font = UIFont(name: FONT_REGULAR, size: self.plantused.font.pointSize)
        }
    }
    
    
    func displayMonths(month:String){
    
      self.plantName.text = month
        
        
        if (month == "Enero"){
            self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=january_min")! as URL) as URLRequest)
            
            
        }
        
        if (month == "Febrero"){
                self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=febuary_min")! as URL) as URLRequest)
        }
        
        if (month == "Marzo"){
                self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=march_min")! as URL) as URLRequest)
        }
        
        if (month == "Abril"){
                self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=april_min")! as URL) as URLRequest)
        }
        
        if (month == "Mayo"){
                self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=may_min")! as URL) as URLRequest)
        }
        
        if (month == "Junio"){
                self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=june_min")! as URL) as URLRequest)
        }
        
        if (month == "Julio"){
                self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=july_min")! as URL) as URLRequest)
        }
        
        if (month == "Agosto"){
                self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=august_min")! as URL) as URLRequest)
        }
        
        if (month == "Septiembre"){
                self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=september_min")! as URL) as URLRequest)
        }
        
        if (month == "Octubre"){
                self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=october_min")! as URL) as URLRequest)
        }
        
        if (month == "Noviembre"){
                self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=november_min")! as URL) as URLRequest)
        }
        
        if (month == "Diciembre"){
            
                self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?month=december_min")! as URL) as URLRequest)
        }
    }
    func displayPlants(plant:Planta){
        
        self.selectedPlant = plant
        self.plantName.text = plant.planta_nombre
        
         if(self.firstWebView != nil){
            self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.railsplayground.net/plants_graph?plant_id=\(plant.planta_id!)")! as URL) as URLRequest)
    
        }
        
        
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        
    
        
        let available = plant.planta_capacidadMax.int32Value
        
        
         if self.plantused != nil{
        let resultavailable = formatter.string(from: NSNumber(value:Int(available)))
        
        
        self.plantused.text = "Capacidad Máxima: $ \(resultavailable!)"
        }
        
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
