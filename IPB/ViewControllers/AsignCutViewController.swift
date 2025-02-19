//
//  AsignCutViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/3/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit
protocol asignDelegate {
    func asignedCut()
}
class AsignCutViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout,UICollectionViewDataSource,plantdelegate {
    @IBOutlet var styleImageView: UIImageView!
    @IBOutlet var BackaddPlantview: UIView!
    @IBOutlet var imageViewBig: UIView!
    @IBOutlet var imagenTitle: UILabel!
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var plant_label: UILabel!
    
    var delegate:asignDelegate!
    @IBOutlet var titleViewcontroller: UILabel!
    @IBOutlet var plants_collectionview: UICollectionView!
    var plants_array:[Planta] = []
    @IBOutlet var corte_idLabel: UILabel!
    @IBOutlet var style_iamge: UIImageView!
    
    @IBOutlet var ingresosLabel: UILabel!
    @IBOutlet var prendaLabel: UILabel!
    
    @IBOutlet var listaLabel: UILabel!
    @IBOutlet var corteLabel: UILabel!
    @IBOutlet var estiloLabel: UILabel!
    @IBOutlet var cantidadLabel: UILabel!
    @IBOutlet var precioUnitarioLabel: UILabel!
    var styles_array:[Styles] = []
    @IBOutlet var fecha_cliente_label: UILabel!
    @IBOutlet var fecha_ib_label: UILabel!
    @IBOutlet var clientLabel: UILabel!
    var imageString:String!
    @IBOutlet var porAsignar: UILabel!
    var styleSelected:Styles!
    var pendingCut:PendingCut!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.titleViewcontroller.font = UIFont(name: FONT_BOLD, size: self.titleViewcontroller.font.pointSize)
        
         self.imagenTitle.font = UIFont(name: FONT_BOLD, size: self.imagenTitle.font.pointSize)
        
        self.ingresosLabel.font = UIFont(name: FONT_REGULAR, size: self.ingresosLabel.font.pointSize)
        self.prendaLabel.font = UIFont(name: FONT_REGULAR, size: self.prendaLabel.font.pointSize)
        
        self.corte_idLabel.font = UIFont(name: FONT_REGULAR, size: self.corte_idLabel.font.pointSize)
        self.listaLabel.font = UIFont(name: FONT_REGULAR, size: self.listaLabel.font.pointSize)
        self.corteLabel.font = UIFont(name: FONT_REGULAR, size: self.corteLabel.font.pointSize)
        self.estiloLabel.font = UIFont(name: FONT_REGULAR, size: self.estiloLabel.font.pointSize)
        self.cantidadLabel.font = UIFont(name: FONT_REGULAR, size: self.cantidadLabel.font.pointSize)
        self.precioUnitarioLabel.font = UIFont(name: FONT_REGULAR, size: self.precioUnitarioLabel.font.pointSize)
  self.closeButton.titleLabel?.font = UIFont(name: FONT_BOLD, size: (self.closeButton.titleLabel?.font.pointSize)!)!
        self.fecha_cliente_label.font = UIFont(name: FONT_REGULAR, size: self.fecha_cliente_label.font.pointSize)
        self.fecha_ib_label.font = UIFont(name: FONT_REGULAR, size: self.fecha_ib_label.font.pointSize)
        self.porAsignar.font = UIFont(name: FONT_BOLD, size: self.porAsignar.font.pointSize)
        self.clientLabel.font = UIFont(name: FONT_REGULAR, size: self.clientLabel.font.pointSize)
        // Do any additional setup after loading the view.
        
        self.imageViewBig.layer.cornerRadius = 4
        self.imageViewBig.layer.masksToBounds = true
        self.BackaddPlantview.alpha = 0
        self.imageViewBig.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.imageViewBig.alpha = 0

        
        let loader  = SBTVLoaderView.create()
        
        let window = UIApplication.shared.keyWindow
        let sub =   (window?.subviews[0])! as UIView
        
        Functions.fillContainerView(sub, with: loader)
        
