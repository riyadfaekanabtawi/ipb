//
//  DashboardReportsViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/29/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class DashboardReportsViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout {


    
    @IBOutlet var titleViewLabel: UILabel!
    var array:NSArray = []
    var array_plant_reports:[Report] = []
var array_plant:[String] = []
    
    @IBOutlet var MycollectionView: UICollectionView!

    
    
    override func viewDidLoad() {
        super.viewDidLoad()


        
        self.titleViewLabel.font = UIFont(name: FONT_BOLD, size: self.titleViewLabel.font.pointSize)

        self.loadReports()
        // Do any additional setup after loading the view.
    }

    
    
    func loadReports(){
    
        
        Services.getReportsWithandHandler({ (response) in
            

            
                self.array = response as! NSArray

                
                self.MycollectionView.reloadData()
           
            
   
        }, orErrorHandler: { (err) in
            
            
        })
    
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
    
        return (self.array[section] as AnyObject).count
        
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.array.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "reports", for: indexPath) as! ReportCollectionViewCell
     
        let array = self.array[indexPath.section] as AnyObject
        
        let arrayReports = array.object(forKey: "reports")as! [AnyObject]
        
        for report in arrayReports{
            
            
            let reportss = Report.init(dictionary:report as! [AnyHashable : Any])
            
            self.array_plant_reports.append(reportss!)
            
            
        }

        
        cell.displayReports(report: self.array_plant_reports[indexPath.row])

        
        
        return cell
    }
    @IBAction func goBack(){
        
        self.navigationController?.popViewController(animated: true)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        
       return CGSize(width: self.MycollectionView.layer.frame.size.width / 4, height: 300)
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        var reusableview:UICollectionReusableView? = nil
        
        if (kind == UICollectionElementKindSectionHeader) {
            
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "HeaderView", for: indexPath) as! RecipeCollectionHeaderView
            let plant = self.array[indexPath.section] as AnyObject
            
            
            
            headerView.title.text = plant.object(forKey: "plant")as?String

            
            
            reusableview = headerView
            
        }
        
        
        return reusableview!
    }
}
