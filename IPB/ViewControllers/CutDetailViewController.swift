//
//  CutDetailViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/18/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit
class CutDetailViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,UITextFieldDelegate {
    
    @IBOutlet var reporteCorteTitle: UILabel!
    @IBOutlet var corteIDLabel: UILabel!
    @IBOutlet var cortesTitle: UILabel!
    @IBOutlet var fechaLabelContainer: UITextField!
    @IBOutlet var hourLabelContainer: UITextField!
    @IBOutlet var fechaLabel: UILabel!
    @IBOutlet var hoirLabel: UILabel!
    @IBOutlet var operariosLabel: UILabel!
    @IBOutlet var faltasLabel: UILabel!
    @IBOutlet var producidasLabel: UILabel!
    @IBOutlet var en_planchaLabel: UILabel!
    @IBOutlet var en_empaquieLabel: UILabel!
    @IBOutlet var bodegaLabel: UILabel!
    @IBOutlet var operariosField: UITextField!
    @IBOutlet var faltasField: UITextField!
    @IBOutlet var producidasField: UITextField!
    @IBOutlet var en_planchaField: UITextField!
    @IBOutlet var en_empaquieField: UITextField!
    @IBOutlet var bodegaField: UITextField!
    @IBOutlet var reportsCollectionView: UICollectionView!
    @IBOutlet var noReportsLabel: UILabel!
    @IBOutlet var cuts_collectionview: UICollectionView!
    @IBOutlet var guardarButton: UIButton!
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var addBackView: UIView!
    @IBOutlet var AddContainerView: UIView!
    var report_id:NSNumber!
    
    var updatingReport = false
    
    
    var pending_cuts_array:[PendingCut] = []
    var selected_cut:PendingCut!
    var reports_array:[Report] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
  
        self.selected_cut = self.pending_cuts_array[0]
          self.cuts_collectionview.reloadData()
        self.cortesTitle.text = "CORTE: \(self.selected_cut.corte!)"
        self.cortesTitle.font = UIFont(name: FONT_BOLD, size: self.cortesTitle.font.pointSize)
        self.noReportsLabel.font = UIFont(name: FONT_BOLD, size: self.noReportsLabel.font.pointSize)
        self.addBackView.alpha = 0
        self.noReportsLabel.alpha = 0
        self.AddContainerView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.AddContainerView.alpha = 0
        self.AddContainerView.layer.cornerRadius = 4
        self.AddContainerView.layer.masksToBounds = true

        self.cuts_collectionview.layer.cornerRadius = 4
        self.cuts_collectionview.layer.masksToBounds = true
        self.reportsCollectionView.layer.cornerRadius = 4
        self.reportsCollectionView.layer.masksToBounds = true
        self.getReports()
      
        
        
        self.corteIDLabel.font = UIFont(name: FONT_BOLD, size: self.corteIDLabel.font.pointSize)
  
