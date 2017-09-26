//
//  PreviewVideoViewController.swift
//  Pods
//
//  Created by Andrew Garcia on 5/14/17.
//
//

import UIKit
import AVFoundation
import AVKit

class PreviewVideoViewController: UIViewController {
    
    @IBOutlet weak var videoView: UIView!
    
    let kota = KotaController.shared
    let kotaData = KotaData.shared
    
    var playerViewController = AVPlayerViewController()
    var playerView = AVPlayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let tempVideoURL = kotaData.tempVideoURL {
            let fileURL = URL(fileURLWithPath: tempVideoURL)
            playerView = AVPlayer(url: fileURL)
            playerViewController.player = playerView
            
            playerViewController.view.frame = videoView.bounds
            videoView.addSubview(playerViewController.view)
            
            playerViewController.player?.play()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if !kota.isHidden {
            kota.hideView()
        }
    }
    
    @IBAction func dismissVScreen(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func sendScreenShotButtonPressed(_ sender: Any) {
        performSegue(withIdentifier: "sendVideoSegue", sender: nil)
    }
}
