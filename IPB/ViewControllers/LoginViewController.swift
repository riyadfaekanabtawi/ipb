//
//  LoginViewController.swift
//  IPB
//
//  Created by Riyad Anabtawi on 11/28/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController,UITextFieldDelegate {

    
    @IBOutlet var entrarButton: UIButton!
    @IBOutlet var loginViewParent: UIView!
    @IBOutlet var emailView: UIView!
    @IBOutlet var passwordView: UIView!
    @IBOutlet var titleWelcome: UILabel!
    @IBOutlet var emailLabel: UILabel!
    @IBOutlet var passwordLabel: UILabel!
    
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var emailTextField: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setNeedsStatusBarAppearanceUpdate()
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)

        
         self.navigationController?.navigationBar.barStyle = UIBarStyle.blackTranslucent
        
        self.navigationController?.navigationBar.isHidden = true
        self.emailLabel.font = UIFont(name: FONT_BOLD, size: self.emailLabel.font.pointSize)
        self.passwordLabel.font = UIFont(name: FONT_BOLD, size: self.passwordLabel.font.pointSize)
        
        self.passwordTextField.font = UIFont(name: FONT_REGULAR, size: (self.passwordTextField.font?.pointSize)!)
        self.emailTextField.font = UIFont(name: FONT_REGULAR, size: (self.emailTextField.font?.pointSize)!)
        
        self.titleWelcome.font = UIFont(name: FONT_BOLD, size: (self.titleWelcome.font?.pointSize)!)
        self.loginViewParent.layer.cornerRadius = 4
        self.loginViewParent.layer.masksToBounds = true
        
        self.emailView.layer.cornerRadius = 4
        self.emailView.layer.masksToBounds = true
        
        
        self.passwordView.layer.cornerRadius = 4
        self.passwordView.layer.masksToBounds = true
        
        
        
        self.entrarButton.layer.cornerRadius = 4
        self.entrarButton.layer.borderColor = UIColor.black.cgColor
        self.entrarButton.layer.borderWidth = 2
        self.entrarButton.layer.masksToBounds = true
        
        
        
        if ((UserDefaults.standard.object(forKey: "user_main")) != nil){
        
        self.performSegue(withIdentifier: "home", sender: self)
        }
        
        // Do any additional setup after loading the view.
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
    
     @IBAction func tapView(){
        self.passwordTextField.resignFirstResponder()
        self.emailTextField.resignFirstResponder()
        
    }
    @IBAction func entrarTouchUpInside(){
     
        
        
        if (self.emailTextField.text == "" || self.passwordTextField.text == ""){
        
            
            let alertController = UIAlertController(title: "Oops", message: "Tienes que completar todos los campos para poder ingresar.", preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
                // ...
            }
            alertController.addAction(cancelAction)
            
            let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                // ...
            }
            alertController.addAction(OKAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
        
        }else{
       Services.loginwith(self.emailTextField.text, andPassword: self.passwordTextField.text, andHandler: { (response) in
        
        
        
        if (response as? String) != nil{
        
            if response as! String == "Email does not match password"{
            
                let alertController = UIAlertController(title: "Oops", message: "Tu correo electrónico no coincide con tu contraseña, intenta nuevamente.", preferredStyle: .alert)
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
                    // ...
                }
                alertController.addAction(cancelAction)
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    // ...
                }
                alertController.addAction(OKAction)
                
                self.present(alertController, animated: true) {
                    // ...
                }
            
            }
            
            if response as! String == "We could not find any users with that email."{
                
                let alertController = UIAlertController(title: "Oops", message: "Parece que no tienes acceso a IPB, comunicate con el Administrador para mayor información.", preferredStyle: .alert)
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
                    // ...
                }
                alertController.addAction(cancelAction)
                
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    // ...
                }
                alertController.addAction(OKAction)
                
                self.present(alertController, animated: true) {
                    // ...
                }
                
            }
            
            
        }else{
        
            
            let user = response as! User
            
            let defaults = UserDefaults.standard
            
            defaults.set(NSKeyedArchiver.archivedData(withRootObject: user), forKey: "user_main")
            
            
            defaults.synchronize()
            
            
            self.performSegue(withIdentifier: "home", sender: self)
        
        }
       }, orErrorHandler: { (err) in
        
        
        
       })
        }
    }
    
    
    
    func keyboardWillShow(notification: NSNotification) {
        
        if !self.emailTextField.isEditing{
        
            if ((notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
                self.view.frame.origin.y -= 90
            }
        }
       
        
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if !self.emailTextField.isEditing{
            
            if ((notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
                self.view.frame.origin.y += 90
            }
        }
    }
    
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if self.emailTextField == textField{
        
            self.passwordTextField.becomeFirstResponder()
        
        }
        
        if self.passwordTextField == textField{
        
        self.passwordTextField.resignFirstResponder()
        self.emailTextField.resignFirstResponder()
        }
        
        
        
        
        return true
    }
    
    
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            return .lightContent
        }
    }

    
    
    
    
    

}
