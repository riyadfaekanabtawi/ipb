//
//  ProjectCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 2/14/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

import UIKit

protocol projectdelegateHome {
    
    func refreshFather()
}
class ProjectCollectionViewCell: UICollectionViewCell {
    
    var delegate:projectdelegateHome!
    var selectedProject:Project!
    var controller:UIViewController!
    @IBOutlet var cantidad_label: UILabel!
    @IBOutlet var precio_label: UILabel!
    @IBOutlet var total_label: UILabel!
    @IBOutlet var approvedButton:  UIButton!
    @IBOutlet var closeButton:  UIButton!
    
    @IBOutlet var user_image_profile: UIImageView!
    override func awakeFromNib() {
        self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        self.approvedButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.approvedButton.titleLabel?.font.pointSize)!)
        
        self.user_image_profile.layer.cornerRadius = 4
        self.user_image_profile.layer.masksToBounds = true
        self.cantidad_label.font = UIFont(name: FONT_REGULAR, size: self.cantidad_label.font.pointSize)
        self.precio_label.font = UIFont(name: FONT_REGULAR, size: self.precio_label.font.pointSize)
        self.total_label.font = UIFont(name: FONT_REGULAR, size: self.total_label.font.pointSize)
      
        
        self.approvedButton.layer.cornerRadius = 4
        self.approvedButton.layer.masksToBounds = true
    }
    
    
    func displayUsers(project:Project){
        self.selectedProject = project
        self.user_image_profile.sd_setImage(with: NSURL(string: BASE_URL+"\(project.photo)") as URL!)
        self.cantidad_label.text = "Cantidad: \(project.cantidad!)"
        self.precio_label.text = "Precio: $ \(project.precio!)"
        self.total_label.text = "Total: $\(project.total!)"
  
        
        
    }
    
    @IBAction func eliminarTouchUpInside(){
        
        let alertController = UIAlertController(title: "Atencion!", message: "Estas seguro que quiere eliminar este proeycto?", preferredStyle: .alert)
        
        
        
        let OKAction = UIAlertAction(title: "Si Estoy Seguro", style: .default) { (action) in
            
            Services.eliminarProyecto(self.selectedProject.project_id, andHandler: { (response) in
                
                
                
                
                
                let alertController = UIAlertController(title: "Atencion!", message: "Has eliminado el proyecto", preferredStyle: .alert)
                
                
                
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

