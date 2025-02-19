//
//  ProveedoresViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 1/5/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//


import UIKit
import MessageUI
class ProveedoresViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,UITextFieldDelegate,clientdelegateHome,MFMailComposeViewControllerDelegate {
    var clients_array:[Proveedores] = []
    @IBOutlet var titleViewLabelColelctionView: UILabel!
    @IBOutlet var titleViewLabel: UILabel!
    
    var editingclient = false
    @IBOutlet var BackaddPlantview: UIView!
    @IBOutlet var addPlantview: UIView!
    @IBOutlet var addplantLabelTitle: UILabel!
    @IBOutlet var plantNameLabel: UILabel!
    
    @IBOutlet var guardarButton: UIButton!
    @IBOutlet var plantNameTextField: UITextField!
    
    @IBOutlet var closeButton: UIButton!
    
    @IBOutlet var puesto_contacto1: UITextField!
    @IBOutlet var puesto_contacto2: UITextField!
    @IBOutlet var puesto_contacto3: UITextField!
    
    @IBOutlet var direccion: UITextField!
    @IBOutlet var nombre_contacto1: UITextField!
    @IBOutlet var email_contacto1: UITextField!
    @IBOutlet var telefono_contacto1: UITextField!
    @IBOutlet var nombre_contacto2: UITextField!
    @IBOutlet var email_contacto2: UITextField!
    @IBOutlet var telefono_contacto2: UITextField!
    @IBOutlet var nombre_contacto3: UITextField!
    @IBOutlet var email_contacto3: UITextField!
    @IBOutlet var telefono_contacto3: UITextField!
    var  selectedclient:Proveedores!
    
    @IBOutlet var plant_collectionview: UICollectionView!
    var revealController:SWRevealViewController!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.direccion.font = UIFont(name: FONT_REGULAR, size: (self.direccion.font?.pointSize)!)
        
        self.nombre_contacto1.font = UIFont(name: FONT_REGULAR, size: (self.nombre_contacto1.font?.pointSize)!)
        self.email_contacto1.font = UIFont(name: FONT_REGULAR, size: (self.email_contacto1.font?.pointSize)!)
        self.telefono_contacto1.font = UIFont(name: FONT_REGULAR, size: (self.telefono_contacto1.font?.pointSize)!)
        self.nombre_contacto2.font = UIFont(name: FONT_REGULAR, size: (self.nombre_contacto2.font?.pointSize)!)
        self.email_contacto2.font = UIFont(name: FONT_REGULAR, size: (self.email_contacto2.font?.pointSize)!)
        self.telefono_contacto2.font = UIFont(name: FONT_REGULAR, size: (self.telefono_contacto2.font?.pointSize)!)
        self.nombre_contacto3.font = UIFont(name: FONT_REGULAR, size: (self.nombre_contacto3.font?.pointSize)!)
        self.email_contacto3.font = UIFont(name: FONT_REGULAR, size: (self.email_contacto3.font?.pointSize)!)
        self.telefono_contacto3.font = UIFont(name: FONT_REGULAR, size: (self.telefono_contacto3.font?.pointSize)!)
        
        
        self.puesto_contacto1.font = UIFont(name: FONT_REGULAR, size: (self.puesto_contacto1.font?.pointSize)!)
        self.puesto_contacto3.font = UIFont(name: FONT_REGULAR, size: (self.puesto_contacto3.font?.pointSize)!)
        self.puesto_contacto2.font = UIFont(name: FONT_REGULAR, size: (self.puesto_contacto2.font?.pointSize)!)
        
        
        
        
        
