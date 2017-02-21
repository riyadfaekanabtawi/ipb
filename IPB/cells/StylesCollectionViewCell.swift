//
//  StylesCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/13/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit
protocol styledelegateHome {
    
    func showImage(image:String)
    func refreshFather()
}
class StylesCollectionViewCell: UICollectionViewCell,UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout {
    var selectedStyle:Styles!
    var arrayInfo:[NSDictionary] = []
    var delegate:styledelegateHome!
    @IBOutlet var plant_collectionview: UICollectionView!
    @IBOutlet var style_image: UIImageView!
    @IBOutlet var style_name: UILabel!
    var controller:UIViewController!
    @IBOutlet var closeButton: UIButton!
    override func awakeFromNib() {
    self.style_name.font = UIFont(name: FONT_REGULAR, size: self.style_name.font.pointSize)
    self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
    }
    
    
    
    func displayStyles(style:Styles){
        self.selectedStyle = style
        self.style_name.text = style.style_name
        self.style_image.sd_setImage(with: NSURL(string: style.style_image) as URL!)
        
        Services.getPlantsforStyle(style.style_id, andHandler: { (response) in
            
            self.arrayInfo = response as! [NSDictionary]
            
            
            self.plant_collectionview.reloadData()
         
        }, orErrorHandler: { (err) in
        
            
            
        })

        
  
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
    
    @IBAction func showImageTouchUpInside(){
    
    self.delegate.showImage(image: self.selectedStyle.style_image)
        
    }
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.arrayInfo.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: 70, height: 30)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "plant", for: indexPath)as!PlantStyleCollectionViewCell
        
        
        cell.showcuts(corte: self.arrayInfo[indexPath.row])
        
        return cell
        
    }
}
