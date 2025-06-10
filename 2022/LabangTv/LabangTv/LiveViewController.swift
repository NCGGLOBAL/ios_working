//
//  LiveViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/10/15.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import WebKit
import HaishinKit
import AVFoundation

class LiveViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var webView: WKWebView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    let urlString = AppDelegate.HOME_URL + "/addon/wlive/TV_live_creator.asp"
    var uniqueProcessPool = WKProcessPool()
    var cookies = HTTPCookieStorage.shared.cookies ?? []
    let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1 webview-type=sub"
    private struct Constants {
        static let callBackHandlerKey = "ios"
    }
        
    let rtmpConnection = RTMPConnection()
    var rtmpStream: RTMPStream? = nil
    var cameraPosition: AVCaptureDevice.Position = .back // 기본 카메라는 후면
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.isIdleTimerDisabled = true
        initCamera()
        
        let contentController = WKUserContentController()
        let config = WKWebViewConfiguration()
        let preferences = WKPreferences()
        preferences.setValue(true, forKey:"developerExtrasEnabled")
        preferences.javaScriptEnabled = true

        contentController.add(self, name: Constants.callBackHandlerKey)
        
        config.userContentController = contentController
        config.preferences = preferences
        config.processPool = uniqueProcessPool
        config.mediaPlaybackRequiresUserAction = false
        config.allowsInlineMediaPlayback = true
        for (cookie) in cookies {
            config.websiteDataStore.httpCookieStore.setCookie(cookie, completionHandler: nil)
        }
        
        webView = WKWebView(frame: self.view.frame, configuration: config)
//        webView.frame.size.height = self.view.frame.size.height - UIApplication.shared.statusBarFrame.size.height
        webView.frame.size.height = self.view.frame.size.height
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.customUserAgent = userAgent
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // self.view = self.webView!
        self.containerView.addSubview(webView)
        
        self.initWebView()
        if AppDelegate.QR_URL != "" {
            AppDelegate.QR_URL = ""
        }
        // Do any additional setup after loading the view.
