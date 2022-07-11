//
//  ViewController.swift
//  Post Image
//
//  Created by 지우석 on 2022/07/01.
//

import UIKit
import Foundation
import Alamofire
import Toast_Swift
import StompClientLib

class ViewController: UIViewController {
    
    var serverURI: String?
    var serverEndpoint: String?
    var currentResponse: ImagePostResponseData?
    
    var compressionQuality = 1.0
    var postResponses: [ImagePostResponseData] = []
    
    var numTrial = 20
    let fps = 10

    var timer: Timer?
    var timePassed = 0
    
    var socketClient: StompClientLib!
    var url: URL!
    
    var async = false
    var imgData = Data()
    var timebaseInfo = mach_timebase_info(numer: 0, denom: 0)
    var tick: UInt64 = 0
    var stompRequestTimestamps = [UInt64]()
    var stompResponseTimestamps = [UInt64]()

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var requestNumLabel: UILabel!
    @IBOutlet weak var compressionQualityLabel: UILabel!
    @IBOutlet weak var asyncSwitch: UISwitch!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var socketSendButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        loadSecrets()
        loadDefaultImage()
        socketSetup()
    }
    
    func socketSetup() {
        url = URL(string: serverURI!)?.appendingPathComponent(serverEndpoint!).appendingPathComponent("websocket")
        print("url constructed: \(url!)")
        
        socketClient = StompClientLib()
        socketClient.openSocketWithURLRequest(request: NSURLRequest(url: url) , delegate: self, connectionHeaders: ["Authorization" : "Bearer xyz)", "heart-beat": "0,10000"])
    }
    
    func loadSecrets() {
        guard let url = Bundle.main.url(forResource: "secrets", withExtension: "plist"),
              let dictionary = NSDictionary(contentsOf: url) else {
            return
        }
        // read
        serverURI = dictionary["server-uri"] as? String
        serverEndpoint = dictionary["image-post-endpoint"] as? String
        
        if let safeServerURI = serverURI {
            print("server uri loaded : \(safeServerURI)")
        } else {
            print("server uri not loaded")
        }
    }
    func loadDefaultImage() {
        if let bundlePath = Bundle.main.path(forResource: K.fileNames.bundleImageName, ofType: K.fileNames.bundleImageExtension),
            let image = UIImage(contentsOfFile: bundlePath) {
            imageView.image = image
        } else {
            self.view.makeToast("default img file not found!")
        }
    }
    
    @IBAction func handleRequestNumSliderChanged(_ sender: UISlider) {
        let value = Int(sender.value)
        requestNumLabel.text = String(value)
        numTrial = value
    }
    @IBAction func handleCompressionQualitySliderChanged(_ sender: UISlider) {
        let value = round(sender.value * 10) / 10
        compressionQualityLabel.text = String(value)
        compressionQuality = Double(value)
    }
    @IBAction func handleChangeButton(_ sender: UIButton) {
        print("Image Selected")
                
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.delegate = self
        vc.allowsEditing = true
        present(vc, animated: true)
        
    }
    
    @IBAction func handleSendButton(_ sender: UIButton) {
        
        if let imgData = imageView.image?.jpegData(compressionQuality: compressionQuality) {
            self.view.makeToast("sending \(numTrial) request. cp: \(String(format: "%.1f", compressionQuality))")
            disableSendButtons()
            imagePostTest(imgData: imgData, async: asyncSwitch.isOn)
        } else {
            self.view.makeToast("img unable to convert into JPEG data!")
        }
    }
    @IBAction func handleSendSocketButton(_ sender: UIButton) {
        if let imgData = imageView.image?.jpegData(compressionQuality: compressionQuality) {
            self.view.makeToast("sending \(numTrial) request via STOMP. cp: \(String(format: "%.1f", compressionQuality))")
            disableSendButtons()
            imageEmitTest(imgData: imgData, async: asyncSwitch.isOn)
        } else {
            self.view.makeToast("img unable to convert into JPEG data!")
        }
        
    }
    
    func imageEmitTest(imgData: Data, async: Bool) {
        self.async = async
        self.imgData = imgData
        postResponses = []
        stompRequestTimestamps = []
        stompResponseTimestamps = []
        timePassed = 0
        
        timebaseInfo = mach_timebase_info(numer: 0, denom: 0)
        mach_timebase_info(&timebaseInfo)
        
        if async {
            
            
            let timeInterval = 1.0 / Double(fps)
            timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { timer in
                
                self.sendImageDataStomp(imgData: imgData, async: true)
                
                // increment count & terminate when done counting
                self.timePassed += 1
                if self.timePassed == self.numTrial {
                    timer.invalidate()
                    self.showResult()
                }
            }
            
        } else {
            sendImageDataStomp(imgData: imgData, async: false)
        }
    }
    
    func sendImageDataStomp(imgData: Data, async: Bool) {
        
        let imgStr = String(imgData.base64EncodedString())
        tick = mach_absolute_time()
        stompRequestTimestamps.append(tick)
        
        if async {
            print("req sent")
            socketClient.sendMessage(message: String(imgData.base64EncodedString()), toDestination: "/pub/upload", withHeaders: nil, withReceipt: nil)
        } else {
            if postResponses.count < numTrial {
                socketClient.sendMessage(message: imgStr, toDestination: "/pub/upload", withHeaders: nil, withReceipt: nil)
            } else {
                self.showResult()
            }
        }
    }
    
    
    func imagePostTest(imgData: Data, async: Bool) {
        postResponses = []
        timePassed = 0
        
        if async {
            let timeInterval = 1.0 / Double(fps)
            timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { timer in
                
                self.postImageData(filename: K.fileNames.postImageName, imgData: imgData, sequenceNo: self.timePassed)
                
                // increment count & terminate when done counting
                self.timePassed += 1
                if self.timePassed == self.numTrial {
                    timer.invalidate()
                    self.showResult()
                }
            }
            
        } else {
            postImageData(filename: K.fileNames.postImageName, imgData: imgData, sequenceNo: 1, async: false)
        }
        
    }
    
    func postImageData(filename: String, imgData: Data, sequenceNo: Int, async: Bool = true) {
        
        var info = mach_timebase_info(numer: 0, denom: 0)
        mach_timebase_info(&info)
        let tick = mach_absolute_time()
        
        let url = "\(serverURI!)/\(serverEndpoint!)"
    
        let parameters: [String: Any] = [
            "filename": filename,
            "sequenceNo": sequenceNo
        ]
        
        AF.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                multipartFormData.append("\(value)".data(using: .utf8)!, withName: key, mimeType: "text/plain")
            }

            multipartFormData.append(imgData, withName: "img", fileName: filename, mimeType: "image/jpg")

        }, to: url).responseDecodable(of: ImagePostResponseRawData.self) { response in
            let diff = Double(mach_absolute_time() - tick) * Double(info.numer) / Double(info.denom)
            print("response recieved: \(sequenceNo)")
            print("\(diff / 1_000_000) milliseconds")
            
            let response = ImagePostResponseData(response: response, timeInNano: diff)
            self.postResponses.append(response)
            
            if !async {
                if sequenceNo < self.numTrial {
                    self.postImageData(filename: filename, imgData: imgData, sequenceNo: sequenceNo + 1, async: false)
                } else {
                    self.showResult()
                }
            }
        }
    }
    
    func disableSendButtons() {
        sendButton.isEnabled = false
        socketSendButton.isEnabled = false
    }
    
    func showResult() {
        sendButton.isEnabled = true
        socketSendButton.isEnabled = true
        performSegue(withIdentifier: K.resultSegue, sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == K.resultSegue {
            let destinationVC = segue.destination as! ResponseViewController
            destinationVC.responseData = postResponses
        }
    }
    
}

