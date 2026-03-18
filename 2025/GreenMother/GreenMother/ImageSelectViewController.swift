//
//  ImageSelectViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/06/12.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import Kingfisher
import BSImagePicker
import Photos

class ImageSelectViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!

    let imagePicker = UIImagePickerController()
    
    let LIMIT_IMAGE_SIZE = 10

    override func viewDidLoad() {
        super.viewDidLoad()

        imagePicker.delegate = self
        
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.title = "\(AppDelegate.ImageFileArray.count) / \(LIMIT_IMAGE_SIZE)"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationItem.title = "\(AppDelegate.ImageFileArray.count) / \(LIMIT_IMAGE_SIZE)"
        self.collectionView.reloadData()
    }
    
    func openCamera() {
        imagePicker.sourceType = .camera
        present(imagePicker, animated: false, completion: nil)
    }
    
    // 앨범을 접근하는 함수
    func openLibrary() {
        let imagePicker = ImagePickerController()

        presentImagePicker(imagePicker, select: { (asset) in
            // User selected an asset. Do something with it. Perhaps begin processing/upload?
        }, deselect: { (asset) in
            // User deselected an asset. Cancel whatever you did when asset was selected.
        }, cancel: { (assets) in
            // User canceled selection.
        },         finish: { (assets) in
            // User finished selection assets.
            for asset in assets {
                let imageItem = ImageData()
                let imageFileItem = ImageFileData()
                
                // 업로드용: 원본 해상도 JPEG 변환 (썸네일 PNG 대신 - 서버 호환성)
                let (uploadImageData, uploadFileName) = self.getAssetImageForUpload(asset: asset)
                guard let imageData = uploadImageData, !uploadFileName.isEmpty else { continue }
                
                imageFileItem.image = imageData
                imageFileItem.fileName = uploadFileName
                imageItem.fileName = uploadFileName
                
                AppDelegate.imageArray.append(imageItem)
                AppDelegate.ImageFileArray.append(imageFileItem)
            }
            
            self.navigationItem.title = "\(AppDelegate.imageArray.count) / \(self.LIMIT_IMAGE_SIZE)"
            self.collectionView.reloadData()
            
            AppDelegate.isChangeImage = true
        })
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        #if DEBUG
        print("[카메라] didFinishPickingMediaWithInfo 호출됨, sourceType: \(picker.sourceType.rawValue)")
        print("[카메라] info keys: \(info.keys.map { $0.rawValue })")
        #endif
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            let imageItem = ImageData()
            let imageFileItem = ImageFileData()
            // 앨범과 동일한 품질 (0.8)로 통일. orientation은 EXIF 유지 (Android도 카메라 원본→saveImage에서 EXIF 회전 적용)
            let compressionQuality: CGFloat = 0.8
            imageFileItem.image = image.jpegData(compressionQuality: compressionQuality)

            // 공백/콜론 제거 (앨범과 동일한 URL 호환성 - 서버·방화벽 이슈 방지)
            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let dateString = dateFormatter.string(from: date)
            let imageName = dateString + ".jpg"
            imageItem.fileName = imageName
            imageFileItem.fileName = imageName
            print("imageName : \(imageName)")
            
            AppDelegate.imageArray.append(imageItem)
            AppDelegate.ImageFileArray.append(imageFileItem)
            #if DEBUG
            let imgData = imageFileItem.image!
            print("[카메라] source: 직접촬영 | originalImage size: \(image.size), orientation: \(image.imageOrientation.rawValue)")
            print("[카메라] JPEG compressionQuality: \(compressionQuality) | imageData size: \(imgData.count) bytes")
            #endif
            
            self.navigationItem.title = "\(AppDelegate.imageArray.count) / \(LIMIT_IMAGE_SIZE)"
        } else {
            #if DEBUG
            print("[카메라] originalImage 추출 실패 - info keys: \(info.keys)")
            #endif
        }
        self.collectionView.reloadData()
        AppDelegate.isChangeImage = true
        self.dismiss(animated: true, completion: nil)
    }
    
    func getAssetThumbnail(asset: PHAsset) -> UIImage {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        var thumbnail = UIImage()
        option.isSynchronous = true
        manager.requestImage(for: asset, targetSize: CGSize(width: self.view.bounds.width, height: self.view.bounds.width), contentMode: .aspectFit, options: option, resultHandler: {(result, info)->Void in
                thumbnail = result!
        })
        return thumbnail
    }
    
    /// 업로드용: 원본 해상도 이미지를 JPEG로 변환. HEIC 등은 .jpg 확장자로 변경
    func getAssetImageForUpload(asset: PHAsset) -> (Data?, String) {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.isSynchronous = true
        option.deliveryMode = .highQualityFormat
        option.isNetworkAccessAllowed = true
        
        var resultImage: UIImage?
        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: option) { image, _ in
            resultImage = image
        }
        
        guard let image = resultImage else { return (nil, "") }
        
        // JPEG로 변환 (서버 호환성, HEIC 미지원 대비)
        let compressionQuality: CGFloat = 0.8
        let jpegData = image.jpegData(compressionQuality: compressionQuality)
        
        // 파일명: .HEIC, .heic 등은 .jpg로 변경
        let resources = PHAssetResource.assetResources(for: asset)
        var fileName = resources.first?.originalFilename ?? "image.jpg"
        let originalFilename = fileName
        if fileName.lowercased().hasSuffix(".heic") {
            fileName = (fileName as NSString).deletingPathExtension + ".jpg"
        } else if !fileName.lowercased().hasSuffix(".jpg") && !fileName.lowercased().hasSuffix(".jpeg") {
            fileName = (fileName as NSString).deletingPathExtension + ".jpg"
        }
        
        #if DEBUG
        let mediaType = asset.mediaType.rawValue  // 1=image, 2=video, 3=audio
        let mediaSubtypes = asset.mediaSubtypes.rawValue
        print("[앨범] source: 앨범선택 | asset mediaType: \(mediaType), mediaSubtypes: \(mediaSubtypes)")
        print("[앨범] originalFilename: \(originalFilename) -> fileName: \(fileName)")
        print("[앨범] originalImage size: \(image.size), orientation: \(image.imageOrientation.rawValue)")
        print("[앨범] JPEG compressionQuality: \(compressionQuality) | imageData size: \(jpegData?.count ?? 0) bytes | cgImage: \(image.cgImage != nil)")
        #endif
        
        return (jpegData, fileName)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        AppDelegate.ImageFileArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: ImageCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath) as! ImageCollectionViewCell
        
        let item = AppDelegate.ImageFileArray[indexPath.row]
        if item.imgUrl != nil {
            let url = URL(string: item.imgUrl!)
            cell.mainImageView.kf.setImage(with: url)
        } else {
            cell.mainImageView.image = UIImage(data: item.image!)
            #if DEBUG
            print("[cellForItem] row \(indexPath.row): imageData size: \(item.image?.count ?? 0) bytes, imageView frame: \(cell.mainImageView.frame)")
            #endif
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let vc = self.storyboard!.instantiateViewController(withIdentifier: "imageSelectDetailViewController") as! ImageSelectDetailViewController
        
        let item = AppDelegate.ImageFileArray[indexPath.row]
        vc.titleString = "\(AppDelegate.imageArray.count)장 중 \(indexPath.row + 1)번째 선택"
        vc.selectedImage = item.image
        vc.selectedImageIndex = indexPath.row
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
        if AppDelegate.ImageFileArray.count >= LIMIT_IMAGE_SIZE {
            self.setCommonPopup(msg: "10개의 이미지만 등록 가능합니다.")
            return
        }
        self.openCamera()
    }
    
    @IBAction func onClickAlbum(_ sender: Any) {
        if AppDelegate.ImageFileArray.count >= LIMIT_IMAGE_SIZE {
            self.setCommonPopup(msg: "10개의 이미지만 등록 가능합니다.")
            return
        }
        self.openLibrary()
    }
    @IBAction func onClickDone(_ sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }
}
