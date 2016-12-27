//
//  CalculadoraViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/14/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class CalculadoraViewController: UIViewController,UITextFieldDelegate {
    @IBOutlet var viewcontrollertitle: UILabel!
    
    @IBOutlet var widthScroll: NSLayoutConstraint!
    
     @IBOutlet var heightScroll: NSLayoutConstraint!
    @IBOutlet var constantes_view: UIView!
    @IBOutlet var contantesBackview: UIView!
    
    @IBOutlet var titleLabels: [UILabel]!
    @IBOutlet var precioPorMinutoReal: UITextField!
    @IBOutlet var produccionSemanal: UITextField!
    @IBOutlet var diasEstimados: UITextField!
    @IBOutlet var metaDiaria: UITextField!
    
    @IBOutlet var clienteTextField: UITextField!
    @IBOutlet var plantaTextField: UITextField!
    @IBOutlet var cantidad_estiloTextField: UITextField!
    @IBOutlet var minutaje_real_estiloTextField: UITextField!
    @IBOutlet var minutaje_cliente_estiloTextField: UITextField!
    @IBOutlet var operariosTexField: UITextField!
    @IBOutlet var ingreso_brutoTextField: UITextField!
    @IBOutlet var gastos_operativosTextField: UITextField!
    @IBOutlet var ingreso_netoTextField: UITextField!
    @IBOutlet var precioUnitarioIPB: UITextField!
    @IBOutlet var precioPorEstilo: UITextField!
    @IBOutlet var minutosDiaOperario: UITextField!
    @IBOutlet var minutosSeamanaOperario: UITextField!
    @IBOutlet var MinutosMesOperario: UITextField!
    @IBOutlet var diasTrabajoalasemana: UITextField!
    @IBOutlet var diasDeTrabajoAlMes: UITextField!
    @IBOutlet var guardarButton: UIButton!
    @IBOutlet var constantesLabelTitle: UILabel!
    @IBOutlet var constantes_button: UIButton!
    
    @IBOutlet var cotizarButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()

        
        
        self.constantes_button.layer.cornerRadius = 4
        self.constantes_button.layer.borderColor = UIColor.lightGray.cgColor
        self.constantes_button.layer.borderWidth = 2
        self.constantes_button.layer.masksToBounds = true
        self.cotizarButton.alpha = 0
        self.viewcontrollertitle.font = UIFont(name: FONT_BOLD, size: self.viewcontrollertitle.font.pointSize)
        self.minutosDiaOperario.font = UIFont(name: FONT_REGULAR, size: (self.minutosDiaOperario.font?.pointSize)!)
         self.minutosSeamanaOperario.font = UIFont(name: FONT_REGULAR, size: (self.minutosSeamanaOperario.font?.pointSize)!)
         self.MinutosMesOperario.font = UIFont(name: FONT_REGULAR, size: (self.MinutosMesOperario.font?.pointSize)!)
         self.diasTrabajoalasemana.font = UIFont(name: FONT_REGULAR, size: (self.diasTrabajoalasemana.font?.pointSize)!)
         self.diasDeTrabajoAlMes.font = UIFont(name: FONT_REGULAR, size: (self.diasDeTrabajoAlMes.font?.pointSize)!)
        
        self.metaDiaria.font = UIFont(name: FONT_REGULAR, size: (self.metaDiaria.font?.pointSize)!)
        self.diasEstimados.font = UIFont(name: FONT_REGULAR, size: (self.diasEstimados.font?.pointSize)!)
        self.produccionSemanal.font = UIFont(name: FONT_REGULAR, size: (self.produccionSemanal.font?.pointSize)!)
        self.precioPorMinutoReal.font = UIFont(name: FONT_REGULAR, size: (self.precioPorMinutoReal.font?.pointSize)!)
        
        
         self.precioUnitarioIPB.font = UIFont(name: FONT_REGULAR, size: (self.precioUnitarioIPB.font?.pointSize)!)
           self.precioPorEstilo.font = UIFont(name: FONT_REGULAR, size: (self.precioPorEstilo.font?.pointSize)!)
        
        self.constantes_view.layer.cornerRadius = 4
        self.constantes_view.layer.masksToBounds = true
        
        self.constantes_view.alpha = 0
        self.constantes_view.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.contantesBackview.alpha = 0
        
        self.widthScroll.constant = self.view.frame.width
        self.heightScroll.constant = self.view.frame.height + 250
        self.view.layoutIfNeeded()
        for label in self.titleLabels{
        
        label.font = UIFont(name: FONT_BOLD, size: label.font.pointSize)
        }
        
               self.constantesLabelTitle.font = UIFont(name: FONT_BOLD, size: (self.constantesLabelTitle.font?.pointSize)!)
            self.guardarButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.guardarButton.titleLabel?.font?.pointSize)!)
                self.constantes_button.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.constantes_button.titleLabel?.font?.pointSize)!)
        
        self.cotizarButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.cotizarButton.titleLabel?.font?.pointSize)!)
        
        
        
        self.clienteTextField.font = UIFont(name: FONT_REGULAR, size: (self.clienteTextField.font?.pointSize)!)
        
        self.plantaTextField.font = UIFont(name: FONT_REGULAR, size: (self.plantaTextField.font?.pointSize)!)
        
        self.cantidad_estiloTextField.font = UIFont(name: FONT_REGULAR, size: (self.cantidad_estiloTextField.font?.pointSize)!)
        
        self.minutaje_real_estiloTextField.font = UIFont(name: FONT_REGULAR, size: (self.minutaje_real_estiloTextField.font?.pointSize)!)
        
        self.minutaje_cliente_estiloTextField.font = UIFont(name: FONT_REGULAR, size: (self.minutaje_cliente_estiloTextField.font?.pointSize)!)
        
        self.operariosTexField.font = UIFont(name: FONT_REGULAR, size: (self.operariosTexField.font?.pointSize)!)
        

        
      
        
        self.ingreso_brutoTextField.font = UIFont(name: FONT_REGULAR, size: (self.ingreso_brutoTextField.font?.pointSize)!)
        
        self.gastos_operativosTextField.font = UIFont(name: FONT_REGULAR, size: (self.gastos_operativosTextField.font?.pointSize)!)
        
        self.ingreso_netoTextField.font = UIFont(name: FONT_REGULAR, size: (self.ingreso_netoTextField.font?.pointSize)!)
        
        
        // Do any additional setup after loading the view.
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
    
    
    @IBAction func goBack(){
        self.navigationController?.popViewController(animated: true)
    }
    
    
    @IBAction func saveConstants(){
        if self.minutosDiaOperario.text == "" || self.minutosSeamanaOperario.text == "" || self.MinutosMesOperario.text == "" || self.diasDeTrabajoAlMes.text == "" || self.diasTrabajoalasemana.text == ""{
        
            let alertController = UIAlertController(title: "Atención!", message: "Tienes que lelnar todas las constantes antes de poder guardarlas", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in}
            
            alertController.addAction(OKAction)
            self.present(alertController, animated: true) {
                // ...
            }

        }else{
        
        
       
        let alertController = UIAlertController(title: "Atención!", message: "Estas seguro que quiere guardar las constantes", preferredStyle: .alert)
        
        
        let OKAction = UIAlertAction(title: "Si", style: .default) { (action) in
            let defaults = UserDefaults.standard
            
            defaults.set(self.minutosDiaOperario.text, forKey: "minutos_dia_operario")
            defaults.set(self.minutosSeamanaOperario.text, forKey: "minutos_semana_operario")
            defaults.set(self.MinutosMesOperario.text, forKey: "minutos_mes_operario")
            
            defaults.set(self.diasDeTrabajoAlMes.text, forKey: "dias_mes")
            defaults.set(self.diasTrabajoalasemana.text, forKey: "dias_semana")
            
            defaults.synchronize()
            
            self.hideCopnstants()
            
            
               let alertController = UIAlertController(title: "Bien!", message: "Has guardado las constantes!", preferredStyle: .alert)
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
          
            }
            
            alertController.addAction(OKAction)
            self.present(alertController, animated: true) {
                // ...
            }
        }

        let cancelAction = UIAlertAction(title: "Cancelar", style: .default) { (action) in
            self.hideCopnstants()
        }
        alertController.addAction(OKAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true) {
            // ...
        }
        
         }

    }
    
    
    @IBAction func showconstants(){
     
        UIView.animate(withDuration: 0.4) {
            self.contantesBackview.alpha = 1
            self.constantes_view.transform = CGAffineTransform.identity
            self.constantes_view.alpha = 1
            
        }
        
        self.clienteTextField.resignFirstResponder()
        self.plantaTextField.resignFirstResponder()
        self.cantidad_estiloTextField.resignFirstResponder()
        self.minutaje_real_estiloTextField.resignFirstResponder()
        self.minutaje_cliente_estiloTextField.resignFirstResponder()
        self.operariosTexField.resignFirstResponder()
        self.precioUnitarioIPB.resignFirstResponder()
        self.precioPorEstilo.resignFirstResponder()
        self.gastos_operativosTextField.resignFirstResponder()
        
        
            let defaults = UserDefaults.standard
            
            if (defaults.object(forKey: "minutos_dia_operario") != nil){
                
                self.minutosDiaOperario.text = (defaults.object(forKey: "minutos_dia_operario") as! String)
                
            }
            
            if (defaults.object(forKey: "minutos_semana_operario") != nil){
                
                self.minutosSeamanaOperario.text = (defaults.object(forKey: "minutos_semana_operario") as! String)
                
            }
            
            
            if (defaults.object(forKey: "minutos_mes_operario") != nil){
                
                self.MinutosMesOperario.text = (defaults.object(forKey: "minutos_mes_operario") as! String)
                
            }
            
            
            if (defaults.object(forKey: "dias_mes") != nil){
                
                self.diasDeTrabajoAlMes.text = (defaults.object(forKey: "dias_mes") as! String)
                
            }
            
            
            if (defaults.object(forKey: "dias_semana") != nil){
                
                self.diasTrabajoalasemana.text = (defaults.object(forKey: "dias_semana") as! String)
                
            }
            
      

    
    
        
        
    }
    
    @IBAction func hideCopnstants(){
        
        UIView.animate(withDuration: 0.4) {
            self.contantesBackview.alpha = 0
            self.constantes_view.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            self.constantes_view.alpha = 0
            
        }
        
        
        self.minutosDiaOperario.resignFirstResponder()
        self.minutosSeamanaOperario.resignFirstResponder()
        self.MinutosMesOperario.resignFirstResponder()
        self.diasDeTrabajoAlMes.resignFirstResponder()
        self.diasTrabajoalasemana.resignFirstResponder()
      
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        
        
        if self.clienteTextField == textField{
        
        self.plantaTextField.becomeFirstResponder()
        }
        
        if self.plantaTextField == textField{
        
        self.cantidad_estiloTextField.becomeFirstResponder()
        }
        
        if self.cantidad_estiloTextField == textField{
        
        
        self.minutaje_real_estiloTextField.becomeFirstResponder()
        }
        
        if self.minutaje_real_estiloTextField == textField{
        
        self.minutaje_cliente_estiloTextField.becomeFirstResponder()
        
        }
        
        
        
        if self.minutaje_cliente_estiloTextField == textField{
        
        self.operariosTexField.becomeFirstResponder()
            
        }
        
        if self.operariosTexField == textField{
        
        self.precioUnitarioIPB.becomeFirstResponder()
        }
        
        if self.precioUnitarioIPB == textField{
        
        self.precioPorEstilo.becomeFirstResponder()
            
        }
        
        if self.precioPorEstilo == textField{
        
            self.precioPorEstilo.resignFirstResponder()
            if self.minutosDiaOperario.text == "" || self.minutosSeamanaOperario.text == "" || self.MinutosMesOperario.text == "" || self.diasTrabajoalasemana.text == "" || self.diasDeTrabajoAlMes.text == "" {
                
                let alertController = UIAlertController(title: "Atención!", message: "Tienes que cargar las constantes antes", preferredStyle: .alert)
                
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
            
                }
            
                alertController.addAction(OKAction)
           
                self.present(alertController, animated: true) {
                    // ...
                }
                
                
            }else{
                
                let equation = Int32(self.cantidad_estiloTextField.text!)! * Int32(self.precioPorEstilo.text!)!
                
                let equationPrecioMinutoReal = Int32(self.precioPorEstilo.text!)! * Int32(self.minutaje_real_estiloTextField.text!)!
                
                let variable = Int32(self.minutosDiaOperario.text!)! * Int32(self.operariosTexField.text!)!
                
                
                let equationMetaDiaria = variable * Int32(self.minutaje_real_estiloTextField.text!)!
                
                let diasFinishEquation = equationMetaDiaria * Int32(self.diasTrabajoalasemana.text!)!
                
                
                
                let produccionSemanalEquation = equationMetaDiaria * Int32(self.diasTrabajoalasemana.text!)!
                
                self.diasEstimados.text = "\(diasFinishEquation)"
                
                self.metaDiaria.text = "\(equationMetaDiaria)"
                
                self.produccionSemanal.text = "\(produccionSemanalEquation)"
                
                self.ingreso_brutoTextField.text = "\(equation)"
                
               
                self.precioPorMinutoReal.text = "\(equationPrecioMinutoReal)"

                
            }
       
        
        
        }
        
        if self.gastos_operativosTextField == textField{
        
        self.gastos_operativosTextField.resignFirstResponder()
            
            if self.ingreso_brutoTextField.text != ""{
        let equation = Int32(self.ingreso_brutoTextField.text!)! - Int32(self.gastos_operativosTextField.text!)!
            
        self.ingreso_netoTextField.text = "\(equation)"
                
            }else{
            self.gastos_operativosTextField.text = ""
                let alertController = UIAlertController(title: "Atención!", message: "Tienes que calcular el ingreso bruto antes de poder ingresar el gasto operativo.", preferredStyle: .alert)
                
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    
                }
                
                alertController.addAction(OKAction)
                
                self.present(alertController, animated: true) {
                    // ...
                }

                
            }
        }
        
        
        
        //Constantes triggers
        if self.minutosDiaOperario == textField{
        
        self.minutosSeamanaOperario.becomeFirstResponder()
        }
        
        if self.minutosSeamanaOperario == textField{
        
        self.MinutosMesOperario.becomeFirstResponder()
        
        }
        
        if self.diasTrabajoalasemana == textField{
        
        self.diasDeTrabajoAlMes.becomeFirstResponder()
        }
        
        if self.diasDeTrabajoAlMes == textField{
        
        self.diasDeTrabajoAlMes.resignFirstResponder()
            
        }
        
        
        return true
    }
    
   
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
        
    {
        if textField != self.plantaTextField && textField != self.clienteTextField{
        
         
            
           let nsString = textField.text as NSString?
            let text = nsString?.replacingCharacters(in: range, with: string)
            
            
            if Int(text!) != nil || text?.range(of: ".") != nil || text == ""{
                // Text field converted to an Int
                return true
            } else {
                // Text field is not an Int
                return false
                
            }
   
          
        }else{
        
        return true
        }
     
    }

    
    
}
