//
//  ListViewController.swift
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

class ListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource,SFSpeechRecognitionTaskDelegate {
    
    @IBOutlet weak var table: UITableView! //送信したデータを表示するTableView
    
    //音声確認用
    @IBOutlet var textView: UITextView!
    
    //レコボタン追加
    @IBOutlet var recordButton: UIButton!
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja_JP"))!
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let audioEngine = AVAudioEngine()
    
    
    var contentArray: [DataSnapshot] = [] //Fetchしたデータを入れておく配列、この配列をTableViewで表示
    
    var contentSubArray: String = ""
    //subから持ってきた
    var isCreate = true //データの作成か更新かを判定、trueなら作成、falseなら更新
    
    var snap: DataSnapshot! //FetchしたSnapshotsを格納する変数
    
    let ref = Database.database().reference() //Firebaseのルートを宣言しておく
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //データを読み込むためのメソッド
        self.read()
        
        //TableViewCellをNib登録、カスタムクラスを作成
        table.register(UINib(nibName: "ListTableViewCell", bundle: nil), forCellReuseIdentifier: "ListCell")
        
        table.delegate = self //デリゲートをセット
        table.dataSource = self //デリゲートをセット
        
        // Do any additional setup after loading the view.
        
        //recordButton.isEnabled = false
        //selectedSnapがnilならその後の処理をしない
        guard let snap = self.selectedSnap else { return }
        
        //受け取ったselectedSnapを辞書型に変換
        let item = snap.value as! Dictionary<String, AnyObject>
        //textFieldに受け取ったデータのcontentを表示
        textView.text = item["content"] as? String
        //isCreateをfalseにし、更新するためであることを明示
        isCreate = false
    }
    
    
    //画面が切り替わったあと
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //Cellの高さを調節
        table.estimatedRowHeight = 56
        table.rowHeight = UITableView.automaticDimension
        
        
        //        //selectedSnapがnilならその後の処理をしない
        //        guard let snap = self.selectedSnap else { return }
        //
        //        //受け取ったselectedSnapを辞書型に変換
        //        let item = snap.value as! Dictionary<String, AnyObject>
        //        //textFieldに受け取ったデータのcontentを表示
        //        textView.text = item["result.bestTranscription.formattedString"] as? String
        //        //isCreateをfalseにし、更新するためであることを明示
        //        isCreate = false
        
        //レコぶん
        //speechRecognizer.delegate = self as! SFSpeechRecognizerDelegate    // デリゲート先になる
        speechRecognizer.delegate = self as? SFSpeechRecognizerDelegate // デリゲート先になる
        
        SFSpeechRecognizer.requestAuthorization { (status) in
            OperationQueue.main.addOperation {
                switch status {
                case .authorized:   // 許可OK
                    self.recordButton.isEnabled = true
                    //self.recordButton.backgroundColor = UIColor.blue
                case .denied:       // 拒否
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("録音許可なし", for: .disabled)
                case .restricted:   // 限定
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("このデバイスでは無効", for: .disabled)
                case .notDetermined:// 不明
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("録音機能が無効", for: .disabled)
                }
            }
        }
        
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        //画面が消えたときに、Firebaseのデータ読み取りのObserverを削除しておく
        ref.removeAllObservers()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    //ViewControllerへの遷移のボタン
    //    @IBAction func didSelectAdd() {
    //        self.transition()
    //    }
    
    //ViewControllerへの遷移
    //    func transition() {
    //        self.performSegue(withIdentifier: "toView", sender: self)
    //    }
    
    //セルの数
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return contentArray.count
    }
    
    //返すセルを決める
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //xibとカスタムクラスで作成したCellのインスタンスを作成
        let cell = table.dequeueReusableCell(withIdentifier: "ListCell") as! ListTableViewCell
        
        //配列の該当のデータをitemという定数に代入
        let item = contentArray[indexPath.row]
        //itemの中身を辞書型に変換
        let content = item.value as! Dictionary<String, AnyObject>
        //contentという添字で保存していた投稿内容を表示(ListTableViewcellに送られる情報
        cell.contenttext.text = String(describing: content["content"]!)
        //dateという添字で保存していた投稿時間をtimeという定数に代入
        let time = content["date"] as! TimeInterval
        //getDate関数を使って、時間をtimestampから年月日に変換して表示
        //cell.postDateLabel.text = self.getDate(number: time/1000)
        
        return cell
    }
    
    func read()  {
        //FIRDataEventTypeを.Valueにすることにより、なにかしらの変化があった時に、実行
        //今回は、childでユーザーIDを指定することで、ユーザーが投稿したデータの一つ上のchildまで指定することになる
        ref.child((Auth.auth().currentUser?.uid)!).observe(.value, with: {(snapShots) in
            if snapShots.children.allObjects is [DataSnapshot] {
                print("snapShots.children...\(snapShots.childrenCount)") //いくつのデータがあるかプリント
                
                print("snapShot...\(snapShots)") //読み込んだデータをプリント
                
                self.snap = snapShots
                
            }
            self.reload(snap: self.snap)
        })
    }
    
    //読み込んだデータは最初すべてのデータが一つにまとまっているので、それらを分割して、配列に入れる
    func reload(snap: DataSnapshot) {
        if snap.exists() {
            print(snap)
            //FIRDataS
            //napshotが存在するか確認
            contentArray.removeAll()
            //1つになっているFIRDataSnapshotを分割し、配列に入れる
            for item in snap.children {
                contentArray.append(item as! DataSnapshot)
            }
            // ローカルのデータベースを更新
            ref.child((Auth.auth().currentUser?.uid)!).keepSynced(true)
            //テーブルビューをリロード
            table.reloadData()
        }
    }
    //timestampで保存されている投稿時間を年月日に表示形式を変換する
    func getDate(number: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: number)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    //変更したいデータのための変数、CellがタップされるselectedSnapに値が代入される
    var selectedSnap: DataSnapshot!
    //選択されたCellの番号を引数に取り、contentArrayからその番号の値を取り出し、selectedSnapに代入
    //その後遷移
