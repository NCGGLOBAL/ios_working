//
//  SplashViewController.swift
//  WagleLive
//
//  Created by 정진만 on 4/1/25.
//

import UIKit
import Gifu

class SplashViewController: UIViewController {
    
    private let gifImage: GIFImageView = {
            let img = GIFImageView()
            img.translatesAutoresizingMaskIntoConstraints = false
            img.isUserInteractionEnabled = true
            img.contentMode = .scaleAspectFit
            return img
        }()

    override func viewDidLoad() {
        super.viewDidLoad()

        gifImage.animate(withGIFNamed: "splash")
        gifImage.frame = self.view.frame
        view.addSubview(gifImage)
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false, block: {[weak self] timer in
            self?.gifImage.stopAnimatingGIF()
            self?.goMain()
        })
    }
    
    func goMain() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let viewController = storyboard.instantiateViewController(withIdentifier: "viewController") as? ViewController {
            self.present(viewController, animated: false, completion: nil)
        }

    }

}
