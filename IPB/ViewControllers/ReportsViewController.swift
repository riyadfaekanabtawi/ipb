//
//  ReportsViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/18/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

class ReportsViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,asignDelegate,pendingCutdelegate,UITextFieldDelegate {
    
    @IBOutlet var styleImageView: UIImageView!
    @IBOutlet var BackaddPlantview: UIView!
    @IBOutlet var imageViewBig: UIView!
    @IBOutlet var imagenTitle: UILabel!
    @IBOutlet var closeButton: UIButton!
    
    @IBOutlet var cortesTitle: UILabel!
    @IBOutlet var noCutsLabel: UILabel!
    @IBOutlet var cuts_collectionview: UICollectionView!
    var pending_cuts_array:[Corte] = []
    var selected_cut:Corte!
    
    @IBOutlet var planta_textField: UITextField!
    @IBOutlet var lista_textfield: UITextField!
    @IBOutlet var corte_textfield: UITextField!
    @IBOutlet var estilo_textfield: UITextField!
    @IBOutlet var status_textfield: UITextField!
    @IBOutlet var fecha_ipb_textfield: UITextField!
    @IBOutlet var fecha_cliente_textfield: UITextField!
     @IBOutlet var filtrarLabel: UILabel!
     @IBOutlet var cancelfiltrarLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        self.imagenTitle.font = UIFont(name: FONT_BOLD, size: self.imagenTitle.font.pointSize)
   self.filtrarLabel.font = UIFont(name: FONT_BOLD, size: self.filtrarLabel.font.pointSize)
         self.cancelfiltrarLabel.font = UIFont(name: FONT_BOLD, size: self.cancelfiltrarLabel.font.pointSize)
        
        
        self.planta_textField.font = UIFont(name: FONT_REGULAR, size: (self.planta_textField.font?.pointSize)!)
        
        
        self.imageViewBig.layer.cornerRadius = 4
        self.imageViewBig.layer.masksToBounds = true
        self.BackaddPlantview.alpha = 0
        self.imageViewBig.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.imageViewBig.alpha = 0
         self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)!
        self.noCutsLabel.alpha = 0
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
        
        Services.getCutsForReportAndHandler({ (response) in
            
            self.pending_cuts_array = response as! [Corte]
            
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
        self.performSegue(withIdentifier: "selectedCut", sender: self)
        
        
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.pending_cuts_array.count
    }
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 1
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cortes_pending", for: indexPath) as! PendingCutCollectionViewCell
        cell.delegate = self
        cell.displayCorte(cut: self.pending_cuts_array[indexPath.row])
        cell.status_label.text = "ASIGNADO"
          cell.status_view.backgroundColor = Functions.color(withHexString: "FFF53C", andAlpha: 1)
        return cell
        
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.cuts_collectionview.frame.size.width-20, height: 240)
    }
    
    @IBAction func goBack(){
        
        self.navigationController?.popViewController(animated: true)
        
    }
    
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "selectedCut"{
            
            let controller = segue.destination as! CutDetailViewController
            controller.pending_cuts_array = [self.selected_cut]
            controller.selected_cut = self.selected_cut
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
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == self.planta_textField{
        
        self.lista_textfield.becomeFirstResponder()
        
        }
        
        if textField == self.lista_textfield{
        
        self.corte_textfield.becomeFirstResponder()
        
        }
        
        
        
        if textField == self.corte_textfield{
            
            self.estilo_textfield.becomeFirstResponder()
            
        }
        
        
        if textField == self.estilo_textfield{
            
            self.status_textfield.becomeFirstResponder()
            
        }
        if textField == self.status_textfield{
            
            self.fecha_ipb_textfield.becomeFirstResponder()
            
        }
        
        if textField == self.fecha_ipb_textfield{
            
            self.fecha_cliente_textfield.becomeFirstResponder()
            
        }
        
        if textField == self.fecha_cliente_textfield{
            
            self.fecha_cliente_textfield.resignFirstResponder()
            
        }
        
        return true
    }
    
     @IBAction func ResetfilterTouchUpInside(){
         self.getPendingCuts()
        self.planta_textField.text = ""
        self.lista_textfield.text = ""
        self.corte_textfield.text = ""
        self.estilo_textfield.text = ""
        self.status_textfield.text = ""
        self.fecha_ipb_textfield.text = ""
        self.fecha_cliente_textfield.text = ""
       
        self.planta_textField.resignFirstResponder()
        self.lista_textfield.resignFirstResponder()
        self.corte_textfield.resignFirstResponder()
        self.estilo_textfield.resignFirstResponder()
        self.status_textfield.resignFirstResponder()
        self.fecha_ipb_textfield.resignFirstResponder()
        self.fecha_cliente_textfield.resignFirstResponder()
    }
    
    
    @IBAction func filterTouchUpInside(){
        
        
        
        Services.filterCuts(self.planta_textField.text, andLista: self.lista_textfield.text, andCorte: self.corte_textfield.text, andEstilo: self.estilo_textfield.text, andStatus: self.status_textfield.text, andfechaIPB: self.fecha_ipb_textfield.text, andFechaCliente: self.fecha_cliente_textfield.text, andHandler:{ (response) in
            
            self.pending_cuts_array = response as! [Corte]
            
            if self.pending_cuts_array.count != 0{
                self.noCutsLabel.alpha = 0
                self.cuts_collectionview.alpha = 1
                self.cuts_collectionview.reloadData()
                
            }else{
                self.noCutsLabel.alpha = 1
                
                self.cuts_collectionview.alpha = 0
                
            }
            
            self.planta_textField.resignFirstResponder()
            self.lista_textfield.resignFirstResponder()
            self.corte_textfield.resignFirstResponder()
            self.estilo_textfield.resignFirstResponder()
            self.status_textfield.resignFirstResponder()
            self.fecha_ipb_textfield.resignFirstResponder()
            self.fecha_cliente_textfield.resignFirstResponder()
    
            
        }, orErrorHandler: { (err) in
            
            self.planta_textField.resignFirstResponder()
            self.lista_textfield.resignFirstResponder()
            self.corte_textfield.resignFirstResponder()
            self.estilo_textfield.resignFirstResponder()
            self.status_textfield.resignFirstResponder()
            self.fecha_ipb_textfield.resignFirstResponder()
            self.fecha_cliente_textfield.resignFirstResponder()
            
        })
        
    }
    
    
    func asignedCut() {
        self.getPendingCuts()
    }
}
