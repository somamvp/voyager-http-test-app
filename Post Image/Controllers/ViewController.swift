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

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var requestNumLabel: UILabel!
    @IBOutlet weak var compressionQualityLabel: UILabel!
    @IBOutlet weak var sendButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        loadSecrets()
        if let safeServerURI = serverURI {
            print("server uri loaded : \(safeServerURI)")
        } else {
            print("server uri not loaded")
        }
        
        if let bundlePath = Bundle.main.path(forResource: K.fileNames.bundleImageName, ofType: "jpeg"),
            let image = UIImage(contentsOfFile: bundlePath) {
            imageView.image = image
        } else {
            self.view.makeToast("default img file not found!")
        }
    }
    
    func loadSecrets() {
        guard let url = Bundle.main.url(forResource: "secrets", withExtension: "plist"),
              let dictionary = NSDictionary(contentsOf: url) else {
            return
        }

        // read
        serverURI = dictionary["server-uri"] as? String
        serverEndpoint = dictionary["image-post-endpoint"] as? String

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
        imagePostTest(async: true)
    }
    
    func imagePostTest(async: Bool) {
        if let imgData = imageView.image?.jpegData(compressionQuality: compressionQuality) {
            
            self.view.makeToast("sending \(numTrial) request. cp: \(String(format: "%.1f", compressionQuality))")
            sendButton.isEnabled = false
            
            if async {
            
                postResponses.removeAll()
                timePassed = 0
                let timeInterval = 1.0 / Double(fps)
                timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true, block: { timer in
                    
                    self.postImageData(filename: K.fileNames.postImageName, imgData: imgData, sequenceNo: self.timePassed)
                    
                    self.timePassed += 1
                    if self.timePassed == self.numTrial {
                        timer.invalidate()
                        self.sendButton.isEnabled = true
                        self.performSegue(withIdentifier: K.resultSegue, sender: self)
                    }
                })
                
            } else {
                postImageData(filename: K.fileNames.postImageName, imgData: imgData, sequenceNo: 1, async: false)
            }
        } else {
            self.view.makeToast("img unable to convert into JPEG data!")
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
                    self.sendButton.isEnabled = true
                    self.performSegue(withIdentifier: K.resultSegue, sender: self)
                    return
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == K.resultSegue {
            let destinationVC = segue.destination as! ResponseViewController
            destinationVC.responseData = postResponses
        }
    }
    
// MARK: - deprecated AF calls
    
    func requestIdentify(userName: String,
                             imgData: Data) {

//            var urlComponent = URLComponents(string: BaseAPI.shared.getBaseString())
//            urlComponent?.path = RequestURL.identify.getRequestURL
//            guard let url = urlComponent?.url else {
//                return
//            }
        let url = "[Server URI]"
    
//        let header: HTTPHeaders = [
//            "Content-Type": "multipart/form-data"
//        ]
        let parameters = [
            "filename":userName,
            "sequenceNo": "0506"
        ]
        


        _ = AF.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                multipartFormData.append("\(value)".data(using: .utf8)!, withName: key, mimeType: "text/plain")
            }

            multipartFormData.append(imgData, withName: "img", fileName: "\(userName).jpg", mimeType: "image/jpg")

        }, to: url).responseDecodable(of: ImagePostResponseRawData.self) { response in
            switch response.result {
            case .success(let upload):
                print(upload)
//                        guard let httpStatusCode
//                            = HttpStatusCode(rawValue: decodedData.statusCode) else {
//                            print("status error")
////                                completion(.failed(NSError(domain: "status error",
////                                                           code: 0,
////                                                           userInfo: nil)))
//                                return
//                        }
//                        completion(.success(httpStatusCode))
//                        print(decodedData.statusCode)

//                    } else {
//                        completion(.failed(NSError(domain: "decode error",
//                                                   code: 0,
//                                                   userInfo: nil)))
//                        print("decode error")
//                        return
//                    }
//                }
            case .failure(let err):
//                completion(.failed(err))
                print(err)
            }
            
        }
    }
    
    /*
    func requestIdentify() {
        guard let sendData = imgObservable.value else {
            return
        }
        let boundary = generateBoundaryString()
        let body: [String: String] = ["userName": userName]
        let bodyData = createBody(parameters: body,
                                  boundary: boundary,
                                  data: sendData,
                                  mimeType: "image/jpg",
                                  filename: "identifyImage.jpg")

        requestIdentifys(boundary: boundary, bodyData: bodyData) { response in
            switch response {
            case .success(let statusCode):
                print(statusCode)
            case .failed(let err):
                print(err)
            }
        }
    }
    
    private func generateBoundaryString() -> String {
        return "Boundary-\(UUID().uuidString)"
    }
    
    private func createBody(parameters: [String: String],
                            boundary: String,
                            data: Data,
                            mimeType: String,
                            filename: String) -> Data {
        var body = Data()
        let imgDataKey = "img"
        let boundaryPrefix = "--\(boundary)\r\n"
        
        for (key, value) in parameters {
            body.append(boundaryPrefix.data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(imgDataKey)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--".appending(boundary.appending("--")).data(using: .utf8)!)
        
        return body as Data
    }
    
    
    
    func requestIdentifys(boundary: String,
                         bodyData: Data,
                         completion: @escaping (DataResponse<HttpStatusCode>) -> Void) {
        var urlComponent = URLComponents(string: BaseAPI.shared.getBaseString())
        urlComponent?.path = RequestURL.identify.getRequestURL
        let header: [String: String] = [
            "Content-Type": "multipart/form-data; boundary=\(boundary)"
        ]
        guard let url = urlComponent?.url,
            let request = requestMaker.makeRequest(url: url,
                                                   method: .post,
                                                   header: header,
                                                   body: bodyData) else {
                                                    return
                                                    
        }
        
        network.dispatch(request: request) { result in
            switch result {
            case .success(let data):
                
                if let decodedData = try? JSONDecoder().decode(ResponseSimple<String>.self,
                                                               from: data) {
                    print(decodedData)
                    guard let httpStatusCode = HttpStatusCode(rawValue: decodedData.statusCode) else {
                        return completion(.failed(NSError(domain: "status error",
                                                          code: 0,
                                                          userInfo: nil)))
                    }
                    completion(.success(httpStatusCode))
                } else {
                    completion(.failed(NSError(domain: "decode error",
                                               code: 0,
                                               userInfo: nil)))
                    return
                }
                
            case .failure(let error):
                completion(.failed(error))
                return
            }
        }
    } */
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

