//
//  ViewController.swift
//  Kota
//
//  Created by drewg233 on 05/10/2017.
//  Copyright (c) 2017 drewg233. All rights reserved.
//

import UIKit
import Kota

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func openFeedBackPressed(_ sender: Any) {
        KotaController.shared.toggleView()
    }
    
    

}

