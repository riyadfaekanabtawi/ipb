//
//  HomeViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 11/28/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController,SWRevealViewControllerDelegate,MenuViewControllerDelegate {

    @IBOutlet var blockView: UIView!
    @IBOutlet var firstWebView: UIWebView!
    var revealController:SWRevealViewController!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setNeedsStatusBarAppearanceUpdate()
        
        self.firstWebView.loadRequest(NSURLRequest(url: NSURL(string: "http://ipb.anabtatec-mobile.com/plants_graph")! as URL) as URLRequest)
           self.blockView.alpha = 0
        self.slideMenuSetUp()
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
        
    }
}
