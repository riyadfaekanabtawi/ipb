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
    @IBOutlet var titleViewLabelColelctionView: UILabel!
    @IBOutlet var titleViewLabel: UILabel!
    @IBOutlet var blockView: UIView!
     @IBOutlet var plant_collectionview: UICollectionView!
    var revealController:SWRevealViewController!
    override func viewDidLoad() {
        super.viewDidLoad()

        self.titleViewLabelColelctionView.font = UIFont(name: FONT_BOLD, size: self.titleViewLabelColelctionView.font.pointSize)

        self.refreshHomePlants()
        self.titleViewLabel.font = UIFont(name: FONT_BOLD, size: self.titleViewLabel.font.pointSize)
                   self.blockView.alpha = 0
        self.slideMenuSetUp()
        
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
        
        
        if option == "salir"{
        
            let defaults = UserDefaults.standard
            
            defaults.removeObject(forKey: "user_main")
            defaults.synchronize()
            
            self.navigationController?.popToRootViewController(animated: true)
            
        
        }
        
        if option == "recursos"{
            
            
        }
        
        
        if option == "plantas"{
            
            
        }
        
        
        if option == "clientes"{
            
            
        }
        
        
        if option == "estilos"{
            
            
        }
        
        
        if option == "pendingcuts"{
            
            self.performSegue(withIdentifier: option, sender: self)
        }
        
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.plants_array.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "homeplant", for: indexPath) as! PlantHomeCollectionViewCell
        
        
        cell.displayPlants(plant: self.plants_array[indexPath.row])
        return cell
    
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: self.plant_collectionview.layer.frame.size.width / 4, height: 300)
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
}
