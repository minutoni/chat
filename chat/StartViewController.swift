//
//  StartViewController.swift
//  chat
//
//  Created by 所　紀彦 on 2019/04/27.
//  Copyright © 2019 所　紀彦. All rights reserved.
//

import UIKit
import SVProgressHUD

class StartViewController: UIViewController {
    
    //AppDelegateのインスタンスを作り、AppDelegateの変数を使えるようにする
    let app:AppDelegate = (UIApplication.shared.delegate as! AppDelegate)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.app.roomId = "0"
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}