        Services.getPlantsWithandHandler({ (response) in
            
            self.plants_array = response as! [Planta]
            
        
            
           Services.getStyle(self.pendingCut.cut_estilo, andHandler: { (response) in
            
            self.styleSelected = response as! Styles
            
            
            self.plants_collectionview.reloadData()
            
            var arrayMUT = [""]
            let arrayPlant = self.styleSelected.plants_array as! [Corte]
            for plant in arrayPlant {
                
                arrayMUT.append(plant.plant_id.stringValue)
                
                
            }
            let arr = arrayMUT
            var counts:[String:Int] = [:]
            
            for item in arr {
                if (item != ""){
                    counts[item] = (counts[item] ?? 0) + 1
                }
                
            }
            
            print(counts)  // "[BAR: 1, FOOBAR: 1, FOO: 2]"
            
            if (counts.description != "[:]"){
                
                
                var stringArray = [""]
                for (key, value) in counts {
                    
                    
                    for plant in self.plants_array{
                        
                        if (plant.planta_id.stringValue == key){
                            
                            stringArray.append("\(plant.planta_nombre!) : \(value) Estilos")
                            
                        }
                        
                        
                    }
                    
                    
                    
                    
                }
                let string = stringArray.joined(separator: ", ").replacingOccurrences(of: ",", with: " ")
                self.plant_label.text = "Estilo asignados a plantas: \(string)"
                
            }else{
                self.plant_label.text = "Estilo no asignado a planta"
                
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
        
    
        self.prendaLabel.text = "Prenda: \(self.pendingCut.prenda!)"
        
        Services.getStyleImage(self.pendingCut.cut_estilo!, andHandler: { (response) in
       
        
            
            self.style_iamge.sd_setImage(with: NSURL(string:"\(BASE_URL)\(response as! String)") as URL!)
            self.imageString = "\(BASE_URL)\(response as! String)"
   
        }, orErrorHandler: { (err) in
            
            
        })
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
      
        
        let resultCantidad = formatter.string(from: NSNumber(value:Int(self.pendingCut.cut_cantidad.intValue)))
      //  let resultPrecio_final = "\(self.pendingCut.cut_precio_final)"
        
        
        
        
        let ingreso = self.pendingCut.cut_cantidad.floatValue * self.pendingCut.cut_precio_unitario
        
        let resultIngreso = formatter.string(from: NSNumber(value:ingreso))
        self.ingresosLabel.text = "Ingresos: $ \(resultIngreso!)"
        
        self.corteLabel.text = "Corte: \(self.pendingCut.corte!)"
        self.listaLabel.text = "Lista: \(self.pendingCut.cut_list!)"
        self.corte_idLabel.text = "\(self.pendingCut.corte!)"
        
        self.cantidadLabel.text = "Cantidad \(resultCantidad!)"
        self.precioUnitarioLabel.text = "Precio/u: $ \(self.pendingCut.cut_precio_unitario)"
        
        self.fecha_ib_label.text = "Fecha IPB \(self.pendingCut.cut_fecha_ipb!)"
        self.fecha_cliente_label.text = "Fecha Cliente \(self.pendingCut.cut_fecha_client!)"
        
        self.clientLabel.text = "\(self.pendingCut.cut_client!)"
    
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
        cell.displayPlant(plant: self.plants_array[indexPath.row])
        cell.viewParent = self.view
        cell.controller = self
        cell.corteSelected = self.pendingCut
        cell.delegate = self
        return cell
        
        
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        
        return CGSize(width: 359, height: self.plants_collectionview.frame.size.height)
    }
    
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func asignedQuantityToPlant(cut: PendingCut) {
        
        self.delegate.asignedCut()
        
        self.pendingCut = cut
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        
        
        let resultCantidad = formatter.string(from: NSNumber(value:Int(self.pendingCut.cut_cantidad.intValue)))
   
        
        
        self.corteLabel.text = "Corte: \(self.pendingCut.corte!)"
        self.listaLabel.text = "Lista: \(self.pendingCut.cut_list!)"
        self.corte_idLabel.text = "\(self.pendingCut.corte!)"
        
        self.cantidadLabel.text = "Cantidad: \(resultCantidad!)"
        self.precioUnitarioLabel.text = "Precio/u: \(self.pendingCut.cut_precio_unitario)"
    
        self.fecha_ib_label.text = "Fecha IPB: \(self.pendingCut.cut_fecha_ipb!)"
        self.fecha_cliente_label.text = "Fecha Cliente: \(self.pendingCut.cut_fecha_client!)"
        
        self.clientLabel.text = "\(self.pendingCut.cut_client!)"
        
        
        if self.pendingCut.estado == "Asignado"{
            self.porAsignar.text = "Asignado"
            self.porAsignar.textColor = Functions.color(withHexString: "5FBA56", andAlpha: 1)
        }else{
            self.porAsignar.text = "Por Asignar"
            self.porAsignar.textColor = Functions.color(withHexString: "EC2127", andAlpha: 1)

            
        
        }
        
        self.plants_collectionview.reloadData()
        self.navigationController?.popViewController(animated: true)
    
    }
    
    
    func refreshFather() {
        
    }
   
  @IBAction func showImage() {
        UIView.animate(withDuration: 0.4) {
            self.BackaddPlantview.alpha = 1
            self.imageViewBig.transform = CGAffineTransform.identity
            self.imageViewBig.alpha = 1
            
            self.styleImageView.sd_setImage(with: NSURL(string: self.imageString) as URL!)
            
            
            
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
    
    
 
}
