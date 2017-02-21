//
//  CutsViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/2/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class CutsViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,asignDelegate,pendingCutdelegate {
    
    @IBOutlet var styleImageView: UIImageView!
    @IBOutlet var BackaddPlantview: UIView!
    @IBOutlet var imageViewBig: UIView!
    @IBOutlet var imagenTitle: UILabel!
    
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var cortesTitle: UILabel!
    @IBOutlet var noCutsLabel: UILabel!
    @IBOutlet var cuts_collectionview: UICollectionView!
    var pending_cuts_array:[PendingCut] = []
    var selected_cut:PendingCut!
    
    
    override func viewDidLoad() {
        
        self.imageViewBig.layer.cornerRadius = 4
        self.imageViewBig.layer.masksToBounds = true
        super.viewDidLoad()
        
         self.imagenTitle.font = UIFont(name: FONT_BOLD, size: self.imagenTitle.font.pointSize)
        
        
        self.BackaddPlantview.alpha = 0
        self.imageViewBig.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.imageViewBig.alpha = 0
        self.cortesTitle.font = UIFont(name: FONT_BOLD, size: self.cortesTitle.font.pointSize)
        self.noCutsLabel.font = UIFont(name: FONT_BOLD, size: self.noCutsLabel.font.pointSize)
        
        self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)!
        
        
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
        cell.delegate = self
        
        return cell
        
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.cuts_collectionview.frame.size.width-10, height: 200)
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
    
    
    
    func showImage(image: String) {
        UIView.animate(withDuration: 0.4) {
            self.BackaddPlantview.alpha = 1
            self.imageViewBig.transform = CGAffineTransform.identity
            self.imageViewBig.alpha = 1
            
            self.styleImageView.sd_setImage(with: NSURL(string: image) as URL!)
            
            
            
        }

        
        
    }
    @IBAction func hideImageBackView(){
        
        UIView.animate(withDuration: 0.4) {
            self.BackaddPlantview.alpha = 0
            self.imageViewBig.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            self.imageViewBig.alpha = 0
            
            self.styleImageView.sd_setImage(with: NSURL(string: "") as URL!)
            
            
            
        }
    }
    
    func asignedCut() {
        self.getPendingCuts()
    }
}
