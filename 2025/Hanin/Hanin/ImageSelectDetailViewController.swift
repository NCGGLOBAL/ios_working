//
//  ImageSelectDetailViewController.swift
//  LabangTv
//
//  Created by glediaer on 2021/01/18.
//  Copyright © 2021 ncgglobal. All rights reserved.
//

import UIKit
import Kingfisher

class ImageSelectDetailViewController: UIViewController {
    
    var titleString = ""
    var selectedImage: Data? = nil
    var selectedImageUrl: String? = nil
    var selectedImageIndex: Int? = nil

    @IBOutlet weak var mainImageView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = titleString
        if let imgData = selectedImage {
            mainImageView.image = UIImage(data: imgData)
        } else if let urlStr = selectedImageUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
            mainImageView.kf.setImage(with: url)
        }
    }
    
    @IBAction func onClickDeleteImage(_ sender: UIBarButtonItem) {
        AppDelegate.imageArray.remove(at: selectedImageIndex ?? 0)
        AppDelegate.ImageFileArray.remove(at: selectedImageIndex ?? 0)
        mainImageView.image = nil
        
        navigationController?.popViewController(animated: true)
    }
}
