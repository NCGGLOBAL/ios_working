//
//  ImageSelectViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/06/12.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import Kingfisher
import AVFoundation
import Photos

class ImageSelectViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!

    let imagePicker = UIImagePickerController()

    override func viewDidLoad() {
        super.viewDidLoad()

        imagePicker.delegate = self
        
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.title = "\(AppDelegate.ImageFileArray.count) / 9"
    }
    
    // MARK: - 권한 요청 함수들
    
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized || status == .limited)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    func openCamera() {
        requestCameraPermission { [weak self] granted in
            guard let self = self else { return }
            
            if granted {
                DispatchQueue.main.async {
                    self.imagePicker.sourceType = .camera
                    self.present(self.imagePicker, animated: false, completion: nil)
                }
            } else {
                DispatchQueue.main.async {
                    self.showPermissionAlert(for: "카메라")
                }
            }
        }
    }
    
    // 앨범을 접근하는 함수
    func openLibrary(){
        requestPhotoLibraryPermission { [weak self] granted in
            guard let self = self else { return }
            
            if granted {
                DispatchQueue.main.async {
                    self.imagePicker.sourceType = .photoLibrary
                    self.present(self.imagePicker, animated: false, completion: nil)
                }
            } else {
                DispatchQueue.main.async {
                    self.showPermissionAlert(for: "사진첩")
                }
            }
        }
    }
    
    func showPermissionAlert(for permission: String) {
        let alertController = UIAlertController(
            title: "권한 필요",
            message: "\(permission) 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.",
            preferredStyle: .alert
        )
        
        let settingsAction = UIAlertAction(title: "설정으로 이동", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        }
        
        let cancelAction = UIAlertAction(title: "취소", style: .cancel)
        
        alertController.addAction(settingsAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCollectionViewCell", for: indexPath) as! ImageCollectionViewCell
        
        let imageFileItem = AppDelegate.ImageFileArray[indexPath.row]
        if let imageData = imageFileItem.image {
            cell.imageView.image = UIImage(data: imageData)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width - 2) / 3
        let cgSize = CGSize(width: width, height: width)
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
