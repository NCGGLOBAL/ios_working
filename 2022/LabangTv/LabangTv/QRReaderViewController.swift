//
//  QRReaderViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/06/30.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import AVFoundation

class QRReaderViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var captureSession:AVCaptureSession?
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // creating session
        let session = AVCaptureSession()
        self.captureSession = session

        // define capture device
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("카메라 디바이스를 찾을 수 없습니다.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                print("세션에 입력을 추가할 수 없습니다.")
                return
            }
        } catch {
            print("카메라 입력 설정 오류: \(error.localizedDescription)")
            return
        }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            print("세션에 출력을 추가할 수 없습니다.")
            return
        }

        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        // 프레임은 viewDidLayoutSubviews에서 설정
        if let previewLayer = videoPreviewLayer {
            view.layer.insertSublayer(previewLayer, at: 0) // 가장 아래 레이어로 추가하여 버튼이 위에 표시되도록
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 뷰의 실제 크기가 설정된 후 프레임 업데이트
        videoPreviewLayer?.frame = view.layer.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 세션이 실행 중이 아니면 시작
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                session.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 세션 중지
        if let session = captureSession, session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                session.stopRunning()
            }
        }
    }
    
    deinit {
        // 리소스 정리
        captureSession?.stopRunning()
        videoPreviewLayer?.removeFromSuperlayer()
    }
    

    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if AppDelegate.QR_URL != "" {
            return
        }
        if metadataObjects != nil && metadataObjects.count != nil {
            if let object = metadataObjects[0] as? AVMetadataMachineReadableCodeObject {
                if object.type == .qr {
                    if object.stringValue != nil {
                        AppDelegate.QR_URL = object.stringValue!
                        navigationController?.popToRootViewController(animated: true)
                    }
                }
            }
        }
    }
}
