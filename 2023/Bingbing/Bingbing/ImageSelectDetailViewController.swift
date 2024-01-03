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
    var selectedImageUrl: String? = nil

    @IBOutlet weak var mainImageView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = titleString
        if selectedImage == nil {
            if selectedImageUrl != nil {
                let url = URL(string: selectedImageUrl!)
                self.mainImageView.kf.setImage(with: url)
            }
        } else {
            self.mainImageView.image = UIImage(data: selectedImage!)
        }
        
    }
    @IBAction func onClickEditImage(_ sender: UIBarButtonItem) {
        let vc = self.storyboard!.instantiateViewController(withIdentifier: "editImageViewController") as! EditImageViewController
        
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func onClickDeleteImage(_ sender: UIBarButtonItem) {
        AppDelegate.imageArray.remove(at: selectedImageIndex ?? 0)
        AppDelegate.ImageFileArray.remove(at: selectedImageIndex ?? 0)
        mainImageView.image = nil
        
        navigationController?.popViewController(animated: true)
    }
}
