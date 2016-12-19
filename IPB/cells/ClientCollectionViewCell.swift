//
//  ClientCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/12/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit
protocol clientdelegateHome {
    
    func refreshFather()
}
class ClientCollectionViewCell: UICollectionViewCell {
    
    var delegate:clientdelegateHome!
    var controller:UIViewController!
    @IBOutlet var client_nameLabel: UILabel!
    @IBOutlet var mainView: UIView!
    var selectedClient:Cliente!
    
    @IBOutlet var closeButton: UIButton!
    override func awakeFromNib() {
           self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        self.client_nameLabel.font = UIFont(name: FONT_BOLD, size: self.client_nameLabel.font.pointSize)
        self.mainView.layer.cornerRadius = 4
        self.mainView.layer.masksToBounds = true
    }
    
    
    func displayClient(client:Cliente){
    
    self.selectedClient = client
    self.client_nameLabel.text = client.client_name
    }
    
    
    
    @IBAction func eliminarTouchUpInside(){
        
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
        
        
        
        
        
    }

}
