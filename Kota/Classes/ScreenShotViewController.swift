//
//  CameraViewController.swift
//  Pods
//
//  Created by Khanh Pham on 5/11/17.
//
//

import UIKit
import Hero

class ScreenShotViewController: UIViewController {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var greenButton: UIButton!
    @IBOutlet weak var blueButton: UIButton!
    @IBOutlet weak var redButton: UIButton!
    
    var lastPoint:CGPoint!
    var isSwiping:Bool!
    var red:CGFloat!
    var green:CGFloat!
    var blue:CGFloat!
    
    let kota = KotaController.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        chooseGreen()
        
        if KotaData.shared.screenshotImage != nil {
            imageView.image = KotaData.shared.screenshotImage
            
            imageView.layer.shadowColor = UIColor.black.cgColor
            imageView.layer.shadowOffset = CGSize(width: 0, height: 0)
            imageView.layer.shadowOpacity = 0.5
            imageView.layer.shadowRadius = 5
            imageView.layer.cornerRadius = 4
            imageView.clipsToBounds = false
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if !kota.isHidden {
            kota.hideView()
        }
    }
    
    @IBAction func undoDrawing(_ sender: AnyObject) {
        self.imageView.image = nil
    }
    
    func image(_ image: UIImage, withPotentialError error: NSErrorPointer, contextInfo: UnsafeRawPointer) {
        UIAlertView(title: nil, message: "Image successfully saved to Photos library", delegate: nil, cancelButtonTitle: "Dismiss").show()
    }
    
    //MARK: Touch events
    override func touchesBegan(_ touches: Set<UITouch>,
                               with event: UIEvent?){
        isSwiping    = false
        if let touch = touches.first{
            lastPoint = touch.location(in: imageView)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>,
                               with event: UIEvent?){
        
        isSwiping = true;
        if let touch = touches.first{
            let currentPoint = touch.location(in: imageView)
            UIGraphicsBeginImageContext(self.imageView.frame.size)
            self.imageView.image?.draw(in: CGRect(x: 0, y: 0, width: self.imageView.frame.size.width, height: self.imageView.frame.size.height))
            UIGraphicsGetCurrentContext()?.move(to: CGPoint(x: lastPoint.x, y: lastPoint.y))
            UIGraphicsGetCurrentContext()?.addLine(to: CGPoint(x: currentPoint.x, y: currentPoint.y))
            UIGraphicsGetCurrentContext()?.setLineCap(CGLineCap.round)
            UIGraphicsGetCurrentContext()?.setLineWidth(9.0)
            UIGraphicsGetCurrentContext()?.setStrokeColor(red: red, green: green, blue: blue, alpha: 1.0)
            UIGraphicsGetCurrentContext()?.strokePath()
            self.imageView.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            lastPoint = currentPoint
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>,
                               with event: UIEvent?){
        if(!isSwiping) {
            // This is a single touch, draw a point
            UIGraphicsBeginImageContext(self.imageView.frame.size)
            self.imageView.image?.draw(in: CGRect(x: 0, y: 0, width: self.imageView.frame.size.width, height: self.imageView.frame.size.height))
            UIGraphicsGetCurrentContext()?.setLineCap(CGLineCap.round)
            UIGraphicsGetCurrentContext()?.setLineWidth(9.0)
            UIGraphicsGetCurrentContext()?.setStrokeColor(red: red, green: green, blue: blue, alpha: 1.0)
            UIGraphicsGetCurrentContext()?.move(to: CGPoint(x: lastPoint.x, y: lastPoint.y))
            UIGraphicsGetCurrentContext()?.addLine(to: CGPoint(x: lastPoint.x, y: lastPoint.y))
            UIGraphicsGetCurrentContext()?.strokePath()
            self.imageView.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }
    }
    
    
    @IBAction func greenButtonTapped(_ sender: Any) {
        chooseGreen()
    }
    
    @IBAction func blueButtonTapped(_ sender: Any) {
        chooseBlue()
    }
    
    @IBAction func redButtonTapped(_ sender: Any) {
        chooseRed()
    }
    
    func chooseGreen() {
        removeBorders()
        red   = (113.0/255.0)
        green = (219.0/255.0)
        blue  = (100.0/255.0)
        
        greenButton.layer.borderWidth = 2
        greenButton.layer.borderColor = UIColor.black.cgColor
    }
    
    func chooseBlue() {
        removeBorders()
        
        red   = (100.0/255.0)
        green = (179.0/255.0)
        blue  = (219.0/255.0)
        
        blueButton.layer.borderWidth = 2
        blueButton.layer.borderColor = UIColor.black.cgColor
    }
    
    func chooseRed() {
        removeBorders()
        
        red   = (219.0/255.0)
        green = (100.0/255.0)
        blue  = (100.0/255.0)
        
        redButton.layer.borderWidth = 2
        redButton.layer.borderColor = UIColor.black.cgColor
    }
    
    func removeBorders() {
        greenButton.layer.borderWidth = 0
        blueButton.layer.borderWidth = 0
        redButton.layer.borderWidth = 0
    }
    
    @IBAction func dismissVScreen(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func sendScreenShotButtonPressed(_ sender: Any) {
        performSegue(withIdentifier: "sendScreenShotSegue", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        KotaData.shared.screenshotImage = self.imageView.image
    }
}
