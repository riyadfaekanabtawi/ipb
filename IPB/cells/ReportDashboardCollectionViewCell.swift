//
//  ReportDashboardCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/29/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class ReportDashboardCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var mainView: UIView!
    @IBOutlet var LabelText: UILabel!
    var plant = false
    override func awakeFromNib() {
        
        self.LabelText.font = UIFont(name: FONT_REGULAR, size: self.LabelText.font.pointSize)
        
        self.mainView.layer.borderColor = UIColor.lightGray.cgColor
        self.mainView.layer.borderWidth = 2
        self.mainView.layer.cornerRadius = 4
        self.mainView.layer.masksToBounds = true
        
    }
    
    
    
    func displayReports(report:Report){
    
      self.LabelText.text = "Corte: \( report.corte!)"
     
    
    }
}
