//
//  DashboardReportsViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/29/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class DashboardReportsViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout {

    @IBOutlet var heightScroll: NSLayoutConstraint!
    @IBOutlet var widthScroll: NSLayoutConstraint!
    
    
    @IBOutlet var reportesDePlantaLabel: UILabel!
    @IBOutlet var reportesDeCortesLabel: UILabel!
    @IBOutlet var reportesDeEnviosLabel: UILabel!
    
    
    @IBOutlet var reportesDePlantaNOLabel: UILabel!
    @IBOutlet var reportesDeCortesNOLabel: UILabel!
    @IBOutlet var reportesDeEnviosNOLabel: UILabel!
    
    @IBOutlet var titleViewLabel: UILabel!
    
    var array_plant_reports:[Report] = []
    var array_plant_cuts:[Report] = []
    var array_plant_envios:[Report] = []
    
    @IBOutlet var reportesDePlantaCollectionView: UICollectionView!
    @IBOutlet var reportesDeCortesCollectionView: UICollectionView!
    @IBOutlet var reportesDeEnviosCollectionView: UICollectionView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        self.widthScroll.constant  = self.view.frame.size.width
        self.heightScroll.constant = self.view.frame.size.height  + 400
        self.view.layoutIfNeeded()
        self.reportesDePlantaLabel.font = UIFont(name: FONT_BOLD, size: self.reportesDePlantaLabel.font.pointSize)
        self.reportesDeCortesLabel.font = UIFont(name: FONT_BOLD, size: self.reportesDeCortesLabel.font.pointSize)
        self.reportesDeEnviosLabel.font = UIFont(name: FONT_BOLD, size: self.reportesDeEnviosLabel.font.pointSize)
        
        self.titleViewLabel.font = UIFont(name: FONT_BOLD, size: self.titleViewLabel.font.pointSize)
        
        
        
        
        self.reportesDePlantaNOLabel.font = UIFont(name: FONT_REGULAR, size: self.reportesDePlantaNOLabel.font.pointSize)
        self.reportesDeCortesNOLabel.font = UIFont(name: FONT_REGULAR, size: self.reportesDeCortesNOLabel.font.pointSize)
        self.reportesDeEnviosNOLabel.font = UIFont(name: FONT_REGULAR, size: self.reportesDeEnviosNOLabel.font.pointSize)
        
        self.reportesDePlantaNOLabel.alpha = 0
        self.reportesDeCortesNOLabel.alpha = 0
        self.reportesDeEnviosNOLabel.alpha = 0
        self.loadReports()
        // Do any additional setup after loading the view.
    }

    
    
    func loadReports(){
    
        
        Services.getReportsWithandHandler({ (response) in
            
            self.array_plant_cuts = response as! [Report]

            if self.array_plant_reports.count == 0{
                self.reportesDePlantaNOLabel.alpha = 1
                self.reportesDePlantaCollectionView.alpha = 1
            }else{
            
                self.reportesDePlantaNOLabel.alpha = 0
                self.reportesDePlantaCollectionView.alpha = 1
                self.reportesDePlantaCollectionView.reloadData()
            }
            
            
            if self.array_plant_envios.count == 0{
                self.reportesDeEnviosNOLabel.alpha = 1
                self.reportesDeEnviosCollectionView.alpha = 1
            }else{
                
                self.reportesDeEnviosNOLabel.alpha = 0
                self.reportesDeEnviosCollectionView.alpha = 1
                self.reportesDeEnviosCollectionView.reloadData()
            }
            
            
            if self.array_plant_cuts.count == 0{
                self.reportesDeCortesNOLabel.alpha = 1
                self.reportesDeCortesCollectionView.alpha = 1
            }else{
                
                self.reportesDeCortesNOLabel.alpha = 0
                self.reportesDeCortesCollectionView.alpha = 1
                self.reportesDeCortesCollectionView.reloadData()
            }
            
            
            
            
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
        
        if collectionView == self.reportesDePlantaCollectionView{
        
        return self.array_plant_reports.count
            
        }else if collectionView == self.reportesDeCortesCollectionView{
        
        return self.array_plant_cuts.count
        
        } else{
        
        return self.array_plant_envios.count
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "reports", for: indexPath) as! ReportDashboardCollectionViewCell
        if collectionView == self.reportesDePlantaCollectionView{
            
            cell.displayReports(report: self.array_plant_envios[indexPath.row])
            
        }else if collectionView == self.reportesDeCortesCollectionView{
            
          cell.displayReports(report: self.array_plant_cuts[indexPath.row])
            
        } else{
            
            cell.displayReports(report: self.array_plant_envios[indexPath.row])
        }
        
        return cell
    }
    @IBAction func goBack(){
        
        self.navigationController?.popViewController(animated: true)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        
        return CGSize(width: 200, height: 200)
        
    }
}
