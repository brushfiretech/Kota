//
//  SendScreenShotViewController.swift
//  Pods
//
//  Created by Andrew Garcia on 5/10/17.
//
//

import Foundation
import UIKit
import Hero

class SendScreenShotViewController: UIViewController, UITextViewDelegate {
    
    @IBOutlet weak var screenShot: UIImageView!
    @IBOutlet weak var textView: UITextView!
    
    override func viewWillAppear(_ animated: Bool) {
        isHeroEnabled = true
        
        screenShot.image = KotaData.shared.screenshotImage
        
        self.textView.delegate = self
        
    }
    
    var sendButton: UIButton = {
        var button = UIButton(type: .custom)
        button.setTitle("Send", for: .normal)
        button.backgroundColor = UIColor(red: 100 / 255.0, green: 219 / 255.0, blue: 111 / 255.0, alpha: 1.0)
        button.imageView?.contentMode = .scaleAspectFit
        button.titleLabel?.textColor = UIColor.white
        return button
    }()
    
    override func viewDidLoad() {
        let when = DispatchTime.now() + 0.5
        DispatchQueue.main.asyncAfter(deadline: when) {
            self.textView.becomeFirstResponder()
        }
        
        let customView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 50))
        customView.addSubview(sendButton)
        customView.addConstraintsWithFormat("H:|[v0]|", views: sendButton)
        customView.addConstraintsWithFormat("V:|[v0]|", views: sendButton)
        sendButton.addTarget(self, action: #selector(sendFeedBack), for: .touchUpInside)
        
        textView.inputAccessoryView = customView
    }
    
    func saveImage(image:UIImage, name: String) -> String {
        let documentsDirectoryURL = try! FileManager().url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        // create a name for your image
        let fileURL = documentsDirectoryURL.appendingPathComponent("\(name).png")
        
        do {
            try UIImagePNGRepresentation(image)!.write(to: fileURL)
            print("Image Added Successfully")
            return fileURL.path
        } catch {
            print(error)
        }

        return ""
    }
    
    func sendFeedBack() {
        DispatchQueue.global(qos: .background).async {
            print("This is run on the background queue")
            if let slackChannel = KotaController.shared.slackChannelString {
                if let screenShotImage = self.screenShot.image {
                    if let savedImagePath = self.saveImage(image: screenShotImage, name: "screenshot") as? String {
                        print("Saved Image Path: \(savedImagePath)")
                        SlackClient.sharedInstance.uploadFile(filePath: savedImagePath, fileName: "screenshot", channels: "#\(slackChannel)", comments: self.textView.text) { (res, error) in
                            if error != nil {
                                print("Unable to send screenshot over Slack.")
                            } else {
                                print("Sent screenshot over Slack.")
                            }
                        }
                    }
                }
            }
        }
        
        let presentingViewController = self.presentingViewController
        self.dismiss(animated: false, completion: {
            presentingViewController!.dismiss(animated: true, completion: {})
        })
    }
    
    @IBAction func dismissButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}
