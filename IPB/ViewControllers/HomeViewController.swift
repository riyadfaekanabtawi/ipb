//
//  HomeViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 11/28/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit
import MessageUI
class HomeViewController: UIViewController,SWRevealViewControllerDelegate,MenuViewControllerDelegate,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,UIImagePickerControllerDelegate,UINavigationControllerDelegate,MFMailComposeViewControllerDelegate,UITextViewDelegate,UITextFieldDelegate {
    var plants_array:[Planta] = []
    var enviosUrgentesArray:[Corte] = []
    var pending_cuts_array:[PendingCut] = []
    
    var monthsArryay = ["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre",]
    var analisisCuts:[Corte] = []
    
    @IBOutlet var heightPlantsGraphs: NSLayoutConstraint!
    @IBOutlet var cortesAsignadosbutton: UIButton!
    @IBOutlet var listo_confec: UILabel!
    @IBOutlet var mesa_corte: UILabel!
    @IBOutlet var enEspera: UILabel!
    
    @IBOutlet var listo_confecV: UIView!
    @IBOutlet var mesa_corteV: UIView!
    @IBOutlet var enEsperaV: UIView!
 
    @IBOutlet var refreshIcon: UIButton!
    @IBOutlet var badgeView: UIView!
    @IBOutlet var badgeLabel: UILabel!
    
    @IBOutlet var analisisCorteLabel: UILabel!
    @IBOutlet var titleViewLabelColelctionView: UILabel!
    @IBOutlet var noEnviosLabel: UILabel!
    @IBOutlet var enviosUrgentesLabel: UILabel!
    @IBOutlet var titleViewLabel: UILabel!
    @IBOutlet var pendingCutsTitleLabel: UILabel!
    @IBOutlet var blockView: UIView!
     @IBOutlet var plant_collectionview: UICollectionView!
    @IBOutlet var enviosUrgentes_collectionview: UICollectionView!
    @IBOutlet var cortesPendientes_collectionview: UICollectionView!
    
        @IBOutlet var cortes_analisis_collectionview: UICollectionView!
    
     @IBOutlet var alertEnvios: UIImageView!
    @IBOutlet var corteLabel: UILabel!
    @IBOutlet var clientLabel: UILabel!
    
    @IBOutlet var corteLabel2: UILabel!
    @IBOutlet var clientLabel2: UILabel!
    
    @IBOutlet var analisis_count_label: UILabel!
    @IBOutlet var corteLabelCell: UILabel!
    @IBOutlet var cantidadLabelCell: UILabel!
    @IBOutlet var clienteLabelCell: UILabel!
    @IBOutlet var cortadasLabelCell: UILabel!
    @IBOutlet var badgeViewAnalisis: UIView!
    
    @IBOutlet var firstWebView: UIWebView!
    
    var revealController:SWRevealViewController!
    
    var indicatorView1 : MAActivityIndicatorView!
    
 
    
    
    @IBOutlet var backAddView: UIView!
    @IBOutlet var AddView: UIView!
    
    @IBOutlet var enviarReporteTitle: UILabel!
 
    @IBOutlet var comentarioLabel: UILabel!
    @IBOutlet var comentarioTextView: UITextView!
    @IBOutlet var selectedImage: UIImageView!
    @IBOutlet var cargarImagenLabel: UILabel!
    
    @IBOutlet var enviarButton: UIButton!
    @IBOutlet var closeButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
      
        
        self.backAddView.alpha = 0
        self.AddView.alpha = 0
        
        self.AddView.layer.cornerRadius = 4
        self.AddView.layer.masksToBounds = true
        
