//
//  CutsViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/2/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class CutsViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,asignDelegate {
    
    
    
    @IBOutlet var cortesTitle: UILabel!
    @IBOutlet var noCutsLabel: UILabel!
    @IBOutlet var cuts_collectionview: UICollectionView!
    var pending_cuts_array:[PendingCut] = []
    var selected_cut:PendingCut!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        self.cortesTitle.font = UIFont(name: FONT_BOLD, size: self.cortesTitle.font.pointSize)
        self.noCutsLabel.font = UIFont(name: FONT_BOLD, size: self.noCutsLabel.font.pointSize)
        self.noCutsLabel.alpha = 0
        self.cuts_collectionview.alpha = 0
        self.cuts_collectionview.layer.cornerRadius = 4
        self.cuts_collectionview.layer.masksToBounds = true
        self.getPendingCuts()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    func getPendingCuts(){
    
    Services.getPendingCutsWithandHandler({ (response) in
        
        self.pending_cuts_array = response as! [PendingCut]
        
        if self.pending_cuts_array.count != 0{
            self.noCutsLabel.alpha = 0
            self.cuts_collectionview.alpha = 1
            self.cuts_collectionview.reloadData()
        
        }else{
            self.noCutsLabel.alpha = 1
            
            self.cuts_collectionview.alpha = 0
        
        }
    }, orErrorHandler: { (err) in
        
        
        
    })
        
    }

    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        
        self.selected_cut = self.pending_cuts_array[indexPath.row]
        self.performSegue(withIdentifier: "asignar", sender: self)
        
        
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.pending_cuts_array.count
    }
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 1
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cortes_pending", for: indexPath) as! PendingCutCollectionViewCell
        
        cell.displayPendingCut(cut: self.pending_cuts_array[indexPath.row])
        
        
        return cell
        
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.cuts_collectionview.frame.size.width-20, height: 160)
    }
    
    @IBAction func goBack(){
    
    self.navigationController?.popViewController(animated: true)
    
    }
    
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "asignar"{
        
        let controller = segue.destination as! AsignCutViewController
            
        controller.pendingCut = self.selected_cut
        controller.delegate = self
        }
        
    }
    
    
    
    func asignedCut() {
        self.getPendingCuts()
    }
}
