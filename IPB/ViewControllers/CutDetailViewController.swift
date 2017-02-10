//
//  CutDetailViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/18/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit
class CutDetailViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,UITextFieldDelegate,pendingCutdelegate {
    
    @IBOutlet var styleImageView: UIImageView!
 
    @IBOutlet var imageViewBig: UIView!
    @IBOutlet var imagenTitle: UILabel!
    @IBOutlet var closeButton: UIButton!
    
    @IBOutlet var envioTypeButton: UIButton!
    @IBOutlet var corteTypeButton: UIButton!
    @IBOutlet var plantaTypeButton: UIButton!
    
    
    @IBOutlet var choosingReportTypeView: UIView!
    @IBOutlet var choosingReportTypeLabel: UILabel!
    @IBOutlet var closeButtonChoosingReportview: UIButton!
    
    
    @IBOutlet var reportCutTitleLabel: UILabel!
    @IBOutlet var closeReportCutviewButton: UIButton!
    @IBOutlet var guardarReportbuttonCut: UIButton!
    @IBOutlet var cant_real_textFiled: UITextField!
    @IBOutlet var canti_real_cut_Label: UILabel!
    @IBOutlet var statusTextField: UITextField!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var cutIDLabelReport: UILabel!
    @IBOutlet var reportcutView: UIView!
    @IBOutlet var corteNameReporteChoosing: UILabel!
    @IBOutlet var reporteDeEnviosLabel: UILabel!
    @IBOutlet var corteNameReporte: UILabel!
    @IBOutlet var cantidadDeEnvioTextfield: UITextField!
    @IBOutlet var cantidadDeEnvioLabel: UILabel!
    @IBOutlet var numeroDeEnvioTextField: UITextField!
    @IBOutlet var numeroDeEnvioLabel: UILabel!

    
    @IBOutlet var reportEnviosView: UIView!
    @IBOutlet var guardarReporteButtonEnvio: UIButton!
    @IBOutlet var closeButtonEnviosReportes: UIButton!
    
    
    
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
    @IBOutlet var closeButtonImage: UIButton!
    @IBOutlet var addBackView: UIView!
    @IBOutlet var AddContainerView: UIView!
    var report_id:NSNumber!
    
    var updatingReport = false
    
    @IBOutlet var en_plancha: UILabel!
    @IBOutlet var en_plancha_label: UILabel!
    @IBOutlet var en_empaque: UILabel!
    @IBOutlet var en_empaque_label: UILabel!
    @IBOutlet var en_bodega: UILabel!
    @IBOutlet var en_bodega_label: UILabel!
    @IBOutlet var prendas_por_enviar: UILabel!
    @IBOutlet var prendas_por_enviar_label: UILabel!
    @IBOutlet var cantidad_real_corte: UILabel!
    @IBOutlet var cantidad_real_corte_label: UILabel!
    
    var pending_cuts_array:[Corte] = []
    var selected_cut:Corte!
    var reports_array:[Report] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.imageViewBig.layer.cornerRadius = 4
        self.imageViewBig.layer.masksToBounds = true