        self.AddView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)
        
        self.enviarButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.enviarButton.titleLabel?.font.pointSize)!)
        
        self.enviarReporteTitle.font = UIFont(name: FONT_BOLD, size: self.enviarReporteTitle.font.pointSize)

        self.comentarioLabel.font = UIFont(name: FONT_REGULAR, size: self.comentarioLabel.font.pointSize)
        self.cargarImagenLabel.font = UIFont(name: FONT_REGULAR, size: self.cargarImagenLabel.font.pointSize)
        
        
        self.corteLabelCell.font = UIFont(name: FONT_BOLD, size: self.corteLabelCell.font.pointSize)
        self.cantidadLabelCell.font = UIFont(name: FONT_BOLD, size: self.cantidadLabelCell.font.pointSize)
        self.clienteLabelCell.font = UIFont(name: FONT_BOLD, size: self.clienteLabelCell.font.pointSize)
        self.cortadasLabelCell.font = UIFont(name: FONT_BOLD, size: self.cortadasLabelCell.font.pointSize)
        self.analisis_count_label.font = UIFont(name: FONT_BOLD, size: self.analisis_count_label.font.pointSize)
        self.badgeViewAnalisis.layer.cornerRadius = self.badgeViewAnalisis.frame.size.width/2
        self.badgeViewAnalisis.clipsToBounds = true
        
        self.badgeView.layer.cornerRadius = self.badgeView.frame.size.width/2
        self.badgeView.clipsToBounds = true
        
        self.listo_confecV.layer.cornerRadius = self.listo_confecV.frame.size.width/2
        self.listo_confecV.clipsToBounds = true
        
        self.mesa_corteV.layer.cornerRadius = self.mesa_corteV.frame.size.width/2
        self.mesa_corteV.clipsToBounds = true
        
        self.enEsperaV.layer.cornerRadius = self.enEsperaV.frame.size.width/2
        self.enEsperaV.clipsToBounds = true
        
        
         self.mesa_corte.font = UIFont(name: FONT_REGULAR, size: self.mesa_corte.font.pointSize)
         self.listo_confec.font = UIFont(name: FONT_REGULAR, size: self.listo_confec.font.pointSize)
         self.enEspera.font = UIFont(name: FONT_REGULAR, size: self.enEspera.font.pointSize)
        
        
        self.heightPlantsGraphs.constant = self.view.frame.size.height/2 + 30
        self.view.layoutIfNeeded()
        //self.showLoader()
        self.corteLabel2.font = UIFont(name: FONT_BOLD, size: self.corteLabel2.font.pointSize)
        self.badgeLabel.font = UIFont(name: FONT_BOLD, size: self.badgeLabel.font.pointSize)
        
        self.clientLabel2.font = UIFont(name: FONT_BOLD, size: self.clientLabel2.font.pointSize)
        
         self.corteLabel.font = UIFont(name: FONT_BOLD, size: self.corteLabel.font.pointSize)
        
         self.clientLabel.font = UIFont(name: FONT_BOLD, size: self.clientLabel.font.pointSize)
        
        self.titleViewLabelColelctionView.font = UIFont(name: FONT_BOLD, size: self.titleViewLabelColelctionView.font.pointSize)
