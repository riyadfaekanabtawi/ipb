//
//  PendingHomecutCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/30/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class PendingHomecutCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var mainView: UIView!
    @IBOutlet var cutNameLabel: UILabel!
    @IBOutlet var clientLabel: UILabel!
    override func awakeFromNib() {
        
        self.cutNameLabel.font = UIFont(name: FONT_REGULAR, size: self.cutNameLabel.font.pointSize)
        self.clientLabel.font = UIFont(name: FONT_REGULAR, size: self.clientLabel.font.pointSize)
        self.mainView.layer.cornerRadius = 4
        self.mainView.layer.masksToBounds = true
    }
    
    
    
    func displayPendingcuts(cut:PendingCut){
        
        self.cutNameLabel.text = "\(cut.corte!)"
        self.clientLabel.text = "\(cut.cut_client!)"
        
    }
    
    


}
