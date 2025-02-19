//
//  ReportCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/19/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class ReportCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var reportTitle: UILabel!
    @IBOutlet var reportDayString: UILabel!
    @IBOutlet var reportDayNumber: UILabel!
    @IBOutlet var reportHour: UILabel!
    @IBOutlet var edirLabel: UIButton!
    
    @IBOutlet var mainView: UIView!
    
    override func awakeFromNib() {
        
        self.edirLabel.titleLabel?.font = UIFont(name: FONT_REGULAR, size: (self.edirLabel.titleLabel?.font.pointSize)!)
        self.reportTitle.font = UIFont(name: FONT_REGULAR, size: self.reportTitle.font.pointSize)
        self.reportHour.font = UIFont(name: FONT_REGULAR, size: self.reportHour.font.pointSize)
        self.reportDayNumber.font = UIFont(name: FONT_REGULAR, size: self.reportDayNumber.font.pointSize)
        self.reportDayString.font = UIFont(name: FONT_REGULAR, size: self.reportDayString.font.pointSize)
        
        self.mainView.layer.cornerRadius = 4
        self.mainView.layer.masksToBounds = true
    }
    
    
    
    func displayReports(report:Report){
    
        if report.dayNumbers != nil{
         self.reportDayNumber.text = report.dayNumbers
        }
        
        if report.hour != nil{
        
        self.reportHour.text = report.hour
        }
       
        
        self.reportTitle.text = "REPORTE DE \(report.type_report!.uppercased())"
        self.reportDayString.text = report.dayString
        
    
    }
}
