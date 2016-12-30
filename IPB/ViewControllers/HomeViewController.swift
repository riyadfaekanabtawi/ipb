//
//  HomeViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 11/28/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController,SWRevealViewControllerDelegate,MenuViewControllerDelegate,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout {
    var plants_array:[Planta] = []
    var enviosUrgentesArray:[PendingCut] = []
    var pending_cuts_array:[PendingCut] = []
    @IBOutlet var titleViewLabelColelctionView: UILabel!
    @IBOutlet var enviosUrgentesLabel: UILabel!
    @IBOutlet var titleViewLabel: UILabel!
    @IBOutlet var pendingCutsTitleLabel: UILabel!
    @IBOutlet var blockView: UIView!
     @IBOutlet var plant_collectionview: UICollectionView!
    @IBOutlet var enviosUrgentes_collectionview: UICollectionView!
    @IBOutlet var cortesPendientes_collectionview: UICollectionView!
    var revealController:SWRevealViewController!
    override func viewDidLoad() {
        super.viewDidLoad()

        
        self.titleViewLabelColelctionView.font = UIFont(name: FONT_BOLD, size: self.titleViewLabelColelctionView.font.pointSize)

        self.refreshHomePlants()
        self.titleViewLabel.font = UIFont(name: FONT_BOLD, size: self.titleViewLabel.font.pointSize)
        self.enviosUrgentesLabel.font = UIFont(name: FONT_BOLD, size: self.enviosUrgentesLabel.font.pointSize)
        self.pendingCutsTitleLabel.font = UIFont(name: FONT_BOLD, size: self.pendingCutsTitleLabel.font.pointSize)
        
                   self.blockView.alpha = 0
        self.slideMenuSetUp()
        
             self.setNeedsStatusBarAppearanceUpdate()
        self.navigationController?.navigationBar.barStyle = UIBarStyle.blackTranslucent
        //[self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        self.getUrgentEnvios()
        self.getPendingCuts()
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
  
    
    func revealController(_ revealController: SWRevealViewController!, animateTo position: FrontViewPosition) {
        
        
        if position == FrontViewPosition.left{
        self.blockView.alpha = 0.4
            UIView.animate(withDuration: 0.3) {
                self.blockView.alpha = 0.0
                
        
            }
            
        
        }
        
        
        
        
        if position == FrontViewPosition.right{
        
            self.blockView.alpha = 0
            
            let menu = revealController.rearViewController as! MenuViewController
            menu.refrsh()
            UIView.animate(withDuration: 0.3) {
                self.blockView.alpha = 0.4
                
                
            }
        
        }
    }
    
    
    
    @IBAction func blockViewTapper(){
        
        let revealController = self.revealController
        
        
        if revealController != nil{
        
        revealController?.revealToggle(animated: true)
            
        }
        
    }
    
    
    
    @IBAction func openMenu(){
        
        let revealController = self.revealController
        
        
        if revealController != nil{
            
            revealController?.revealToggle(animated: true)
            
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
            
            self.performSegue(withIdentifier: option, sender: self)
        }
        
        
        
        if option == "reportes"{
            
            self.performSegue(withIdentifier: option, sender: self)
        }
        
        if option == "listas"{
        
        self.performSegue(withIdentifier: "pendingcuts", sender: self)
        
        }
        
        if option == "dashboard"{
            
            self.refreshHomePlants ()
        }
        if option == "plantas"{
            
            self.performSegue(withIdentifier: option, sender: self)
            
        }
        
        
        if option == "clientes"{
          self.performSegue(withIdentifier: option, sender: self)
            
        }
        
        
        if option == "calculadora"{
              self.performSegue(withIdentifier: option, sender: self)
            
        }
        
     
        
  
        
        if option == "estilos"{
            
             self.performSegue(withIdentifier: option, sender: self)
        }
        
        if option == "usuarios"{
              self.performSegue(withIdentifier: option, sender: self)
            
        }
        if option == "pendingcuts"{
            
            self.performSegue(withIdentifier: option, sender: self)
        }
        
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
   
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if self.enviosUrgentes_collectionview == collectionView{
        
            return self.enviosUrgentesArray.count
        
        }else if self.cortesPendientes_collectionview == collectionView{
        
            return self.pending_cuts_array.count
        
        
        }else{
        return self.plants_array.count
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if self.enviosUrgentes_collectionview == collectionView{
        
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "urgent", for: indexPath)as!UrgentSebdsDashboardCollectionViewCell
            
            cell.displayCuts(cut: self.enviosUrgentesArray[indexPath.row])
            
            return cell
        }else if self.cortesPendientes_collectionview == collectionView{
        
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "pendingHome", for: indexPath)as!PendingHomecutCollectionViewCell
            
            cell.displayPendingcuts(cut: self.pending_cuts_array[indexPath
                .row])
            
            return cell
        
        
        }else{
     
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "homeplant", for: indexPath) as! PlantHomeCollectionViewCell
            
            
            cell.displayPlants(plant: self.plants_array[indexPath.row])
            return cell
        
        }
    
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
         if self.enviosUrgentes_collectionview == collectionView || self.cortesPendientes_collectionview == collectionView{
            
            
            return CGSize(width: 250 , height: 70)
        
        
         }else{
          return CGSize(width: self.plant_collectionview.layer.frame.size.width , height: self.plant_collectionview.layer.frame.size.width - 100)
        
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    
    func refreshHomePlants()
    
    {
    
    
    Services.getPlantsWithandHandler({ (response) in
        
        self.plants_array = response as! [Planta]
        
        
        self.plant_collectionview.reloadData()
        
    }, orErrorHandler: { (err) in
        
        
        
    })

    
    }
    
    
    func getUrgentEnvios()
        
    {
        
        
        Services.getEnviosUrgentesWithandHandler({ (response) in
            
            self.enviosUrgentesArray = response as! [PendingCut]
            
            
            self.enviosUrgentes_collectionview.reloadData()
            
        }, orErrorHandler: { (err) in
            
            
            
        })
        
        
    }
    
    
    func getPendingCuts()
        
    {
        
        
        Services.getPendingCutsWithandHandler({ (response) in
            
            self.pending_cuts_array = response as! [PendingCut]
            
            
            self.cortesPendientes_collectionview.reloadData()
            
        }, orErrorHandler: { (err) in
            
            
            
        })
        
        
    }

}
