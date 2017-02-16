//
//  AnalisisSecondViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 2/14/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

import UIKit
import MessageUI
class AnalisisSecondViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,UITextFieldDelegate{
    
    
    var cortes_array:[Corte] = []
  
    @IBOutlet var titleViewLabel: UILabel!
    
     @IBOutlet var statusLabel1: UILabel!
     @IBOutlet var statusLabel2: UILabel!
     @IBOutlet var statusLabel3: UILabel!
    
     @IBOutlet var status1_textfield: UITextField!
     @IBOutlet var status2_textfield: UITextField!
     @IBOutlet var status3_textfield: UITextField!

    
    @IBOutlet var status1_button: UILabel!
    @IBOutlet var status2_button: UILabel!
    @IBOutlet var status3_button: UILabel!
    
    @IBOutlet var corte_collectionView: UICollectionView!

    
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if self.status1_textfield == textField{
        
        self.status1_textfield.resignFirstResponder()
        }
        
        if self.status2_textfield == textField{
        
        self.status2_textfield.resignFirstResponder()
        
        }
        
        if self.status3_textfield == textField{
        
        self.status3_textfield.resignFirstResponder()
        }
        
        return true
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.statusLabel1.font = UIFont(name: FONT_BOLD, size: self.statusLabel1.font.pointSize)
        
        self.statusLabel2.font = UIFont(name: FONT_BOLD, size: self.statusLabel2.font.pointSize)
        
        self.statusLabel3.font = UIFont(name: FONT_BOLD, size: self.statusLabel3.font.pointSize)
    
        
        self.status1_textfield.font = UIFont(name: FONT_REGULAR, size: (self.status1_textfield.font?.pointSize)!)
         self.status2_textfield.font = UIFont(name: FONT_REGULAR, size: (self.status2_textfield.font?.pointSize)!)
         self.status3_textfield.font = UIFont(name: FONT_REGULAR, size: (self.status3_textfield.font?.pointSize)!)

        
        
          self.status1_button.font = UIFont(name: FONT_BOLD, size: (self.status1_button.font.pointSize))
        self.status2_button.font = UIFont(name: FONT_BOLD, size: (self.status2_button.font.pointSize))
        self.status3_button.font = UIFont(name: FONT_BOLD, size: (self.status3_button.font.pointSize))
        
        self.titleViewLabel.font = UIFont(name: FONT_BOLD, size: self.titleViewLabel.font.pointSize)
        

        self.refreshHomePlants()
        self.titleViewLabel.font = UIFont(name: FONT_BOLD, size: self.titleViewLabel.font.pointSize)
        

        
        self.setNeedsStatusBarAppearanceUpdate()
        self.navigationController?.navigationBar.barStyle = UIBarStyle.blackTranslucent
        //[self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
        // Do any additional setup after loading the view.
    }
    
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            return .lightContent
        }
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
    
    
    
    
    
    
 
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.cortes_array.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "analisis", for: indexPath) as! Analisis2CollectionViewCell
        
        
        cell.showcuts(corte: self.cortes_array[indexPath.row])
        
        return cell
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: self.corte_collectionView.frame.size.width-10, height: 40)
    }
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    
    func refreshHomePlants()
        
    {
        
        
        Services.getAllcuts({ (response) in
            
            self.cortes_array = response as! [Corte]
            
            
            self.corte_collectionView.reloadData()
            
        }, orErrorHandler: { (err) in
            
            
            
        })
        
        
    }
    
    
     @IBAction func goBack(){
        self.navigationController?.popViewController(animated: true)
    }
    

    
 }

