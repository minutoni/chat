//
//  ViewController.swift
//  chat
//
//  Created by 所　紀彦 on 2019/04/27.
//  Copyright © 2019 所　紀彦. All rights reserved.
//

import UIKit
import Firebase
import SVProgressHUD
import Speech
import FirebaseCore
import FirebaseDatabase
//import JSQMessagesViewController


class ViewController: UIViewController,SFSpeechRecognitionTaskDelegate,UITextFieldDelegate{
//    var messages: [JSQMessage]?
//
//    var incomingBubble: JSQMessagesBubbleImage!
//    var outgoingBubble: JSQMessagesBubbleImage!
//    var exitcomingBubble: JSQMessagesBubbleImage!
//
//    var incomingAvater: JSQMessagesAvatarImage!
//    var outgoingAvater: JSQMessagesAvatarImage!
    
    //========================改変==========
    @IBOutlet weak var textView: UITextView!
    @IBOutlet var messageButton: UIButton!
    //@IBOutlet var recordButton == messageButton      : UIButton!
    @IBOutlet weak var nameField: UITextField!
    var databaseRef:DatabaseReference!
    
    
    
    var uid:String = UUID().uuidString
    
    let userRef = Database.database().reference().child("users")
    let roofRef = Database.database().reference()
    
    let userDefaults = UserDefaults.standard
    
    //AppDelegateのインスタンスを作り、AppDelegateの変数を使えるようにする
    //let app:AppDelegate = (UIApplication.shared.delegate as!, AppDelegate)
    let app:AppDelegate = (UIApplication.shared.delegate as! AppDelegate)
    
    //ここから追加＊
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja_JP"))!
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let audioEngine = AVAudioEngine()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //=====================改変
        //messageField.delegate = self as! UITextFieldDelegate
        
        // Do any additional setup after loading the view.
        
        //初回時のみ自分のIDを保存しておく、それ以降は使い回し(uid管理
        if(userDefaults.string(forKey: "uid") != nil){
            uid = userDefaults.string(forKey: "uid")!
            self.textView.text! = "\(String(describing: self.textView.text))\n\(String(describing: uname)) : \(messageButton)"
        }else{
            userDefaults.set(uid, forKey: "uid")
        }
//        //セッティングしている。新しいデータが入ってくるのを見張ってる。もしも、新しいデータが入ってきた場合{}内の処理を実行する。
//        databaseRef.observe(DataEventType.childAdded, with: { snapshot in //セッティングしている。新しいデータが入ってくるのを見張ってる。もしも、新しいデータが入ってきた場合{}内の処理を実行する。
//            if let name = (snapshot.value! as AnyObject).object(forKey: "name") as? String,
//                let message = (snapshot.value! as AnyObject).object(forKey: "message") as? String {
//                self.textView.text! = "\(self.textView.text!)\n\(name) : \(message)"
//
//            }
//        })
    
        print("自分のuid→\(self.uid)")
        
        //indicatorを回す
        SVProgressHUD.setDefaultStyle(SVProgressHUDStyle.dark)
        //↓の処理を入れるとIndicatorが回っている間は背後のUIが非活性になる。
        //     SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.black)
        SVProgressHUD.show(withStatus: "チャット相手を探しています")
        
        self.app.chatStartFlg = false
        
        //表示される名前(未実装)
        //self.senderDisplayName = "hoge"
        setupFirebase()
        getRoom()
        //setUpChatUi()
        
        //self.messages = []
        
        //＊
        messageButton.isEnabled = false
        