        self.imageViewBig.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.imageViewBig.alpha = 0
        self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)!
  self.closeButtonImage.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButtonImage.titleLabel?.font.pointSize)!)!
        
        
         self.cant_real_textFiled.font = UIFont(name: FONT_REGULAR, size: (self.cant_real_textFiled.font?.pointSize)!)
         self.statusTextField.font = UIFont(name: FONT_REGULAR, size: (self.statusTextField.font?.pointSize)!)
         self.guardarReportbuttonCut.titleLabel?.font = UIFont(name: FONT_REGULAR, size: (self.guardarReportbuttonCut.titleLabel?.font?.pointSize)!)
         self.closeReportCutviewButton.titleLabel?.font = UIFont(name: FONT_REGULAR, size: (self.closeReportCutviewButton.titleLabel?.font?.pointSize)!)
        
        self.choosingReportTypeLabel.font = UIFont(name: FONT_BOLD, size: self.choosingReportTypeLabel.font.pointSize)
        
        self.fechaLabel.font = UIFont(name: FONT_BOLD, size: self.fechaLabel.font.pointSize)
        self.numeroDeEnvioLabel.font = UIFont(name: FONT_BOLD, size: self.numeroDeEnvioLabel.font.pointSize)
        
        self.reporteDeEnviosLabel.font = UIFont(name: FONT_BOLD, size: self.reporteDeEnviosLabel.font.pointSize)
        
        self.corteNameReporte.font = UIFont(name: FONT_BOLD, size: self.corteNameReporte.font.pointSize)
        
        self.cantidadDeEnvioLabel.font = UIFont(name: FONT_BOLD, size: self.cantidadDeEnvioLabel.font.pointSize)
        
        
        self.corteNameReporteChoosing.font = UIFont(name: FONT_BOLD, size: self.corteNameReporteChoosing.font.pointSize)
        
        
       

        self.numeroDeEnvioTextField.font = UIFont(name: FONT_REGULAR, size: (self.numeroDeEnvioTextField.font?.pointSize)!)
        self.cantidadDeEnvioTextfield.font = UIFont(name: FONT_REGULAR, size: (self.cantidadDeEnvioTextfield.font?.pointSize)!)
            
  
 

        self.cortesTitle.font = UIFont(name: FONT_BOLD, size: self.cortesTitle.font.pointSize)
        self.noReportsLabel.font = UIFont(name: FONT_BOLD, size: self.noReportsLabel.font.pointSize)
        self.addBackView.alpha = 0
        self.noReportsLabel.alpha = 0
        self.AddContainerView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.AddContainerView.alpha = 0
        self.AddContainerView.layer.cornerRadius = 4
        self.AddContainerView.layer.masksToBounds = true
        
        
        self.choosingReportTypeView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.choosingReportTypeView.alpha = 0
        self.choosingReportTypeView.layer.cornerRadius = 4
        self.choosingReportTypeView.layer.masksToBounds = true

        
        self.reportEnviosView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.reportEnviosView.alpha = 0
        
        self.reportEnviosView.layer.cornerRadius = 4
        self.reportEnviosView.layer.masksToBounds = true
        
        
        self.reportcutView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.reportcutView.alpha = 0
        
        self.reportcutView.layer.cornerRadius = 4
        self.reportcutView.layer.masksToBounds = true
        
        
        self.cuts_collectionview.layer.cornerRadius = 4
        self.cuts_collectionview.layer.masksToBounds = true
        self.reportsCollectionView.layer.cornerRadius = 4
        self.reportsCollectionView.layer.masksToBounds = true
      
      
        self.cutIDLabelReport.font = UIFont(name: FONT_BOLD, size: self.cutIDLabelReport.font.pointSize)
         self.reportCutTitleLabel.font = UIFont(name: FONT_BOLD, size: self.reportCutTitleLabel.font.pointSize)
         self.statusLabel.font = UIFont(name: FONT_BOLD, size: self.statusLabel.font.pointSize)
         self.canti_real_cut_Label.font = UIFont(name: FONT_BOLD, size: self.canti_real_cut_Label.font.pointSize)
        
        self.corteIDLabel.font = UIFont(name: FONT_BOLD, size: self.corteIDLabel.font.pointSize)
  
        self.closeButtonChoosingReportview.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButtonChoosingReportview.titleLabel?.font.pointSize)!)
        
        self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        
           self.corteTypeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.corteTypeButton.titleLabel?.font.pointSize)!)
           self.plantaTypeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.plantaTypeButton.titleLabel?.font.pointSize)!)
           self.envioTypeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.envioTypeButton.titleLabel?.font.pointSize)!)
        
        
        
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
        
        
        self.en_plancha.font = UIFont(name: FONT_BOLD, size: (self.en_plancha.font?.pointSize)!)
        self.en_empaque.font = UIFont(name: FONT_BOLD, size: (self.en_empaque.font?.pointSize)!)
        self.en_bodega.font = UIFont(name: FONT_BOLD, size: (self.en_bodega.font?.pointSize)!)
        self.prendas_por_enviar.font = UIFont(name: FONT_BOLD, size: (self.prendas_por_enviar.font?.pointSize)!)
        self.cantidad_real_corte.font = UIFont(name: FONT_BOLD, size: (self.cantidad_real_corte.font?.pointSize)!)
        
        
        
        self.en_plancha_label.font = UIFont(name: FONT_REGULAR, size: (self.en_plancha_label.font?.pointSize)!)
        self.en_empaque_label.font = UIFont(name: FONT_REGULAR, size: (self.en_empaque_label.font?.pointSize)!)
        self.en_bodega_label.font = UIFont(name: FONT_REGULAR, size: (self.en_bodega_label.font?.pointSize)!)
        self.prendas_por_enviar_label.font = UIFont(name: FONT_REGULAR, size: (self.prendas_por_enviar_label.font?.pointSize)!)
        self.cantidad_real_corte_label.font = UIFont(name: FONT_REGULAR, size: (self.cantidad_real_corte_label.font?.pointSize)!)
        
        
        
        
        self.selected_cut = self.pending_cuts_array[0]
        self.cuts_collectionview.reloadData()
        self.cortesTitle.text = "CORTE: \(self.selected_cut.corte!)"
        self.corteNameReporte.text = "\(self.selected_cut.corte!)"
        self.corteNameReporteChoosing.text = "\(self.selected_cut.corte!)"
        self.corteIDLabel.text = "\(self.selected_cut.corte!)"
        self.cutIDLabelReport.text = "\(self.selected_cut.corte!)"
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        let resultPlancha = formatter.string(from: self.selected_cut.en_plancha)
        let resultEmpaque = formatter.string(from: self.selected_cut.en_empaque)
        let resultBodega = formatter.string(from: self.selected_cut.bodega)
        let resultEnviar = formatter.string(from: self.selected_cut.cantidad_por_enviar)
        let resultReal = formatter.string(from: self.selected_cut.cantidad_real_envio)
        
        self.en_plancha.text = "\(resultPlancha!)"
        self.en_empaque.text = "\(resultEmpaque!)"
        self.en_bodega.text = "\(resultBodega!)"
        self.prendas_por_enviar.text = "\(resultEnviar!)"
        self.cantidad_real_corte.text = "\(resultReal!)"
        
          self.getReports()
        // Do any additional setup after loading the view.
    }
    
    
    
    func loadCut(){
    
        Services.getCutDetail(self.selected_cut.cut_id, andHandler:{ (response) in
            
           self.selected_cut = response as! Corte
            
            self.pending_cuts_array.removeAll()
            
            self.pending_cuts_array.append(self.selected_cut)
            self.cuts_collectionview.reloadData()
            
            
            self.corteNameReporte.text = "\(self.selected_cut.corte!)"
            self.corteNameReporteChoosing.text = "\(self.selected_cut.corte!)"
            self.corteIDLabel.text = "\(self.selected_cut.corte!)"
            self.cutIDLabelReport.text = "\(self.selected_cut.corte!)"
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            
            let resultPlancha = formatter.string(from: self.selected_cut.en_plancha)
            let resultEmpaque = formatter.string(from: self.selected_cut.en_empaque)
            let resultBodega = formatter.string(from: self.selected_cut.bodega)
            let resultEnviar = formatter.string(from: self.selected_cut.cantidad_por_enviar)
            let resultReal = formatter.string(from: self.selected_cut.cantidad_real_envio)
            
            self.en_plancha.text = "\(resultPlancha!)"
            self.en_empaque.text = "\(resultEmpaque!)"
            self.en_bodega.text = "\(resultBodega!)"
            self.prendas_por_enviar.text = "\(resultEnviar!)"
            self.cantidad_real_corte.text = "\(resultReal!)"
            self.getReports()
        }, orErrorHandler: { (err) in
            
            
            
        })
    
  
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
            self.guardarReporteButtonEnvio.isHidden = false
            self.guardarButton.isHidden = false
            self.guardarReportbuttonCut.isHidden = false
        self.showChooseReportView()
        }
        else{
        self.updatingReport = true
            
       
        
          
            let report = self.reports_array[indexPath.row - 1]
            
            if report.type_report == "planta"{
                    self.guardarButton.isHidden = true
                self.operariosField.text = "\(report.operarios!)"
                self.faltasField.text = "\(report.faltas!)"
                self.producidasField.text = "\(report.produciad!)"
                self.en_planchaField.text = "\(report.en_plancha!)"
                self.en_empaquieField.text = "\(report.en_empaque!)"
                self.bodegaField.text = "\(report.bodega!)"
                self.report_id = report.reporte_id
                self.showAddPlantView()

            
            }else if report.type_report == "corte"{
            
                  self.guardarReportbuttonCut.isHidden = false
                self.statusTextField.text = report.status_report!
                self.cant_real_textFiled.text = "\(report.cantidad_real_envio!)"
                self.report_id = report.reporte_id
                self.showAddReportCorte()
            
            }else if report.type_report == "envio"{
                     self.guardarReporteButtonEnvio.isHidden = true
                self.cantidadDeEnvioTextfield.text = "\(report.cantidad_de_envio!)"
                self.numeroDeEnvioTextField.text = "\(report.numero_de_envio!)"
                self.report_id = report.reporte_id
                self.showAddReportEnvio()
            }
            
            
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
            
            cell.displayCorte(cut: self.pending_cuts_array[indexPath.row])
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            cell.delegate = self
            

            
            return cell
        
        }
     
        
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if collectionView == self.reportsCollectionView{
            return CGSize(width: self.reportsCollectionView.layer.frame.size.width / 4, height: 300)
        
        }else{
        
         return CGSize(width: self.view.frame.size.width-20, height: 240)
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
                    
                    
                    
                   Services.updateReport(self.selected_cut.cut_list, andReportID: self.report_id, andCut: self.selected_cut.corte, andStyle: self.selected_cut.cut_estilo, andCantidad: "\(self.selected_cut.cut_cantidad!)", andFechaIPB: self.selected_cut.cut_fecha_ipb, andRealizadas: "", andOperarios: operarios, andFaltas: faltas, andProducidas: producidaas, andPlancha: plancha, andEmpaque: empaque, andCutName: self.selected_cut.corte, andCutID: self.selected_cut.cut_id, andBodega: bodega, andHandler: { (response) in
                    self.loadCut()
                    let alertController = UIAlertController(title: "Bien!", message: "Actualizaste el reporte al corte: \(self.selected_cut.corte!)", preferredStyle: .alert)
                    
                    
                    let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                        
                    }
                    alertController.addAction(OKAction)
                    
                    self.present(alertController, animated: true) {
                        // ...
                    }
       

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
                
                
                Services.createReport(self.selected_cut.cut_list, andCutID:self.selected_cut.cut_id, andCut: "\(self.selected_cut.corte!)", andStyle: self.selected_cut.cut_estilo, andCantidad: "\(self.selected_cut.cut_cantidad!)", andFechaIPB: self.selected_cut.cut_fecha_ipb, andRealizadas: "", andOperarios: operarios, andFaltas: faltas, andProducidas: producidaas, andPlancha: plancha, andEmpaque: empaque, andBodega: bodega, andHandler: { (response) in
    
                    self.loadCut()
                    let alertController = UIAlertController(title: "Bien!", message: "Cargaste el reporte al corte: \(self.selected_cut.corte!)", preferredStyle: .alert)
                    
                    
                    let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                        
                    }
                    alertController.addAction(OKAction)
                    
                    self.present(alertController, animated: true) {
                        // ...
                    }
    
                    
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
        
        if self.cantidadDeEnvioTextfield == textField{
        
        self.numeroDeEnvioTextField.becomeFirstResponder()
        }
        
        if self.numeroDeEnvioTextField == textField{
        
            self.numeroDeEnvioTextField.resignFirstResponder()
        
        }
        
        
        if self.statusTextField == textField{
        
               self.cant_real_textFiled.becomeFirstResponder()
        }
        
        if self.cant_real_textFiled == textField{
            
            self.cant_real_textFiled.resignFirstResponder()
            
        }
        
        
        
        
        return true
    }
    
    
    
    
    func showAddReportEnvio(){
    
        
        UIView.animate(withDuration: 0.4) {
            self.addBackView.alpha = 1
            self.reportEnviosView.transform = CGAffineTransform.identity
            self.reportEnviosView.alpha = 1
            
        }
        
    }
    
    
    func hideAddReportEnvio(){
        
        UIView.animate(withDuration: 0.4) {
            self.addBackView.alpha = 0
            self.reportEnviosView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            self.reportEnviosView.alpha = 0
            
        }
        
        
        self.cantidadDeEnvioTextfield.resignFirstResponder()
        self.numeroDeEnvioTextField.resignFirstResponder()

     
        
    }
    
    @IBAction func closeReportEnvio(){
        
        self.hideAddReportEnvio()
        
    }
    
    @IBAction func guardarReporteEnvio(){
        
        if self.cantidadDeEnvioTextfield.text == "" || self.numeroDeEnvioTextField.text == ""{
            
            let alertController = UIAlertController(title: "Oops!", message: "Debes llenar todos los campos para cargar un reporte de envio", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
        }else{
            
            if self.updatingReport{
                
                
                let alertController = UIAlertController(title: "Atencion!", message: "Está por actualizar el reporte de envio \(self.selected_cut.corte!)", preferredStyle: .alert)
                
                
                
                let OKAction = UIAlertAction(title: "Actualizar Reporte", style: .default) { (action) in
                    
                    let cantidadEnvio = NSNumber(value: Int32(self.cantidadDeEnvioTextfield.text!)!)
             
                    
                    Services.updateReportEnvio(cantidadEnvio, andReportID:self.report_id, andCutName: self.corteIDLabel.text, andCutID:self.selected_cut.cut_id, andNumeroDeEnvio: self.numeroDeEnvioTextField.text, andHandler: { (response) in
                        self.loadCut()
                        let alertController = UIAlertController(title: "Bien!", message: "Actualizaste el reporte de envio: \(self.selected_cut.corte!)", preferredStyle: .alert)
                        
                        
                        let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                            
                        }
                        alertController.addAction(OKAction)
                        
                        self.present(alertController, animated: true) {
                            // ...
                        }
       
                        
                    }, orErrorHandler: { (err) in
                        
                        
                    })
                    
                }
                alertController.addAction(OKAction)
                
                self.present(alertController, animated: true) {
                    // ...
                }
                
                
                
                
            }else{
                
                let alertController = UIAlertController(title: "Atencion!", message: "Está por cargar el reporte de envio: \(self.selected_cut.corte!)", preferredStyle: .alert)
                
                
                
                let OKAction = UIAlertAction(title: "Cargar Reporte", style: .default) { (action) in
                    
                    let cantidadEnvio = NSNumber(value: Int32(self.cantidadDeEnvioTextfield.text!)!)
      

        
                    
                    
                    
                    Services.createReportEnvio(cantidadEnvio, andCutName: self.corteIDLabel.text, andCutID:self.selected_cut.cut_id, andNumeroDeEnvio: self.numeroDeEnvioTextField.text, andHandler: { (response) in
                        
                        self.loadCut()
                        let alertController = UIAlertController(title: "Bien!", message: "Cargaste el reporte de envio: \(self.selected_cut.corte!)", preferredStyle: .alert)
                        
                        
                        let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                            
                        }
                        alertController.addAction(OKAction)
                        
                        self.present(alertController, animated: true) {
                            // ...
                        }
         
                        
 
                        
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

    
    
    
    func showAddReportCorte(){
        
        
        UIView.animate(withDuration: 0.4) {
            self.addBackView.alpha = 1
            self.reportcutView.transform = CGAffineTransform.identity
            self.reportcutView.alpha = 1
            
        }
        
    }
    
    
    func hideAddReportCorte(){
        
        UIView.animate(withDuration: 0.4) {
            self.addBackView.alpha = 0
            self.reportcutView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            self.reportcutView.alpha = 0
            
        }
        
        
        self.statusTextField.resignFirstResponder()
        self.cant_real_textFiled.resignFirstResponder()
      
        
        
    }
    
    @IBAction func closeReportCorte(){
        
        self.hideAddReportCorte()
        
    }
    
    @IBAction func guardarReporteCorte(){
        
        if self.statusTextField.text == ""{
            
            let alertController = UIAlertController(title: "Oops!", message: "Debes llenar todos los campos para cargar un reporte del corte", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
        }else{
            
            if self.updatingReport{
                
                
                let alertController = UIAlertController(title: "Atencion!", message: "Está por actualizar el reporte del corte \(self.selected_cut.corte!)", preferredStyle: .alert)
                
                
                
                let OKAction = UIAlertAction(title: "Actualizar Reporte", style: .default) { (action) in
                    
                    if self.cant_real_textFiled.text == ""{
                    
                    self.cant_real_textFiled.text = "0"
                    }
                    let cantReal = NSNumber(value: Int32(self.cant_real_textFiled.text!)!)
                    
            
                    
                    Services.updateReportCorte(cantReal, andstatus: self.statusTextField.text, andCutName:self.selected_cut.corte, andCutID:self.selected_cut.cut_id, andReportID:self.report_id, andHandler: { (response) in
                        self.loadCut()
                        let alertController = UIAlertController(title: "Bien!", message: "Actualizaste el reporte del corte: \(self.selected_cut.corte!)", preferredStyle: .alert)
                        
                        
                        let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                            
                        }
                        alertController.addAction(OKAction)
                        
                        self.present(alertController, animated: true) {
                            // ...
                        }
          
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
                    if self.cant_real_textFiled.text == ""{
                        
                        self.cant_real_textFiled.text = "0"
                    }
                    
                    let cantReal = NSNumber(value: Int32(self.cant_real_textFiled.text!)!)
                    
                    
                    
                    
                    Services.createReportCorte(cantReal, andstatus: self.statusTextField.text, andCutName:self.selected_cut.corte, andCutID:self.selected_cut.cut_id, andHandler: { (response) in
                        self.loadCut()
                        if ((response as? String) != nil){
                            let alertController = UIAlertController(title: "Oops", message: "No puedes cargar mas de un reporte de corte", preferredStyle: .alert)
                            
                            
                            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                                
                            }
                            alertController.addAction(OKAction)
                            
                            self.present(alertController, animated: true) {
                                // ...
                            }
                            
                            
                        }else{
                            let alertController = UIAlertController(title: "Bien!", message: "Cargaste el reporte al corte: \(self.selected_cut.corte!)", preferredStyle: .alert)
                            
                            
                            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                                
                            }
                            alertController.addAction(OKAction)
                            
                            self.present(alertController, animated: true) {
                                // ...
                            }
                            
                            
                            
                        }
                        
               
                        

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

    func showChooseReportView(){

        self.operariosField.text = ""
        self.faltasField.text = ""
        self.producidasField.text = ""
        self.en_planchaField.text = ""
        self.en_empaquieField.text = ""
        self.bodegaField.text = ""
        self.statusTextField.text = ""
        self.cant_real_textFiled.text = ""
        self.cantidadDeEnvioTextfield.text = ""
        self.numeroDeEnvioTextField.text = ""

 
    
        UIView.animate(withDuration: 0.4) {
            self.addBackView.alpha = 1
            self.choosingReportTypeView.transform = CGAffineTransform.identity
            self.choosingReportTypeView.alpha = 1
    
        }
        
    }
    
    
    func hideChooseReportView(){
        
        UIView.animate(withDuration: 0.4) {
            self.addBackView.alpha = 0
            self.choosingReportTypeView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            self.choosingReportTypeView.alpha = 0
            
        }
        
        

        
        
        
    }
    
    @IBAction func selectedCutType(){
        
 
            
            
            Services.getReportsForCut(self.selected_cut.cut_id, andHandler:{ (response) in
                
                self.reports_array = response as! [Report]
                
                var boolReport = false
                for report in self.reports_array{
                
                    if report.type_report.lowercased() == "corte"{
                    
                        boolReport = true
                    
                    }
                }
                
                
                if !boolReport{
                
                    self.hideChooseReportView()
                    self.showAddReportCorte()
                    
                
                }else{
                
                    
                    let alertController = UIAlertController(title: "Oops!", message: "No puedes crear otro reporte de corte.", preferredStyle: .alert)
                    
                    
                    let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                        
                    }
                    alertController.addAction(OKAction)
                    
                    self.present(alertController, animated: true) {
                        // ...
                    }
                
                }
                
            }, orErrorHandler: { (err) in
                
                
                
            })
   
    }
    @IBAction func selectedPlantType(){
        self.hideChooseReportView()
        self.showAddPlantView()
        
    }
    @IBAction func selectedenvioType(){
        self.hideChooseReportView()
        self.showAddReportEnvio()
    }
    
    
    @IBAction func closeChooseingView(){
        
        self.hideChooseReportView()
    }
    
    
    func showImage(image: String) {
        UIView.animate(withDuration: 0.4) {
            self.addBackView.alpha = 1
            self.imageViewBig.transform = CGAffineTransform.identity
            self.imageViewBig.alpha = 1
            
            self.styleImageView.sd_setImage(with: NSURL(string: image) as URL!)
            
            
            
        }
        
        
        
    }
    @IBAction func hideImageBackView(){
        
        UIView.animate(withDuration: 0.4) {
            self.addBackView.alpha = 0
            self.imageViewBig.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            self.imageViewBig.alpha = 0
            
            self.styleImageView.sd_setImage(with: NSURL(string: "") as URL!)
            
            
            
        }
    }
}
