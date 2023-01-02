//
//  ImageSelectViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/06/12.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import Kingfisher

class ImageSelectViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!

    let imagePicker = UIImagePickerController()

    override func viewDidLoad() {
        super.viewDidLoad()

        imagePicker.delegate = self
        
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.title = "\(AppDelegate.ImageFileArray.count) / 9"
    }
    
    func openCamera() {
        imagePicker.sourceType = .camera
        present(imagePicker, animated: false, completion: nil)
    }
    
    // 앨범을 접근하는 함수
    func openLibrary(){
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: false, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            let imageItem = ImageData()
            let imageFileItem = ImageFileData()
            imageFileItem.image = image.jpegData(compressionQuality: 0.1)
//            if let url = info[UIImagePickerController.InfoKey.imageURL] as? URL {
//                imageItem.fileName = url.lastPathComponent
//                imageFileItem.fileName = url.lastPathComponent
//            }
            

            var date = Date()  // 날짜 데이터
            let dateFomatter = DateFormatter()
            dateFomatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateString = dateFomatter.string(from: date)

            // 이미지 확장자 추출
//            let assetPath = info[UIImagePickerController.InfoKey.referenceURL] as! NSURL
            var imageExtention = ".jpg"
//            if (assetPath.absoluteString?.hasSuffix("JPG"))! {
//                print("JPG")
//                imageExtention = ".jpg"
//            }
//            else if (assetPath.absoluteString?.hasSuffix("PNG"))! {
//                print("PNG")
//                imageExtention = ".png"
//            }
//            else if (assetPath.absoluteString?.hasSuffix("GIF"))! {
//                print("GIF")
//                imageExtention = ".gif"
//            }
//            else {
//                print("Unknown")
//            }
            
            // 이미지 이름 지정
            let imageName : String = dateString + imageExtention
            imageItem.fileName = imageName
            imageFileItem.fileName = imageName
            print("imageName : \(imageName)")
            
            AppDelegate.imageArray.append(imageItem)
            AppDelegate.ImageFileArray.append(imageFileItem)
            
            self.navigationItem.title = "\(AppDelegate.imageArray.count) / 9"
        }
        self.collectionView.reloadData()
        
        AppDelegate.isChangeImage = true
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        AppDelegate.ImageFileArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: ImageCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath) as! ImageCollectionViewCell
        
        let item = AppDelegate.ImageFileArray[indexPath.row]
        // 이미지 url 변환
        if item.imgUrl != nil {
            let url = URL(string: item.imgUrl!)
            cell.mainImageView.kf.setImage(with: url)
        } else {
            cell.mainImageView.image = UIImage(data: item.image!)
        }
        return cell
    }
    
    // size
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        // 1. collectionview width 구하기
        let collectionWidth = collectionView.frame.width
//        print("collectionWidth : \(collectionWidth)")
        // 2. cell width 구하기
        let cellWidth = collectionWidth / 3 - 1
//        print("cellWidth :  \(cellWidth)")

        let cgSize = CGSize(width: cellWidth, height: cellWidth)

        return cgSize
    }
    
    
    // 옆라인 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    // 위아래 라인 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func setCommonPopup(msg: String) {
        let alertController = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "확인", style: .default) { (UIAlertAction) in
        }
        alertController.addAction(okAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func onClickCamera(_ sender: UIButton) {
        if AppDelegate.ImageFileArray.count > 9 {
            self.setCommonPopup(msg: "10개의 이미지만 등록 가능합니다.")
            return
        }
        self.openCamera()
    }
    
    @IBAction func onClickAlbum(_ sender: Any) {
        if AppDelegate.ImageFileArray.count > 9 {
            self.setCommonPopup(msg: "10개의 이미지만 등록 가능합니다.")
            return
        }
        self.openLibrary()
    }
    @IBAction func onClickDone(_ sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
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
