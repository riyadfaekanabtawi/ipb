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
 let mask = "##/##"
    @IBOutlet var guardarButton: UIButton!
    
    @IBOutlet var cliente_textfield: UITextField!
    @IBOutlet var cliente_name_label: UILabel!
    
    @IBOutlet var minutaje_textfield: UITextField!
    @IBOutlet var minutaje_label: UILabel!
    
    @IBOutlet var tela_textfield: UITextField!
    @IBOutlet var tela_label: UILabel!
    
    @IBOutlet var cantidad_textfield: UITextField!
    @IBOutlet var cantidad_label: UILabel!

    @IBOutlet var precio_textfield: UITextField!
    @IBOutlet var precio_label: UILabel!
    
    @IBOutlet var fecha_entrega_textfield: UITextField!
    @IBOutlet var fecha_entrega_label: UILabel!
    
    @IBOutlet var closeButton: UIButton!
    var selectedProject:Project!
    @IBOutlet var status_textfield: UITextField!
    @IBOutlet var status_label: UILabel!
    @IBOutlet var notas_textfield: UITextField!
    @IBOutlet var notas_label: UILabel!
    
    
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
        
        self.cliente_name_label.font = UIFont(name: FONT_BOLD, size: self.cliente_name_label.font.pointSize)
        self.cliente_textfield.font = UIFont(name: FONT_REGULAR, size: (self.cliente_textfield.font?.pointSize)!)
        
        
        self.minutaje_label.font = UIFont(name: FONT_BOLD, size: self.minutaje_label.font.pointSize)
        self.minutaje_textfield.font = UIFont(name: FONT_REGULAR, size: (self.minutaje_textfield.font?.pointSize)!)
        
        self.tela_label.font = UIFont(name: FONT_BOLD, size: self.tela_label.font.pointSize)
        self.tela_textfield.font = UIFont(name: FONT_REGULAR, size: (self.tela_textfield.font?.pointSize)!)
        
        

        
        self.cantidad_label.font = UIFont(name: FONT_BOLD, size: self.cantidad_label.font.pointSize)
        self.cantidad_textfield.font = UIFont(name: FONT_REGULAR, size: (self.cantidad_textfield.font?.pointSize)!)
        
        self.precio_label.font = UIFont(name: FONT_BOLD, size: self.precio_label.font.pointSize)
        self.precio_textfield.font = UIFont(name: FONT_REGULAR, size: (self.precio_textfield.font?.pointSize)!)
        
        self.fecha_entrega_label.font = UIFont(name: FONT_BOLD, size: self.fecha_entrega_label.font.pointSize)
        self.fecha_entrega_textfield.font = UIFont(name: FONT_REGULAR, size: (self.fecha_entrega_textfield.font?.pointSize)!)
        
        self.notas_label.font = UIFont(name: FONT_BOLD, size: self.notas_label.font.pointSize)
        self.notas_textfield.font = UIFont(name: FONT_REGULAR, size: (self.notas_textfield.font?.pointSize)!)
        
        
        self.status_label.font = UIFont(name: FONT_BOLD, size: self.status_label.font.pointSize)
        self.status_textfield.font = UIFont(name: FONT_REGULAR, size: (self.status_textfield.font?.pointSize)!)
        
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
        
        if self.cliente_textfield == textField{
            
            self.minutaje_textfield.becomeFirstResponder()
        }
        
        if self.minutaje_textfield == textField{
            
            self.tela_textfield.becomeFirstResponder()
        }
        if self.tela_textfield == textField{
            
            self.cantidad_textfield.becomeFirstResponder()
        }
        if self.cantidad_textfield == textField{
            
            self.precio_textfield.becomeFirstResponder()
        }
        
        if self.precio_textfield == textField{
            
            self.fecha_entrega_textfield.becomeFirstResponder()
            
        }
        
        
        if self.fecha_entrega_textfield == textField{
           self.notas_textfield.becomeFirstResponder()
            
            
        }
        
        if self.notas_textfield == textField{
            
            self.status_textfield.becomeFirstResponder()
            
        }
        
        if self.status_textfield == textField{
            
            self.status_textfield.resignFirstResponder()
            
        }
        return true
    }
    
    
    
    
    
    
    func showAddPlantView(){
        
        if self.editingproject == true{
          self.addplantLabelTitle.text = "EDITAR PEOYECTO"
            if self.selectedProject.cantidad != nil{
            
                self.cantidad_textfield.text = self.selectedProject.cantidad!
            }
            
            if self.selectedProject.precio != nil{
            self.precio_textfield.text = self.selectedProject.precio!
            
            }
            
      
            
            if self.selectedProject.minutaje != nil{
            
            self.minutaje_textfield.text = self.selectedProject.minutaje!
                
            
            }
            
            if self.selectedProject.cliente != nil{
            
            self.cliente_textfield.text = self.selectedProject.cliente!
            
            }
            
            
            if self.selectedProject.fecha_entrega != nil{
            
            self.fecha_entrega_textfield.text = self.selectedProject.fecha_entrega!
            
            }
            
            if self.selectedProject.tela != nil{
            
            self.tela_textfield.text = self.selectedProject.tela!
                
            }
            
            if self.selectedProject.status != nil{
            
                self.status_textfield.text = self.selectedProject.status!
            
            }
        
            if self.selectedProject.notes != nil{
                
                self.notas_textfield.text = self.selectedProject.notes!
                
            }
            
            
            self.user_avatar.sd_setImage(with: NSURL(string:BASE_URL + self.selectedProject.photo!) as URL!)
        }else{
        
        
                self.cliente_textfield.text = "";
                self.minutaje_textfield.text = ""
                self.tela_textfield.text = ""
                
                self.cantidad_textfield.text = ""
                self.precio_textfield.text  = ""
                self.fecha_entrega_textfield.text = ""
                
                self.notas_textfield.text = ""
            
                self.status_textfield.text  = ""
       
                self.addplantLabelTitle.text = "NUEVO PEOYECTO"
                
            
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
        
        
        self.cliente_textfield.resignFirstResponder()
        self.minutaje_textfield.resignFirstResponder()
        self.tela_textfield.resignFirstResponder()
        self.cantidad_textfield.resignFirstResponder()
        self.precio_textfield.resignFirstResponder()
        self.fecha_entrega_textfield.resignFirstResponder()
        self.notas_textfield.resignFirstResponder()
        self.status_textfield.resignFirstResponder()
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
//        if indexPath.row == 0{
//                self.editingproject = false
//            self.showAddPlantView()
//            self.guardarButton.alpha = 1
//
//                
//                self.usuario_name.text = ""
// 
//                self.usuario_apellido.text = ""
// 
//            
//                
//                self.usuario_telefono.text = ""
// 
//                
//                self.usuario_plantaTextField.text = ""
//  
//                
//                self.proyect_clienteTextField.text = ""
//          
//                
//                self.usuario_email.text = ""
//
//                
//                self.usuario_password.text = ""
//   
//                
//                self.usuario_puesto.text = ""
//          
//                self.user_avatar.image = UIImage(named: "add photo.png")
//            
//            
//        }else{
            self.editingproject = true
            self.selectedProject = self.users_array[indexPath.row]
             self.guardarButton.alpha = 1
            self.showAddPlantView()
      //  }
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
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "users", for: indexPath) as! ProjectCollectionViewCell
        
        
        cell.displayUsers(project: self.users_array[indexPath.row])
        cell.delegate = self
        cell.controller = self
        return cell
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: collectionView.frame.size.width, height: 170)
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
        
        
        
        if self.cliente_textfield.text == "" || self.minutaje_textfield.text == "" || self.tela_textfield.text == "" || self.cantidad_textfield.text == "" || self.precio_textfield.text == "" || self.fecha_entrega_textfield.text == "" || self.notas_textfield.text == "" || self.status_textfield.text == "" {
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
                
                
            
                
                let OKAction = UIAlertAction(title: "Actualizar Proyecto", style: .default) { (action) in
                    
                    Services.updateProject(forIPB: self.cantidad_textfield.text, andID:self.selectedProject.project_id, andPrecio: self.precio_textfield.text, andTotal: "\(Float(self.cantidad_textfield.text!)!*Float(self.precio_textfield.text!)!)", andMinutaje: self.minutaje_textfield.text, andStatus: self.status_textfield.text, andCliente: self.cliente_textfield.text, andTela: self.tela_textfield.text, andbase64String: base64String, andFechaEntrega:self.fecha_entrega_textfield.text, andNotes:self.notas_textfield.text, andHandler: { (response) in
                        
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
                
                let cancel = UIAlertAction(title: "Cancelar", style: .default) { (action) in
                    
                }
                alertController.addAction(OKAction)
                alertController.addAction(cancel)
                
                self.present(alertController, animated: true) {
                    // ...
                }

            
            }else{
                let alertController = UIAlertController(title: "Atencion!", message: "Está por cargar un proyecto", preferredStyle: .alert)
                let imageData = UIImageJPEGRepresentation(self.user_avatar.image!, 0.1)
                
                let base64String = imageData?.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
                
                
             
                
                let OKAction = UIAlertAction(title: "Cargar Proyecto", style: .default) { (action) in
                    
                    Services.createProject(forIPB: self.cantidad_textfield.text, andPrecio: self.precio_textfield.text, andTotal: "\(Float(self.cantidad_textfield.text!)!*Float(self.precio_textfield.text!)!)", andMinutaje: self.minutaje_textfield.text, andStatus: self.status_textfield.text, andCliente: self.cliente_textfield.text, andTela: self.tela_textfield.text, andbase64String: base64String, andFechaEntrega:self.fecha_entrega_textfield.text, andNote:self.notas_textfield.text, andHandler: { (response) in
                        
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
                let cancel = UIAlertAction(title: "Cancelar", style: .default) { (action) in
                    
                }
                alertController.addAction(OKAction)
                alertController.addAction(cancel)
                
                self.present(alertController, animated: true) {
                    // ...
                }

            
            }
            
            
            
            
        }
        
        
        
    }
    
    @IBAction func ShowAddPlantViewTouchUpInside(){
        self.editingproject = false
        self.showAddPlantView()
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
    
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
        
    {
        
        
        
        
        let nsString = textField.text as NSString?
        let text = nsString?.replacingCharacters(in: range, with: string)
        
        if self.cantidad_textfield == textField || self.precio_textfield == textField{
            if Int(text!) != nil || text?.range(of: ".") != nil || text == ""{
                // Text field converted to an Int
                return true
            } else {
                // Text field is not an Int
                return false
                
            }

        }
        
        
    return true
        
    }
    
  

}

