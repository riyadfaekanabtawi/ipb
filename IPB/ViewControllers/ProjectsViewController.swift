//
//  ProjectsViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 2/14/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

import UIKit


class ProjectsViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,UITextFieldDelegate,projectdelegateHome,UIImagePickerControllerDelegate,UINavigationControllerDelegate {
    var users_array:[Project] = []
    @IBOutlet var titleViewLabelColelctionView: UILabel!
    @IBOutlet var titleViewLabel: UILabel!
    @IBOutlet var avatar_placeholder: UIImageView!
    @IBOutlet var user_avatar: UIImageView!
    var editingproject = false
    @IBOutlet var BackaddPlantview: UIView!
    @IBOutlet var addPlantview: UIView!
    @IBOutlet var addplantLabelTitle: UILabel!
    let imagePicker = UIImagePickerController()

    @IBOutlet var guardarButton: UIButton!
    
    @IBOutlet var usuario_name: UITextField!
    @IBOutlet var user_nameLabel: UILabel!
    
    @IBOutlet var usuario_apellido: UITextField!
    @IBOutlet var user_apellidoLabel: UILabel!
    
    @IBOutlet var proyect_clienteTextField: UITextField!
    @IBOutlet var proyect_clienteLabel: UILabel!
    
    @IBOutlet var usuario_plantaTextField: UITextField!
    @IBOutlet var usuario_plantaLabel: UILabel!

    @IBOutlet var usuario_telefono: UITextField!
    @IBOutlet var user_telefonoLabel: UILabel!
    
    @IBOutlet var usuario_email: UITextField!
    @IBOutlet var user_emailLabel: UILabel!
    @IBOutlet var closeButton: UIButton!
    var selectedProject:Project!
    @IBOutlet var usuario_password: UITextField!
    @IBOutlet var user_passwordLabel: UILabel!
    @IBOutlet var usuario_puesto: UITextField!
    @IBOutlet var user_puestoLabel: UILabel!
    @IBOutlet var plant_collectionview: UICollectionView!
    var revealController:SWRevealViewController!
    override func viewDidLoad() {
        super.viewDidLoad()
  
       
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
        
        self.proyect_clienteLabel.font = UIFont(name: FONT_BOLD, size: self.proyect_clienteLabel.font.pointSize)
        self.proyect_clienteTextField.font = UIFont(name: FONT_REGULAR, size: (self.proyect_clienteTextField.font?.pointSize)!)
        
        

        
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
           self.usuario_plantaTextField.becomeFirstResponder()
            
            
        }
        
        if self.usuario_plantaTextField == textField{
            
            self.proyect_clienteTextField.becomeFirstResponder()
            
        }
        
