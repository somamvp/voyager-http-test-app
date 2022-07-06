//
//  ResponseData.swift
//  Post Image
//
//  Created by 지우석 on 2022/07/05.
//

import Foundation
import Alamofire

struct ImagePostResponseData {
    
    let response: AFDataResponse<ImagePostResponseRawData>
    let timeInNano: Double
    var timeInMilli: Double { timeInNano / 1_000_000 }
    
    var description: String {
        var description = """
--------------------------------------
Respond in \(String(format: "%.2f", timeInMilli)) milliseconds
--------------------------------------
"""
        if case .failure = response.result {
            description += response.debugDescription
        }
        return description
    }
    
    var title: String {
        switch response.result {
            case .success:
                return "Success"
            case .failure:
                return "Failure"
        }
    }
}