//        navigationController?.isNavigationBarHidden = false
        
        webView.allowsBackForwardNavigationGestures = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // RTMP 연결 및 스트림 재설정
        if (rtmpStream != nil) {
            // 카메라, 오디오 다시 attach
            self.attachCameraDevice()
            self.attachMicrophone()
            
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (rtmpStream != nil) {
            // 카메라, 오디오만 해제 (연결은 유지)
            rtmpStream?.attachCamera(nil)
            rtmpStream?.attachAudio(nil)
            
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        // 리소스 완전 해제
        if (rtmpStream != nil) {
            // 스트림 중지 및 연결 해제
            rtmpStream?.close()
            rtmpConnection.close()
            
            // 카메라/오디오 연결 해제
            rtmpStream?.attachCamera(nil)
            rtmpStream?.attachAudio(nil)
            
            // 기타 리소스 해제
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func initWebView() {
        let url = URL(string: self.urlString)
        var request = URLRequest(url: url!, cachePolicy: .useProtocolCachePolicy)
        
        let headers = HTTPCookie.requestHeaderFields(with: cookies)
        
        for (name, value) in headers {
            request.addValue(value, forHTTPHeaderField: name)
        }
        webView.navigationDelegate = self
        webView.load(request)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // 로딩 시작
        self.indicatorView.startAnimating()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 로딩 종료
        self.indicatorView.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // 로딩 에러
        self.indicatorView.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.indicatorView.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        var action: WKNavigationActionPolicy?
        
        guard let url = navigationAction.request.url else { return }
        
        if url.absoluteString.range(of: "//itunes.apple.com/") != nil {
            UIApplication.shared.openURL(url)
            decisionHandler(.cancel)
            return
        } else if !url.absoluteString.hasPrefix("http://") && !url.absoluteString.hasPrefix("https://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.openURL(url)
                decisionHandler(.cancel)
                return
            }
        }
        
        switch navigationAction.navigationType {
        case .linkActivated:
            if navigationAction.targetFrame == nil || !navigationAction.targetFrame!.isMainFrame {
                webView.load(URLRequest.init(url: url))
                    decisionHandler(.cancel)
                    return
                }
            case .backForward:
                break
            case .formResubmitted:
                break
            case .formSubmitted:
                break
            case .other:
                break
            case .reload:
                break
         default:
            break
        }
            
        decisionHandler(.allow)
        
        #if DEBUG
        let urlScheme = url.scheme
        let urlString = url.absoluteString
        let decodeString = urlString

        print("url : \(url)")
        print("url absoluteString: \(url.absoluteString)")
        print("url scheme: \(url.scheme)")
        #endif
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else {
            return nil
        }
        guard let targetFrame = navigationAction.targetFrame, targetFrame.isMainFrame else {
            webView.load(URLRequest.init(url: url) as URLRequest)
                return nil
            }
        return nil
    }

    // JS -> Native CALL
    @available(iOS 8.0, *)
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage){
        print("message.name:\(message.name)")
        if message.name == Constants.callBackHandlerKey {
            print("message.body:\(message.body)")
            
            if let dictionary = message.body as? Dictionary<String, AnyObject> {
                let actionCode = dictionary["action_code"] as? String
                // param
                let actionParamArray = dictionary["action_param"] as? Array<Any>
                let actionParamObj = actionParamArray?[0] as? Dictionary<String, AnyObject>
                
                #if DEBUG
                print("actionCode : \(actionCode)")
                print("actionParamArray : \(actionParamArray)")
                print("actionParamObj : \(actionParamObj)")
                #endif
                
                // callback
                let callback = dictionary["callBack"] as? String ?? ""
                #if DEBUG
                print("callBack : \(callback)")
                #endif
                
                switch actionCode {
                    case "ACT1015":
                        #if DEBUG
                        print("ACT1015 - 웹뷰 새창")
                        #endif
                        if let requestUrl = actionParamObj!["url"] as? String{
                            let vc = self.storyboard!.instantiateViewController(withIdentifier: "subWebViewController") as! SubWebViewController
                            vc.urlString = requestUrl
                            vc.uniqueProcessPool = self.uniqueProcessPool
                            WKWebsiteDataStore.default().httpCookieStore.getAllCookies({
                                (cookies) in
                                vc.cookies = cookies
                                self.navigationController?.pushViewController(vc, animated: true)
                            })
                        }
                    break
                    case "ACT1027": // wlive 전, 후면 카메라 제어
                        var resultcd = "1"
                        if let val = actionParamObj?["key_type"] {
                            cameraPosition = (cameraPosition == .back) ? .front : .back
                            let camera = getCameraDevice(for: cameraPosition)
                            
                            rtmpStream?.attachCamera(camera) { error, result  in
                                if let error = error {
                                    print("Error attaching camera: \(error)")
                                }
                            }
                        } else {
                            resultcd = "0"
                        }
                        var dic = Dictionary<String, String>()
                        dic.updateValue(resultcd, forKey: "resultcd")

                        do {
                          let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
                         let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                            let javascript = "\(callback)('\(stringValue)')"
                            #if DEBUG
                            print("jsonData : \(jsonData)")
                            print("javascript : \(javascript)")
                            #endif
                            // call back!
                            self.webView.evaluateJavaScript(javascript) { (result, error) in
                                #if DEBUG
                                print("result : \(String(describing: result))")
                                print("error : \(error)")
                                #endif
                            }
                        } catch let error as NSError {
                            print(error)
                        }
                    break

                    case "ACT1028": // wlive 마이크 제어
                        var resultcd = "1"
                        if (actionParamObj?["key_type"]) != nil {
                            if (actionParamObj?["key_type"] as? String == "0") {  //0: 마이크 끄기,1: 켜기
                                self.detachMicrophone()
                            } else  {
                                self.attachMicrophone()
                            }
                        } else {
                            resultcd = "0"
                        }
                        var dic = Dictionary<String, String>()
                        dic.updateValue(resultcd, forKey: "resultcd")

                        do {
                          let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
                         let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                            let javascript = "\(callback)('\(stringValue)')"
                            #if DEBUG
                            print("jsonData : \(jsonData)")
                            print("javascript : \(javascript)")
                            #endif
                            // call back!
                            self.webView.evaluateJavaScript(javascript) { (result, error) in
                                #if DEBUG
                                print("result : \(String(describing: result))")
                                print("error : \(error)")
                                #endif
                            }
                        } catch let error as NSError {
                            print(error)
                        }
                    break
                    case "ACT1029": // wlive 이미지필터 제어
//                        var resultcd = "1"
//                        if let val = actionParamObj?["key_type"] as? Int {
//                            switch val {
//                            case 0:
//                                kit?.setupFilter(nil)
//                                break
//                            case 1:
//                                let bf = KSYBeautifyFaceFilter()
//                                kit?.setupFilter(bf)
//                                break
////                            case 2:
////                                let bf = KSYBeautifyProFilter()
////                                kit?.setupFilter(bf)
////                                break
//                            default:
//                                kit?.setupFilter(nil)
//                            }
//                        } else {
//                            resultcd = "0"
//                        }
//                        var dic = Dictionary<String, String>()
//                        dic.updateValue(resultcd, forKey: "resultcd")
//
//                        do {
//                          let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
//                         let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
//                            let javascript = "\(callback)('\(stringValue)')"
//                            #if DEBUG
//                            print("jsonData : \(jsonData)")
//                            print("javascript : \(javascript)")
//                            #endif
//                            // call back!
//                            self.webView.evaluateJavaScript(javascript) { (result, error) in
//                                #if DEBUG
//                                print("result : \(String(describing: result))")
//                                print("error : \(error)")
//                                #endif
//                            }
//                        } catch let error as NSError {
//                            print(error)
//                        }
                    break
                    case "ACT1030": // wlive 스트림키 전달 및 송출
                        var resultcd = "1"
                        if let streamUrl = actionParamObj?["stream_url"] as? String {
                            DispatchQueue.main.async {
                                self.initStreamer(streamUrl: streamUrl)
                            }
                        } else {
                            resultcd = "0"
                        }
                        var dic = Dictionary<String, String>()
                        dic.updateValue(resultcd, forKey: "resultcd")

                        do {
                          let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
                         let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                            let javascript = "\(callback)('\(stringValue)')"
                            #if DEBUG
                            print("jsonData : \(jsonData)")
                            print("javascript : \(javascript)")
                            #endif
                            // call back!
                            self.webView.evaluateJavaScript(javascript) { (result, error) in
                                #if DEBUG
                                print("result : \(String(describing: result))")
                                print("error : \(error)")
                                #endif
                            }
                        } catch let error as NSError {
                            print(error)
                        }
                    break
                    case "ACT1031": // 종료
                        self.navigationController?.popToRootViewController(animated: true)
                    break
                    
                case "ACT1036": //스트리밍 화면 캡쳐
                    // 현재 화면의 이미지 캡처
                    let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
                    let image = renderer.image { context in
                        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
                    }
                    
                    if image != nil {
                        if let base64String = image.toBase64() {
                            print("Base64 string: \(base64String)")
                            var dic = Dictionary<String, String>()
                            dic.updateValue(base64String, forKey: "fData")
                            
                            do {
                                let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
                                let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                                let javascript = "\(callback)('\(stringValue)')"
                                #if DEBUG
                                print("jsonData : \(jsonData)")
                                print("javascript : \(javascript)")
                                #endif
                                // call back!
                                self.webView.evaluateJavaScript(javascript) { (result, error) in
                                    #if DEBUG
                                    print("result : \(String(describing: result))")
                                    print("error : \(error)")
                                    #endif
                                }
                            } catch let error as NSError {
                                print(error)
                            }
                        } else {
                            print("Failed to convert image to Base64 string.")
                        }
                    }
                    
                    break
                case "ACT1037": // 앨범 열기
                    self.uploadPhoto()
                    break
                    
                    default:
                        print("디폴트를 꼭 해줘야 합니다.")
                }
            }
        }
    }
    
    func attachCameraDevice() {
        cameraPosition = (cameraPosition == .back) ? .front : .back
        let cameraDevice = getCameraDevice(for: cameraPosition)
        rtmpStream?.attachCamera(cameraDevice)
    }

    
    func attachMicrophone() {
        let audioDevice = AVCaptureDevice.default(for: .audio)
        rtmpStream?.attachAudio(audioDevice) { error, result in
               if let error = error {
                   print("Error attaching audio: \(error)")
               }
           }
    }

   func detachMicrophone() {
       rtmpStream?.attachAudio(nil) { error, result in
           if let error = error {
               print("Error detaching audio: \(error)")
           }
       }
   }
    
    func getCameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
            let devices = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            ).devices
            
            return devices.first { $0.position == position }
        }
    
    func uploadPhoto() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self //3
        // imagePicker.allowsEditing = true
        present(imagePicker, animated: true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "확인", style: .cancel) { _ in
            completionHandler()
        }
        alertController.addAction(cancelAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "취소", style: .cancel) { _ in
            completionHandler(false)
        }
        let okAction = UIAlertAction(title: "확인", style: .default) { _ in
            completionHandler(true)
        }
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func initCamera() {
        // RTMPConnection과 RTMPStream 설정
        self.rtmpStream = RTMPStream(connection: rtmpConnection)
        
        // 카메라 및 마이크 설정
//        rtmpStream?.videoSettings = [
//            .width: 1280,
//            .height: 720,
//            .fps: 30
//        ]
//        rtmpStream.audioSettings = [
//            .bitrate: 128000,
//            .sampleRate: 44100
//        ]
        
        // UI에 AVCaptureVideoPreviewLayer 추가
        let hkView = MTHKView(frame: view.bounds)
        hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
        hkView.attachStream(rtmpStream)
        
        // add ViewController#view
        self.containerView.addSubview(hkView)
    }

    func initStreamer(streamUrl: String) {
        let components = streamUrl.components(separatedBy: "/")
        if components.count > 1 {
            let streamKey = components.last!
            let convertStreamUrl = components.dropLast().joined(separator: "/")

            self.rtmpConnection.connect(convertStreamUrl)
            self.rtmpStream?.publish(streamKey)
        }
        
        self.rtmpStream?.attachAudio(AVCaptureDevice.default(for: .audio)) { _, error in
            print("attachAudio")
          if let error {
            print("attachAudio error")
          }
        }

        self.rtmpStream?.attachCamera(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), track: 0) { _, error in
            print("attachCamera")
          if let error {
              print("attachCamera error")
          }
        }
    }

}

extension UIImage {
    func toBase64() -> String? {
        guard let imageData = self.pngData() else {
            return nil
        }
        return imageData.base64EncodedString(options: .lineLength64Characters)
    }
}