        //firebaseのfromカラムに入る値
               //self.senderId = self.uid
        
        
    }
    
    //＊
    override func viewWillAppear(_ animated: Bool) {
        
        SFSpeechRecognizer.requestAuthorization { (status) in
            OperationQueue.main.addOperation {
                switch status {
                case .authorized: break   // 許可OK
                    self.messageButton.isEnabled = true
                    //録音ボタンの設定
                    self.messageButton.backgroundColor = UIColor.blue
                case .denied:       // 拒否
                    self.messageButton.isEnabled = false
                    self.messageButton.setTitle("録音許可なし", for: .disabled)
                case .restricted:   // 限定
                    self.messageButton.isEnabled = false
                    self.messageButton.setTitle("このデバイスでは無効", for: .disabled)
                case .notDetermined:// 不明
                    self.messageButton.isEnabled = false
                    self.messageButton.setTitle("録音機能が無効", for: .disabled)
                }
            }
        }
        
        speechRecognizer.delegate = self as? SFSpeechRecognizerDelegate // デリゲート先になる
        
    }
    
    func setupFirebase(){
        //匿名アカウントを認証する
        Auth.auth().signInAnonymously() { (user, error) in
            if error != nil {
                //エラー時の処理
                print("失敗")
                return
            }
            //成功時の処理
            print("成功")
        }
    }
    
    func getRoom(){
//        let user = ["name":hoge,
//            //senderDisplayName,
//                    "inRoom": "0",
//                    "waitingFlg": "0"] as [String : Any]
        
        userRef.child(self.uid).setValue(databaseRef)
        
        //一回だけwaitingFlgが1のユーザーを取得
        userRef.queryOrdered(byChild: "waitingFlg").queryEqual(toValue: "1").observeSingleEvent(of: .value,with: { (snapshot) in
            let value = snapshot.value as? NSDictionary
            
            if (value != nil){
                if(value!.count >= 1){
                    
                    //ルームを作る側の処理
                    print(value!.count);
                    print("value \(value!)")
                    print("↑初回ボタン押下時に、waitingFlgが１のユーザ")
                    //ルームを作る側の処理
                    self.createRoom(value: value as! Dictionary<AnyHashable, Any>)
                }
            }else{
                //ルームを作られのを待つ側の処理
                self.userRef.child(self.uid).updateChildValues(["waitingFlg":"1"])
                self.checkMyWaitingFlg();
            }
        })
    }
    
    //他のユーザが自分とマッチするまで待機する
    func checkMyWaitingFlg(){
        //userRef.child(self.uid).observe(FIRDataEventType.childCahnged, with: {(snapshot) in
            userRef.child(self.uid).child("waitingFlg").observe(.value, with: { (snapshot) in
            print(snapshot)
            let snapshotVal = snapshot.value as! String
            let snapshotKey = snapshot.key
            
            if (snapshotVal == "0" && snapshotKey == "waitingFlg"){
                self.getJoinRoom()
            }
        })
    }
    
    //自身のjoinする（している）roomIdを取得
    func getJoinRoom(){
        userRef.child(self.uid).child("inRoom").observeSingleEvent(of: .value, with: { (snapshot) in
            //帰ってくる型が一つしかないからstr型になる
            let snapshotValue = snapshot.value as! String
            self.app.roomId = snapshotValue
            
            if(self.app.roomId != "1"){
                print("roomId→ \(self.app.roomId!)")
                print("チャットを開始します")
                self.getMessages()
            }
        })
    }
    
    //roomIdからそのroomのmessage情報を取得する
    //chatが始まる際必ず呼ばれるmethod
    func getMessages(){
        //Indicatorを止める
        SVProgressHUD.dismiss()
        
        SVProgressHUD.showSuccess(withStatus: "マッチングしました")
        
        self.app.chatStartFlg = true
    
    //【非同期】子要素が増えるたびにmessageに値を追加する。
        roofRef.child("rooms").child(self.app.roomId!).queryLimited(toLast: 100).observe(DataEventType.childAdded, with: { (snapshot) in
            let snapshotValue = snapshot.value as! NSDictionary
            let text          = snapshotValue["text"] as! String
            let sender        = snapshotValue["from"] as! String
            let name          = snapshotValue["name"] as! String
            
            print("display名前→\(name)")
//            let message       = getMessages(senderId: sender,
//                                            displayName: name,
//                                            text: text)
//            self.messages?.append(message!)
//            self.finishReceivingMessage()
        })
    }
    
    func createRoom(value:Dictionary<AnyHashable, Any>){
        //chatを始めるユーザを取得
        
        for(key,val)in value {
            //自分のidと違うユーザを取得
            if(key as! String != self.uid){
                //待機中のユーザーがいた場合(必ずこの処理でいるが)の処理
                print("待機中のユーザId\(key)")
                self.app.targetId = key as? String
            }
        }
        
        print("チャットを開始するユーザId\(self.app.targetId!)")
        
        //新規のroomを作るための数値を取得
        getNewRoomId()
    }
    
    var count: Int = 1
    
    //新しくルームを作る際の数値を取得
    func getNewRoomId(){
        Database.database().reference().child("roomKeyNum").observeSingleEvent(of: .value, with: { (snapshot) in
            
            if !(snapshot.value is NSNull){
                self.count = (snapshot.value as! Int) + 1
                }
            Database.database().reference()
            .child("roomKeyNum")
            .setValue(self.count)
            
            self.app.newroomId = String(self.count)
            self.updateEachUserInfo()
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
    //1to1でマッチした場合、お互いの情報を更新する
    func updateEachUserInfo() {
        self.app.roomId = self.app.roomId
        
        print (self.app.roomId!)
        print (self.app.newroomId!)
        //ユーザ情報を書き換えて行く
        userRef.child(self.app.targetId!).updateChildValues(["inRoom":self.app.roomId!])
        userRef.child(self.app.targetId!).updateChildValues(["waitingFlg":"0"])
        userRef.child(self.uid).updateChildValues(["inRoom":self.app.roomId!])
        userRef.child(self.uid).updateChildValues(["waitingFlg":"0"])
        
        //新しく作ったルームのidを取ってくる処理[非同期]
        getMessages()
        
    }

    
    
    //別の画面に遷移する直前に実行される処理
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("ViewController/viewWillDisappear/別の画面に遷移する直前")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("ViewController/viewDidDisappear/別の画面に遷移した直後")
        
        userRef.child(self.uid).updateChildValues(["waitingFlg":"0"])
        
        //Indicatorを止める
        SVProgressHUD.dismiss()
        
        if(self.app.roomId != "0"){
            //相手に退出のメッセージを送るようにする
            let endMsg = "~相手が退出したよ！~"
            //sendTextToDb(text: endMsg,exitFlg: true)
            self.app.roomId = "0"
            
        }
    }
    
    //メッセージの送信
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, //senderId: String!, senderDisplayName: String!,
        date: Date!) {
        self.finishSendingMessage(animated: true)

        if(self.app.chatStartFlg! == true){

            startRecording(text:text)
            //*ここからsendTextToDbへデータを送る
            sendTextToDb(text: text)
            self.textView.text = Result.bestTranscription.formattedString

            let messageData = ["name": nameField.text!, "message": ] //messageField.text!
            // firebaseにdictionary型を保存するためデータを作成！
            databaseRef.childByAutoId().setValue(messageData) // データを保存！
            textView.resignFirstResponder() //キーボードを閉じる
            //messageField.text = "" //最終的にはtextFieldを空にする。
            return true

        }else{
            print("チャット相手を検索中です,,,")
        }
    }
    

    
    
//====================================================＊===============================================
    
   
    
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            // 利用可能になったら、録音ボタンを有効にする
            messageButton.isEnabled = true
            messageButton.setTitle("Start Recording", for: [])
            messageButton.backgroundColor = UIColor.blue
        } else {
            // 利用できないなら、録音ボタンは無効にする
            messageButton.isEnabled = false
            messageButton.setTitle("現在、使用不可", for: .disabled)
        }
    }
    
