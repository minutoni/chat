//
//  subViewController.swift
//  chat
//
//  Created by 所　紀彦 on 2019/05/17.
//  Copyright © 2019 所　紀彦. All rights reserved.
//

import UIKit
import Firebase
import SVProgressHUD
import Speech
import FirebaseCore
import FirebaseDatabase

class subViewController: UIViewController,SFSpeechRecognitionTaskDelegate,UITextFieldDelegate {

    
    
    
    let ref = Database.database().reference() //FirebaseDatabaseのルートを指定
    
    @IBOutlet var textField: UITextField! //投稿のためのTextField
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textField.delegate = self as! UITextFieldDelegate //デリゲートをセット
    }
    
    var isCreate = true //データの作成か更新かを判定、trueなら作成、falseなら更新
    
    var selectedSnap: DataSnapshot! //ListViewControllerからのデータの受け取りのための変数
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //selectedSnapがnilならその後の処理をしない
        guard let snap = self.selectedSnap else { return }
        
        //受け取ったselectedSnapを辞書型に変換
        let item = snap.value as! Dictionary<String, AnyObject>
        //textFieldに受け取ったデータのcontentを表示
        textField.text = item["content"] as? String
        //isCreateをfalseにし、更新するためであることを明示
        isCreate = false
    }
    //Postボタンを以下のように変更
    @IBAction func post(sender: UIButton) {
        if isCreate {
            //投稿のためのメソッド
            create()
        }else {
            //更新するためのメソッド
            update()
        }
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //Returnキーを押すと、キーボードを隠す
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    //データの送信のメソッド
    func create() {
        //textFieldになにも書かれてない場合は、その後の処理をしない
        guard let text = textField.text else { return }
        
        //ロートからログインしているユーザーのIDをchildにしてデータを作成
        //childByAutoId()でユーザーIDの下に、IDを自動生成してその中にデータを入れる
        //setValueでデータを送信する。第一引数に送信したいデータを辞書型で入れる
        //今回は記入内容と一緒にユーザーIDと時間を入れる
        //FIRServerValue.timestamp()で現在時間を取る
        self.ref.child((Auth.auth().currentUser?.uid)!).childByAutoId().setValue(["user": (Auth.auth().currentUser?.uid)!,"content": text, "date": ServerValue.timestamp()])
    }
    
    //更新のためのメソッド
    func update() {
        //ルートからのchildをユーザーIDに指定
        //ユーザーIDからのchildを受け取ったデータのIDに指定
        //updateChildValueを使って更新
        ref.keepSynced(true)
        ref.child((Auth.auth().currentUser?.uid)!).child("\(self.selectedSnap.key)").updateChildValues(["user": (Auth.auth().currentUser?.uid)!,"content": self.textField.text!, "date": ServerValue.timestamp()])
    }
    
    func logout() {
        do {
            //do-try-catchの中で、FIRAuth.auth()?.signOut()を呼ぶだけで、ログアウトが完了
            try Auth.auth().signOut()
            
            //先頭のNavigationControllerに遷移
            let storyboard = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Nav")
            self.present(storyboard, animated: true, completion: nil)
        }catch let error as NSError {
            print("\(error.localizedDescription)")
        }
        
    }
    
}
