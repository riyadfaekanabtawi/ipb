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
    
     @IBOutlet var proveedoresLabel: UILabel!
     @IBOutlet var proveedoresView: UIView!
    
    @IBOutlet var reportesOverall: UILabel!
    @IBOutlet var dashboard_label: UILabel!
    @IBOutlet var lista_label: UILabel!
    @IBOutlet var reportes_label: UILabel!
    @IBOutlet var plantas_label: UILabel!
    @IBOutlet var clientes_label: UILabel!
    @IBOutlet var usuarios_label: UILabel!
    @IBOutlet var estilos_label: UILabel!

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
    
    
    @IBOutlet var calendar_innerView: UIView!
  
     @IBOutlet var proyectos_innerView: UIView!
     @IBOutlet var proyectos_label: UILabel!
    
    @IBOutlet var calculadora_innerView: UIView!
    @IBOutlet var envios_innerView: UIView!
    @IBOutlet var cerrarSesion_innerView: UIView!
    @IBOutlet var calendarViewHeight: NSLayoutConstraint!

    
    @IBOutlet var reportessend_InnerView: UIView!
    @IBOutlet var reportesSend_label: UILabel!
    @IBOutlet var calendar_label: UILabel!
    @IBOutlet var dashboardHeight: NSLayoutConstraint!
    @IBOutlet var asignarCortesHeight: NSLayoutConstraint!
    @IBOutlet var generarReporteHeight: NSLayoutConstraint!
    @IBOutlet var reportesHeight: NSLayoutConstraint!
    @IBOutlet var proyectosHeight: NSLayoutConstraint!
    @IBOutlet var plantasHeight: NSLayoutConstraint!
    @IBOutlet var clientesHeight: NSLayoutConstraint!
    @IBOutlet var proveedoresHeight: NSLayoutConstraint!
    @IBOutlet var usuariosHeight: NSLayoutConstraint!
    @IBOutlet var estilosHeight: NSLayoutConstraint!
    @IBOutlet var calculadoraHeight: NSLayoutConstraint!
    @IBOutlet var enviosUrgentesHeight: NSLayoutConstraint!
    
    
    @IBOutlet var scrollView: UIScrollView!
    override func viewDidLoad() {
        super.viewDidLoad()
        

        self.menuHeight.constant = self.view.frame.size.height + 80
        self.view.layoutIfNeeded()
        
        self.setNeedsStatusBarAppearanceUpdate()
        
        
         self.reportesSend_label.font = UIFont(name: FONT_REGULAR, size: self.reportesSend_label.font.pointSize)
        
        
        self.proveedoresLabel.font = UIFont(name: FONT_REGULAR, size: self.proveedoresLabel.font.pointSize)
        self.dashboard_label.font = UIFont(name: FONT_REGULAR, size: self.dashboard_label.font.pointSize)
        self.lista_label.font = UIFont(name: FONT_REGULAR, size: self.lista_label.font.pointSize)
        self.reportes_label.font = UIFont(name: FONT_REGULAR, size: self.reportes_label.font.pointSize)
        self.plantas_label.font = UIFont(name: FONT_REGULAR, size: self.plantas_label.font.pointSize)
        self.clientes_label.font = UIFont(name: FONT_REGULAR, size: self.clientes_label.font.pointSize)
        self.usuarios_label.font = UIFont(name: FONT_REGULAR, size: self.usuarios_label.font.pointSize)
        self.estilos_label.font = UIFont(name: FONT_REGULAR, size: self.estilos_label.font.pointSize)
        self.proyectos_label.font = UIFont(name: FONT_REGULAR, size: self.proyectos_label.font.pointSize)
        self.calendar_label.font = UIFont(name: FONT_REGULAR, size: self.proyectos_label.font.pointSize)
        
        
         self.reportesOverall.font = UIFont(name: FONT_REGULAR, size: self.reportesOverall.font.pointSize)
        
        self.calculadora_label.font = UIFont(name: FONT_REGULAR, size: self.calculadora_label.font.pointSize)
        self.envios_label.font = UIFont(name: FONT_REGULAR, size: self.envios_label.font.pointSize)
        self.cerrarSesion_label.font = UIFont(name: FONT_REGULAR, size: self.cerrarSesion_label.font.pointSize)
        
        
        self.proyectos_innerView.layer.cornerRadius = 4
        self.proyectos_innerView.layer.masksToBounds = true
        
        self.proveedoresView.layer.cornerRadius = 4
        self.proveedoresView.layer.masksToBounds = true
        
        self.RPOVERALL_innerView.layer.cornerRadius = 4
        self.RPOVERALL_innerView.layer.masksToBounds = true
        
        self.dashboard_innerView.layer.cornerRadius = 4
        self.dashboard_innerView.layer.masksToBounds = true
        
        self.listas_innerView.layer.cornerRadius = 4
        self.listas_innerView.layer.masksToBounds = true
        
        
        self.calendar_innerView.layer.cornerRadius = 4
        self.calendar_innerView.layer.masksToBounds = true
        
        
        self.reportes_innerView.layer.cornerRadius = 4
        self.reportes_innerView.layer.masksToBounds = true
        
        self.plantas_innerView.layer.cornerRadius = 4
        self.plantas_innerView.layer.masksToBounds = true
        
        self.clientes_innerView.layer.cornerRadius = 4
        self.clientes_innerView.layer.masksToBounds = true
        
        self.usuarios_innerView.layer.cornerRadius = 4
        self.usuarios_innerView.layer.masksToBounds = true
        
        self.estilos_innerView.layer.cornerRadius = 4
        self.estilos_innerView.layer.masksToBounds = true
        
        self.reportessend_InnerView.layer.cornerRadius = 4
        self.reportessend_InnerView.layer.masksToBounds = true
        
        self.calculadora_innerView.layer.cornerRadius = 4
        self.calculadora_innerView.layer.masksToBounds = true
        
        self.envios_innerView.layer.cornerRadius = 4
        self.envios_innerView.layer.masksToBounds = true
        
        self.cerrarSesion_innerView.layer.cornerRadius = 4
        self.cerrarSesion_innerView.layer.masksToBounds = true
        
     
        
        self.proyectos_innerView.alpha = 0
        self.proveedoresView.alpha = 0
        self.RPOVERALL_innerView.alpha = 0
        self.dashboard_innerView.alpha = 0
        self.listas_innerView.alpha = 0
        self.reportes_innerView.alpha = 0
        self.plantas_innerView.alpha = 0
        self.clientes_innerView.alpha = 0
        self.usuarios_innerView.alpha = 0
        self.estilos_innerView.alpha = 0
        self.reportessend_InnerView.alpha = 0
        self.calculadora_innerView.alpha = 0
        self.envios_innerView.alpha = 0
        self.cerrarSesion_innerView.alpha = 0
        self.calendar_innerView.alpha = 0

        
        self.user_nameLabel.font = UIFont(name: FONT_BOLD, size: self.user_nameLabel.font.pointSize)
        self.user_puestoLabel.font = UIFont(name: FONT_LIGHT, size: self.user_puestoLabel.font.pointSize)
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: collectionView.frame.size.width/3, height: collectionView.frame.size.height/3)
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
    
        if (user.puesto == "Administrador"){
            
            self.dashboardHeight.constant = 60
            self.calendarViewHeight.constant = 60
            self.asignarCortesHeight.constant = 60
            self.generarReporteHeight.constant = 60
            self.reportesHeight.constant = 60
            self.proyectosHeight.constant = 60
            self.plantasHeight.constant = 60
            self.clientesHeight.constant = 60
            self.proveedoresHeight.constant = 60
            self.usuariosHeight.constant = 60
            self.estilosHeight.constant = 60
            self.calculadoraHeight.constant = 60
            self.enviosUrgentesHeight.constant = 60
                  self.view.layoutIfNeeded()
        }
        
        if (user.puesto == "Gerente de Cortes"){
            self.dashboardHeight.constant = 0
            self.asignarCortesHeight.constant = 60
            self.generarReporteHeight.constant = 0
            self.reportesHeight.constant = 60
            self.proyectosHeight.constant = 0
            self.plantasHeight.constant = 0
            self.clientesHeight.constant = 0
            self.proveedoresHeight.constant = 0
            self.usuariosHeight.constant = 0
            self.estilosHeight.constant = 0
            self.calculadoraHeight.constant = 0
            self.enviosUrgentesHeight.constant = 0
             self.calendarViewHeight.constant = 0
                  self.view.layoutIfNeeded()
           
        }
        
        
        if (user.puesto == "Gerente de Planta"){
            self.dashboardHeight.constant = 0
            self.asignarCortesHeight.constant = 0
            self.generarReporteHeight.constant = 0
            self.reportesHeight.constant = 60
            self.proyectosHeight.constant = 0
            self.plantasHeight.constant = 0
            self.clientesHeight.constant = 0
            self.proveedoresHeight.constant = 0
            self.usuariosHeight.constant = 0
            self.estilosHeight.constant = 0
            self.calculadoraHeight.constant = 0
            self.enviosUrgentesHeight.constant = 0
            self.calendarViewHeight.constant = 0
                  self.view.layoutIfNeeded()
        }
        
        if (user.puesto == "Gerente de Envios"){
            
            self.dashboardHeight.constant = 0
            self.asignarCortesHeight.constant = 0
            self.generarReporteHeight.constant = 0
            self.reportesHeight.constant = 60
            self.proyectosHeight.constant = 0
            self.plantasHeight.constant = 0
            self.clientesHeight.constant = 0
            self.proveedoresHeight.constant = 0
            self.usuariosHeight.constant = 0
            self.estilosHeight.constant = 0
            self.calculadoraHeight.constant = 0
            self.enviosUrgentesHeight.constant = 60
             self.calendarViewHeight.constant = 0
                  self.view.layoutIfNeeded()
        }

   self.scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
  
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
            self.reportessend_InnerView.alpha = 0
            self.dashboard_innerView.alpha = 1
            self.listas_innerView.alpha = 0
            self.proveedoresView.alpha = 0
             self.RPOVERALL_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
             self.calendar_innerView.alpha = 0
            self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("dashboard")
        }
 
    
    }

    @IBAction func calendarTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
            self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.calendar_innerView.alpha = 1
            self.proveedoresView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.reportessend_InnerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("calendar")
        }
        
    }
    
    
    
    @IBAction func listasTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.listas_innerView.alpha = 1
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.reportessend_InnerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("listas")
        }
        
    }
    
    
    
    
    @IBAction func reportesTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.listas_innerView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.reportes_innerView.alpha = 1
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.reportessend_InnerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.proyectos_innerView.alpha = 0
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
            self.proveedoresView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 1
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("plantas")
        }
        
    }
    
    
    @IBAction func clientesTouchUpInside(){
        
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.reportessend_InnerView.alpha = 0
            self.clientes_innerView.alpha = 1
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("clientes")
        }
        
    }
    
    @IBAction func usuariosTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.dashboard_innerView.alpha = 1
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.reportessend_InnerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 1
            self.estilos_innerView.alpha = 0
            self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("usuarios")
        }
    }
    
    
    
    @IBAction func estilosTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.reportessend_InnerView.alpha = 0
            self.estilos_innerView.alpha = 1
            self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("estilos")
        }
    }
    
    
    
    @IBAction func envios_urgentesTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("envios_urgentes")
        }
    }
    
    
    
    
    
    
    @IBAction func reportsallTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
            self.RPOVERALL_innerView.alpha = 1
            self.reportessend_InnerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("reportsall")
        }
    }
    
    @IBAction func calculadorasTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
  self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 1
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("calculadora")
        }
    }
    
    
    @IBAction func enviosTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.reportessend_InnerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
        self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 1
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("envios")
        }
    }
    
    
    @IBAction func cerrarSesionTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
             self.RPOVERALL_innerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.dashboard_innerView.alpha = 1
            self.reportessend_InnerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
      self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("cerrar_sesion")
        }
    }
    
    
    @IBAction func proveedoresTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
            self.RPOVERALL_innerView.alpha = 0
            self.proveedoresView.alpha = 1
            self.calendar_innerView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportessend_InnerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
          self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("proveedores")
        }
    }
    
    @IBAction func createReportHomeTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
            self.RPOVERALL_innerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.proyectos_innerView.alpha = 0
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.reportessend_InnerView.alpha = 1
            self.delegate.selectedMenuviewcontrollerOption("createReportHome")
        }
    }
    
    
    
    @IBAction func proyectosTouchUpInside(){
        UIView.animate(withDuration: 0.4) {
            self.RPOVERALL_innerView.alpha = 0
            self.proveedoresView.alpha = 0
            self.dashboard_innerView.alpha = 0
            self.listas_innerView.alpha = 0
            self.calendar_innerView.alpha = 0
            self.reportes_innerView.alpha = 0
            self.reportessend_InnerView.alpha = 0
            self.plantas_innerView.alpha = 0
            self.clientes_innerView.alpha = 0
            self.usuarios_innerView.alpha = 0
            self.estilos_innerView.alpha = 0
            self.proyectos_innerView.alpha = 1
            self.calculadora_innerView.alpha = 0
            self.envios_innerView.alpha = 0
            self.cerrarSesion_innerView.alpha = 0
            self.delegate.selectedMenuviewcontrollerOption("proyectos")
        }
    }
    
}
