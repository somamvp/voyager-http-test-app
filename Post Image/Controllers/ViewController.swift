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
import GRPC
import NIOCore
import NIOPosix

import Network

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
    
    
    var connection: NWConnection?
    var hostUDP: NWEndpoint.Host = "[server uri]"
    var portUDP: NWEndpoint.Port = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        loadSecrets()
        loadDefaultImage()
        socketSetup()
        connectToUDP(hostUDP, portUDP)
    }
    
    func connectToUDP(_ hostUDP: NWEndpoint.Host, _ portUDP: NWEndpoint.Port) {
        // Transmited message:
        let messageToUDP = "Test message"

        self.connection = NWConnection(host: hostUDP, port: portUDP, using: .udp)

        self.connection?.stateUpdateHandler = { (newState) in
            print("This is stateUpdateHandler:")
            switch (newState) {
                case .ready:
                    print("State: Ready\n")
                    self.sendUDP(messageToUDP)
                    self.receiveUDP()
                case .setup:
                    print("State: Setup\n")
                case .cancelled:
                    print("State: Cancelled\n")
                case .preparing:
                    print("State: Preparing\n")
                default:
                    print("ERROR! State not defined!\n")
            }
        }

        self.connection?.start(queue: .global())
    }

    func sendUDP(_ content: Data) {
        self.connection?.send(content: content, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            if (NWError == nil) {
                print("Data was sent to UDP")
            } else {
                print("ERROR! Error when data (Type: Data) sending. NWError: \n \(NWError!)")
            }
        })))
    }

    func sendUDP(_ content: String) {
        let contentToSendUDP = content.data(using: String.Encoding.utf8)
        self.connection?.send(content: contentToSendUDP, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            if (NWError == nil) {
                print("Data was sent to UDP")
            } else {
                print("ERROR! Error when data (Type: Data) sending. NWError: \n \(NWError!)")
            }
        })))
    }

    func receiveUDP() {
        self.connection?.receiveMessage { (data, context, isComplete, error) in
            if (isComplete) {
                print("Receive is complete")
                if (data != nil) {
                    let backToString = String(decoding: data!, as: UTF8.self)
                    print("Received message: \(backToString)")
                } else {
                    print("Data == nil")
                }
            }
        }
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
//            sendUDP(imgData)
        } else {
            self.view.makeToast("img unable to convert into JPEG data!")
        }
    }
    @IBAction func handleSendSocketButton(_ sender: UIButton) {
        if let imgData = imageView.image?.jpegData(compressionQuality: compressionQuality) {
//            print(imgData.map{String(format: "%02x", $0)}.joined())
            self.view.makeToast("sending \(numTrial) request via STOMP. cp: \(String(format: "%.1f", compressionQuality))")
            disableSendButtons()
            imageEmitTest(imgData: imgData, async: asyncSwitch.isOn)
        } else {
            self.view.makeToast("img unable to convert into JPEG data!")
        }
        
    }
    @IBAction func handleSendGRPCButton(_ sender: UIButton) {
        
        if let imgData = imageView.image?.jpegData(compressionQuality: compressionQuality) {
            
//            self.view.makeToast("sending \(numTrial) request via GRPC. cp: \(String(format: "%.1f", compressionQuality))")
            disableSendButtons()
            
            
                
            self.imgData = imgData
            postResponses = []
            stompRequestTimestamps = []
            stompResponseTimestamps = []
            timePassed = 0
            
            timebaseInfo = mach_timebase_info(numer: 0, denom: 0)
            mach_timebase_info(&timebaseInfo)
            
            
            Task {
                
                do {
//                    try imageGRPCTest(imgData: imgData)
                    try await HelloWorld(name: imgData).run(viewController: self)
                } catch {
                    print(error)
                }
            }
            
        } else {
            self.view.makeToast("img unable to convert into JPEG data!")
        }
    }
    
    func imageGRPCTest(imgData: Data) throws {
        
        self.imgData = imgData
        postResponses = []
        stompRequestTimestamps = []
        stompResponseTimestamps = []
        timePassed = 0
        
        timebaseInfo = mach_timebase_info(numer: 0, denom: 0)
        mach_timebase_info(&timebaseInfo)
        

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Make sure the group is shutdown when we're done with it.
        defer {
            try! group.syncShutdownGracefully()
        }
        
        // Configure the channel, we're not using TLS so the connection is `insecure`.
        let channel = try GRPCChannelPool.with(
            target: .host("ec2-3-34-131-247.ap-northeast-2.compute.amazonaws.com", port: 9090),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )
        
        
        // Close the connection when we're done with it.
        defer {
            try! channel.close().wait()
        }
        
        // Provide the connection to the generated client.
        let greeter = GreeterAsyncClient(channel: channel)
        // Form the request with the name, if one was provided.
        let request = HelloRequest.with {
            $0.name = imgData
        }
        
        Task {
            try await sendImageDataGRPC(imgData: imgData, greeter: greeter, request: request)
        }
    }
    func startTick() {
        tick = mach_absolute_time()
        stompRequestTimestamps.append(tick)
        print("sending hello: \(tick)")
    }
    
    func endTick() {
        
        stompResponseTimestamps.append(mach_absolute_time())
        let lastIdx = stompResponseTimestamps.count - 1
        let diff = Double(mach_absolute_time() - stompRequestTimestamps[lastIdx]) * Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
        print("\(diff / 1_000_000) milliseconds")
        
        let response = ImagePostResponseData(response: nil, timeInNano: diff)
        self.postResponses.append(response)
    }
    
    func sendImageDataGRPC(imgData: Data, greeter: GreeterAsyncClient, request: HelloRequest) async throws {
        
        do {
            tick = mach_absolute_time()
            stompRequestTimestamps.append(tick)
            print("sending hello: \(tick)")
            
            let greeting = try await greeter.sayHello(request)
            print("Greeter received: \(greeting.message)")
            
            stompResponseTimestamps.append(mach_absolute_time())
            let lastIdx = stompResponseTimestamps.count - 1
            let diff = Double(mach_absolute_time() - stompRequestTimestamps[lastIdx]) * Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
            print("\(diff / 1_000_000) milliseconds")
            
            let response = ImagePostResponseData(response: nil, timeInNano: diff)
            self.postResponses.append(response)
            
            
            if postResponses.count < numTrial {
                try await sendImageDataGRPC(imgData: imgData, greeter: greeter, request: request)
            } else {
                self.showResult()
            }
            
            
        } catch {
            print("Greeter failed: \(error)")
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
        
        tick = mach_absolute_time()
        stompRequestTimestamps.append(tick)
        
        if async {
            print("req sent")
            socketClient.sendMessage(message: String(imgData.base64EncodedString()), toDestination: "/pub/upload", withHeaders: nil, withReceipt: nil)
        } else {
            if postResponses.count < numTrial {
                socketClient.sendMessage(message: String(imgData.base64EncodedString()), toDestination: "/pub/upload", withHeaders: nil, withReceipt: nil)
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

