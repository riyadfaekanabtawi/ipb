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
    
    
    @IBOutlet var reportesOverall: UILabel!
    @IBOutlet var dashboard_label: UILabel!
    @IBOutlet var lista_label: UILabel!
    @IBOutlet var reportes_label: UILabel!
    @IBOutlet var plantas_label: UILabel!
    @IBOutlet var clientes_label: UILabel!
    @IBOutlet var usuarios_label: UILabel!
    @IBOutlet var estilos_label: UILabel!
    @IBOutlet var envios_urgentes_label: UILabel!
    @IBOutlet var calculadora_label: UILabel!
    @IBOutlet var envios_label: UILabel!
    @IBOutlet var cerrarSesion_label: UILabel!
    @IBOutlet var RPOVERALL_innerView: UIView!
    @IBOutlet var dashboard_innerView: UIView!
    @IBOutlet var listas_innerView: UIView!
    @IBOutlet var reportes_innerView: UIView!
    @IBOutlet var plantas_innerView: UIView!
    @IBOutlet var clientes_innerView: UIView!
    @IBOutlet var usuarios_innerView: UIView!
    @IBOutlet var estilos_innerView: UIView!
    @IBOutlet var envios_urgentes_innerView: UIView!
    @IBOutlet var calculadora_innerView: UIView!
    @IBOutlet var envios_innerView: UIView!
    @IBOutlet var cerrarSesion_innerView: UIView!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.menuHeight.constant = self.view.frame.size.height
        self.view.layoutIfNeeded()
        
        self.setNeedsStatusBarAppearanceUpdate()
        
        self.dashboard_label.font = UIFont(name: FONT_REGULAR, size: self.dashboard_label.font.pointSize)
        self.lista_label.font = UIFont(name: FONT_REGULAR, size: self.lista_label.font.pointSize)
        self.reportes_label.font = UIFont(name: FONT_REGULAR, size: self.reportes_label.font.pointSize)
        self.plantas_label.font = UIFont(name: FONT_REGULAR, size: self.plantas_label.font.pointSize)
        self.clientes_label.font = UIFont(name: FONT_REGULAR, size: self.clientes_label.font.pointSize)
        self.usuarios_label.font = UIFont(name: FONT_REGULAR, size: self.usuarios_label.font.pointSize)
        self.estilos_label.font = UIFont(name: FONT_REGULAR, size: self.estilos_label.font.pointSize)
        self.envios_urgentes_label.font = UIFont(name: FONT_REGULAR, size: self.envios_urgentes_label.font.pointSize)
        
         self.reportesOverall.font = UIFont(name: FONT_REGULAR, size: self.reportesOverall.font.pointSize)
        
        self.calculadora_label.font = UIFont(name: FONT_REGULAR, size: self.calculadora_label.font.pointSize)
        self.envios_label.font = UIFont(name: FONT_REGULAR, size: self.envios_label.font.pointSize)
        self.cerrarSesion_label.font = UIFont(name: FONT_REGULAR, size: self.cerrarSesion_label.font.pointSize)
        
        self.RPOVERALL_innerView.alpha = 0
        self.dashboard_innerView.alpha = 0
        self.listas_innerView.alpha = 0
        self.reportes_innerView.alpha = 0
        self.plantas_innerView.alpha = 0
        self.clientes_innerView.alpha = 0
        self.usuarios_innerView.alpha = 0
        self.estilos_innerView.alpha = 0
        self.envios_urgentes_innerView.alpha = 0
        self.calculadora_innerView.alpha = 0
        self.envios_innerView.alpha = 0
        self.cerrarSesion_innerView.alpha = 0

        
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
    
    @IBAction func dashboardTouchUpInside(){
    
        UIView.animate(withDuration: 0.4) {
            
            self.dashboard_innerView.alpha = 1
            self.listas_innerView.alpha = 0
             self.RPOVERALL_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.envios_urgentes_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("dashboard")
        }
 
    
    }

    
    
    @IBAction func listasTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 1
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.envios_urgentes_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("listas")
        }
        
    }
    
    
    
    
    @IBAction func reportesTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 1
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.envios_urgentes_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("reportes")
        }
        
    }
    
    
    @IBAction func plantasTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 1
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.envios_urgentes_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("plantas")
        }
        
    }
    
    
    @IBAction func clientesTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 1
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.envios_urgentes_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("clientes")
        }
        
    }
    
    @IBAction func usuariosTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 1
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 1
            self.estilos_innerView.alpha = 0
            self.envios_urgentes_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("usuarios")
        }
    }
    
    
    
    @IBAction func estilosTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 1
            self.envios_urgentes_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("estilos")
        }
    }
    
    
    
    @IBAction func envios_urgentesTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.envios_urgentes_innerView.alpha = 1
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("envios_urgentes")
        }
    }
    
    
    @IBAction func calculadorasTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.envios_urgentes_innerView.alpha = 0
            self.calculadora_innerView.alpha = 1
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("calculadora")
        }
    }
    
    
    @IBAction func enviosTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.envios_urgentes_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 1
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("envios")
        }
    }
    
    
    @IBAction func cerrarSesionTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 1
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.envios_urgentes_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("cerrar_sesion")
        }
    }
    
}
