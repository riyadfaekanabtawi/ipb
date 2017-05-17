//
//  CutsViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/2/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class CutsViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,asignDelegate,pendingCutdelegate,SWRevealViewControllerDelegate,MenuViewControllerDelegate {
    
    @IBOutlet var styleImageView: UIImageView!
    @IBOutlet var BackaddPlantview: UIView!
    @IBOutlet var imageViewBig: UIView!
    @IBOutlet var imagenTitle: UILabel!
    var revealController:SWRevealViewController!
    @IBOutlet var backButton: UIView!
    @IBOutlet var menuButton: UIView!
     @IBOutlet var refreshIcon: UIButton!
    
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var cortesTitle: UILabel!
    @IBOutlet var noCutsLabel: UILabel!
    @IBOutlet var cuts_collectionview: UICollectionView!
    var pending_cuts_array:[PendingCut] = []
    var selected_cut:PendingCut!
    
    
    override func viewDidLoad() {
        
        self.imageViewBig.layer.cornerRadius = 4
        self.imageViewBig.layer.masksToBounds = true
        super.viewDidLoad()
        
         self.imagenTitle.font = UIFont(name: FONT_BOLD, size: self.imagenTitle.font.pointSize)
        
        
        let user = NSKeyedUnarchiver.unarchiveObject(with: (UserDefaults.standard.object(forKey: "user_main")as!NSData) as Data)as!User
    
        
           if (user.puesto == "Administrador"){
            
            self.backButton.isHidden = false
            self.menuButton.isHidden = true
           }else{
            self.backButton.isHidden = true
            self.menuButton.isHidden = false
            self.slideMenuSetUp()
        
            }
        self.BackaddPlantview.alpha = 0
        self.imageViewBig.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.imageViewBig.alpha = 0
        self.cortesTitle.font = UIFont(name: FONT_BOLD, size: self.cortesTitle.font.pointSize)
        self.noCutsLabel.font = UIFont(name: FONT_BOLD, size: self.noCutsLabel.font.pointSize)
        
        self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)!
        
        
        self.noCutsLabel.alpha = 0
        self.cuts_collectionview.alpha = 0
        self.cuts_collectionview.layer.cornerRadius = 4
        self.cuts_collectionview.layer.masksToBounds = true
        self.getPendingCuts()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func slideMenuSetUp(){
        
        self.revealController = self.revealViewController()
        
        if (self.revealController != nil){
            
            self.revealController.delegate = self
            self.revealController.toggleAnimationDuration=1;
            self.revealController.rearViewRevealWidth=250;
            
            
            let menu = self.revealController.rearViewController as! MenuViewController
            
            menu.delegate = self
            
        }
        
    }
    func selectedMenuviewcontrollerOption(_ option: String) {
        
        
        let revealController = self.revealController
        
        
        if revealController != nil{
            
            revealController?.revealToggle(animated: true)
            
        }
        
        
        if option == "cerrar_sesion"{
            
            let defaults = UserDefaults.standard
            
            defaults.removeObject(forKey: "user_main")
            defaults.synchronize()
            
            self.navigationController?.popToRootViewController(animated: true)
            
            
        }
        
        
        if option == "envios"{
            
            self.performSegue(withIdentifier: option, sender: self)
        }
        
        if option == "reportsall"{
            
           // self.performSegue(withIdentifier: option, sender: self)
        }
        
      
        
        if option == "reportes"{
            
          self.performSegue(withIdentifier: option, sender: self)
        }
        
        if option == "listas"{
            
            //self.performSegue(withIdentifier: "pendingcuts", sender: self)
            
        }
        
        if option == "dashboard"{
            
            //self.refreshHomePlants ()
        }
        if option == "plantas"{
            
            //self.performSegue(withIdentifier: option, sender: self)
            
        }
        
        
        if option == "clientes"{
            //self.performSegue(withIdentifier: "clients", sender: self)
            
        }
        
        
        if option == "calculadora"{
           // self.performSegue(withIdentifier: option, sender: self)
            
        }
        
        
        if option == "proyectos"{
            
           // self.performSegue(withIdentifier: option, sender: self)
        }
        
        
        if option == "estilos"{
            
           // self.performSegue(withIdentifier: option, sender: self)
        }
        
        if option == "usuarios"{
           // self.performSegue(withIdentifier: option, sender: self)
            
        }
        if option == "pendingcuts"{
            
           // self.performSegue(withIdentifier: option, sender: self)
        }
        
        if option == "proveedores"{
            //self.performSegue(withIdentifier: option, sender: self)
            
        }
        
    }
     @IBAction func refreshTUI(){
        Functions.runSpinAnimation(on: self.refreshIcon, duration: 0.6, rotations: 1, repeat: 0)
    self.getPendingCuts()
        
        
    }
    
    @IBAction func openMenu(){
        
        let revealController = self.revealController
        
        
        if revealController != nil{
            
            revealController?.revealToggle(animated: true)
            
        }
        
    }
    
    
    func revealController(_ revealController: SWRevealViewController!, animateTo position: FrontViewPosition) {
        
        
        if position == FrontViewPosition.left{
          
            
        }
        
        
        
        
        if position == FrontViewPosition.right{
            
            let menu = revealController.rearViewController as! MenuViewController
            menu.refrsh()
          
            
        }
    }

    
    func getPendingCuts(){
    
        let loader  = SBTVLoaderView.create()
        
        let window = UIApplication.shared.keyWindow
        let sub =   (window?.subviews[0])! as UIView
        
        Functions.fillContainerView(sub, with: loader)
        
        
    Services.getPendingCutsWithandHandler({ (response) in
        
        self.pending_cuts_array = response as! [PendingCut]
        
        if self.pending_cuts_array.count != 0{
            self.noCutsLabel.alpha = 0
            self.cuts_collectionview.alpha = 1
            self.cuts_collectionview.reloadData()
        
        }else{
            self.noCutsLabel.alpha = 1
            
            self.cuts_collectionview.alpha = 0
        
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

    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        
        self.selected_cut = self.pending_cuts_array[indexPath.row]
        self.performSegue(withIdentifier: "asignar", sender: self)
        
        
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.pending_cuts_array.count
    }
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 1
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cortes_pending", for: indexPath) as! PendingCutCollectionViewCell
        
        cell.displayPendingCut(cut: self.pending_cuts_array[indexPath.row])
        cell.delegate = self
        
        return cell
        
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.cuts_collectionview.frame.size.width-10, height: 66)
    }
    
    @IBAction func goBack(){
    
    self.navigationController?.popViewController(animated: true)
    
    }
    
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "asignar"{
        
        let controller = segue.destination as! AsignCutViewController
            
        controller.pendingCut = self.selected_cut
        controller.delegate = self
        }
        
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
    
    func asignedCut() {
        self.getPendingCuts()
    }
    
    
}