//    func didSelectRow(selectedIndexPath indexPath: IndexPath) {
//        //ルートからのchildをユーザーのIDに指定
//        //ユーザーIDからのchildを選択されたCellのデータのIDに指定
//        self.selectedSnap = contentArray[indexPath.row]
//        //self.transition(from: <#UIViewController#>, to: <#UIViewController#>)
//    }
    //Cellがタップされると呼ばれる
    //上記のdidSelectedRowにタップされたCellのIndexPathを渡す
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        //self.didSelectRow(selectedIndexPath: indexPath)
//    }
    //遷移するときに呼ばれる
    //    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    //        if segue.identifier == "toView" {
    //            let view = segue.destination as! subViewController
    //            if let snap = self.selectedSnap {
    //                view.selectedSnap = snap
    //            }
    //        }
    //    }
    
    //スワイプ削除のメソッド
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        //デリートボタンを追加
        if editingStyle == .delete {
            //選択されたCellのNSIndexPathを渡し、データをFirebase上から削除するためのメソッド
            //self.delete(indexPath)
            self.delete(deleteIndexPath: indexPath)
            //TableView上から削除
            table.deleteRows(at: [indexPath as IndexPath], with: .fade)
        }
    }
    
    func delete(deleteIndexPath indexPath: IndexPath) {
        ref.child((Auth.auth().currentUser?.uid)!).child(contentArray[indexPath.row].key).removeValue()
        contentArray.remove(at: indexPath.row)
    }
    
    
    //==========================================subViewからの引用〜
    
    
    //Postボタンを以下のように変更=====subから
    //@IBAction
    //    func post(sender: UIButton) {
    //        if isCreate {
    //            //投稿のためのメソッド
    //            create()
    //        }else {
    //            //更新するためのメソッド
    //            update()
    //        }
    //        _ = self.navigationController?.popViewController(animated: true)
    //    }
    //Returnキーを押すと、キーボードを隠す
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    //データの送信のメソッド
    func create() {
        //textFieldになにも書かれてない場合は、その後の処理をしない
        //guard let text = textField.text else { return }
        
        //ロートからログインしているユーザーのIDをchildにしてデータを作成
        //childByAutoId()でユーザーIDの下に、IDを自動生成してその中にデータを入れる
        //setValueでデータを送信する。第一引数に送信したいデータを辞書型で入れる
        //今回は記入内容と一緒にユーザーIDと時間を入れる
        //FIRServerValue.timestamp()で現在時間を取る
        self.ref.child((Auth.auth().currentUser?.uid)!)
            .childByAutoId().setValue([
                "user": (Auth.auth().currentUser?.uid)!,
                "content": contentSubArray,
                "date": ServerValue.timestamp()
                ]
        )
    }
    
    //更新のためのメソッド
    func update() {
        //ルートからのchildをユーザーIDに指定
        //ユーザーIDからのchildを受け取ったデータのIDに指定
        //updateChildValueを使って更新
        ref.keepSynced(true)
        ref.child((Auth.auth().currentUser?.uid)!)
            .childByAutoId().setValue([
                "user": (Auth.auth().currentUser?.uid)!,
                "content": contentSubArray,
                "date": ServerValue.timestamp()
            ])
    }
    
    @IBAction func logout() {
        let firebaseAuth = Auth.auth()
        do {
            //do-try-catchの中で、FIRAuth.auth()?.signOut()を呼ぶだけで、ログアウトが完了
            try firebaseAuth.signOut()
            
            //先頭のNavigationControllerに遷移
            let storyboard = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Nav")
            self.present(storyboard, animated: true, completion: nil)
        }catch let error as NSError {
            print("\(error.localizedDescription)")
        }
        
    }
    
    //===========================音声認識===================================================
    
    @IBAction func recordButtonTapped() {
        
        //recordButton.layer.shadowOpacity = 0.5
        // ボタンを縮こませます
        //UIView.animate(withDuration: 0.2, animations: { _ in
            //self.recordButton.transform = CGAffineTransformMakeRotation(0)
        //})
        if audioEngine.isRunning {
            
            recordButton.setImage(UIImage.init(named: "アプリアイコン1_アートボード 1.png"), for: UIControl.State.normal)
            // 音声エンジン動作中なら停止
            audioEngine.stop()
            print("if文が呼ばれました")
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
            
            //recordButton.col = UIColor.lightGray
            //            self.create()
            //self.reload(snap: self.snap)
            if isCreate {
                //投稿のためのメソッド
                create()
            } else {
                //更新するためのメソッド
                update()
            }
            //_ = self.navigationController?.popViewController(animated: true)
            //isCreateをfalseにし、更新するためであることを明示
            isCreate = false
        } else {
            // 録音を開始する
          try! startRecording()
            //recordButton.setTitle("認識を完了する", for: [])
            print("認識を完了する")
            //recordButton.backgroundColor = UIColor.red
            
            recordButton.setImage(UIImage.init(named: "アプリアイコン(赤).png"), for: UIControl.State.normal)
        }
        
        
        
    }
    
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
                self.textView.text = result.bestTranscription.formattedString
                self.contentSubArray = result.bestTranscription.formattedString
                // item.text =  String[result.bestTranscription.formattedString]
                
                isFinal = result.isFinal
            }
            
            //ここのせい！多分！
            
            
            if error != nil || isFinal {
                print("error:(error)")
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.recordButton.isEnabled = true
                //self.textView.text = "音声認識スタート"
                //self.recordButton.setTitle("録音開始", for: [])
                print("録音開始")
            }
            
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {(buffer:AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare() //オーディオエンジン準備
        try audioEngine.start() //オーディオエンジン開始
        //print("audioEngine.isRunnnig2")
        
        
        //textView.text = "(認識中、、、そのまま話し続けてください)"
    }
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            // 利用可能になったら、録音ボタンを有効にする
            recordButton.isEnabled = true
            //recordButton.setTitle("Start Recording", for: [])
            //recordButton.backgroundColor = UIColor.blue
        } else {
            // 利用できないなら、録音ボタンは無効にする
            recordButton.isEnabled = false
            recordButton.setTitle("現在、使用不可", for: .disabled)
        }
    }
    

    
    
}


