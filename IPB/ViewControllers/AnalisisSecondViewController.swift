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
    
    @IBOutlet var refreshIcon: UIButton!
    var cortes_array:[Corte] = []
  var en_listo_array:[Corte] = []
    var en_espera_array:[Corte] = []
    var en_mesa_array:[Corte] = []
    @IBOutlet var titleViewLabel: UILabel!
     @IBOutlet var titleLabels: [UILabel]!
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
    @IBOutlet var corte_collectionView_mesa: UICollectionView!
    
    @IBOutlet var corte_collectionView_listo: UICollectionView!
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if self.status1_textfield == textField{
            self.filter1()
        
        self.status1_textfield.resignFirstResponder()
        }
        
        if self.status2_textfield == textField{
            self.filter2()
        self.status2_textfield.resignFirstResponder()
        
        }
        
        if self.status3_textfield == textField{
            self.filter3()
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
        
        
        for label in self.titleLabels{
            
            label.font = UIFont(name: FONT_BOLD, size: label.font.pointSize)
        }
        
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
        if self.corte_collectionView_mesa == collectionView{
                return self.en_mesa_array.count
        
        }else if collectionView == self.corte_collectionView{
        
                return self.en_espera_array.count
        }else{
        
        return self.en_listo_array.count
        }

    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "analisis", for: indexPath) as! Analisis2CollectionViewCell
        
        
        cell.showcuts(corte: self.cortes_array[indexPath.row])
        
        return cell
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if (self.corte_collectionView_listo == collectionView){
        
           return CGSize(width: self.corte_collectionView_listo.frame.size.width-20, height: 40)
        }else{
           return CGSize(width: self.corte_collectionView.frame.size.width-10, height: 40)
        
        }
     
     
    }
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    
    func refreshHomePlants()
        
    {
        
        self.en_listo_array.removeAll()
        self.en_mesa_array.removeAll()
        self.en_espera_array.removeAll()
        Services.getAllcuts({ (response) in
            
            self.cortes_array = response as! [Corte]
            
            for corte in self.cortes_array{
            
             if corte.status.lowercased() == "en mesa de corte"{
            self.en_mesa_array.append(corte)
             }else if corte.status.lowercased() == "en espera"{
                self.en_espera_array.append(corte)
             }else{
                
                self.en_listo_array.append(corte)
                }
                
            }
            self.corte_collectionView.reloadData()
            self.corte_collectionView_listo.reloadData()
            self.corte_collectionView_mesa.reloadData()
            
        }, orErrorHandler: { (err) in
            
            
            
        })
        
        
    }
    
    
     @IBAction func goBack(){
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func refresh(){
        Functions.runSpinAnimation(on: self.refreshIcon, duration: 0.6, rotations: 1, repeat: 0)
     self.refreshHomePlants()
    }
    
    @IBAction func filter1(){
     
        self.en_espera_array.removeAll()
        Services.filterCortes(byName: self.status1_textfield.text, andHandler:{ (response) in
            
            self.cortes_array = response as! [Corte]
            
            for corte in self.cortes_array{
                
                if corte.status.lowercased() == "en espera"{
                    self.en_espera_array.append(corte)
                }
            }
            self.corte_collectionView.reloadData()
        
            
        }, orErrorHandler: { (err) in
            
            
            
        })
        
    }
    
    
    @IBAction func filter2(){
        
        self.en_mesa_array.removeAll()
        Services.filterCortes(byName: self.status2_textfield.text, andHandler:{ (response) in
            
            self.cortes_array = response as! [Corte]
            
            for corte in self.cortes_array{
                
                if corte.status.lowercased() == "en mesa de corte"{
                    self.en_mesa_array.append(corte)
                }
                
            }
 
            self.corte_collectionView_mesa.reloadData()
            
        }, orErrorHandler: { (err) in
            
            
            
        })
        
        
    }
    
    @IBAction func filter3(){
        
        self.en_listo_array.removeAll()
        Services.filterCortes(byName: self.status3_textfield.text, andHandler:{ (response) in
            
            self.cortes_array = response as! [Corte]
            
            for corte in self.cortes_array{
      if corte.status.lowercased() == "listo para confeccionar"{
                    self.en_listo_array.append(corte)
                }
                
            }
          
            self.corte_collectionView_listo.reloadData()
    
            
        }, orErrorHandler: { (err) in
            
            
            
        })
        
        
    }
    
 }

