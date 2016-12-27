//
//  AddButtonCollectionViewCell.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/12/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class AddButtonCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var addLabel: UILabel!
    @IBOutlet var plusLabel: UILabel!
    
    
    override func awakeFromNib() {
        
        self.addLabel.font = UIFont(name: FONT_BOLD, size: 20)
        self.plusLabel.font = UIFont(name: FONT_BOLD, size: self.plusLabel.font.pointSize)
    }
    
    
    
}