self.analisisCorteLabel.font = UIFont(name: FONT_BOLD, size: self.analisisCorteLabel.font.pointSize)
        
        self.refreshHomePlants()
        self.titleViewLabel.font = UIFont(name: FONT_BOLD, size: self.titleViewLabel.font.pointSize)
        self.enviosUrgentesLabel.font = UIFont(name: FONT_BOLD, size: self.enviosUrgentesLabel.font.pointSize)
        self.pendingCutsTitleLabel.font = UIFont(name: FONT_BOLD, size: self.pendingCutsTitleLabel.font.pointSize)
        
         self.noEnviosLabel.font = UIFont(name: FONT_REGULAR, size: self.noEnviosLabel.font.pointSize)
        self.noEnviosLabel.alpha = 0
                   self.blockView.alpha = 0
        self.slideMenuSetUp()
        
             self.setNeedsStatusBarAppearanceUpdate()
        self.navigationController?.navigationBar.barStyle = UIBarStyle.blackTranslucent
        //[self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        
        self.refreshHomePlants()
        self.getUrgentEnvios()
        self.getPendingCuts()
        
        self.loadAnalisis()
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "pendingcutsFilter"{
        
        let controller = segue.destination as! ReportsViewController
            controller.filteringFromHome = true
        
        }
    }
    
    
    func slideMenuSetUp(){
    
    self.revealController = self.revealViewController()
        
        if (self.revealController != nil){
        
        self.revealController.delegate = self
            self.revealController.toggleAnimationDuration=1;
            self.revealController.rearViewRevealWidth=250;
            
            
            let menu = self.revealController.rearViewController as! MenuViewController
            
            menu.delegate = self
        
        }
    
    }
  
    
    func revealController(_ revealController: SWRevealViewController!, animateTo position: FrontViewPosition) {
        
        
        if position == FrontViewPosition.left{
        self.blockView.alpha = 0.4
            UIView.animate(withDuration: 0.3) {
                self.blockView.alpha = 0.0
                
        
            }
            
        
        }
        
        
        
        
        if position == FrontViewPosition.right{
        
            self.blockView.alpha = 0
            
            let menu = revealController.rearViewController as! MenuViewController
            menu.refrsh()
            UIView.animate(withDuration: 0.3) {
                self.blockView.alpha = 0.4
                
                
            }
        
        }
    }
    @IBAction func refreshHome(){
        Functions.runSpinAnimation(on: self.refreshIcon, duration: 0.6, rotations: 1, repeat: 0)
       
        self.refreshHomePlants()
        self.getUrgentEnvios()
        self.getPendingCuts()
        
        self.loadAnalisis()
        
    }
    
    
    
    func showCargarReport(){
        UIView.animate(withDuration: 0.3) {
            self.comentarioTextView.text = "ingresar"
            self.selectedImage.image = UIImage.init(named: "add photo.png")
            self.backAddView.alpha = 1
            self.AddView.transform = CGAffineTransform.identity
            self.AddView.alpha = 1
        }
        
    
    
    }

    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if self.comentarioTextView == textField{
            
            self.comentarioTextView.resignFirstResponder()
        }
        
        
        
     return true
    }
    func hideReport(){
    
        UIView.animate(withDuration: 0.3) {
            self.backAddView.alpha = 0
            self.AddView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
             self.AddView.alpha = 0
        }
    
    }
    @IBAction func goToUrgents(){
        
        self.performSegue(withIdentifier: "envios", sender: self)
    }
     @IBAction func goToPendings(){
        
          self.performSegue(withIdentifier: "pendingcuts", sender: self)
    }
    @IBAction func cortesAsignados(){
        
        self.performSegue(withIdentifier: "pendingcutsFilter", sender: self)
        
    }
    
    
    
    @IBAction func blockViewTapper(){
        
        let revealController = self.revealController
        
        
        if revealController != nil{
        
        revealController?.revealToggle(animated: true)
            
        }
        
    }
    
  
    
    
    @IBAction func openMenu(){
        
        let revealController = self.revealController
        
        
        if revealController != nil{
            
            revealController?.revealToggle(animated: true)
            
        }
        
    }
    
    
    
    func selectedMenuviewcontrollerOption(_ option: String) {
        
        
        let revealController = self.revealController
        
        
        if revealController != nil{
            
            revealController?.revealToggle(animated: true)
            
        }
        
        
        if option == "cerrar_sesion"{
        
            let defaults = UserDefaults.standard
            
            defaults.removeObject(forKey: "user_main")
            defaults.synchronize()
            
            self.navigationController?.popToRootViewController(animated: true)
            
        
        }
        
  
        if option == "envios"{
            
            self.performSegue(withIdentifier: option, sender: self)
        }
        
        if option == "reportsall"{
            
            self.performSegue(withIdentifier: option, sender: self)
        }
        
        if option == "createReportHome"{
            
           self.showCargarReport()
        }
        
        
        if option == "reportes"{
            
            self.performSegue(withIdentifier: option, sender: self)
        }
        
        if option == "listas"{
        
        self.performSegue(withIdentifier: "pendingcuts", sender: self)
        
        }
        
        if option == "dashboard"{
            
            self.refreshHomePlants ()
        }
        if option == "plantas"{
            
            self.performSegue(withIdentifier: option, sender: self)
            
        }
        
        
        if option == "clientes"{
          self.performSegue(withIdentifier: "clients", sender: self)
            
        }
        
        
        if option == "calculadora"{
              self.performSegue(withIdentifier: option, sender: self)
            
        }
        
     
        if option == "proyectos"{
        
         self.performSegue(withIdentifier: option, sender: self)
        }
  
        
        if option == "estilos"{
            
             self.performSegue(withIdentifier: option, sender: self)
        }
        
        if option == "usuarios"{
              self.performSegue(withIdentifier: option, sender: self)
            
        }
        if option == "pendingcuts"{
            
            self.performSegue(withIdentifier: option, sender: self)
        }
        
        if option == "proveedores"{
          self.performSegue(withIdentifier: option, sender: self)
        
        }
        
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
   
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if self.enviosUrgentes_collectionview == collectionView{
        
            return self.enviosUrgentesArray.count
        
        }else if self.cortesPendientes_collectionview == collectionView{
        
            return self.pending_cuts_array.count
        
        
        }else if self.cortes_analisis_collectionview == collectionView{
        
        return self.analisisCuts.count
        }else{
        return self.monthsArryay.count
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if self.enviosUrgentes_collectionview == collectionView{
        
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "urgent", for: indexPath)as!UrgentSebdsDashboardCollectionViewCell
            
            cell.displayCorte(cut: self.enviosUrgentesArray[indexPath.row])
            
            return cell
        }else if self.cortesPendientes_collectionview == collectionView{
        
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "pendingHome", for: indexPath)as!PendingHomecutCollectionViewCell
            
            cell.displayPendingcuts(cut: self.pending_cuts_array[indexPath
                .row])
            
            return cell
        
        
        }else if collectionView == self.cortes_analisis_collectionview{
        
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "analisisCuts", for: indexPath)as!AnalisisCollectionViewCell
            
            cell.displayAnalisisCuts(cuts: self.analisisCuts[indexPath
                .row])
            
            return cell
        
        }else{
     
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "homeplant", for: indexPath) as! PlantHomeCollectionViewCell
            
            
            cell.displayMonths(month: self.monthsArryay[indexPath.row])
            return cell
        
        }
    
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
         if self.enviosUrgentes_collectionview == collectionView || self.cortesPendientes_collectionview == collectionView{
            
            
            return CGSize(width: 250 , height: 50)
        
        
         }else if collectionView == self.cortes_analisis_collectionview{
          return CGSize(width: self.cortes_analisis_collectionview.frame.size.width-20 , height: 50)
         
         }else{
          return CGSize(width: self.plant_collectionview.layer.frame.size.width , height: self.view.frame.size.height/2)
        
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    
    func refreshHomePlants()
    
    {
    
        let loader  = SBTVLoaderView.create()
        
        let window = UIApplication.shared.keyWindow
        let sub =   (window?.subviews[0])! as UIView
        
        Functions.fillContainerView(sub, with: loader)
        
            
    Services.getPlantsWithandHandler({ (response) in
        
        self.plants_array = response as! [Planta]
        
        
        self.plant_collectionview.reloadData()
           loader?.removeFromSuperview()
    }, orErrorHandler: { (err) in
      loader?.removeFromSuperview()
        
        let alertController = UIAlertController(title: "Oops!", message: "Revisa tu conexión a internet.", preferredStyle: .alert)
        
        
        let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
            
        }
        alertController.addAction(OKAction)
        
        self.present(alertController, animated: true) {
            // ...
        }
        
        
    })

    
    }
    
    
    func hideLoader(){

    }
    func showLoader(){
        
    }
    
    
    func loadAnalisis(){
    
    
    Services.getAllcuts({ (response) in
        
        self.analisisCuts = response as! [Corte]
        
        
        self.analisis_count_label.text = "\(self.analisisCuts.count)"
        self.cortes_analisis_collectionview.reloadData()
        
        
    }, orErrorHandler: { (err) in
        
        
        
    })
        
    }
    func getUrgentEnvios()
        
    {
        
        
        Services.getEnviosUrgentesWithandHandler({ (response) in
            
            self.enviosUrgentesArray = response as! [Corte]
            
            if self.enviosUrgentesArray .count == 0{
            self.noEnviosLabel.alpha = 1
                self.enviosUrgentes_collectionview.alpha = 0
            self.alertEnvios.alpha = 0
            }else{
            self.alertEnvios.alpha = 1
                self.noEnviosLabel.alpha = 0
                 self.enviosUrgentes_collectionview.alpha = 1
                self.enviosUrgentes_collectionview.reloadData()
                
            
            }
            
           
        }, orErrorHandler: { (err) in
            
            
            
        })
        
        
    }
    
    
    func getPendingCuts()
        
    {
        
        
        Services.getPendingCutsWithandHandler({ (response) in
            
            self.pending_cuts_array = response as! [PendingCut]
            
            self.badgeLabel.text = "\(self.pending_cuts_array.count)"
            self.cortesPendientes_collectionview.reloadData()
            
        }, orErrorHandler: { (err) in
            
            
            
        })
        
        
    }

    @IBAction func closeReports(){
        
        self.hideReport()
            
    }
    
    
    @IBAction func enviarEmail(){
        
        self.hideReport()
        self.sendMail()
    }
     @IBAction func goToCalculator(){
        
        self.performSegue(withIdentifier: "calculadora",
                          sender: self)
    }
    
    
    @IBAction func analisisTupI(){
        
        self.performSegue(withIdentifier: "analisis", sender: self)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        Functions.isChoosingImage(false)
        
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.selectedImage.contentMode = UIViewContentMode.scaleAspectFill
            self.selectedImage.image = pickedImage
            
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    
    
    @IBAction func openCameraButton() {
            Functions.isChoosingImage(true)
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.camera;
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    
  
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        
         picker.dismiss(animated: true, completion: nil);
    }
    
    
    
    func sendMail() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self;
            mail.setCcRecipients([""])
            mail.setSubject("Su Mensaje")
            mail.setMessageBody(self.comentarioTextView.text, isHTML: false)
            let imageData: NSData = UIImagePNGRepresentation(self.selectedImage.image!)! as NSData
            mail.addAttachmentData(imageData as Data, mimeType: "image/png", fileName: "imageName")
            self.present(mail, animated: true, completion: nil)
        }
    }
}
