//
//  AsignCutViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 12/3/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class AsignCutViewController: UIViewController {

    
    
    @IBOutlet var titleViewcontroller: UILabel!
    
    
    @IBOutlet var corte_idLabel: UILabel!
    @IBOutlet var listaLabel: UILabel!
    @IBOutlet var corteLabel: UILabel!
    @IBOutlet var estiloLabel: UILabel!
    @IBOutlet var cantidadLabel: UILabel!
    @IBOutlet var precioUnitarioLabel: UILabel!
    @IBOutlet var precio_total: UILabel!
    @IBOutlet var fecha_cliente_label: UILabel!
    @IBOutlet var fecha_ib_label: UILabel!
    @IBOutlet var realizadas_label: UILabel!
    
    @IBOutlet var porAsignar: UILabel!
    
    var pendingCut:PendingCut!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.titleViewcontroller.font = UIFont(name: FONT_BOLD, size: self.titleViewcontroller.font.pointSize)
        
        
        self.corte_idLabel.font = UIFont(name: FONT_REGULAR, size: self.corte_idLabel.font.pointSize)
        self.listaLabel.font = UIFont(name: FONT_BOLD, size: self.listaLabel.font.pointSize)
        self.corteLabel.font = UIFont(name: FONT_BOLD, size: self.corteLabel.font.pointSize)
        self.estiloLabel.font = UIFont(name: FONT_BOLD, size: self.estiloLabel.font.pointSize)
        self.cantidadLabel.font = UIFont(name: FONT_BOLD, size: self.cantidadLabel.font.pointSize)
        self.precioUnitarioLabel.font = UIFont(name: FONT_BOLD, size: self.precioUnitarioLabel.font.pointSize)
        self.precio_total.font = UIFont(name: FONT_BOLD, size: self.precio_total.font.pointSize)
        self.fecha_cliente_label.font = UIFont(name: FONT_BOLD, size: self.fecha_cliente_label.font.pointSize)
        self.fecha_ib_label.font = UIFont(name: FONT_BOLD, size: self.fecha_ib_label.font.pointSize)
        self.porAsignar.font = UIFont(name: FONT_BOLD, size: self.porAsignar.font.pointSize)
        self.realizadas_label.font = UIFont(name: FONT_BOLD, size: self.realizadas_label.font.pointSize)
        // Do any additional setup after loading the view.
        
        
        
        
        
        self.corteLabel.text = "Corte: \(self.pendingCut.cut_id!)"
        self.listaLabel.text = "\(self.pendingCut.cut_list!)"
        self.corte_idLabel.text = "\(self.pendingCut.cut_id!)"
        
        self.cantidadLabel.text = "\(self.pendingCut.cut_cantidad!)"
        self.precioUnitarioLabel.text = "\(self.pendingCut.cut_precio_unitario!)"
        self.precio_total.text = "\(self.pendingCut.cut_precio_final!)"
        self.fecha_ib_label.text = "Fecha IPB: \(self.pendingCut.cut_fecha_ipb!)"
        self.fecha_cliente_label.text = "Fecha Cliente: \(self.pendingCut.cut_fecha_client!)"
        
        self.realizadas_label.text = "Realizadas: 0"
    
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
}