        self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        NotificationCenter.default.addObserver(self, selector: #selector(ProveedoresViewController.keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ProveedoresViewController.keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        self.BackaddPlantview.alpha = 0
        
        self.titleViewLabelColelctionView.font = UIFont(name: FONT_BOLD, size: self.titleViewLabelColelctionView.font.pointSize)
        
        self.addplantLabelTitle.font = UIFont(name: FONT_BOLD, size: self.addplantLabelTitle.font.pointSize)
       
        self.plantNameTextField.font = UIFont(name: FONT_REGULAR, size: (self.plantNameTextField.font?.pointSize)!)
        
        self.guardarButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.guardarButton.titleLabel?.font.pointSize)!)
        self.addPlantview.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.addPlantview.alpha = 0
        
        
        self.refreshHomePlants()
        self.titleViewLabel.font = UIFont(name: FONT_BOLD, size: self.titleViewLabel.font.pointSize)
        
        
        self.addPlantview.layer.cornerRadius = 4
        self.addPlantview.layer.masksToBounds = true
        
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
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
    
    func keyboardWillShow(notification: NSNotification) {
        
        
    }
    
    func keyboardWillHide(notification: NSNotification) {
        
    }
    
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if self.plantNameTextField == textField{
            
            self.direccion.becomeFirstResponder()
        }
        if self.direccion == textField{
            
            self.nombre_contacto1.becomeFirstResponder()
        }
        
        if self.nombre_contacto1 == textField{
            
            self.email_contacto1.becomeFirstResponder()
        }
        
        if self.email_contacto1 == textField{
            
            self.telefono_contacto1.becomeFirstResponder()
        }
        
        
        if self.telefono_contacto1 == textField{
            
            self.puesto_contacto1.becomeFirstResponder()
            
        }
        
        if self.puesto_contacto1 == textField{
            
            self.nombre_contacto2.becomeFirstResponder()
            
        }
        
        if self.nombre_contacto2 == textField{
            
            self.email_contacto2.becomeFirstResponder()
            
        }
        
        
        if self.email_contacto2 == textField{
            
            self.telefono_contacto2.becomeFirstResponder()
            
        }
        
        
        if self.telefono_contacto2 == textField{
            
            self.puesto_contacto2.becomeFirstResponder()
            
        }
        if self.puesto_contacto2 == textField{
            
            self.nombre_contacto3.becomeFirstResponder()
            
        }
        
        if self.nombre_contacto3 == textField{
            
            self.email_contacto3.becomeFirstResponder()
            
        }
        
        
        if self.email_contacto3 == textField{
            
            self.telefono_contacto3.becomeFirstResponder()
            
        }
        
        
        if self.telefono_contacto3 == textField{
            
            self.puesto_contacto3.becomeFirstResponder()
            
        }
        
        
        if self.puesto_contacto3 == textField{
            
            self.puesto_contacto3.resignFirstResponder()
            
        }
        
        
        return true
    }
    
    
    
    
    func showAddPlantView(){
   
        if self.editingclient == true{
                 self.addplantLabelTitle.text = "ACTUALIZAR PROVEEDOR"
            if self.selectedclient.nombrecontacto3 != nil{
                self.nombre_contacto3.text = self.selectedclient.nombrecontacto3
            }
            if self.selectedclient.nombrecontacto1 != nil{
                self.nombre_contacto1.text = self.selectedclient.nombrecontacto1
            }
            if self.selectedclient.nombrecontacto2 != nil{
                self.nombre_contacto2.text = self.selectedclient.nombrecontacto2
            }
            if self.selectedclient.direccion != nil{
                self.direccion.text = self.selectedclient.direccion
            }
            
            
            if  self.selectedclient.emailcontacto2 != nil{
                
                self.email_contacto2.text = self.selectedclient.emailcontacto2
            }
            if self.selectedclient.emailcontacto1 != nil{
                self.email_contacto1.text = self.selectedclient.emailcontacto1
            }
            
            if self.selectedclient.emailcontacto3 != nil{
                self.email_contacto3.text = self.selectedclient.emailcontacto3
            }
            
            if  self.selectedclient.telefonocontacto3 != nil{
                
                self.telefono_contacto3.text = self.selectedclient.telefonocontacto3
            }
            
            if self.selectedclient.telefonocontacto2 != nil{
                
                self.telefono_contacto2.text = self.selectedclient.telefonocontacto2
            }
            
            if self.selectedclient.telefonocontacto1 != nil{
                self.telefono_contacto1.text = self.selectedclient.telefonocontacto1
                
            }
            
            
            if  self.selectedclient.puestocontacto3 != nil{
                
                self.puesto_contacto3.text = self.selectedclient.puestocontacto3
            }
            
            if self.selectedclient.puestocontacto2 != nil{
                
                self.puesto_contacto2.text = self.selectedclient.puestocontacto2
            }
            
            if self.selectedclient.puestocontacto1 != nil{
                self.puesto_contacto1.text = self.selectedclient.puestocontacto1
                
            }
            
            
            self.plantNameTextField.text = self.selectedclient.client_name
            
        }else{
            self.puesto_contacto1.text = "";
            self.puesto_contacto2.text = ""
            self.puesto_contacto3.text = ""
            
            self.telefono_contacto1.text = ""
            self.telefono_contacto2.text  = ""
            self.telefono_contacto3.text = ""
            
            self.email_contacto1.text = ""
            self.email_contacto2.text  = ""
            self.email_contacto3.text = ""
            
            self.nombre_contacto1.text = ""
            self.nombre_contacto2.text  = ""
            self.nombre_contacto3.text = ""
            
            self.direccion.text = ""
            self.plantNameTextField.text  = ""
            self.addplantLabelTitle.text = "NUEVO PROVEEDOR"
            
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
        
        
        self.plantNameTextField.resignFirstResponder()
        self.nombre_contacto1.resignFirstResponder()
        self.nombre_contacto2.resignFirstResponder()
        self.nombre_contacto3.resignFirstResponder()
        self.email_contacto1.resignFirstResponder()
        self.email_contacto2.resignFirstResponder()
        self.email_contacto3.resignFirstResponder()
        
        self.telefono_contacto1.resignFirstResponder()
        self.telefono_contacto2.resignFirstResponder()
        self.telefono_contacto3.resignFirstResponder()
        
        self.puesto_contacto1.resignFirstResponder()
        self.puesto_contacto2.resignFirstResponder()
        self.puesto_contacto3.resignFirstResponder()
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
      
            self.editingclient = true
            self.selectedclient = self.clients_array[indexPath.row]
            
            self.showAddPlantView()
    
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.clients_array.count
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
        
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "clients", for: indexPath) as! ClientCollectionViewCell
        
        
        cell.displayProveedor(client: self.clients_array[indexPath.row])
        cell.delegate = self
        cell.controller = self
        return cell
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: collectionView.frame.size.width, height: 150)
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
        
        
        Services.getProveedoresWithandHandler({ (response) in
            
            self.clients_array = response as! [Proveedores]
            
            
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
    
  
       @IBAction func newProveedor(){
      
        self.editingclient = false
          self.showAddPlantView()
        
    }
    @IBAction func saveClientInfoAndCreate(){
        
        
        
        if self.plantNameTextField.text == "" {
            let alertController = UIAlertController(title: "Oops!", message: "Debes llenar el nombre de proveedor por lo menos para agregarlo", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
        }else{
            
            if self.editingclient{
                let alertController = UIAlertController(title: "Atencion!", message: "Está por actualizar el proveedor: \(self.plantNameTextField.text!)", preferredStyle: .alert)
                
                
                let OKAction = UIAlertAction(title: "Actualizar Proveedor", style: .default) { (action) in
                    
                    let loader  = SBTVLoaderView.create()
                    
                    let window = UIApplication.shared.keyWindow
                    let sub =   (window?.subviews[0])! as UIView
                    
                    Functions.fillContainerView(sub, with: loader)
                    
        
                    
                    Services.updateProveedor(forIPB: self.plantNameTextField.text, andID:self.selectedclient.client_id,andContactName1: self.nombre_contacto1.text,andContactEmail1: self.email_contacto1.text,andContactTelefone1:self.telefono_contacto1.text, andContactName2:self.nombre_contacto2.text, andContactEmail2:self.email_contacto2.text, andContactTelefone2:self.telefono_contacto2.text, andContactName3:self.nombre_contacto3.text, andContactEmail3:self.email_contacto3.text, andContactTelefone3:self.telefono_contacto3.text, andContactPuesto1:self.puesto_contacto1.text,andContactPuesto2:self.puesto_contacto2.text,andContactPuesto3:self.puesto_contacto3.text, andDireccion: self.direccion.text, andHandler: { (response) in
                        
                        self.closeAddPlantView()
                        self.refreshHomePlants()
                        let alertController = UIAlertController(title: "Bien!", message: "Actualizaste el proveedor: \(self.plantNameTextField.text!)", preferredStyle: .alert)
                        
                        
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
                
                let cancelAction = UIAlertAction(title: "Cancelar", style: .default) { (action) in
                    
                    alertController.dismiss(animated: true, completion: nil)
                    
                }
                    alertController.addAction(OKAction)
                alertController.addAction(cancelAction)
                
                self.present(alertController, animated: true) {
                    // ...
                }
                
                

            
            }else{
            
                let alertController = UIAlertController(title: "Atencion!", message: "Está por cargar el proveedor: \(self.plantNameTextField.text!)", preferredStyle: .alert)
                
                
                let OKAction = UIAlertAction(title: "Cargar Proveedor", style: .default) { (action) in
                    let loader  = SBTVLoaderView.create()
                    
                    let window = UIApplication.shared.keyWindow
                    let sub =   (window?.subviews[0])! as UIView
                    
                    Functions.fillContainerView(sub, with: loader)
                    
                    
                    Services.createProveedor(forIPB: self.plantNameTextField.text,andContactName1: self.nombre_contacto1.text,andContactEmail1: self.email_contacto1.text,andContactTelefone1:self.telefono_contacto1.text, andContactName2:self.nombre_contacto2.text, andContactEmail2:self.email_contacto2.text, andContactTelefone2:self.telefono_contacto2.text, andContactName3:self.nombre_contacto3.text, andContactEmail3:self.email_contacto3.text, andContactTelefone3:self.telefono_contacto3.text, andContactPuesto1:self.puesto_contacto1.text,andContactPuesto2:self.puesto_contacto2.text,andContactPuesto3:self.puesto_contacto3.text, andDireccion: self.direccion.text, andHandler: { (response) in
                        
                        self.closeAddPlantView()
                        self.refreshHomePlants()
                        let alertController = UIAlertController(title: "Bien!", message: "Cargaste el proveedor: \(self.plantNameTextField.text!)", preferredStyle: .alert)
                        
                        
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
                
                let cancelAction = UIAlertAction(title: "Cancelar", style: .default) { (action) in
                    
                    alertController.dismiss(animated: true, completion: nil)
                    
                }
                alertController.addAction(OKAction)
                  alertController.addAction(cancelAction)
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
    
    func sendemailP(client: Proveedores) {
        self.selectedclient = client
        let mailComposeViewController = configuredMailComposeViewController()
        if MFMailComposeViewController.canSendMail() {
            self.present(mailComposeViewController, animated: true, completion: nil)
        } else {
            self.showSendMailErrorAlert()
        }
    }
    
    func sendemail(client: Cliente) {
     
    }
    
    
    func configuredMailComposeViewController() -> MFMailComposeViewController {
        let mailComposerVC = MFMailComposeViewController()
        mailComposerVC.mailComposeDelegate = self // Extremely important to set the --mailComposeDelegate-- property, NOT the --delegate-- property
        
        mailComposerVC.setToRecipients(["\(self.selectedclient.emailcontacto1!.lowercased())","\(self.selectedclient.emailcontacto2!.lowercased())","\(self.selectedclient.emailcontacto3!.lowercased())"])
        
        
        return mailComposerVC
    }
    
    func showSendMailErrorAlert() {
        let sendMailErrorAlert = UIAlertView(title: "Oops", message: "No pudimos enviar el email, tu dispositivo no tiene cuenta de e-mail configurada.", delegate: self, cancelButtonTitle: "OK")
        sendMailErrorAlert.show()
    }
    
    // MARK: MFMailComposeViewControllerDelegate Method
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }

    
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
        
    {
        
        if (self.telefono_contacto1 == textField || self.telefono_contacto2 == textField || self.telefono_contacto3 == textField){
            let nsString = textField.text as NSString?
            let text = nsString?.replacingCharacters(in: range, with: string)
            
            
            if Int(text!) != nil || text == ""{
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
