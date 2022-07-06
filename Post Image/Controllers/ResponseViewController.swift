//
//  ResponseViewController.swift
//  Post Image
//
//  Created by 지우석 on 2022/07/05.
//

// Scroll View Auto Layout
// https://corykim0829.github.io//ios/UIScrollView-with-storyboard/#

import Foundation
import UIKit

class ResponseViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UITextView!
    
    var responseData: [ImagePostResponseData] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let avgTime = responseData.reduce(0) { $0 + Int($1.timeInMilli) } / responseData.count
        titleLabel.text = "\(responseData.count) req : \(avgTime) milli"
        contentLabel.text = responseData.reduce("") { partialResult, response in
            partialResult + response.description + "\n"
        }
        UIPasteboard.general.string = contentLabel.text
    }
    
    @IBAction func handleDismissButton(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    
}
