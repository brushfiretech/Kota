//
//  Kota.swift
//  Pods
//
//  Created by Andrew Garcia on 5/10/17.
//
//

import Foundation
import UIKit
import ReplayKit

open class KotaController: UIViewController {
    
    public static let shared = KotaController()
    let slackClient = SlackClient.sharedInstance
    
    public var slackChannelString: String?
    public var slackTokenString: String? {
        didSet {
            slackClient.setup(slackToken: slackTokenString!)
        }
    }

    public var button: UIButton!
    let window = KotaWindow()
    let viewWidth = 100
    let viewHeight = 120
    var screenshot: UIImage?
    
    // Window Properties
    var midY: CGFloat?
    var rightX: CGFloat?
    
    let contentView = UIView()
    
    private(set) var isHidden = false
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    let cameraButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(red: 100 / 255.0, green: 219 / 255.0, blue: 111 / 255.0, alpha: 1.0)
        button.setTitle("📷", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 40)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.lineBreakMode = .byClipping
        return button
    }()
    
    let recordButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(red: 100 / 255.0, green: 219 / 255.0, blue: 111 / 255.0, alpha: 1.0)
        button.layer.cornerRadius = 5
        button.setTitle("Record", for: .normal)
        return button
    }()
    
    public init() {
        super.init(nibName: nil, bundle: nil)
        window.windowLevel = CGFloat.greatestFiniteMagnitude
        window.isHidden = false
        window.rootViewController = self
        window.isUserInteractionEnabled = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(note:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
    }

    open override func loadView() {
        let mainView = UIView()
        
        
        midY = (window.frame.height / 2) - CGFloat(viewHeight / 2)
        rightX = window.frame.width
        if rightX != nil && midY != nil {
            contentView.frame = CGRect(origin: CGPoint(x: rightX!, y: midY!), size: CGSize(width: viewWidth, height: viewHeight))
        }
        
        contentView.backgroundColor = UIColor.clear
        mainView.addSubview(contentView)
        
        cameraButton.addTarget(self, action: #selector(goToScreenShot), for: .touchUpInside)
        recordButton.addTarget(self, action: #selector(recordButtonPressed), for: .touchUpInside)

        contentView.addSubview(cameraButton)
//        contentView.addSubview(recordButton)
        contentView.addConstraintsWithFormat("H:[v0(\(viewWidth))]|", views: cameraButton)
        contentView.addConstraintsWithFormat("V:[v0(\(viewWidth))]|", views: cameraButton)
        cameraButton.layer.cornerRadius = CGFloat(viewWidth / 2)
        cameraButton.layer.masksToBounds = true
//        contentView.addConstraintsWithFormat("V:[v0(35)]-10-[v1(35)]|", views: recordButton, cameraButton)
        
//        contentView.addConstraintsWithFormat("H:[v0(\(viewWidth))]|", views: recordButton)
        
        showView()
        
        self.view = mainView
        
        window.recordButton = recordButton
        window.button = cameraButton
    }
    
    public func showView() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            if self.rightX != nil && self.midY != nil {
                self.contentView.frame = CGRect(origin: CGPoint(x: self.rightX! - CGFloat(self.viewWidth), y: self.midY!), size: CGSize(width: self.viewWidth, height: self.viewHeight))
                self.isHidden = false
            }
        }, completion: nil)
    }
    
    public func hideView() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            if self.rightX != nil && self.midY != nil {
                self.contentView.frame = CGRect(origin: CGPoint(x: self.rightX!, y: self.midY!), size: CGSize(width: self.viewWidth, height: self.viewHeight))
                self.isHidden = true
            }
        }, completion: nil)
    }
    
    public func keyboardDidShow(note: NSNotification) {
        window.windowLevel = 0
        window.windowLevel = CGFloat.greatestFiniteMagnitude
    }
    
    func captureScreen() {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        KotaData.shared.screenshotImage = image
    }
    
    func takeScreenshot(view: UIView) {
        UIGraphicsBeginImageContext(view.frame.size)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
        
        KotaData.shared.screenshotImage = image
    }
    
    func recordButtonPressed() {
        print("Starting Recording")
        let sharedRecorder = RPScreenRecorder.shared()
        sharedRecorder.delegate = self
        
        print(sharedRecorder.isAvailable)
        
        if #available(iOS 10.0, *) {
            sharedRecorder.startRecording { error in
                print(error.debugDescription)
                
                let when = DispatchTime.now() + 6
                DispatchQueue.main.asyncAfter(deadline: when) {
                    self.stopRecording()
                }
            }
        }
    }
    
    func stopRecording() {
        print("Stoping Recording")
        let sharedRecorder = RPScreenRecorder.shared()
        print(sharedRecorder.isRecording)
        
        sharedRecorder.stopRecording { [unowned self] previewViewController, error in
            
            guard let previewViewController = previewViewController else {
                return
            }
            
            previewViewController.previewControllerDelegate = self
            
            DispatchQueue.main.async { [unowned self] in
                self.present(previewViewController, animated: true, completion: nil)
            }
        }
    }
    

    
    func selectImageFromPhotoLibrary() {

    }
    

    
    public func goToScreenShot() {
//        captureScreen()
        
        
        print("Button tapped")
        
        guard let mainWindow = UIApplication.shared.keyWindow else {
            print("Not found window")
            return
        }
        
        takeScreenshot(view: mainWindow.rootViewController!.view)
        
        let podBundle = Bundle(for: KotaController.self)
        
        let bundleURL = podBundle.url(forResource: "Kota", withExtension: "bundle")
        let bundle = Bundle(url: bundleURL!)!
        
        let storyboard = UIStoryboard(name: "ScreenShot", bundle: bundle)
        let camVC = storyboard.instantiateViewController(withIdentifier: "screenShotViewController") as! ScreenShotViewController
        let vc: UIViewController? = mainWindow.rootViewController?.presentedViewController ?? mainWindow.rootViewController
        vc?.present(camVC, animated: true, completion: nil)
    }
    
}

