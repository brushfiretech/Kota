//
//  SlackHelper.swift
//  Pods
//
//  Created by Andrew Garcia on 4/28/17.
//
//

import Foundation
import MobileCoreServices

class SlackClient: NSObject {
    
    static let sharedInstance = SlackClient()
    
    /// Slack Auth Token
    var SlackToken: String!
    
    let SlackUploadURL = "https://slack.com/api/files.upload"
    
    func setup(slackToken: String) {
        SlackToken = slackToken
    }
    
    /// Post file upload request to upload file to channels
    func uploadFile(filePath: String, fileName: String, channels: String, comments: String, handler: ((AnyObject?, NSError?) -> Void)?) {
        let request = createRequest(token: SlackToken, filePath: filePath, filename: fileName, channels: channels, comments: comments)
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            if error != nil {
                // handle error here
                print(error)
                handler?(nil, error as! NSError)
                return
            }
            
            // if response was JSON, then parse it
            
            do {
                if let responseDictionary = try JSONSerialization.jsonObject(with: data!, options: []) as? NSDictionary {
                    
                    print("success == \(responseDictionary)")
                    
                    DispatchQueue.main.async() {
                        handler?(responseDictionary, nil)
                    }
                }
            } catch {
                print(error)
                
                let responseString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
                print("responseString = \(responseString)")
                DispatchQueue.main.async() {
                    handler?(nil, NSError(domain: "SlackFileUploadClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot parse response JSON: \(error)"]))
                }
            }
        }
        task.resume()
    }
    
    /// Create request
    ///
    /// - parameter token: Authentication token (Requires scope: files:write:user)
    /// - parameter filePath: Local path of file to upload.
    /// - parameter filename: Filename of file.
    /// - parameter channels: Comma-separated list of channel names or IDs where the file will be shared.
    ///
    /// - returns:            The NSURLRequest that was created
    
    func createRequest(token token: String, filePath: String, filename: String, channels: String, comments: String) -> NSURLRequest {
        let param = [
            "token"  : token,
            "filename"    : filename,
            "channels" : channels,
            "initial_comment" : comments
        ]
        
        let boundary = generateBoundaryString()
        
        let url = NSURL(string: SlackUploadURL)!
        let request = NSMutableURLRequest(url: url as URL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = createBodyWithParameters(parameters: param, filePathKey: "file", paths: [filePath], boundary: boundary) as Data
        
        return request
    }
    
    /// Create body of the multipart/form-data request
    ///
    /// - parameter parameters:   The optional dictionary containing keys and values to be passed to web service
    /// - parameter filePathKey:  The optional field name to be used when uploading files. If you supply paths, you must supply filePathKey, too.
    /// - parameter paths:        The optional array of file paths of the files to be uploaded
    /// - parameter boundary:     The multipart/form-data boundary
    ///
    /// - returns:                The NSData of the body of the request
    
    func createBodyWithParameters(parameters: [String: String]?, filePathKey: String?, paths: [String]?, boundary: String) -> NSData {
        let body = NSMutableData()
        if parameters != nil {
            for (key, value) in parameters! {
                body.appendString(string: "--\(boundary)\r\n")
                body.appendString(string: "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.appendString(string: "\(value)\r\n")
            }
        }
        
        if paths != nil {
            for path in paths! {
                let url = URL(fileURLWithPath: path)
                let filename = url.lastPathComponent
                do {
                    let data = try Data(contentsOf: url)
                    let mimetype = mimeTypeForPath(path: path)
                    
                    body.appendString(string: "--\(boundary)\r\n")
                    body.appendString(string: "Content-Disposition: form-data; name=\"\(filePathKey!)\"; filename=\"\(filename)\"\r\n")
                    body.appendString(string: "Content-Type: \(mimetype)\r\n\r\n")
                    body.append(data)
                    body.appendString(string: "\r\n")
                } catch {
                    break
                }
            }
        }
        
        body.appendString(string: "--\(boundary)--\r\n")
        return body
    }
    
    /// Create boundary string for multipart/form-data request
    ///
    /// - returns:            The boundary string that consists of "Boundary-" followed by a UUID string.
    
    func generateBoundaryString() -> String {
        return "Boundary-\(NSUUID().uuidString)"
    }
    
    /// Determine mime type on the basis of extension of a file.
    ///
    /// This requires MobileCoreServices framework.
    ///
    /// - parameter path:         The path of the file for which we are going to determine the mime type.
    ///
    /// - returns:                Returns the mime type if successful. Returns application/octet-stream if unable to determine mime type.
    
    func mimeTypeForPath(path: String) -> String {
        let url = NSURL(fileURLWithPath: path)
        let pathExtension = url.pathExtension
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream"
    }
}

extension NSMutableData {
    
    /// Append string to NSMutableData
    ///
    /// Rather than littering my code with calls to `dataUsingEncoding` to convert strings to NSData, and then add that data to the NSMutableData, this wraps it in a nice convenient little extension to NSMutableData. This converts using UTF-8.
    ///
    /// - parameter string:       The string to be added to the `NSMutableData`.
    
    func appendString(string: String) {
        let data = string.data(using: String.Encoding.utf8, allowLossyConversion: true)
        append(data!)
    }
}
