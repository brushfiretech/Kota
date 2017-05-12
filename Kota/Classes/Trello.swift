//
//  Trello.swift
//  Pods
//
//  Created by Andrew Garcia on 5/11/17.
//
//

import Foundation
import UIKit
import Alamofire
import NotificationBannerSwift

public class Trello {
    static let baseURLString = "https://api.trello.com/1/cards/"
    let authParameters: [String: Any]
    
    public init(apiKey: String, authToken: String) {
        self.authParameters = ["key": apiKey, "token": authToken]
    }
}

// MARK: Cards
extension Trello {
    public func postCard(id: String, name: String, feedBack: String, file: UIImage) {
        DispatchQueue.main.async {
            let banner = StatusBarNotificationBanner(title: "Submitting Feedback", style: .info)
            banner.show()
        }

        if let params: [String: Any] = self.authParameters + ["idList": id, "desc": feedBack, "name": name, "pos": "top"] {
            if let header: HTTPHeaders = ["Content-Type": "application/x-www-form-urlencoded"] {
//                Alamofire.request(Trello.baseURLString, method: .post, parameters: params, headers: header).responseJSON { response in
//                    debugPrint(response)
//                    
//                    if let json = response.result.value {
//                        print("JSON: \(json)")
//                    }
//                }
            
                Alamofire.upload(
                    multipartFormData: { MultipartFormData in
                        for (key, value) in params {
                            MultipartFormData.append((value as AnyObject).data(using: String.Encoding.utf8.rawValue)!, withName: key)
                        }
                        
                        MultipartFormData.append(UIImageJPEGRepresentation(file, 1)!, withName: "fileSource", fileName: "screeshot.png", mimeType: "image/png")
                }, to: Trello.baseURLString) { (result) in
                    
                    switch result {
                    case .success(let upload, _, _):
                        upload.responseJSON { response in
                            print("Created a new trello card")
                            DispatchQueue.main.async {
                                let banner = StatusBarNotificationBanner(title: "Thanks for the feedback!", style: .success)
                                banner.show()
                            }
                        }
                    case .failure(let encodingError): break
                        print(encodingError)
                    }
                }
            }
        }

    }
}

// MARK: Dictionary Operator Overloading
// http://stackoverflow.com/questions/24051904/how-do-you-add-a-dictionary-of-items-into-another-dictionary/
func +=<K, V> ( left: inout [K: V], right: [K: V]) {
    right.forEach({ left.updateValue($1, forKey: $0) })
}

func +<K, V> (left: [K: V], right: [K: V]) -> [K: V] {
    var newDict: [K: V] = [:]
    for (k, v) in left {
        newDict[k] = v
    }
    for (k, v) in right {
        newDict[k] = v
    }
    
    return newDict
}
