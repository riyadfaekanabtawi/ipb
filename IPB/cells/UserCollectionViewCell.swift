//
//  UserCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/13/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit
protocol userdelegateHome {
    
    func refreshFather()
}
class UserCollectionViewCell: UICollectionViewCell {
    
    var delegate:userdelegateHome!
    var selectedUser:User!
    var controller:UIViewController!
    @IBOutlet var user_name_label: UILabel!
    @IBOutlet var user_apellido_label: UILabel!
    @IBOutlet var user_puesto_label: UILabel!
    @IBOutlet var user_email_label: UILabel!
    @IBOutlet var closeButton:  UIButton!
    
    @IBOutlet var user_image_profile: UIImageView!
    override func awakeFromNib() {
        
        self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        self.user_image_profile.layer.cornerRadius = 4
        self.user_image_profile.layer.masksToBounds = true
        self.user_name_label.font = UIFont(name: FONT_REGULAR, size: self.user_name_label.font.pointSize)
        self.user_apellido_label.font = UIFont(name: FONT_REGULAR, size: self.user_apellido_label.font.pointSize)
        self.user_puesto_label.font = UIFont(name: FONT_REGULAR, size: self.user_puesto_label.font.pointSize)
        self.user_email_label.font = UIFont(name: FONT_REGULAR, size: self.user_email_label.font.pointSize)
    }
    
    
    func displayUsers(user:User){
    self.selectedUser = user
    self.user_image_profile.sd_setImage(with: NSURL(string: user.avatar_url) as URL!)
    self.user_name_label.text = user.nombre
    self.user_apellido_label.text = user.apellido
    self.user_email_label.text = user.email
    self.user_puesto_label.text = user.puesto
        
    
    }
    
    @IBAction func eliminarTouchUpInside(){
        
        let alertController = UIAlertController(title: "Atencion!", message: "Estas seguro que quiere eliminar este usuario?", preferredStyle: .alert)
        
        
        
        let OKAction = UIAlertAction(title: "Si Estoy Seguro", style: .default) { (action) in
            
            Services.eliminarUsuario(self.selectedUser.user_id, andHandler: { (response) in
                
                
                
                
                
                let alertController = UIAlertController(title: "Atencion!", message: "Has eliminado el usuario", preferredStyle: .alert)
                
                
                
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
