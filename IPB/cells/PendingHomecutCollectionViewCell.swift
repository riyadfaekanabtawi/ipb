//
//  PendingHomecutCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/30/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class PendingHomecutCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var cutLabel: UILabel!
    @IBOutlet var mainView: UIView!
    
    override func awakeFromNib() {
        
        self.mainView.layer.cornerRadius = 4
        self.mainView.layer.masksToBounds = true
        
        self.cutLabel.font = UIFont(name: FONT_REGULAR, size: self.cutLabel.font.pointSize)
    }
    
    
    func displayPendingcuts(cut:PendingCut){
    
    self.cutLabel.text = "Corte: \(cut.corte!)"
    
    }
}
