//
//  SendVideoFeedback.swift
//  Pods
//
//  Created by Andrew Garcia on 5/14/17.
//
//

import UIKit
import Foundation
import AVFoundation
import AVKit

class SendVideoFeedbackViewController: UIViewController {

    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var textView: UITextView!
    
    let kotaData = KotaData.shared
    
    var playerViewController = AVPlayerViewController()
    var playerView = AVPlayer()
    
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
    
    override func viewWillAppear(_ animated: Bool) {
        if let tempVideoURL = kotaData.tempVideoURL {
            let fileURL = URL(fileURLWithPath: tempVideoURL)
            playerView = AVPlayer(url: fileURL)
            playerViewController.player = playerView
            
            playerViewController.view.frame = videoView.bounds
            videoView.addSubview(playerViewController.view)
            
            playerViewController.player?.play()
        }
    }
    
    
    @objc func sendFeedBack() {
        if let apiKey = KotaController.setup.apiKey, let authToken = KotaController.setup.authToken, let idList = KotaController.setup.idList {
            let trello = Trello.init(apiKey: apiKey, authToken: authToken)
            if let videoURL = self.kotaData.tempVideoURL {
                    
                    if FileManager.default.fileExists(atPath: videoURL) {
                        let url = URL(fileURLWithPath: videoURL)
                        do {
                            let data = try Data(contentsOf: url)
                            trello.postVideoCard(id: idList, name: "Video Feedback", feedBack: self.textView.text, file: try Data(contentsOf: url))
                        } catch {
                            print("Error loading image : \(error)")
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
