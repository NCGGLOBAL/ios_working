//
//  QRReaderViewController.swift
//  FlatLive
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

        // define capture device
        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice!)
            session.addInput(input)
        } catch {
            print("Error")
        }
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)

        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        videoPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)

        session.startRunning()
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
