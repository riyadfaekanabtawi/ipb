//
//  ClientesViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/12/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class ClientesViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,UITextFieldDelegate,clientdelegateHome {
    var clients_array:[Cliente] = []
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
    
    
    @IBOutlet var nombre_contacto1: UITextField!
    @IBOutlet var email_contacto1: UITextField!
    @IBOutlet var telefono_contacto1: UITextField!
    @IBOutlet var nombre_contacto2: UITextField!
    @IBOutlet var email_contacto2: UITextField!
    @IBOutlet var telefono_contacto2: UITextField!
    @IBOutlet var nombre_contacto3: UITextField!
    @IBOutlet var email_contacto3: UITextField!
    @IBOutlet var telefono_contacto3: UITextField!
    var  selectedclient:Cliente!
    
    @IBOutlet var plant_collectionview: UICollectionView!
    var revealController:SWRevealViewController!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        self.nombre_contacto1.font = UIFont(name: FONT_REGULAR, size: (self.nombre_contacto1.font?.pointSize)!)
        self.email_contacto1.font = UIFont(name: FONT_REGULAR, size: (self.email_contacto1.font?.pointSize)!)
        self.telefono_contacto1.font = UIFont(name: FONT_REGULAR, size: (self.telefono_contacto1.font?.pointSize)!)
        self.nombre_contacto2.font = UIFont(name: FONT_REGULAR, size: (self.nombre_contacto2.font?.pointSize)!)
        self.email_contacto2.font = UIFont(name: FONT_REGULAR, size: (self.email_contacto2.font?.pointSize)!)
        self.telefono_contacto2.font = UIFont(name: FONT_REGULAR, size: (self.telefono_contacto2.font?.pointSize)!)
        self.nombre_contacto3.font = UIFont(name: FONT_REGULAR, size: (self.nombre_contacto3.font?.pointSize)!)
        self.email_contacto3.font = UIFont(name: FONT_REGULAR, size: (self.email_contacto3.font?.pointSize)!)
        self.telefono_contacto3.font = UIFont(name: FONT_REGULAR, size: (self.telefono_contacto3.font?.pointSize)!)
        
        
        
        
         self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        NotificationCenter.default.addObserver(self, selector: #selector(ClientesViewController.keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ClientesViewController.keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        self.BackaddPlantview.alpha = 0
        
        self.titleViewLabelColelctionView.font = UIFont(name: FONT_BOLD, size: self.titleViewLabelColelctionView.font.pointSize)
        
        self.addplantLabelTitle.font = UIFont(name: FONT_BOLD, size: self.addplantLabelTitle.font.pointSize)
        self.plantNameLabel.font = UIFont(name: FONT_BOLD, size: self.plantNameLabel.font.pointSize)
   
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
            
             self.nombre_contacto1.becomeFirstResponder()
        }
        
        if self.nombre_contacto1 == textField{
        
        self.email_contacto1.becomeFirstResponder()
        }

        if self.email_contacto1 == textField{
        
        self.telefono_contacto1.becomeFirstResponder()
        }
        
        
        if self.telefono_contacto1 == textField{
        
        self.nombre_contacto2.becomeFirstResponder()
            
        }
        
        
        if self.nombre_contacto2 == textField{
        
        self.email_contacto2.becomeFirstResponder()
        
        }
        
        
        if self.email_contacto2 == textField{
        
        self.telefono_contacto2.becomeFirstResponder()
        
        }
        
        
        if self.telefono_contacto2 == textField{
        
        self.nombre_contacto3.becomeFirstResponder()
        
        }
        
        
        if self.nombre_contacto3 == textField{
        
            self.email_contacto3.becomeFirstResponder()
        
        }
        
        
        if self.email_contacto3 == textField{
        
        self.telefono_contacto3.becomeFirstResponder()
        
        }
        
        
        if self.telefono_contacto3 == textField{
        
            self.telefono_contacto3.resignFirstResponder()
        
        }
       
        
        
        
        return true
    }
    
    
    
    
    
    
    func showAddPlantView(){
        
        if self.editingclient == true{
        
            if self.selectedclient.nombrecontacto3 != nil{
            self.nombre_contacto3.text = self.selectedclient.nombrecontacto3
            }
            if self.selectedclient.nombrecontacto1 != nil{
            self.nombre_contacto1.text = self.selectedclient.nombrecontacto1
            }
            if self.selectedclient.nombrecontacto2 != nil{
            self.nombre_contacto2.text = self.selectedclient.nombrecontacto2
            }
            
            
            if  self.selectedclient.emailcontacto3 != nil{
            
            self.email_contacto3.text = self.selectedclient.emailcontacto3
            }
            if self.selectedclient.emailcontacto3 != nil{
            self.email_contacto3.text = self.selectedclient.emailcontacto3
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
       
            
            
            self.plantNameTextField.text = self.selectedclient.client_name
            
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
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if indexPath.row == 0{
            
            self.showAddPlantView()
            self.editingclient = false
        }else{
            self.editingclient = true
            self.selectedclient = self.clients_array[indexPath.row-1]
            
            self.showAddPlantView()
            
        }
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.clients_array.count + 1
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        
        if indexPath.row == 0{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ADD", for: indexPath)as!AddButtonCollectionViewCell
            
            return cell
            
        }else{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "clients", for: indexPath) as! ClientCollectionViewCell
            
            
            cell.displayClient(client: self.clients_array[indexPath.row - 1])
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
        
        
        Services.getClientsWithandHandler({ (response) in
            
            self.clients_array = response as! [Cliente]
            
            
            self.plant_collectionview.reloadData()
            
        }, orErrorHandler: { (err) in
            
            
            
        })
        
        
    }
    
    
    @IBAction func saveClientInfoAndCreate(){
        
        
        
        if self.plantNameTextField.text == "" || self.nombre_contacto1.text == "" || self.nombre_contacto2.text == ""  || self.nombre_contacto3.text == ""  || self.email_contacto1.text == "" || self.email_contacto2.text == "" || self.email_contacto3.text == "" || self.telefono_contacto1.text == "" || self.telefono_contacto2.text == "" || self.telefono_contacto3.text == "" {
            let alertController = UIAlertController(title: "Oops!", message: "Debes llenar todos los campos para cargar un cliente", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
        }else{
            
            
            let alertController = UIAlertController(title: "Atencion!", message: "Está por cargar el cliente: \(self.plantNameTextField.text!)", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "Cargar Cliente", style: .default) { (action) in
                
                Services.createClient(forIPB: self.plantNameTextField.text,andContactName1: self.nombre_contacto1.text,andContactEmail1: self.email_contacto1.text,andContactTelefone1:self.telefono_contacto1.text, andContactName2:self.nombre_contacto2.text, andContactEmail2:self.email_contacto2.text, andContactTelefone2:self.telefono_contacto2.text, andContactName3:self.nombre_contacto3.text, andContactEmail3:self.email_contacto3.text, andContactTelefone3:self.telefono_contacto3.text , andHandler: { (response) in
                    
                    self.closeAddPlantView()
                    self.refreshHomePlants()
                    let alertController = UIAlertController(title: "Bien!", message: "Cargaste el cliente: \(self.plantNameTextField.text!)", preferredStyle: .alert)
                    
                    
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
