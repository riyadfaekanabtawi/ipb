//
//  StylesCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/13/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit
protocol styledelegateHome {
    
    func refreshFather()
}
class StylesCollectionViewCell: UICollectionViewCell {
    var selectedStyle:Styles!
    var delegate:styledelegateHome!
    @IBOutlet var style_image: UIImageView!
    @IBOutlet var style_name: UILabel!
    var controller:UIViewController!
    @IBOutlet var closeButton: UIButton!
    override func awakeFromNib() {
    self.style_name.font = UIFont(name: FONT_BOLD, size: self.style_name.font.pointSize)
    self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
    }
    
    
    
    func displayStyles(style:Styles){
        self.selectedStyle = style
        self.style_name.text = style.style_name
        self.style_image.sd_setImage(with: NSURL(string: style.style_image) as URL!)
        
        
  
    }

    @IBAction func eliminarTouchUpInside(){
        
        let alertController = UIAlertController(title: "Atencion!", message: "Estas seguro que quiere eliminar este estilo?", preferredStyle: .alert)
        
        
        
        let OKAction = UIAlertAction(title: "Si Estoy Seguro", style: .default) { (action) in
            
            Services.eliminarEstilo(self.selectedStyle.style_id, andHandler: { (response) in
                
                
                
                
                
                let alertController = UIAlertController(title: "Atencion!", message: "Has eliminado el estilo", preferredStyle: .alert)
                
                
                
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
