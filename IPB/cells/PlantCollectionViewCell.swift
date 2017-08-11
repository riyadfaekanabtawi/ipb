//
//  PlantCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/3/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit


protocol plantdelegate {
    func asignedQuantityToPlant(cut:PendingCut)
   
}
class PlantCollectionViewCell: UICollectionViewCell,UITextFieldDelegate,FSCalendarDelegate {
    var currentDate:Date!
    var cameFromCalendar:Bool = false
    var controller:UIViewController!
    @IBOutlet var graphview: UIWebView!
    var delegate:plantdelegate!
    @IBOutlet var cantidad_por_asignar_textViewlabel: UITextField!
    var calendar:FSCalendar!
    @IBOutlet var calendarView: UIView!
    @IBOutlet var capax_used: UILabel!
    @IBOutlet var capax_max: UILabel!
    @IBOutlet var plant_name: UILabel!
    @IBOutlet var capax_disp: UILabel!
    var corteSelected:PendingCut!
    var selectedPlant:Planta!
    @IBOutlet var asignarLabel: UILabel!
    var selectedDate:String!
    var viewParent:UIView!
    override func awakeFromNib() {
        

        NotificationCenter.default.addObserver(self, selector: #selector(PlantCollectionViewCell.keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PlantCollectionViewCell.keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)

        if (self.cantidad_por_asignar_textViewlabel != nil){
        self.cantidad_por_asignar_textViewlabel.font = UIFont(name: FONT_REGULAR, size: (self.cantidad_por_asignar_textViewlabel.font?.pointSize)!)
        }
        
        
        let calendar = FSCalendar(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
       // calendar.dataSource = self
        //calendar.delegate = self
       Functions.fillContainerView(self.calendarView, with: calendar)
        //self.calendarView.addSubview(calendar)
        self.calendar = calendar
        
        self.calendar.delegate = self
        if (self.asignarLabel != nil){
        self.asignarLabel.font = UIFont(name: FONT_REGULAR, size: (self.asignarLabel.font?.pointSize)!)
        }
        self.capax_used.font = UIFont(name: FONT_REGULAR, size: (self.capax_used.font?.pointSize)!)
        self.capax_max.font = UIFont(name: FONT_REGULAR, size: (self.capax_max.font?.pointSize)!)
        self.plant_name.font = UIFont(name: FONT_REGULAR, size: (self.plant_name.font?.pointSize)!)
        
        self.capax_disp.font = UIFont(name: FONT_REGULAR, size: (self.capax_disp.font?.pointSize)!)
        
    }
    
    
    func displayPlant(plant:Planta){
        
    self.selectedPlant = plant
    self.plant_name.text = plant.planta_nombre
        
        
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        
        
      
        let resultMax = formatter.string(from: NSNumber(value:Int(plant.planta_capacidadMax.intValue)))
        
      
        
        self.capax_max.text = "Capacidad Máxima: $ \(resultMax!)"
        
     
       
        if (self.cameFromCalendar){
            
            let cortes = plant.cortes as! [Corte]
            
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM-yyyy"
            
            
            for corte in cortes{
                NSLog("\(corte.cut_fecha_client!)", "")
                 self.calendar.select(formatter.date(from: corte.cut_fecha_client!)!, scrollToDate: false)
                
            }
           
        }
    }
    
    
    func keyboardWillShow(notification: NSNotification) {
        
       
        if !self.cantidad_por_asignar_textViewlabel.isEditing{
            
            if ((notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
                self.viewParent.frame.origin.y = -200
            }
        }
        
        
    }
    
    func keyboardWillHide(notification: NSNotification) {
        
        
        if !self.cantidad_por_asignar_textViewlabel.isEditing{
    
                if ((notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
                    
                    self.viewParent.frame.origin.y = 0
                }
            
          
          
        }
    }
    
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        self.cantidad_por_asignar_textViewlabel.resignFirstResponder()
        
        
        
        return true
    }
    
    
    
    @IBAction func asignarTouchUpInside(){
    
       self.cantidad_por_asignar_textViewlabel.resignFirstResponder()
        if (self.selectedDate != nil && self.cantidad_por_asignar_textViewlabel.text != ""){
            
            
            
            let preficofinal = Float32(self.cantidad_por_asignar_textViewlabel.text!)!
            
            if preficofinal > self.corteSelected.cut_cantidad.floatValue{
            
                let alertController = UIAlertController(title: "Oops!", message: "La capacidad a asignar no puede ser mayor a la cantidad del corte", preferredStyle: .alert)
                
                
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    // ...
                }
                alertController.addAction(OKAction)
                
                self.controller.present(alertController, animated: true) {
                    // ...
                }

            
            }else{
            
                
                let cantidad = Float32(self.cantidad_por_asignar_textViewlabel.text!)
                
                let total = cantidad! * self.corteSelected.cut_precio_unitario
                
                let alertController = UIAlertController(title: "Atención!", message: "Estas por asignar : \(self.cantidad_por_asignar_textViewlabel.text!) prendas a la planta: \(self.selectedPlant.planta_nombre!) = \(total)  $", preferredStyle: .alert)
                
                
                let OKAction = UIAlertAction(title: "Confirmar Asignación", style: .default) { (action) in
                    Services.assignCutToPlant(withQuantity: NSNumber(value:Float32(self.cantidad_por_asignar_textViewlabel.text!)!), andCliente: self.corteSelected.cut_client, fecha: self.selectedDate, andPrecioTotal:  NSNumber(value: Float32(total)), andPrecioUnitario: NSNumber(value: Float32(self.corteSelected.cut_precio_unitario)), andstyleImage: self.corteSelected.cut_estilo, andStyle: self.corteSelected.cut_estilo, andPlantID: self.selectedPlant.planta_id, andPendingCutID:self.corteSelected.cut_id, andHandler: { (response) in
                        
                        if ((response as? String) != nil){
                            
                            let alertController = UIAlertController(title: "Oops!", message: "La planta ha llegado a su capacidad maxima.", preferredStyle: .alert)
                            
                            
                            
                            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                                // ...
                            }
                            alertController.addAction(OKAction)
                            
                            self.controller.present(alertController, animated: true) {
                                // ...
                            }
                            
                        }else{
                            
                            let alertController = UIAlertController(title: "Bien!", message: "As asignado la cantidad: \(self.cantidad_por_asignar_textViewlabel.text!) a la planta: \(self.selectedPlant.planta_nombre!)", preferredStyle: .alert)
                            
                            
                            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                         self.delegate.asignedQuantityToPlant(cut: response as! PendingCut)
                            }
                            alertController.addAction(OKAction)
                            
                            self.controller.present(alertController, animated: true) {
                                // ...
                            }
                            
                           
                        }
           
                        
                    }, orErrorHandler: { (err) in
                        
                        
                        
                    })
                }
                
                
                  let CAction = UIAlertAction(title: "Cancelar", style: .default) { (action) in
                    
                    
                }
                
                alertController.addAction(OKAction)
                alertController.addAction(CAction)
                
                
                self.controller.present(alertController, animated: true) {
                    // ...
                }

            

            
            }
            
                    }else{
            let alertController = UIAlertController(title: "Oops!", message: "Debes elejir una fecha en el calendario o ingresar una cantidad para asignar", preferredStyle: .alert)
            
     
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                // ...
            }
            alertController.addAction(OKAction)
            
            self.controller.present(alertController, animated: true) {
                // ...
            }
        
        }
   
        
    
    }
    
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date) {
        if (self.cameFromCalendar){
        
        
        }else{
        
            UIView.animate(withDuration: 0.2, animations: {
                if (self.cantidad_por_asignar_textViewlabel != nil){
                    self.cantidad_por_asignar_textViewlabel.resignFirstResponder()
                }
                
            }, completion: {
                (value: Bool) in
                
                let formatter = DateFormatter()
                formatter.dateFormat = "dd-MM-yyyy"
                
                
                let dateString = formatter.string(from: date)
                
                self.selectedDate = dateString
                
                
                
                
                let alertController = UIAlertController(title: "Bien!", message: "Ejiste la fecha: \(self.selectedDate!)", preferredStyle: .alert)
                
                
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    // ...
                }
                alertController.addAction(OKAction)
                
                self.controller.present(alertController, animated: true) {
                    // ...
                }
                
                
            })

        }
        
        
        
        
        
    
        
    }
    
    
    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        
       let formatterd = DateFormatter()
        
        formatterd.dateFormat = "MM"
        
        let total = self.selectedPlant.planta_capacidadMax.floatValue
        
        let stringDate = formatterd.string(from: calendar.currentPage)
        
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        
        
        if stringDate == "01"{

            
             let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.january_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
    

            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.january_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
        }
        
        if stringDate == "02"{
      
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.febuary_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.febuary_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
        
        if stringDate == "03"{
  
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.march_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.march_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
        
        if stringDate == "04"{

            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.april_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.april_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
        
        if stringDate == "05"{
    
        
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.may_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.may_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
            
        }
        
        if stringDate == "06"{
   
     
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.june_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.june_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
            
        }
        
        if stringDate == "07"{
            
         
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.july_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.july_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
            
        }
        
        if stringDate == "08"{
    
          
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.august_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.august_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
            
        }
        
        if stringDate == "09"{
         
         
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.september_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.september_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
        
        if stringDate == "10"{
 
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.october_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.october_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
        
        if stringDate == "11"{

            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.november_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.november_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
        }
        
        if stringDate == "12"{
          
  
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.december_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.december_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
      
        
    }
   
    func calendar(_ calendar: FSCalendar, willDisplay cell: FSCalendarCell, for date: Date, at position: FSCalendarMonthPosition) {
        
        self.currentDate = calendar.currentPage
        
        let formatterdate = DateFormatter()
        
        formatterdate.dateFormat = "MM"
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        
        cell.performSelecting()
        
        let total = self.selectedPlant.planta_capacidadMax.floatValue
        
        let stringDate = formatterdate.string(from: calendar.currentPage)
        
        if stringDate == "01"{
         
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.january_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.january_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
        }
        
        if stringDate == "02"{
            
       
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.febuary_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.febuary_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
        
        if stringDate == "03"{
            

            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.march_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.march_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
        
        if stringDate == "04"{
            

            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.april_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.april_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
        
        if stringDate == "05"{
            
            
            
    
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.may_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.may_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
            
        }
        
        if stringDate == "06"{
            
            
            
 
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.june_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.june_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
            
        }
        
        if stringDate == "07"{

            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.july_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.july_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
            
        }
        
        if stringDate == "08"{

            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.august_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.august_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
            
        }
        
        if stringDate == "09"{
            
  
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.september_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.september_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
        
        if stringDate == "10"{
      
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.october_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.october_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
        
        if stringDate == "11"{
     
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.november_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.november_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
        }
        
        if stringDate == "12"{
            
     
            
            let totalUsed = formatter.string(from: NSNumber(value:Float32(self.selectedPlant.december_used)))
            self.capax_used.text = "Capacidad Usada: $ \(totalUsed!) "
            
            
            let totaldisp = formatter.string(from: NSNumber(value:Float32(total - self.selectedPlant.december_used)))
            
            
            self.capax_disp.text = "Capacidad Disponible: $ \(totaldisp!) "
            
        }
        
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
        
    {
     
            
            
            
            let nsString = textField.text as NSString?
            let text = nsString?.replacingCharacters(in: range, with: string)
            
            
            if Int(text!) != nil || text?.range(of: ".") != nil || text == ""{
                // Text field converted to an Int
                return true
            } else {
                // Text field is not an Int
                return false
                
            }
            
      
        
    }

}
