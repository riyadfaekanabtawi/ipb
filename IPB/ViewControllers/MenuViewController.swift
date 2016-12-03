//
//  MenuViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 11/28/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit


protocol MenuViewControllerDelegate {
    func selectedMenuviewcontrollerOption(_ option:String)
}
class MenuViewController: UIViewController {

    @IBOutlet var menuHeight: NSLayoutConstraint!
    @IBOutlet var image_user: UIImageView!
    @IBOutlet var user_nameLabel: UILabel!
    @IBOutlet var user_puestoLabel: UILabel!
    var delegate:MenuViewControllerDelegate!
    @IBOutlet var recursos_label: UILabel!
    @IBOutlet var plantas_label: UILabel!
    @IBOutlet var cortes_label: UILabel!
    @IBOutlet var clientes_label: UILabel!
    @IBOutlet var estilos_label: UILabel!
    @IBOutlet var salir_label: UILabel!
    
    
    @IBOutlet var recursos_innerView: UIView!
    @IBOutlet var plantas_innerView: UIView!
    @IBOutlet var cortes_innerView: UIView!
    @IBOutlet var clientes_innerView: UIView!
    @IBOutlet var estilos_innerView: UIView!
    @IBOutlet var salir_innerView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.menuHeight.constant = self.view.frame.size.height
        self.view.layoutIfNeeded()
        
        self.setNeedsStatusBarAppearanceUpdate()
        
        self.recursos_label.font = UIFont(name: FONT_REGULAR, size: self.recursos_label.font.pointSize)
        self.plantas_label.font = UIFont(name: FONT_REGULAR, size: self.plantas_label.font.pointSize)
        self.cortes_label.font = UIFont(name: FONT_REGULAR, size: self.cortes_label.font.pointSize)
        self.clientes_label.font = UIFont(name: FONT_REGULAR, size: self.clientes_label.font.pointSize)
        self.estilos_label.font = UIFont(name: FONT_REGULAR, size: self.estilos_label.font.pointSize)
        self.salir_label.font = UIFont(name: FONT_REGULAR, size: self.salir_label.font.pointSize)
        
        self.recursos_innerView.alpha = 0
        self.plantas_innerView.alpha = 0
        self.cortes_innerView.alpha = 0
        self.clientes_innerView.alpha = 0
        self.estilos_innerView.alpha = 0
        self.salir_innerView.alpha = 0
        
        self.user_nameLabel.font = UIFont(name: FONT_BOLD, size: self.user_nameLabel.font.pointSize)
        self.user_puestoLabel.font = UIFont(name: FONT_LIGHT, size: self.user_puestoLabel.font.pointSize)
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            return .lightContent
        }
    }
    
    
    
    func refrsh(){
        
        
        let user = NSKeyedUnarchiver.unarchiveObject(with: (UserDefaults.standard.object(forKey: "user_main")as!NSData) as Data)as!User
    
        self.image_user.sd_setImage(with: (URL(string:user.avatar_url)) as URL!)
        
        self.user_nameLabel.text = user.nombre + " " + user.apellido
        self.user_puestoLabel.text = user.puesto
    
    
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    @IBAction func recursosTouchUpInside(){
    
        UIView.animate(withDuration: 0.4) {
            
            self.recursos_innerView.alpha = 1
            self.plantas_innerView.alpha = 0
            self.cortes_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.salir_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("recursos")    
        }
 
    
    }

    
    
    @IBAction func plantasTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
            
            self.recursos_innerView.alpha = 0
            self.plantas_innerView.alpha = 1
            self.cortes_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.salir_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("plantas")
        }
        
        
    }
    
    
    
    
    @IBAction func cortesTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
            
            self.recursos_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.cortes_innerView.alpha = 1
            self.clientes_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.salir_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("pendingcuts")
        }
        
        
    }
    
    
    @IBAction func clientesTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
            
            self.recursos_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.cortes_innerView.alpha = 0
            self.clientes_innerView.alpha = 1
            self.estilos_innerView.alpha = 0
            self.salir_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("clientes")
        }
        
        
    }
    
    
    @IBAction func estilosTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
            
            self.recursos_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.cortes_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.estilos_innerView.alpha = 1
            self.salir_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("estilos")
        }
        
        
    }
    
    @IBAction func salirTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
            
            self.recursos_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.cortes_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.salir_innerView.alpha = 1
            
            self.delegate.selectedMenuviewcontrollerOption("salir")
        }
        
        
    }
    
    
    
}
