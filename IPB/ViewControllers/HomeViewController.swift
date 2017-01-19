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
    var enviosUrgentesArray:[Corte] = []
    var pending_cuts_array:[PendingCut] = []
    
    
    var analisisCuts:[Corte] = []
    
    @IBOutlet var heightPlantsGraphs: NSLayoutConstraint!
    
    @IBOutlet var listo_confec: UILabel!
    @IBOutlet var mesa_corte: UILabel!
    @IBOutlet var enEspera: UILabel!
    
    @IBOutlet var listo_confecV: UIView!
    @IBOutlet var mesa_corteV: UIView!
    @IBOutlet var enEsperaV: UIView!
    
    
    
    @IBOutlet var analisisCorteLabel: UILabel!
    @IBOutlet var titleViewLabelColelctionView: UILabel!
    @IBOutlet var noEnviosLabel: UILabel!
    @IBOutlet var enviosUrgentesLabel: UILabel!
    @IBOutlet var titleViewLabel: UILabel!
    @IBOutlet var pendingCutsTitleLabel: UILabel!
    @IBOutlet var blockView: UIView!
     @IBOutlet var plant_collectionview: UICollectionView!
    @IBOutlet var enviosUrgentes_collectionview: UICollectionView!
    @IBOutlet var cortesPendientes_collectionview: UICollectionView!
    
        @IBOutlet var cortes_analisis_collectionview: UICollectionView!
    
    
    @IBOutlet var corteLabel: UILabel!
    @IBOutlet var clientLabel: UILabel!
    
    @IBOutlet var corteLabel2: UILabel!
    @IBOutlet var clientLabel2: UILabel!
    
    
    @IBOutlet var corteLabelCell: UILabel!
    @IBOutlet var cantidadLabelCell: UILabel!
    @IBOutlet var clienteLabelCell: UILabel!
    @IBOutlet var cortadasLabelCell: UILabel!
    
    
    
    var revealController:SWRevealViewController!
    
    var indicatorView1 : MAActivityIndicatorView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        self.corteLabelCell.font = UIFont(name: FONT_BOLD, size: self.corteLabelCell.font.pointSize)
        self.cantidadLabelCell.font = UIFont(name: FONT_BOLD, size: self.cantidadLabelCell.font.pointSize)
        self.clienteLabelCell.font = UIFont(name: FONT_BOLD, size: self.clienteLabelCell.font.pointSize)
        self.cortadasLabelCell.font = UIFont(name: FONT_BOLD, size: self.cortadasLabelCell.font.pointSize)
        
        

        self.listo_confecV.layer.cornerRadius = self.listo_confecV.frame.size.width/2
        self.listo_confecV.clipsToBounds = true
        
        self.mesa_corteV.layer.cornerRadius = self.mesa_corteV.frame.size.width/2
        self.mesa_corteV.clipsToBounds = true
        
        self.enEsperaV.layer.cornerRadius = self.enEsperaV.frame.size.width/2
        self.enEsperaV.clipsToBounds = true
        
        
         self.mesa_corte.font = UIFont(name: FONT_REGULAR, size: self.mesa_corte.font.pointSize)
         self.listo_confec.font = UIFont(name: FONT_REGULAR, size: self.listo_confec.font.pointSize)
         self.enEspera.font = UIFont(name: FONT_REGULAR, size: self.enEspera.font.pointSize)
        
        
        self.heightPlantsGraphs.constant = self.view.frame.size.height/2 + 30
        self.view.layoutIfNeeded()
        //self.showLoader()
        self.corteLabel2.font = UIFont(name: FONT_BOLD, size: self.corteLabel2.font.pointSize)
        
        self.clientLabel2.font = UIFont(name: FONT_BOLD, size: self.clientLabel2.font.pointSize)
        
         self.corteLabel.font = UIFont(name: FONT_BOLD, size: self.corteLabel.font.pointSize)
        
         self.clientLabel.font = UIFont(name: FONT_BOLD, size: self.clientLabel.font.pointSize)
        
        self.titleViewLabelColelctionView.font = UIFont(name: FONT_BOLD, size: self.titleViewLabelColelctionView.font.pointSize)
self.analisisCorteLabel.font = UIFont(name: FONT_BOLD, size: self.analisisCorteLabel.font.pointSize)
        
        self.refreshHomePlants()
        self.titleViewLabel.font = UIFont(name: FONT_BOLD, size: self.titleViewLabel.font.pointSize)
        self.enviosUrgentesLabel.font = UIFont(name: FONT_BOLD, size: self.enviosUrgentesLabel.font.pointSize)
        self.pendingCutsTitleLabel.font = UIFont(name: FONT_BOLD, size: self.pendingCutsTitleLabel.font.pointSize)
        
         self.noEnviosLabel.font = UIFont(name: FONT_REGULAR, size: self.noEnviosLabel.font.pointSize)
        self.noEnviosLabel.alpha = 0
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
        
        self.loadAnalisis()
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
          self.performSegue(withIdentifier: "clients", sender: self)
            
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
        
        if option == "proveedores"{
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
        
        
        }else if self.cortes_analisis_collectionview == collectionView{
        
        return self.analisisCuts.count
        }else{
        return self.plants_array.count
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if self.enviosUrgentes_collectionview == collectionView{
        
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "urgent", for: indexPath)as!UrgentSebdsDashboardCollectionViewCell
            
            cell.displayCorte(cut: self.enviosUrgentesArray[indexPath.row])
            
            return cell
        }else if self.cortesPendientes_collectionview == collectionView{
        
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "pendingHome", for: indexPath)as!PendingHomecutCollectionViewCell
            
            cell.displayPendingcuts(cut: self.pending_cuts_array[indexPath
                .row])
            
            return cell
        
        
        }else if collectionView == self.cortes_analisis_collectionview{
        
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "analisisCuts", for: indexPath)as!AnalisisCollectionViewCell
            
            cell.displayAnalisisCuts(cuts: self.analisisCuts[indexPath
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
            
            
            return CGSize(width: 250 , height: 50)
        
        
         }else if collectionView == self.cortes_analisis_collectionview{
          return CGSize(width: self.cortes_analisis_collectionview.frame.size.width-20 , height: 90)
         
         }else{
          return CGSize(width: self.plant_collectionview.layer.frame.size.width , height: self.view.frame.size.height/2)
        
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    
    func refreshHomePlants()
    
    {
    
        self.showLoader()
    
    Services.getPlantsWithandHandler({ (response) in
        
        self.plants_array = response as! [Planta]
        
        
        self.plant_collectionview.reloadData()
        self.hideLoader()
    }, orErrorHandler: { (err) in
        self.hideLoader()
        
        
    })

    
    }
    
    
    func hideLoader(){

    }
    func showLoader(){
        
    }
    
    
    func loadAnalisis(){
    
    
    Services.getAllcuts({ (response) in
        
        self.analisisCuts = response as! [Corte]
        
        self.cortes_analisis_collectionview.reloadData()
        
        
    }, orErrorHandler: { (err) in
        
        
        
    })
        
    }
    func getUrgentEnvios()
        
    {
        
        
        Services.getEnviosUrgentesWithandHandler({ (response) in
            
            self.enviosUrgentesArray = response as! [Corte]
            
            if self.enviosUrgentesArray .count == 0{
            self.noEnviosLabel.alpha = 1
                self.enviosUrgentes_collectionview.alpha = 0
            
            }else{
            
                self.noEnviosLabel.alpha = 0
                 self.enviosUrgentes_collectionview.alpha = 1
                self.enviosUrgentes_collectionview.reloadData()
                
            
            }
            
           
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
