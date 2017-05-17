//
//  UsuariosViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/13/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class UsuariosViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,UITextFieldDelegate,userdelegateHome, UIPickerViewDataSource, UIPickerViewDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate {
    var users_array:[User] = []
    @IBOutlet var titleViewLabelColelctionView: UILabel!
    @IBOutlet var titleViewLabel: UILabel!
    @IBOutlet var avatar_placeholder: UIImageView!
    @IBOutlet var user_avatar: UIImageView!
    
    @IBOutlet var BackaddPlantview: UIView!
    @IBOutlet var addPlantview: UIView!
    @IBOutlet var addplantLabelTitle: UILabel!
    let imagePicker = UIImagePickerController()
    
    var pickerDataSource = ["Administrador", "Gerente de Planta", "Gerente de Cortes", "Gerente de Envios"];
    var pickerDataSourcePlants:[Planta] = []
    @IBOutlet var guardarButton: UIButton!
    
    @IBOutlet var usuario_name: UITextField!
    @IBOutlet var user_nameLabel: UILabel!
    
    @IBOutlet var usuario_apellido: UITextField!
    @IBOutlet var user_apellidoLabel: UILabel!
    
    
    @IBOutlet var usuario_plantaTextField: UITextField!
    @IBOutlet var usuario_plantaLabel: UILabel!
    var pickerView = UIPickerView()
    var pickerView2 = UIPickerView()
    @IBOutlet var usuario_telefono: UITextField!
    @IBOutlet var user_telefonoLabel: UILabel!
    
    @IBOutlet var usuario_email: UITextField!
    @IBOutlet var user_emailLabel: UILabel!
    @IBOutlet var closeButton: UIButton!
    
    @IBOutlet var usuario_password: UITextField!
    @IBOutlet var user_passwordLabel: UILabel!
    @IBOutlet var usuario_puesto: UITextField!
    @IBOutlet var user_puestoLabel: UILabel!
    @IBOutlet var plant_collectionview: UICollectionView!
    var revealController:SWRevealViewController!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.usuario_plantaTextField.alpha = 0
        
        self.usuario_plantaLabel.alpha = 0
        
          self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        NotificationCenter.default.addObserver(self, selector: #selector(UsuariosViewController.keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(UsuariosViewController.keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        self.BackaddPlantview.alpha = 0
        
        self.titleViewLabelColelctionView.font = UIFont(name: FONT_BOLD, size: self.titleViewLabelColelctionView.font.pointSize)
        
        self.addplantLabelTitle.font = UIFont(name: FONT_BOLD, size: self.addplantLabelTitle.font.pointSize)
        
        self.user_nameLabel.font = UIFont(name: FONT_BOLD, size: self.user_nameLabel.font.pointSize)
        self.usuario_name.font = UIFont(name: FONT_REGULAR, size: (self.usuario_name.font?.pointSize)!)
        
        
        self.usuario_plantaLabel.font = UIFont(name: FONT_BOLD, size: self.usuario_plantaLabel.font.pointSize)
        self.usuario_plantaTextField.font = UIFont(name: FONT_REGULAR, size: (self.usuario_plantaTextField.font?.pointSize)!)
        
        let loader  = SBTVLoaderView.create()
        
        let window = UIApplication.shared.keyWindow
        let sub =   (window?.subviews[0])! as UIView
        
        Functions.fillContainerView(sub, with: loader)
        
        
        Services.getPlantsWithandHandler({ (response) in
            
            self.pickerDataSourcePlants = response as! [Planta]
            
            
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
        
        self.user_apellidoLabel.font = UIFont(name: FONT_BOLD, size: self.user_apellidoLabel.font.pointSize)
        self.usuario_apellido.font = UIFont(name: FONT_REGULAR, size: (self.usuario_apellido.font?.pointSize)!)
        
        self.user_telefonoLabel.font = UIFont(name: FONT_BOLD, size: self.user_telefonoLabel.font.pointSize)
        self.usuario_telefono.font = UIFont(name: FONT_REGULAR, size: (self.usuario_telefono.font?.pointSize)!)
        
        self.user_emailLabel.font = UIFont(name: FONT_BOLD, size: self.user_emailLabel.font.pointSize)
        self.usuario_email.font = UIFont(name: FONT_REGULAR, size: (self.usuario_email.font?.pointSize)!)
        
        self.user_puestoLabel.font = UIFont(name: FONT_BOLD, size: self.user_puestoLabel.font.pointSize)
        self.usuario_puesto.font = UIFont(name: FONT_REGULAR, size: (self.usuario_puesto.font?.pointSize)!)
        

        self.user_passwordLabel.font = UIFont(name: FONT_BOLD, size: self.user_passwordLabel.font.pointSize)
        self.usuario_password.font = UIFont(name: FONT_REGULAR, size: (self.usuario_password.font?.pointSize)!)
        
        self.guardarButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.guardarButton.titleLabel?.font.pointSize)!)
        self.addPlantview.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.addPlantview.alpha = 0
       
        
        
        self.pickerView2.delegate = self
        self.pickerView2.dataSource = self
        
        
        
        
        self.pickerView2.showsSelectionIndicator = true
        self.pickerView2.delegate = self
        self.pickerView2.dataSource = self

        
        
 
        
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        


        
        self.pickerView.showsSelectionIndicator = true
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        
        let toolBar = UIToolbar()
        toolBar.barStyle = UIBarStyle.default
        toolBar.isTranslucent = true
        toolBar.tintColor = UIColor(red: 128/255, green: 128/255, blue: 128/255, alpha: 1)
        toolBar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Terminar", style: UIBarButtonItemStyle.plain, target: self, action: #selector(UsuariosViewController.donePicker(sender:)))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: "Cancelar", style: UIBarButtonItemStyle.plain, target: self, action: #selector(UsuariosViewController.cancelPicker(sender:)))
        
        toolBar.setItems([cancelButton, spaceButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        
      
        self.usuario_plantaTextField.inputView = self.pickerView2
         self.usuario_plantaTextField.inputAccessoryView = toolBar
        
        self.usuario_puesto.inputView = self.pickerView
        
        
          self.usuario_puesto.inputAccessoryView = toolBar
        self.refreshHomePlants()
        self.titleViewLabel.font = UIFont(name: FONT_BOLD, size: self.titleViewLabel.font.pointSize)
        
        
        self.addPlantview.layer.cornerRadius = 4
        self.addPlantview.layer.masksToBounds = true
       
        
        self.imagePicker.delegate = self
        self.setNeedsStatusBarAppearanceUpdate()
        self.navigationController?.navigationBar.barStyle = UIBarStyle.blackTranslucent
        //[self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
        // Do any additional setup after loading the view.
    }
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        
        if self.pickerView2 == pickerView{
          return self.pickerDataSourcePlants.count;
        
        }else{
          return self.pickerDataSource.count;
        
        }
      
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
         if self.pickerView2 == pickerView{
              return self.pickerDataSourcePlants[row].planta_nombre
            
         }else{
        return self.pickerDataSource[row]
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            return .lightContent
        }
    }
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
          return 1
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func donePicker (sender:UIBarButtonItem)
    {
        
        if self.usuario_puesto.isEditing{
        
        
                if self.usuario_puesto.text == "Gerente de Planta"{
                    
                    UIView.animate(withDuration: 0.2) {
                        self.usuario_plantaTextField.alpha = 1
                        
                        self.usuario_plantaLabel.alpha = 1
                        
                    }
                      self.usuario_puesto.resignFirstResponder()
                    self.usuario_plantaTextField.becomeFirstResponder()
                }else{
                    self.usuario_puesto.resignFirstResponder()
                    
                }
                
         
      
            
        }
        
        
        if self.usuario_plantaTextField.isEditing{
        
          self.usuario_plantaTextField.resignFirstResponder()
        
        }
      
    }
    
    
    func cancelPicker (sender:UIBarButtonItem)
    {
        self.usuario_puesto.resignFirstResponder()
        self.usuario_plantaTextField.resignFirstResponder()
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
        
        if self.user_nameLabel == textField{
            
            self.usuario_apellido.becomeFirstResponder()
        }
        
        if self.usuario_apellido == textField{
            
            self.usuario_telefono.becomeFirstResponder()
        }
        if self.usuario_telefono == textField{
            
            self.usuario_email.becomeFirstResponder()
        }
        if self.usuario_email == textField{
            
            self.usuario_password.becomeFirstResponder()
        }
        
        if self.usuario_password == textField{
        
        self.usuario_puesto.becomeFirstResponder()
        
        }
        
        
        if self.usuario_puesto == textField{
            if self.usuario_puesto.text == "Gerente de Planta"{
            
                UIView.animate(withDuration: 0.2) {
                    self.usuario_plantaTextField.alpha = 1
                
                    self.usuario_plantaLabel.alpha = 1
                    
                }
               self.usuario_plantaTextField.becomeFirstResponder()
            }else{
               self.usuario_puesto.resignFirstResponder()
            
            }
         
            
        }
        
        if self.usuario_plantaTextField == textField{
        
        self.usuario_plantaTextField.resignFirstResponder()
        
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
        self.usuario_email.resignFirstResponder()
        self.usuario_apellido.resignFirstResponder()
        self.usuario_password.resignFirstResponder()
        self.usuario_telefono.resignFirstResponder()
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if indexPath.row == 0{
            
            self.showAddPlantView()
            
        }else{
            
        }
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.users_array.count + 1
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        
        if indexPath.row == 0{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ADD", for: indexPath)as!AddButtonCollectionViewCell
            
            return cell
            
        }else{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "users", for: indexPath) as! UserCollectionViewCell
            
            
            cell.displayUsers(user: self.users_array[indexPath.row - 1])
            cell.delegate = self
            cell.controller = self
            return cell
        }
        
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: 220, height: 340)
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
        
        
        Services.getUsersWithandHandler({ (response) in
            
            self.users_array = response as! [User]
            
            
            
            loader?.removeFromSuperview()
            self.plant_collectionview.reloadData()
            
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
    
    @IBAction func selectUserImageTouchUpInside(sender: UIButton) {
        self.avatar_placeholder.transform = CGAffineTransform(scaleX: 0.01, y: 0.01);
        Functions.isChoosingImage(true)
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
        
        
        
        if self.usuario_name.text == "" || self.usuario_telefono.text == "" || self.usuario_password.text == "" || self.usuario_apellido.text == "" || self.usuario_email.text == "" {
            let alertController = UIAlertController(title: "Oops!", message: "Debes llenar todos los campos para cargar un usuario", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
        }else{
            
            if self.usuario_puesto.text == "Gerente de Planta" && self.usuario_plantaTextField.text == ""{
            
                let alertController = UIAlertController(title: "Oops!", message: "El usuario es Gerente de Planta, debes asignarle una planta.", preferredStyle: .alert)
                
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    
                }
                alertController.addAction(OKAction)
                
                self.present(alertController, animated: true) {
                    // ...
                }
                
            }else{
            
                let alertController = UIAlertController(title: "Atencion!", message: "Está por cargar el usuario: \(self.usuario_name.text!) \(self.usuario_apellido.text!)", preferredStyle: .alert)
                let imageData = UIImageJPEGRepresentation(self.user_avatar.image!, 0.1)
                
                let base64String = imageData?.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
                
                
                let defults = UserDefaults.standard
                var device_token = ""
                if (defults.object(forKey: "device_token") != nil){
                    device_token = defults.object(forKey: "device_token") as! String
                }else{
                    device_token = "0"
                    
                }
                
                var string = ""
                if self.usuario_plantaTextField.text != ""{
                    string = self.usuario_plantaTextField.text!
                }
                
                let OKAction = UIAlertAction(title: "Cargar Usuario", style: .default) { (action) in
                    
                    let loader  = SBTVLoaderView.create()
                    
                    let window = UIApplication.shared.keyWindow
                    let sub =   (window?.subviews[0])! as UIView
                    
                    Functions.fillContainerView(sub, with: loader)
                    
                    Services.createUser(forIPB: self.usuario_name.text, andUserSurname: self.usuario_apellido.text, andTelefone: self.usuario_telefono.text, andEmail: self.usuario_email.text, andPassword: self.usuario_password.text, andPuesto: self.usuario_puesto.text, andbase64String: base64String, andDeviceToken: device_token, andPlantName:string, andHandler: { (response) in
                        
                        
                        self.closeAddPlantView()
                        self.refreshHomePlants()
                        let alertController = UIAlertController(title: "Bien!", message: "Cargaste el usuario: \(self.usuario_name.text!) \(self.usuario_apellido.text!)", preferredStyle: .alert)
                        
                        
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
        
        
        
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        if self.pickerView == pickerView{
            self.usuario_puesto.text = self.pickerDataSource[row]
        
        }else{
            self.usuario_plantaTextField.text = self.pickerDataSourcePlants[row].planta_nombre
        
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
}
