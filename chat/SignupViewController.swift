//
//  SignupViewController.swift
//  chat
//
//  Created by 所　紀彦 on 2019/05/17.
//  Copyright © 2019 所　紀彦. All rights reserved.
//

import UIKit
import Firebase //Firebaseをインポート

class SignupViewController: UIViewController,UITextFieldDelegate{
    
    @IBOutlet var emailTextField: UITextField! // Emailを打つためのTextField
    
    @IBOutlet var passwordTextField: UITextField! //Passwordを打つためのTextField
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        emailTextField.delegate = self //デリゲートをセット
        passwordTextField.delegate = self //デリゲートをセット
        passwordTextField.isSecureTextEntry = true // 文字を非表示に
        
        //self.layoutFacebookButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //ログインしていれば、遷移
        //FIRAuthがユーザー認証のためのフレーム
        //checkUserVerifyでチェックして、ログイン済みなら画面遷移
        if self.checkUserVerify() {
            self.transitionToView()
        }
    }
    
    // ログイン済みかどうかと、メールのバリデーションが完了しているか確認
    func checkUserVerify()  -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        return user.isEmailVerified
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    //サインアップボタン
    @IBAction func willSignup() {
        //サインアップのための関数
        signup()
    }
    //ログイン画面への遷移ボタン
    @IBAction func willTransitionToLogin() {
        transitionToLogin()
    }
    
//    @IBAction func willLoginWithFacebook() {
//        self.willLoginWithFacebook()
//    }
    
    //ログイン画面への遷移
    func transitionToLogin() {
        self.performSegue(withIdentifier: "toLogin", sender: self)
    }
    //ListViewControllerへの遷移
    func transitionToView() {
        self.performSegue(withIdentifier: "toView", sender: self)
    }
    //Returnキーを押すと、キーボードを隠す
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
}

    //Signupのためのメソッド
    func signup() {
        //emailTextFieldとpasswordTextFieldに文字がなければ、その後の処理をしない
        guard let email = emailTextField.text else  { return }
        guard let password = passwordTextField.text else { return }
        //FIRAuth.auth()?.createUserWithEmailでサインアップ
        //第一引数にEmail、第二引数にパスワード
        Auth.auth().createUser(withEmail: email, password: password, completion: { (user, error) in
            //エラーなしなら、認証完了
            if error == nil{
                // メールのバリデーションを行う
                Auth.auth().currentUser?.sendEmailVerification(completion: { (error) in
                    if error == nil {
                        // エラーがない場合にはそのままログイン画面に飛び、ログインしてもらう
                        self.transitionToLogin()
                    }else {
                        print("\(error?.localizedDescription)")
                    }
                })
            }else {
                
                print("\(error?.localizedDescription)")
            }
        })
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //outputText.text = inputText.text
        self.view.endEditing(true)
    }
    
    func firebaseLoginWithCredial(_ credial: AuthCredential) {
        if Auth.auth().currentUser != nil {
            print("current user is not nil")
            Auth.auth().currentUser?.linkAndRetrieveData(with: credial, completion: { dataResult, error in
                if error != nil {
                    print("error happens")
                    print("error reason...\(String(describing: error))")
                }else {
                    print("sign in with credential")
                    Auth.auth().signInAndRetrieveData(with: credial, completion: { dataResult, error in
                        if error != nil {
                            print("\(String(describing: error?.localizedDescription))")
                        }else {
                            print("Logged in")
                        }
                    })
                }
            })
        }else {
            print("current user is nil")
            Auth.auth().signInAndRetrieveData(with: credial) { dataResult, error in
                if error != nil {
                    print("\(String(describing: error))")
                }else {
                    print("Logged in")
                }
            }
        }
    }
   
}
    

