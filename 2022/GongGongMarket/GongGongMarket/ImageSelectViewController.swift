//
//  ImageSelectViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/06/12.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import Kingfisher

class ImageSelectViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ELCImagePickerControllerDelegate {

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
    func openLibrary() {
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: false, completion: nil)
//        let elcPicker = ELCImagePickerController()
//        ELCImagePickerController *elcPicker = [[ELCImagePickerController alloc] initImagePicker];
//        elcPicker.imagePickerDelegate  = self
//        elcPicker.currentCount         = AppDelegate.ImageFileArray.count
//        [self presentViewController:elcPicker animated:YES completion:nil];
//        self.navigationController?.present(elcPicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            let imageItem = ImageData()
            let imageFileItem = ImageFileData()
            imageFileItem.image = image.jpegData(compressionQuality: 0.1)

            var date = Date()  // 날짜 데이터
            let dateFomatter = DateFormatter()
            dateFomatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateString = dateFomatter.string(from: date)

            // 이미지 확장자 추출
            var imageExtention = ".jpg"
            
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let vc = self.storyboard!.instantiateViewController(withIdentifier: "imageSelectDetailViewController") as! ImageSelectDetailViewController
        
        let item = AppDelegate.ImageFileArray[indexPath.row]
        vc.titleString = "\(AppDelegate.imageArray)장 중 \(indexPath.row + 1)번째 선택"
        vc.selectedImage = item.image
        self.navigationController?.pushViewController(vc, animated: true)
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

    func elcImagePickerController(_ picker: ELCImagePickerController!, didFinishPickingMediaWithInfo info: [Any]!) {
    }
    
    func elcImagePickerControllerDidCancel(_ picker: ELCImagePickerController!) {
        
    }
}