// MARK: - image picker

extension ViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let image = info[UIImagePickerController.InfoKey(rawValue: "UIImagePickerControllerEditedImage")] as? UIImage {
            imageView.image = image
        }
        
        picker.dismiss(animated: true, completion: nil)
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
}

// MARK: - STOMP client delegate

extension ViewController: StompClientLibDelegate {
    
    func stompClient(client: StompClientLib!, didReceiveMessageWithJSONBody jsonBody: AnyObject?, akaStringBody stringBody: String?, withHeader header: [String : String]?, withDestination destination: String) {
//        print("Destination : \(destination)")
//        print("JSON Body : \(String(describing: jsonBody))")
        print("String Body : \(stringBody ?? "nil")")
        
        stompResponseTimestamps.append(mach_absolute_time())
        let lastIdx = stompResponseTimestamps.count - 1
        let diff = Double(mach_absolute_time() - stompRequestTimestamps[lastIdx]) * Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
        print("\(diff / 1_000_000) milliseconds")
        
        let response = ImagePostResponseData(response: nil, timeInNano: diff)
        self.postResponses.append(response)
        
        if !self.async {
            sendImageDataStomp(imgData: imgData, async: false)
        }
    }
    
    func stompClientDidConnect(client: StompClientLib!) {
        print("Socket is connected")
        
        // Stomp subscribe will be here!
        socketClient.subscribe(destination: "/sub/upload")
    }
    
    func stompClientDidDisconnect(client: StompClientLib!) {
        print("Socket is Disconnected")
    }
    
    func serverDidSendReceipt(client: StompClientLib!, withReceiptId receiptId: String) {
        print("Receipt : \(receiptId)")
    }

    func serverDidSendError(client: StompClientLib!, withErrorMessage description: String, detailedErrorMessage message: String?) {
        print("Error Send : \(String(describing: message))")
    }
    
    func serverDidSendPing() {
        print("Server ping")
    }
}

