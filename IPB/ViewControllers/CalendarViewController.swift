//
//  CalendarViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 8/7/17.
//  Copyright © 2017 Riyad Anabtawi. All rights reserved.
//

import UIKit

class CalendarViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout,UICollectionViewDataSource {
    @IBOutlet var titleViewcontroller: UILabel!
    
    var pendingCut:PendingCut!
     var plants_array:[Planta] = []
    @IBOutlet var plants_collectionview: UICollectionView!
    
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.titleViewcontroller.font = UIFont(name: FONT_REGULAR, size: self.titleViewcontroller.font.pointSize)
        
        
        
        Services.getPlantsWithandHandler({ (response) in
            
            self.plants_array = response as! [Planta]
            self.plants_collectionview.reloadData()
        }, orErrorHandler: { (err) in
            
            
        })

        
        
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        
        
        
    }
    
    
    
    @IBAction func goBack(){
        
        self.navigationController?.popViewController(animated: true)
        
        
        
    }
    
    
    
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.plants_array.count
        
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "plants", for: indexPath)as!PlantCollectionViewCell
         cell.cameFromCalendar = true
        cell.displayPlant(plant: self.plants_array[indexPath.row])
        cell.viewParent = self.view
        cell.controller = self
       
        cell.corteSelected = self.pendingCut
       // cell.delegate = self
        return cell
        
        
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        
        return CGSize(width: 250, height: 410)
    }
    
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


}