        if self.proyect_clienteTextField == textField{
            
            self.proyect_clienteTextField.resignFirstResponder()
            
        }
        return true
    }
    
    
    
    
    
    
    func showAddPlantView(){
        
        if self.editingproject == true{
        
            if self.selectedProject.cantidad != nil{
            
                self.usuario_name.text = self.selectedProject.cantidad!
            }
            
            if self.selectedProject.precio != nil{
            self.usuario_apellido.text = self.selectedProject.precio!
            
            }
            
            if self.selectedProject.total != nil{
            
            self.usuario_telefono.text = self.selectedProject.total!
            
            }
            
            if self.selectedProject.minutaje != nil{
            
            self.usuario_plantaTextField.text = self.selectedProject.minutaje!
                
            
            }
            
            if self.selectedProject.cliente != nil{
            
            self.proyect_clienteTextField.text = self.selectedProject.cliente!
            
            }
            
            
            if self.selectedProject.fecha_entrega != nil{
            
            self.usuario_email.text = self.selectedProject.fecha_entrega!
            
            }
            
            if self.selectedProject.tela != nil{
            
            self.usuario_password.text = self.selectedProject.tela!
                
            }
            
            if self.selectedProject.status != nil{
            
                self.usuario_puesto.text = self.selectedProject.status!
            
            }
        
            
            self.user_avatar.sd_setImage(with: NSURL(string:BASE_URL + self.selectedProject.photo!) as URL!)
        }
        
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
        self.proyect_clienteTextField.resignFirstResponder()
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if indexPath.row == 0{
                self.editingproject = false
            self.showAddPlantView()
            self.guardarButton.alpha = 1

                
                self.usuario_name.text = ""
 
                self.usuario_apellido.text = ""
 
            
                
                self.usuario_telefono.text = ""
 
                
                self.usuario_plantaTextField.text = ""
  
                
                self.proyect_clienteTextField.text = ""
          
                
                self.usuario_email.text = ""

                
                self.usuario_password.text = ""
   
                
                self.usuario_puesto.text = ""
          
                self.user_avatar.image = UIImage(named: "add photo.png")
            
            
        }else{
            self.editingproject = true
            self.selectedProject = self.users_array[indexPath.row-1]
             self.guardarButton.alpha = 1
            self.showAddPlantView()
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "users", for: indexPath) as! ProjectCollectionViewCell
            
            
            cell.displayUsers(project: self.users_array[indexPath.row - 1])
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
        
        
        
        Services.getAllProjects({ (response) in
            
            self.users_array = response as! [Project]
            
            
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
            let alertController = UIAlertController(title: "Oops!", message: "Debes llenar todos los campos para cargar un proyecto", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
        }else{
            
            if self.editingproject{
                let alertController = UIAlertController(title: "Atencion!", message: "Está por actualizar un proyecto", preferredStyle: .alert)
                let imageData = UIImageJPEGRepresentation(self.user_avatar.image!, 0.1)
                
                let base64String = imageData?.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
                
                
                var string = ""
                if self.usuario_plantaTextField.text != ""{
                    string = self.usuario_plantaTextField.text!
                }
                
                let OKAction = UIAlertAction(title: "Actualizar Proyecto", style: .default) { (action) in
                    
                    Services.updateProject(forIPB: self.usuario_name.text, andID:self.selectedProject.project_id, andPrecio: self.usuario_apellido.text, andTotal: self.usuario_telefono.text, andMinutaje: self.usuario_plantaTextField.text, andStatus: self.usuario_puesto.text, andCliente: self.proyect_clienteTextField.text, andTela: self.usuario_password.text, andbase64String: base64String, andFechaEntrega:self.usuario_email.text, andHandler: { (response) in
                        
                        self.closeAddPlantView()
                        self.refreshHomePlants()
                        let alertController = UIAlertController(title: "Bien!", message: "Actualizaste el proyecto", preferredStyle: .alert)
                        
                        
                        let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                            
                        }
                        alertController.addAction(OKAction)
                        
                        self.present(alertController, animated: true) {
                            // ...
                        }
                        
                    }, orErrorHandler: { (err) in
                        
                        
                    })
                    
                }
                alertController.addAction(OKAction)
                
                self.present(alertController, animated: true) {
                    // ...
                }

            
            }else{
                let alertController = UIAlertController(title: "Atencion!", message: "Está por cargar un proyecto", preferredStyle: .alert)
                let imageData = UIImageJPEGRepresentation(self.user_avatar.image!, 0.1)
                
                let base64String = imageData?.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
                
                
                var string = ""
                if self.usuario_plantaTextField.text != ""{
                    string = self.usuario_plantaTextField.text!
                }
                
                let OKAction = UIAlertAction(title: "Cargar Proyecto", style: .default) { (action) in
                    
                    Services.createProject(forIPB: self.usuario_name.text, andPrecio: self.usuario_apellido.text, andTotal: self.usuario_telefono.text, andMinutaje: self.usuario_plantaTextField.text, andStatus: self.usuario_puesto.text, andCliente: self.proyect_clienteTextField.text, andTela: self.usuario_password.text, andbase64String: base64String, andFechaEntrega:self.usuario_email.text, andHandler: { (response) in
                        
                        self.closeAddPlantView()
                        self.refreshHomePlants()
                        let alertController = UIAlertController(title: "Bien!", message: "Cargaste el proyecto", preferredStyle: .alert)
                        
                        
                        let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                            
                        }
                        alertController.addAction(OKAction)
                        
                        self.present(alertController, animated: true) {
                            // ...
                        }
                        
                    }, orErrorHandler: { (err) in
                        
                        
                    })
                    
                }
                alertController.addAction(OKAction)
                
                self.present(alertController, animated: true) {
                    // ...
                }

            
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
}

