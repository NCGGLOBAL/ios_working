//
//  ImageSelectDetailViewController.swift
//  LabangTv
//
//  Created by glediaer on 2021/01/18.
//  Copyright © 2021 ncgglobal. All rights reserved.
//

import UIKit

class ImageSelectDetailViewController: UIViewController {
    
    var titleString = ""
    var selectedImage: Data? = nil
    var selectedImageIndex: Int? = nil

    @IBOutlet weak var mainImageView: UIImageView!
    @IBOutlet weak var tabBarView: UITabBar!
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = titleString
        mainImageView.image = UIImage(data: selectedImage!)
    }
}
