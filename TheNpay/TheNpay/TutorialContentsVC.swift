//
//  TutorialContentsVC.swift
//  LabangTv
//
//  Created by 정진만 on 2021/11/16.
//  Copyright © 2021 ncgglobal. All rights reserved.
//

import UIKit

class TutorialContentsVC: UIViewController {
    
    @IBOutlet weak var bgImageView: UIImageView!
    
    var pageIndex: Int!
    var titleText: String!
    var imageFile: String!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.bgImageView.image = UIImage(named: self.imageFile)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
