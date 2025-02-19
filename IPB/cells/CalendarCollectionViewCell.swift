//
//  CalendarCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 8/6/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

import UIKit

class CalendarCollectionViewCell: UICollectionViewCell,FSCalendarDelegate {
    var calendar:FSCalendar!
    var currentDate:Date!
    
    var controller:UIViewController!
    var selectedPlant:Planta!
    @IBOutlet var plant_name: UILabel!
    @IBOutlet var month_year_label: UILabel!
    @IBOutlet var capax_disp: UILabel!
    @IBOutlet var capax_used: UILabel!
    @IBOutlet var capax_max: UILabel!
    
    override func awakeFromNib() {
        self.currentDate = Date()
        let calendar = Calendar.current
        
        let year = calendar.component(.year, from: self.currentDate)
        let month = calendar.component(.month, from: self.currentDate)
        self.month_year_label.text = "\(month) \(year)"
        
    }
    func displayPlants(plant:Planta){
    
    self.plant_name.text = plant.planta_nombre!
    
    
    
    
    }
    func calendar(_ calendar: FSCalendar, didSelect date: Date) {
        
//        UIView.animate(withDuration: 0.2, animations: {
//            
//
//        }, completion: {
//            (value: Bool) in
//            
//            let formatter = DateFormatter()
//            formatter.dateFormat = "dd-MM-yyyy"
//            
//            
//            let dateString = formatter.string(from: date)
//            
//            self.currentDate = dateString
//            
//            
//            
//            
//            let alertController = UIAlertController(title: "Bien!", message: "Ejiste la fecha: \(self.currentDate!)", preferredStyle: .alert)
//            
//            
//            
//            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
//                // ...
//            }
//            alertController.addAction(OKAction)
//            
//            self.controller.present(alertController, animated: true) {
//                // ...
//            }
//            
//            
//        })
        
        
        
        
        
        
        
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

}