        self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        self.guardarButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.guardarButton.titleLabel?.font.pointSize)!)
        self.fechaLabel.font = UIFont(name: FONT_BOLD, size: self.fechaLabel.font.pointSize)
        self.hoirLabel.font = UIFont(name: FONT_BOLD, size: self.hoirLabel.font.pointSize)
        self.operariosLabel.font = UIFont(name: FONT_BOLD, size: self.operariosLabel.font.pointSize)
        self.faltasLabel.font = UIFont(name: FONT_BOLD, size: self.faltasLabel.font.pointSize)
        self.en_planchaLabel.font = UIFont(name: FONT_BOLD, size: self.en_planchaLabel.font.pointSize)
        self.en_empaquieLabel.font = UIFont(name: FONT_BOLD, size: self.en_empaquieLabel.font.pointSize)
        self.bodegaLabel.font = UIFont(name: FONT_BOLD, size: self.bodegaLabel.font.pointSize)
        self.producidasLabel.font = UIFont(name: FONT_BOLD, size: self.producidasLabel.font.pointSize)
        self.reporteCorteTitle.font = UIFont(name: FONT_BOLD, size: self.reporteCorteTitle.font.pointSize)
        
        self.producidasField.font = UIFont(name: FONT_REGULAR, size: (self.producidasField.font?.pointSize)!)
        self.fechaLabelContainer.font = UIFont(name: FONT_REGULAR, size: (self.fechaLabelContainer.font?.pointSize)!)
        self.hourLabelContainer.font = UIFont(name: FONT_REGULAR, size: (self.hourLabelContainer.font?.pointSize)!)
        self.operariosField.font = UIFont(name: FONT_REGULAR, size: (self.operariosField.font?.pointSize)!)
        self.faltasField.font = UIFont(name: FONT_REGULAR, size: (self.faltasField.font?.pointSize)!)
        self.en_planchaField.font = UIFont(name: FONT_REGULAR, size: (self.en_planchaField.font?.pointSize)!)
        self.en_empaquieField.font = UIFont(name: FONT_REGULAR, size: (self.en_empaquieField.font?.pointSize)!)
        self.bodegaField.font = UIFont(name: FONT_REGULAR, size: (self.bodegaField.font?.pointSize)!)

        self.corteIDLabel.text = "\(self.selected_cut.corte!)"
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func getReports(){
    
        
        Services.getReportsForCut(self.selected_cut.cut_id, andHandler:{ (response) in
            
            self.reports_array = response as! [Report]
            
            
            self.reportsCollectionView.reloadData()
            
        }, orErrorHandler: { (err) in
    
    
    
    })
    }
    
    

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if indexPath.row == 0{
         self.updatingReport = false
        self.showAddPlantView()
        }else{
        self.updatingReport = true
            let report = self.reports_array[indexPath.row - 1]
            self.operariosField.text = "\(report.operarios!)"
            self.faltasField.text = "\(report.faltas!)"
            self.producidasField.text = "\(report.produciad!)"
            self.en_planchaField.text = "\(report.en_plancha!)"
            self.en_empaquieField.text = "\(report.en_empaque!)"
            self.bodegaField.text = "\(report.bodega!)"
            self.report_id = report.reporte_id
            self.showAddPlantView()
        }
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        
        if collectionView == self.reportsCollectionView{
        return self.reports_array.count + 1
        }else{
        return self.pending_cuts_array.count
        }
        }
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 1
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        
        if collectionView == self.reportsCollectionView{
        
            if indexPath.row == 0{
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "add", for: indexPath)as!AddButtonCollectionViewCell
                
                
                return cell;
            }else{
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "reports", for: indexPath) as! ReportCollectionViewCell
                
            cell.displayReports(report: self.reports_array[indexPath.row - 1])
                
            return cell
            
            }
        }else{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cortes_pending", for: indexPath) as! PendingCutCollectionViewCell
            
            cell.displayPendingCut(cut: self.pending_cuts_array[indexPath.row])
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            
            
            
            let resultCantidad = formatter.string(from: NSNumber(value:Int(self.pending_cuts_array[indexPath.row].cut_precio_final.intValue)))
            
            cell.ingreso_label.text = "Ingreso: \(resultCantidad!) $MXN"
            cell.status_label.text = "ASIGNADO"
            
            return cell
        
        }
     
        
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if collectionView == self.reportsCollectionView{
            return CGSize(width: self.reportsCollectionView.layer.frame.size.width / 4, height: 300)
        
        }else{
        
         return CGSize(width: self.view.frame.size.width-20, height: 160)
        }
       
    }
    
    @IBAction func goBack(){
        
        self.navigationController?.popViewController(animated: true)
        
    }
    
    
    @IBAction func closeAddView(){
        
        self.hideAddplantView()
        
    }
    
    @IBAction func guardarReporte(){
        
        if self.operariosField.text == "" || self.faltasField.text == "" || self.producidasField.text == "" || self.en_planchaField.text == "" || self.en_empaquieField.text == "" || self.bodegaField.text == ""{
        
            let alertController = UIAlertController(title: "Oops!", message: "Debes llenar todos los campos para cargar un reporte al corte", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
        
        }else{
            
            if self.updatingReport{
            
            
                let alertController = UIAlertController(title: "Atencion!", message: "Está por actualizar el reporte del corte: \(self.selected_cut.corte!)", preferredStyle: .alert)
                
                
                
                let OKAction = UIAlertAction(title: "Actualizar Reporte", style: .default) { (action) in
                    
                    let faltas = NSNumber(value: Int32(self.faltasField.text!)!)
                    let producidaas = NSNumber(value: Int32(self.producidasField.text!)!)
                    let plancha = NSNumber(value: Int32(self.en_planchaField.text!)!)
                    let empaque = NSNumber(value: Int32(self.en_empaquieField.text!)!)
                    let bodega = NSNumber(value: Int32(self.bodegaField.text!)!)
                    let operarios = NSNumber(value: Int32(self.operariosField.text!)!)
                    
                    
                    
                    Services.updateReport(self.selected_cut.cut_list, andReportID:self.report_id, andCut: "\(self.selected_cut.cut_id!)", andStyle: self.selected_cut.cut_estilo, andCantidad: "\(self.selected_cut.cut_cantidad!)", andFechaIPB: self.selected_cut.cut_fecha_ipb, andRealizadas: "", andOperarios: operarios, andFaltas: faltas, andProducidas: producidaas, andPlancha: plancha, andEmpaque: empaque, andBodega: bodega, andHandler: { (response) in
                        
                        let alertController = UIAlertController(title: "Bien!", message: "Actualizaste el reporte al corte: \(self.selected_cut.corte!)", preferredStyle: .alert)
                        
                        
                        let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                            
                        }
                        alertController.addAction(OKAction)
                        
                        self.present(alertController, animated: true) {
                            // ...
                        }
                        self.getReports()
                        self.hideAddplantView()
                        
                    }, orErrorHandler: { (err) in
                        
                        
                    })
                    
                }
                alertController.addAction(OKAction)
                
                self.present(alertController, animated: true) {
                    // ...
                }

                
                
                
            }else{
            
            let alertController = UIAlertController(title: "Atencion!", message: "Está por cargar el reporte del corte: \(self.selected_cut.corte!)", preferredStyle: .alert)

            
            
            let OKAction = UIAlertAction(title: "Cargar Reporte", style: .default) { (action) in
                
                let faltas = NSNumber(value: Int32(self.faltasField.text!)!)
                let producidaas = NSNumber(value: Int32(self.producidasField.text!)!)
                let plancha = NSNumber(value: Int32(self.en_planchaField.text!)!)
                let empaque = NSNumber(value: Int32(self.en_empaquieField.text!)!)
                let bodega = NSNumber(value: Int32(self.bodegaField.text!)!)
                let operarios = NSNumber(value: Int32(self.operariosField.text!)!)
                
                
                
                Services.createReport(self.selected_cut.cut_list, andCut: "\(self.selected_cut.cut_id!)", andStyle: self.selected_cut.cut_estilo, andCantidad: "\(self.selected_cut.cut_cantidad!)", andFechaIPB: self.selected_cut.cut_fecha_ipb, andRealizadas: "", andOperarios: operarios, andFaltas: faltas, andProducidas: producidaas, andPlancha: plancha, andEmpaque: empaque, andBodega: bodega, andHandler: { (response) in
                    
                    let alertController = UIAlertController(title: "Bien!", message: "Cargaste el reporte al corte: \(self.selected_cut.corte!)", preferredStyle: .alert)
                    
                    
                    let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                        
                    }
                    alertController.addAction(OKAction)
                    
                    self.present(alertController, animated: true) {
                        // ...
                    }
                    self.getReports()
                    self.hideAddplantView()
                    
                }, orErrorHandler: { (err) in
                    
                    
                })
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
            
            
            }
            
            
            
     
        
        }
        
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "asignar"{
            
            let controller = segue.destination as! AsignCutViewController
            
            controller.pendingCut = self.selected_cut
         
        }
        
    }
    
    
    
    func showAddPlantView(){
        let dateformatter = DateFormatter()
        
        dateformatter.dateFormat = "dd-MM-YYY"
        self.fechaLabelContainer.text = dateformatter.string(from: Date())
        
        dateformatter.dateFormat = "HH:mm"
        
        self.hourLabelContainer.text = dateformatter.string(from: Date())
        
        UIView.animate(withDuration: 0.4) {
            self.addBackView.alpha = 1
            self.AddContainerView.transform = CGAffineTransform.identity
            self.AddContainerView.alpha = 1
            
        }
        
    }
    
    
    func hideAddplantView(){
        
        UIView.animate(withDuration: 0.4) {
            self.addBackView.alpha = 0
            self.AddContainerView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            self.AddContainerView.alpha = 0
            
        }
        
        
        self.operariosField.resignFirstResponder()
        self.faltasField.resignFirstResponder()
        self.producidasField.resignFirstResponder()
        self.en_planchaField.resignFirstResponder()
        self.en_empaquieField.resignFirstResponder()
        self.bodegaField.resignFirstResponder()
        
    }
    
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if self.operariosField == textField{
            
            self.faltasField.becomeFirstResponder()
        }
        
        if self.faltasField == textField{
        
        self.producidasField.becomeFirstResponder()
        }
        
        if self.producidasField == textField{
        
        self.en_planchaField.becomeFirstResponder()
            
        }
        
        if self.en_planchaField == textField{
        
        self.en_empaquieField.becomeFirstResponder()
        }
        
        if self.en_empaquieField == textField{
        
        
        self.bodegaField.becomeFirstResponder()
        }
        
        if self.bodegaField == textField{
        
        self.bodegaField.resignFirstResponder()
        }
        
        
        
        
        
        
        return true
    }
    
}
