//
//  VideoThumbViewController.swift
//  Kpopcon
//
//  Created by 정진만 on 7/20/24.
//

import UIKit
import AVFoundation

class VideoThumbViewController: UIViewController {

    @IBOutlet weak var thumbImageView: UIImageView!

    var videoUrl: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // 동영상 썸네일 추출
        if videoUrl != nil {
            generateThumbnail(for: videoUrl!) { thumbnail in
                if let thumbnail = thumbnail {
                    print("썸네일을 성공적으로 가져왔습니다.")
                    self.thumbImageView.image = thumbnail
                    AppDelegate.VIDEO_THUMBNAIL_UIImage = thumbnail
//                    self.setImageUrl(thumbnail: thumbnail)
                } else {
                    print("썸네일을 가져오지 못했습니다.")
                }
            }
        }
    }
    
    func generateThumbnail(for videoURL: URL, completion: @escaping (UIImage?) -> Void) {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 0.0, preferredTimescale: 1)
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
            if let cgImage = image {
                let thumbnail = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    completion(thumbnail)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
//    func setImageUrl(thumbnail: UIImage) {
//        if let imageData = thumbnail.jpegData(compressionQuality: 0.8) {
//            let tempDirectoryURL = FileManager.default.temporaryDirectory
//            let imageURL = tempDirectoryURL.appendingPathComponent("thumbnail.jpg")
//            AppDelegate.VIDEO_THUMBNAIL_UIImage = thumbnail
//        }
//    }
    
    @IBAction func onClickSelectImage(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
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