extension KotaController: RPScreenRecorderDelegate {
    public func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        print(screenRecorder.isAvailable)
    }
    
    public func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWithError error: Error, previewViewController: RPPreviewViewController?) {
        print(error.localizedDescription)
    }
}

extension KotaController: RPPreviewViewControllerDelegate {
    public func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true, completion: nil)
    }
    
    public func previewController(_ previewController: RPPreviewViewController, didFinishWithActivityTypes activityTypes: Set<String>) {
        if activityTypes.contains("com.apple.UIKit.activity.SaveToCameraRoll") {
            print("Save to CameraRoll")
            // do something
            let when = DispatchTime.now() + 0.5
            DispatchQueue.main.asyncAfter(deadline: when) {
                self.selectImageFromPhotoLibrary()
            }
            
        }
    }
}


public class KotaWindow: UIWindow {
    var button: UIButton?
    var recordButton: UIButton?
    
    public init() {
        super.init(frame: UIScreen.main.bounds)
        backgroundColor = nil
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if checkPoint(inside: point, button: button, with: event) {
            return true
        }
        if checkPoint(inside: point, button: recordButton, with: event) {
            return true
        }
        
        return false
    }
    
    private func checkPoint(inside point: CGPoint, button: UIButton?, with event: UIEvent?) -> Bool {
        guard let btn = button else { return false }
        
        let buttonPoint = convert(point, to: btn)
        
        return btn.point(inside: buttonPoint, with: event)
    }
}

extension UIView {
    open func addConstraintsWithFormat(_ format: String, views: UIView...) {
        var viewsDictionary = [String: UIView]()
        for (index, view) in views.enumerated() {
            let key = "v\(index)"
            view.translatesAutoresizingMaskIntoConstraints = false
            viewsDictionary[key] = view
        }
        
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: format, options: NSLayoutFormatOptions(), metrics: nil, views: viewsDictionary))
    }
}

public class KotaData {
    static let shared = KotaData()
    
    var screenshotImage: UIImage?
}

//        let button = UIButton(type: .custom)
//        button.setTitle("Floating", for: .normal)
//        button.setTitleColor(UIColor.white, for: .normal)
//        button.backgroundColor = UIColor.green
//        button.sizeToFit()
//        button.frame = CGRect(origin: CGPoint(x: 10, y: 100), size: button.bounds.size)
//        button.autoresizingMask = []
//        view.addSubview(button)
