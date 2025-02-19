//
//  EnviosViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/29/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

class EnviosViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout,asignDelegate,pendingCutdelegate {
    
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
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        self.imagenTitle.font = UIFont(name: FONT_BOLD, size: self.imagenTitle.font.pointSize)
        
        self.imageViewBig.layer.cornerRadius = 4
        self.imageViewBig.layer.masksToBounds = true
        self.BackaddPlantview.alpha = 0
        self.imageViewBig.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.imageViewBig.alpha = 0
        self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)!
        self.noCutsLabel.alpha = 0
        self.cortesTitle.font = UIFont(name: FONT_BOLD, size: self.cortesTitle.font.pointSize)
        self.noCutsLabel.font = UIFont(name: FONT_REGULAR, size: self.noCutsLabel.font.pointSize)
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
        
        let loader  = SBTVLoaderView.create()
        
        let window = UIApplication.shared.keyWindow
        let sub =   (window?.subviews[0])! as UIView
        
        Functions.fillContainerView(sub, with: loader)
        
        
        Services.getEnviosUrgentesWithandHandler({ (response) in
            
            self.pending_cuts_array = response as! [Corte]
            
            if self.pending_cuts_array.count != 0{
                self.noCutsLabel.alpha = 0
                self.cuts_collectionview.alpha = 1
                self.cuts_collectionview.reloadData()
                
            }else{
                self.noCutsLabel.alpha = 1
                
                self.cuts_collectionview.alpha = 0
                
            }
            
            
            loader?.removeFromSuperview()
        }, orErrorHandler: { (err) in
            
            let alertController = UIAlertController(title: "Oops!", message: "Revisa tu conexión a internet.", preferredStyle: .alert)
            
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            loader?.removeFromSuperview()
            
        })
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        
//        self.selected_cut = self.pending_cuts_array[indexPath.row]
//        self.performSegue(withIdentifier: "selectedCut", sender: self)
        
        
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
        let resultIngreso = formatter.string(from: NSNumber(value:self.pending_cuts_array[indexPath.row].cut_precio_final))
        cell.ingreso_label.text = "Ingreso: $ \(resultIngreso!)"
  
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
    
    
    func asignedCut() {
        self.getPendingCuts()
    }
}
