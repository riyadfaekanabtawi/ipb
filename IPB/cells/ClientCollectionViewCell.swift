//
//  ClientCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/12/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//
import MessageUI
import UIKit
protocol clientdelegateHome {
    func sendemail(client:Cliente)
    func sendemailP(client:Proveedores)
    func refreshFather()
}
class ClientCollectionViewCell: UICollectionViewCell {
    
    var delegate:clientdelegateHome!
    
    var controller:UIViewController!
    @IBOutlet var client_nameLabel: UILabel!
    @IBOutlet var mainView: UIView!
    var selectedClient:Cliente!
    var selectedProveedor:Proveedores!
    @IBOutlet var closeButton: UIButton!
    
    
   // @IBOutlet var giro_label: UILabel!
    @IBOutlet var direccion_label: UILabel!
    @IBOutlet var nombre1_label: UILabel!
    @IBOutlet var nombre2_label: UILabel!
    @IBOutlet var nombre3_label: UILabel!
    
    @IBOutlet var puesto1_label: UILabel!
    @IBOutlet var puesto2_label: UILabel!
    @IBOutlet var puesto3_label: UILabel!
    
    
    @IBOutlet var email1_label: UILabel!
    @IBOutlet var email2_label: UILabel!
    @IBOutlet var email3_label: UILabel!
    
    
    @IBOutlet var telefono1_label: UILabel!
    @IBOutlet var telefono2_label: UILabel!
    @IBOutlet var telefono3_label: UILabel!
    
    override func awakeFromNib() {
           self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        self.client_nameLabel.font = UIFont(name: FONT_MEDIUM, size: self.client_nameLabel.font.pointSize)
        self.mainView.layer.cornerRadius = 4
        self.mainView.layer.masksToBounds = true
        
        //self.giro_label.font = UIFont(name: FONT_REGULAR, size: self.giro_label.font.pointSize)
        self.direccion_label.font = UIFont(name: FONT_MEDIUM, size: self.direccion_label.font.pointSize)
        self.nombre1_label.font = UIFont(name: FONT_REGULAR, size: self.nombre1_label.font.pointSize)
        self.nombre3_label.font = UIFont(name: FONT_REGULAR, size: self.nombre3_label.font.pointSize)
        self.nombre2_label.font = UIFont(name: FONT_REGULAR, size: self.nombre2_label.font.pointSize)
        self.puesto1_label.font = UIFont(name: FONT_REGULAR, size: self.puesto1_label.font.pointSize)
        self.puesto2_label.font = UIFont(name: FONT_REGULAR, size: self.puesto2_label.font.pointSize)
        self.puesto3_label.font = UIFont(name: FONT_REGULAR, size: self.puesto3_label.font.pointSize)
        self.email1_label.font = UIFont(name: FONT_REGULAR, size: self.email1_label.font.pointSize)
        self.email2_label.font = UIFont(name: FONT_REGULAR, size: self.email2_label.font.pointSize)
        self.email3_label.font = UIFont(name: FONT_REGULAR, size: self.email3_label.font.pointSize)
        self.telefono1_label.font = UIFont(name: FONT_REGULAR, size: self.telefono1_label.font.pointSize)
        self.telefono2_label.font = UIFont(name: FONT_REGULAR, size: self.telefono2_label.font.pointSize)
        self.telefono3_label.font = UIFont(name: FONT_MEDIUM, size: self.telefono3_label.font.pointSize)
    }
    
    
    func displayClient(client:Cliente){
    
    self.selectedClient = client
    self.client_nameLabel.text = client.client_name
        
   
    
        if(client.direccion != nil){
            
           self.direccion_label.text = "Dirección: \(client.direccion!)"
        }
   
        
        if(client.nombrecontacto1 != nil){
        
         self.nombre1_label.text = client.nombrecontacto1!
        }
   
        if(client.nombrecontacto2 != nil){
            
            self.nombre2_label.text = client.nombrecontacto2!
        }
        
        if(client.nombrecontacto3 != nil){
            
             self.nombre3_label.text = client.nombrecontacto3!
        }
        if(client.puestocontacto1 != nil){
            
            self.puesto1_label.text = client.puestocontacto1!
        }
        
        if(client.puestocontacto2 != nil){
            
             self.puesto2_label.text = client.puestocontacto2!
        }
    
        if(client.puestocontacto3 != nil){
            
            self.puesto3_label.text = client.puestocontacto3!
        }
        
        if(client.emailcontacto1 != nil){
            
            self.email1_label.text = client.emailcontacto1!
        }
 
        if(client.emailcontacto2 != nil){
            
            self.email2_label.text = client.emailcontacto2!
        }
        
        if(client.emailcontacto3 != nil){
            
            self.email3_label.text = client.emailcontacto3!
        }
        
        if(client.telefonocontacto1 != nil){
            
            self.telefono1_label.text = client.telefonocontacto1!
        }
        if(client.telefonocontacto2 != nil){
            
            self.telefono2_label.text = client.telefonocontacto2!
        }
        
        if(client.telefonocontacto3 != nil){
            
            self.telefono3_label.text = client.telefonocontacto3!
        }
   
    
    }
    
    func displayProveedor(client:Proveedores){
        
        self.selectedProveedor = client
        self.client_nameLabel.text = client.client_name
    }
    
    
    @IBAction func eliminarTouchUpInside(){
        
        if (self.selectedClient != nil){
        
            let alertController = UIAlertController(title: "Atencion!", message: "Estas seguro que quiere eliminar este cliente?", preferredStyle: .alert)
            
            
            
            let OKAction = UIAlertAction(title: "Si Estoy Seguro", style: .default) { (action) in
                
                Services.eliminarCliente(self.selectedClient.client_id, andHandler: { (response) in
                    
                    
                    
                    
                    
                    let alertController = UIAlertController(title: "Atencion!", message: "Has eliminado el cliente", preferredStyle: .alert)
                    
                    
                    
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

        
        }else{
        
            let alertController = UIAlertController(title: "Atencion!", message: "Estas seguro que quiere eliminar este proveedor?", preferredStyle: .alert)
            
            
            
            let OKAction = UIAlertAction(title: "Si Estoy Seguro", style: .default) { (action) in
                
                Services.eliminarProveedor(self.selectedProveedor.client_id, andHandler: { (response) in
                    
                    
                    
                    
                    
                    let alertController = UIAlertController(title: "Atencion!", message: "Has eliminado el proveedor", preferredStyle: .alert)
                    
                    
                    
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
    
     @IBAction func sendemail(){
        self.delegate.sendemail(client: self.selectedClient)
    }
    @IBAction func sendemailP(){
        self.delegate.sendemailP(client: self.selectedProveedor)
    }
}
