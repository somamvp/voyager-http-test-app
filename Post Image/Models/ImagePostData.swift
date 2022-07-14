//
//  ImagePostData.swift
//  Post Image
//
//  Created by 지우석 on 2022/07/01.
//

import Foundation

struct ImagePostResponseRawData: Decodable {
    let sequenceNo: Int
}

class ImagePostRequestData: Codable {
    
    init(image: Data) {
        self.image = image
    }
    
    var image: Data
}
