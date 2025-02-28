//
//  PlantasViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/12/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class PlantasViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,UITextFieldDelegate,plantdelegateHome {
    var plants_array:[Planta] = []
    @IBOutlet var titleViewLabelColelctionView: UILabel!
    @IBOutlet var titleViewLabel: UILabel!

    var editarPlanta = false
    @IBOutlet var BackaddPlantview: UIView!
    @IBOutlet var addPlantview: UIView!
    @IBOutlet var addplantLabelTitle: UILabel!
    @IBOutlet var plantNameLabel: UILabel!
    @IBOutlet var plantCapaxMaxLabel: UILabel!
    @IBOutlet var guardarButton: UIButton!
    @IBOutlet var plantNameTextField: UITextField!
    @IBOutlet var plantCapaxMaxTextField: UITextField!
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var plant_collectionview: UICollectionView!
    var selectedPlant:Planta!
    var revealController:SWRevealViewController!
    override func viewDidLoad() {
        super.viewDidLoad()
        
                self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        NotificationCenter.default.addObserver(self, selector: #selector(PlantasViewController.keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PlantasViewController.keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
         self.BackaddPlantview.alpha = 0
        
        self.titleViewLabelColelctionView.font = UIFont(name: FONT_BOLD, size: self.titleViewLabelColelctionView.font.pointSize)
        
        self.addplantLabelTitle.font = UIFont(name: FONT_BOLD, size: self.addplantLabelTitle.font.pointSize)
        self.plantNameLabel.font = UIFont(name: FONT_BOLD, size: self.plantNameLabel.font.pointSize)
        self.plantCapaxMaxLabel.font = UIFont(name: FONT_BOLD, size: self.plantCapaxMaxLabel.font.pointSize)
        
        self.plantCapaxMaxTextField.font = UIFont(name: FONT_REGULAR, size: (self.plantCapaxMaxTextField.font?.pointSize)!)
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
        
        if !self.plantNameTextField.isEditing{
            
            if ((notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
                self.view.frame.origin.y -= 150
            }
        }
        
        
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if !self.plantNameTextField.isEditing{
            
            if ((notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
                self.view.frame.origin.y += 150
            }
        }
    }
    
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if self.plantNameTextField == textField{
        
        self.plantCapaxMaxTextField.becomeFirstResponder()
        }
        
        if self.plantCapaxMaxTextField == textField{
            
              self.plantCapaxMaxTextField.resignFirstResponder()
            self.plantNameTextField.resignFirstResponder()
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
        
        self.plantCapaxMaxTextField.resignFirstResponder()
        self.plantNameTextField.resignFirstResponder()
    
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
   
             self.addplantLabelTitle.text = "EDITAR PLANTA"
            self.editarPlanta = true
 
            
            let plant = self.plants_array[indexPath.row]
            self.selectedPlant = plant
            
            if (plant.planta_nombre != nil){
            self.plantNameTextField.text = plant.planta_nombre
                
            }
            
            if (plant.planta_capacidadMax != nil){
            
            self.plantCapaxMaxTextField.text = "\(plant.planta_capacidadMax!)"
            }
            
            

        
        
        self.showAddPlantView()
        
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.plants_array.count
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
        
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "homeplant", for: indexPath) as! PlantHomeCollectionViewCell
        
        
        cell.displayPlants(plant: self.plants_array[indexPath.row])
        cell.delegate = self
        cell.controller = self
        return cell
        
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: collectionView.layer.frame.size.width, height: 120)
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
    
    
 
      @IBAction func newPlant (){
        self.editarPlanta = false
        self.addplantLabelTitle.text = "NUEVA PLANTA"
        self.plantCapaxMaxTextField.text = ""
        self.plantNameTextField.text = ""
               self.showAddPlantView()
        
    }
    
    @IBAction func savePlantInfoAndCreate(){
        
        
        
        if self.plantNameTextField.text == "" || self.plantCapaxMaxTextField.text == ""{
            let alertController = UIAlertController(title: "Oops!", message: "Debes llenar todos los campos para crear una planta", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
        
        }else{
        
            if self.editarPlanta{
            
                
              
                
                let alertController = UIAlertController(title: "Atencion!", message: "Está por actualizar la planta: \(self.plantNameTextField.text!) con capacidad máxima de: $ \(self.plantCapaxMaxTextField.text!), está seguro?", preferredStyle: .alert)
                
                
                let OKAction = UIAlertAction(title: "Actualizar Planta", style: .default) { (action) in
                    
                    let loader  = SBTVLoaderView.create()
                    
                    let window = UIApplication.shared.keyWindow
                    let sub =   (window?.subviews[0])! as UIView
                    
                    Functions.fillContainerView(sub, with: loader)
                    
                    
                    Services.updatePlant(forIPB: self.plantNameTextField.text, andPlantID: self.selectedPlant.planta_id, andCapacityMax: NSNumber(value:Int32(self.plantCapaxMaxTextField.text!)!), andHandler: { (response) in
                        self.closeAddPlantView()
                        self.refreshHomePlants()
                        let alertController = UIAlertController(title: "Bien!", message: "Actualizaste la planta: \(self.plantNameTextField.text!)", preferredStyle: .alert)
                        
                        
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
                
            
            }else{
                
                
                
            let alertController = UIAlertController(title: "Atencion!", message: "Está por crear la planta: \(self.plantNameTextField.text!) con capacidad máxima de: $ \(self.plantCapaxMaxTextField.text!), está seguro?", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "Crear Planta", style: .default) { (action) in
                let loader  = SBTVLoaderView.create()
                
                let window = UIApplication.shared.keyWindow
                let sub =   (window?.subviews[0])! as UIView
                
                Functions.fillContainerView(sub, with: loader)
                
                Services.createPlant(forIPB: self.plantNameTextField.text, andCapacityMax: NSNumber(value:Int32(self.plantCapaxMaxTextField.text!)!), andHandler: { (response) in
                    
                    self.closeAddPlantView()
                    self.refreshHomePlants()
                    let alertController = UIAlertController(title: "Bien!", message: "Creaste la planta: \(self.plantNameTextField.text!)", preferredStyle: .alert)
                    
                    
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
