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
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = titleString
        mainImageView.image = UIImage(data: selectedImage!)
        
        
    }
    
    @IBAction func onClickDeleteImage(_ sender: Any) {
        AppDelegate.imageArray.remove(at: selectedImageIndex ?? 0)
        AppDelegate.ImageFileArray.remove(at: selectedImageIndex ?? 0)
        mainImageView.image = nil
    }
}
