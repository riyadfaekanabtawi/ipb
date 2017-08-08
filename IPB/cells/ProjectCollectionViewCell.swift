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
    @IBOutlet var fecha_entrega_label: UILabel!
    @IBOutlet var nota_label: UILabel!
    @IBOutlet var cliente_label: UILabel!
    @IBOutlet var minutaje_label: UILabel!
    @IBOutlet var tela_label: UILabel!
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
        
        self.approvedButton.backgroundColor = Functions.color(withHexString: "AAAAAA", andAlpha: 1)
        self.approvedButton.setTitle("Pendiente", for: UIControlState.normal)
    }
    
    
    func displayUsers(project:Project){
        self.selectedProject = project
        let strings = BASE_URL+"\(project.photo!)"
        self.user_image_profile.sd_setImage(with: NSURL(string:strings) as URL!)
        self.cantidad_label.text = "Cantidad: \(project.cantidad!)"
        self.precio_label.text = "Precio: $ \(project.precio!)"
        self.total_label.text = "Total: $\(project.total!)"
  
        self.cliente_label.text = "Cliente: \(project.cliente!)"
        self.minutaje_label.text = "Minutaje: \(project.minutaje!)"
        self.tela_label.text = "Tela: \(project.tela!)"
       // self.nota_label.text = "Notas: \(project.notas)"
        self.fecha_entrega_label.text = "Fecha de Entrega: \(project.fecha_entrega!)"
        if project.status == "pendiente"{
        
            self.approvedButton.backgroundColor = Functions.color(withHexString: "AAAAAA", andAlpha: 1)
            self.approvedButton.setTitle("Pendiente", for: UIControlState.normal)
            
        }
        
        if project.status == "aceptado"{
            self.approvedButton.backgroundColor = Functions.color(withHexString: "4AAC54", andAlpha: 1)
            self.approvedButton.setTitle("Aceptado", for: UIControlState.normal)
        
        }
        
        if project.status == "declinado"{
            self.approvedButton.backgroundColor = Functions.color(withHexString: "F44336", andAlpha: 1)
            self.approvedButton.setTitle("Declinado", for: UIControlState.normal)
            
        }
        
    }
    
    
    
     @IBAction func changeStatusTouchUpInside(){
        
        let alertController = UIAlertController(title: "Atencion!", message: "Que status tendrá el proyecto?", preferredStyle: .alert)
        
        
        
        let aceptado = UIAlertAction(title: "Aceptado", style: .default) { (action) in
            
            Services.updateProject(self.selectedProject.project_id, andStatus: "aceptado", andHandler: { (response) in
                
                let alertController = UIAlertController(title: "Bien!", message: "Actualizaste el status del proyecto", preferredStyle: .alert)
                
                
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    
                    
                }
                alertController.addAction(OKAction)
                self.delegate.refreshFather()
                self.controller.present(alertController, animated: true) {
                    // ...
                }

                self.approvedButton.backgroundColor = Functions.color(withHexString: "4AAC54", andAlpha: 1)
                self.approvedButton.setTitle("Aceptado", for: UIControlState.normal)

            }, orErrorHandler: { (err) in
                
                
            })
            
        
        }
        alertController.addAction(aceptado)
        
        
        let declinado = UIAlertAction(title: "Declinado", style: .default) { (action) in
            
            Services.updateProject(self.selectedProject.project_id, andStatus: "declinado", andHandler: { (response) in
                
                let alertController = UIAlertController(title: "Bien!", message: "Actualizaste el status del proyecto", preferredStyle: .alert)
                
                
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    
                    
                }
                alertController.addAction(OKAction)
                self.delegate.refreshFather()
                self.controller.present(alertController, animated: true) {
                    // ...
                }
                self.approvedButton.backgroundColor = Functions.color(withHexString: "F44336", andAlpha: 1)
                self.approvedButton.setTitle("Declinado", for: UIControlState.normal)
                
            }, orErrorHandler: { (err) in
                
                
            })
            
            
           
        }
        alertController.addAction(declinado)
        
        
        let Pendiente = UIAlertAction(title: "Pendiente", style: .default) { (action) in
            
            Services.updateProject(self.selectedProject.project_id, andStatus: "pendiente", andHandler: { (response) in
                
                let alertController = UIAlertController(title: "Bien!", message: "Actualizaste el status del proyecto", preferredStyle: .alert)
                
                
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    
                    
                }
                alertController.addAction(OKAction)
                self.delegate.refreshFather()
                self.controller.present(alertController, animated: true) {
                    // ...
                }
                self.approvedButton.backgroundColor = Functions.color(withHexString: "AAAAAA", andAlpha: 1)
                self.approvedButton.setTitle("Pendiente", for: UIControlState.normal)
                
            }, orErrorHandler: { (err) in
                
                
            })
            
          
            
        }
        alertController.addAction(Pendiente)
        
        
        let Cancelar = UIAlertAction(title: "Cancelar", style: .default) { (action) in
            
            
        }
        alertController.addAction(Cancelar)
        
        
        
    
        
        self.controller.present(alertController, animated: true) {
            // ...
        }

        
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