//==================================================-ボタンメソッド==================
    private func startRecording() throws{
        //ここに録音する処理を記述
        if let recognitionTask = recognitionTask {
            //既存タスクがあればキャンセルしてリセット
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSession.Category.record)
        try audioSession.setMode(AVAudioSession.Mode.measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("リクエスト生成エラー")}
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode // elsedo {fatalError("InputNodewエラー")}
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { (result, error) in
            var isFinal = false
            
            
            if let result = result{
                //ここ！音声データが送られてくる場所？
                self.textView.text = result.bestTranscription.formattedString
                
//                let post:Dictionary<String, Any>? = ["from":tmpSenderId,
//                                                     "name":senderDisplayName(),
//                                                     "text":text]
                isFinal = result.isFinal
                //self.sendTextToDb(text: result.bestTranscription.formattedString)
                
                
            }
            
            if Error.self != nil || isFinal{
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.messageButton.isEnabled = true
                self.messageButton.setTitle("start recording", for: [])
                self.messageButton.backgroundColor = UIColor.white
                
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {(buffer:AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare() //オーディオエンジン準備
        try audioEngine.start() //オーディオエンジン開始
        
        //textView.text = "(認識中、、、そのまま話し続けてください)"
        
    }
    
    
   func sendTextToDb(text: String,exitFlg:Bool = false){
        //データベースへの送信（後述）
        let rootRef = Database.database().reference()
    
        //var tmpSenderId = senderId as String
        if(exitFlg){
            //tmpSenderId = "exit"
        }
        
//        let post:Dictionary<String, Any>? = ["from":tmpSenderId,
//                                             "name"://senderDisplayName(),
//                                             "text":text]
    
//    let messageData = ["name": UITextField.text,
//                       "message": //self.messageField.text!
//        ] as [String : Any]
    self.textView.resignFirstResponder()
    //self.messa.text = ""
    //return true
        
        let postRef = rootRef.child("rooms").child(self.app.roomId!).childByAutoId()
        //postRef.setValue(post)
    
    
    
    }
    
      @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            // 音声エンジン動作中なら停止
            audioEngine.stop()
            recognitionRequest?.endAudio()
            messageButton.isEnabled = false
            messageButton.setTitle("Stopping", for: .disabled)
           messageButton.backgroundColor = UIColor.lightGray
            return
        }
        // 録音を開始する
        try! startRecording()
        messageButton.setTitle("認識を完了する", for: [])
        messageButton.backgroundColor = UIColor.red
    }
    
    //=================================================代用案(カメラボタンを変えてみる)==================
//    override func didPressAccessoryButton(_ sender: UIButton!) {
//        recordButtonTapped()
//    }
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
    //=================================↓JSQMessageの色々==========================================//
    
    
    
    
    
//    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
//        return self.messages?[indexPath.item]
//    }
//
//    //バブルの色を返す。
//    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
//        let message = self.messages?[indexPath.item]
//
//        if message?.senderId == self.senderId {
//            return self.outgoingBubble
//        } else if message?.senderId == "exit"{
//            return self.exitcomingBubble
//        }
//        return self.incomingBubble
//    }
//
//    //アバター（サムネを返す）
//    override func collectionView(_ collectionView: JSQMessagesCollectionView!,
//                                 avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
//        let message = self.messages?[indexPath.item]
//        if message?.senderId == self.senderId {
//            return self.outgoingAvater
//        }
//        return self.incomingAvater
//    }
//
//    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return (self.messages?.count)!
//    }
//
//    func setUpChatUi() {
//        //ツールバーの設定
//        //inputToolbar!.contentView!.leftBarButtonItem = nil
//        inputToolbar!.contentView!.rightBarButtonItem = nil
//        automaticallyScrollsToMostRecentMessage = true
//
//        //firebaseのfromカラムに入る値
//        self.senderId = self.uid
//
//        //jself.collectionView.backgroundView = JSQPhotoMediaItem(image: UIImage(named: "p0121_l.png"))
//
//        self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
//        self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
//
//        let bubbleFactory = JSQMessagesBubbleImageFactory()
//        self.incomingBubble = bubbleFactory?.incomingMessagesBubbleImage(
//            with: UIColor.gray)
//        self.outgoingBubble = bubbleFactory?.outgoingMessagesBubbleImage(
//            with: UIColor.jsq_messageBubbleGreen())
//        self.exitcomingBubble = bubbleFactory?.incomingMessagesBubbleImage(
//            with: UIColor.jsq_messageBubbleRed())
//
//    }
}


