//
//  StylesViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/13/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class StylesViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,UITextFieldDelegate,styledelegateHome,UIImagePickerControllerDelegate,UINavigationControllerDelegate,UIScrollViewDelegate {
    var users_array:[Styles] = []
    var plants_array:[Planta] = []
    @IBOutlet var titleViewLabelColelctionView: UILabel!
    @IBOutlet var titleViewLabel: UILabel!
    @IBOutlet var avatar_placeholder: UIImageView!
    @IBOutlet var user_avatar: UIImageView!
    @IBOutlet var styleImageView: UIImageView!
    @IBOutlet var styleImageViewTitle: UILabel!
    @IBOutlet var BackaddPlantview: UIView!
    @IBOutlet var addPlantview: UIView!
    @IBOutlet var addplantLabelTitle: UILabel!
    let imagePicker = UIImagePickerController()
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var guardarButton: UIButton!
    @IBOutlet var imageViewBig: UIView!
    @IBOutlet var closeButtonImage: UIButton!
    @IBOutlet var usuario_name: UITextField!
    @IBOutlet var user_nameLabel: UILabel!
     @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var plant_collectionview: UICollectionView!
    
    
    
    private func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return self.styleImageView
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        

          self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        NotificationCenter.default.addObserver(self, selector: #selector(StylesViewController.keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(StylesViewController.keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        
        self.titleViewLabelColelctionView.font = UIFont(name: FONT_BOLD, size: self.titleViewLabelColelctionView.font.pointSize)
        
        self.addplantLabelTitle.font = UIFont(name: FONT_BOLD, size: self.addplantLabelTitle.font.pointSize)
     
        self.user_nameLabel.font = UIFont(name: FONT_BOLD, size: self.user_nameLabel.font.pointSize)
        self.usuario_name.font = UIFont(name: FONT_REGULAR, size: (self.usuario_name.font?.pointSize)!)
        
        self.styleImageViewTitle.font = UIFont(name: FONT_BOLD, size: (self.styleImageViewTitle.font?.pointSize)!)
        self.guardarButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.guardarButton.titleLabel?.font.pointSize)!)
        self.BackaddPlantview.alpha = 0
        self.addPlantview.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.addPlantview.alpha = 0
        self.refreshHomePlants()
        self.titleViewLabel.font = UIFont(name: FONT_BOLD, size: self.titleViewLabel.font.pointSize)
        self.closeButtonImage.titleLabel?.font = UIFont(name: FONT_REGULAR, size: (self.closeButtonImage.titleLabel?.font?.pointSize)!)
        self.imageViewBig.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.imageViewBig.alpha = 0
        
        self.addPlantview.layer.cornerRadius = 4
        self.addPlantview.layer.masksToBounds = true
        
        self.imageViewBig.layer.cornerRadius = 4
        self.imageViewBig.layer.masksToBounds = true
        self.imagePicker.delegate = self
        self.setNeedsStatusBarAppearanceUpdate()
        self.navigationController?.navigationBar.barStyle = UIBarStyle.blackTranslucent
        //[self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
        // Do any additional setup after loading the view.
    }

  
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            return .lightContent
        }
    }
 
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    

    
    func keyboardWillShow(notification: NSNotification) {
        
        //        if !self.usuario_name.isEditing || !self.usuario_apellido.isEditing {
        //
        //            if ((notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
        //                self.view.frame.origin.y -= 150
        //            }
        //        }
        //
        
    }
    
    func keyboardWillHide(notification: NSNotification) {
        //        if !self.usuario_name.isEditing || !self.usuario_apellido.isEditing {
        //
        //            if ((notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
        //                self.view.frame.origin.y += 150
        //            }
        //        }
    }
    
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if self.usuario_name == textField{
            
            self.usuario_name.resignFirstResponder()
        }
        
       
        
        return true
    }
    
    
    
    
    
    
    func showAddPlantView(){
        
        
        UIView.animate(withDuration: 0.4) {
            self.BackaddPlantview.alpha = 1
            self.addPlantview.transform = CGAffineTransform.identity
            self.addPlantview.alpha = 1
            
        }
        
    }
    
    
    func hideAddplantView(){
        
        UIView.animate(withDuration: 0.4) {
            self.BackaddPlantview.alpha = 0
            self.addPlantview.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            self.addPlantview.alpha = 0
            
        }
        
        
        self.usuario_name.resignFirstResponder()

        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
       
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.users_array.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        
//        if indexPath.row == 0{
//            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ADD", for: indexPath)as!AddButtonCollectionViewCell
//            
//            return cell
//            
//        }else{
//            
//        }
//        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "styles", for: indexPath) as! StylesCollectionViewCell
        
        cell.plantas_array = self.plants_array
        cell.displayStyles(style: self.users_array[indexPath.row])
        cell.delegate = self
        cell.controller = self
        return cell
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
       return CGSize(width: 250, height: 250)
    }
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    
    func refreshHomePlants()
        
    {
        let loader  = SBTVLoaderView.create()
        
        let window = UIApplication.shared.keyWindow
        let sub =   (window?.subviews[0])! as UIView
        
        Functions.fillContainerView(sub, with: loader)
        
        
        Services.getPlantsWithandHandler({ (response) in
            
            self.plants_array = response as! [Planta]
            
            Services.getStylesWithandHandler({ (response) in
                
                self.users_array = response as! [Styles]
                
                
                self.plant_collectionview.reloadData()
                loader?.removeFromSuperview()
            }, orErrorHandler: { (err) in
                
                let alertController = UIAlertController(title: "Oops!", message: "Revisa tu conexión a internet.", preferredStyle: .alert)
                
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    
                }
                alertController.addAction(OKAction)
                
                self.present(alertController, animated: true) {
                    // ...
                }
                loader?.removeFromSuperview()
                
            })
            
        }) { (err) in
            
            let alertController = UIAlertController(title: "Oops!", message: "Revisa tu conexión a internet.", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            loader?.removeFromSuperview()
        }
  
        
    }
    
     @IBAction func showAddStyleTouchUpInside() {
            self.showAddPlantView()
    }
    @IBAction func selectUserImageTouchUpInside(sender: UIButton) {
               Functions.isChoosingImage(true)
        self.avatar_placeholder.transform = CGAffineTransform(scaleX: 0.01, y: 0.01);
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.30, initialSpringVelocity: 6.0, options: UIViewAnimationOptions.allowUserInteraction, animations: { () -> Void in
            self.avatar_placeholder.transform = CGAffineTransform.identity;
            
        }) { (Bool) -> Void in
            
            self.imagePicker.allowsEditing = false
            self.imagePicker.sourceType = .photoLibrary
            
 
            
     
            self.present(self.imagePicker, animated: true, completion: nil)
            
            
        }
        
        
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        

        Functions.isChoosingImage(false)
        
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.user_avatar.contentMode = UIViewContentMode.scaleAspectFill
            self.user_avatar.image = pickedImage
            
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        Functions.isChoosingImage(false)
        dismiss(animated: true, completion: nil)
    }
    
    
    
    @IBAction func saveClientInfoAndCreate(){
        
        
        
        if self.usuario_name.text == ""  {
            let alertController = UIAlertController(title: "Oops!", message: "Debes llenar todos los campos para cargar un estilo", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
        }else{
            
            
            let alertController = UIAlertController(title: "Atencion!", message: "Está por cargar el estilo: \(self.usuario_name.text!)", preferredStyle: .alert)
            let imageData = UIImageJPEGRepresentation(self.user_avatar.image!, 0.1)
            
            let base64String = imageData?.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
            
            
            
            let OKAction = UIAlertAction(title: "Cargar Estilo", style: .default) { (action) in
                
                let loader  = SBTVLoaderView.create()
                
                let window = UIApplication.shared.keyWindow
                let sub =   (window?.subviews[0])! as UIView
                
                Functions.fillContainerView(sub, with: loader)
        
                
                
           Services.createStyle(forIPB: self.usuario_name.text, andbase64String: base64String, andHandler: { (response) in
            self.closeAddPlantView()
            self.refreshHomePlants()
            let alertController = UIAlertController(title: "Bien!", message: "Cargaste el estilo: \(self.usuario_name.text!)", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
            loader?.removeFromSuperview()
            
           }, orErrorHandler: { (err) in
            
            let alertController = UIAlertController(title: "Oops!", message: "Revisa tu conexión a internet.", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            loader?.removeFromSuperview()
           })
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
            
            
            
        }
        
        
        
    }
    
  
    @IBAction func closeAddPlantView(){
        self.hideAddplantView()
    }
    @IBAction func goBack(){
        self.navigationController?.popViewController(animated: true)
    }
    
    
    func refreshFather() {
        
        self.refreshHomePlants()
    }
    
    func showImage(image: String) {
        
        UIView.animate(withDuration: 0.4) {
            self.BackaddPlantview.alpha = 1
            self.imageViewBig.transform = CGAffineTransform.identity
            self.imageViewBig.alpha = 1
            
            self.styleImageView.sd_setImage(with: NSURL(string: image) as URL!)
            
            
            
        }
        
    }
    @IBAction func hideImageBackView(){
        
        UIView.animate(withDuration: 0.4) {
            self.BackaddPlantview.alpha = 0
            self.imageViewBig.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            self.imageViewBig.alpha = 0
            
            self.styleImageView.sd_setImage(with: NSURL(string: "") as URL!)
            
            
            
        }
    }
    
}
