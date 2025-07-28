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
import VideoToolbox

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
    var currentCameraPosition: AVCaptureDevice.Position = .front
    
    // ✅ 해상도 고정을 위한 설정 (타이머 관련 제거)
    private let fixedVideoSize = CGSize(width: 720, height: 1280)
    private var lastStreamUrl: String?
    private var lastStreamKey: String?
    private var lastAppliedBitrate: Int = 2_500_000
    
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
        webView.frame.size.height = self.view.frame.size.height
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.customUserAgent = userAgent
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        self.containerView.addSubview(webView)
        
        self.initWebView()
        if AppDelegate.QR_URL != "" {
            AppDelegate.QR_URL = ""
        }
        
        // ✅ 최소한의 알림만 등록
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        webView.allowsBackForwardNavigationGestures = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // ✅ 기존 방식 유지 (프리뷰 보장)
        if (rtmpStream != nil) {
            self.attachCameraDevice()
            self.attachMicrophone()
            
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (rtmpStream != nil) {
            // ✅ 기존 방식 유지
            rtmpStream?.attachCamera(nil)
            rtmpStream?.attachAudio(nil)
            
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if (rtmpStream != nil) {
            rtmpStream?.close()
            rtmpConnection.close()
            
            rtmpStream?.attachCamera(nil)
            rtmpStream?.attachAudio(nil)
            
            UIApplication.shared.isIdleTimerDisabled = false
            
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // ✅ 단순한 백그라운드/포그라운드 처리
    @objc func appWillEnterForeground() {
        print("[App State] 포그라운드 진입")

        guard let stream = rtmpStream else { return }

        // 스트리밍 재개
        stream.receiveVideo = true
        stream.receiveAudio = true
        
        // ✅ RTMP 연결이 끊어진 경우에만 재연결
        if !rtmpConnection.connected && lastStreamUrl != nil && lastStreamKey != nil {
            rtmpConnection.connect(lastStreamUrl!)
            rtmpStream?.publish(lastStreamKey!)
        }

        UIApplication.shared.isIdleTimerDisabled = true
    }

    @objc func appDidEnterBackground() {
        print("[App State] 백그라운드 진입")

        guard let stream = rtmpStream else { return }

        // 스트리밍 중지
        stream.receiveVideo = false
        stream.receiveAudio = false

        UIApplication.shared.isIdleTimerDisabled = false
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
        self.indicatorView.startAnimating()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.indicatorView.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
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
    
    @available(iOS 8.0, *)
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage){
        print("message.name:\(message.name)")
        if message.name == Constants.callBackHandlerKey {
            print("message.body:\(message.body)")
            
            if let dictionary = message.body as? Dictionary<String, AnyObject> {
                let actionCode = dictionary["action_code"] as? String
                let actionParamArray = dictionary["action_param"] as? Array<Any>
                let actionParamObj = actionParamArray?[0] as? Dictionary<String, AnyObject>
                
#if DEBUG
                print("actionCode : \(actionCode)")
                print("actionParamArray : \(actionParamArray)")
                print("actionParamObj : \(actionParamObj)")
#endif
                
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
                case "ACT1027": // 전/후면 카메라 제어
                    var resultcd = "1"
                    if let val = actionParamObj?["key_type"] {
                        currentCameraPosition = (currentCameraPosition == .back) ? .front : .back
                        let camera = getCameraDevice(for: currentCameraPosition)
                        
                        rtmpStream?.attachCamera(camera) { [weak self] error, result in
                            if let error = error {
                                print("Error attaching camera: \(error)")
                            } else {
                                // ✅ 카메라 전환 후 한 번만 해상도 적용
                                self?.applyVideoSettings(bitrate: self?.lastAppliedBitrate ?? 2_500_000)
                            }
                        }
                    } else {
                        resultcd = "0"
                    }
                    var dic = Dictionary<String, String>()
                    dic.updateValue(resultcd, forKey: "resultcd")
                    
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                        let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                        let javascript = "\(callback)('\(stringValue)')"
#if DEBUG
                        print("jsonData : \(jsonData)")
                        print("javascript : \(javascript)")
#endif
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
                    
                case "ACT1028": // 마이크 제어
                    var resultcd = "1"
                    if (actionParamObj?["key_type"]) != nil {
                        if (actionParamObj?["key_type"] as? String == "0") {
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
                        let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                        let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                        let javascript = "\(callback)('\(stringValue)')"
#if DEBUG
                        print("jsonData : \(jsonData)")
                        print("javascript : \(javascript)")
#endif
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
                case "ACT1029":
                    break
                case "ACT1030": // 스트림키 전달 및 송출
                    var resultcd = "1"
                    if let streamUrl = actionParamObj?["stream_url"] as? String {
                        let previewFps = actionParamObj?["previewFps"] as? Int ?? 30
                        let targetFps = actionParamObj?["targetFps"] as? Int ?? 30
                        
                        var videoBitrateList: [Int] = []
                        if let bitrateArray = actionParamObj?["setVideoKBitrate"] as? [Int] {
                            videoBitrateList = bitrateArray
                        } else if let singleBitrate = actionParamObj?["setVideoKBitrate"] as? Int {
                            videoBitrateList = [singleBitrate]
                        } else {
                            videoBitrateList = [2_500_000]
                        }
                        
                        DispatchQueue.main.async {
                            self.initStreamer(
                                streamUrl: streamUrl,
                                previewFps: previewFps,
                                targetFps: targetFps,
                                videoBitrateList: videoBitrateList
                            )
                        }
                    } else {
                        resultcd = "0"
                    }

                    var dic = Dictionary<String, String>()
                    dic.updateValue(resultcd, forKey: "resultcd")
                    
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                        let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                        let javascript = "\(callback)('\(stringValue)')"
#if DEBUG
                        print("jsonData : \(jsonData)")
                        print("javascript : \(javascript)")
#endif
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
                case "ACT1031":
                    self.navigationController?.popToRootViewController(animated: true)
                    break
                    
                case "ACT1036":
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
                                let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                                let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                                let javascript = "\(callback)('\(stringValue)')"
#if DEBUG
                                print("jsonData : \(jsonData)")
                                print("javascript : \(javascript)")
#endif
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
                case "ACT1037":
                    self.uploadPhoto()
                    break
                    
                default:
                    print("디폴트를 꼭 해줘야 합니다.")
                }
            }
        }
    }
    
    // ✅ 카메라 연결 시 단순하게 한 번만 적용
    func attachCameraDevice() {
        let cameraDevice = getCameraDevice(for: currentCameraPosition)
        rtmpStream?.attachCamera(cameraDevice) { [weak self] error, result in
            if let error = error {
                print("Error attaching camera: \(error)")
            } else {
                // 카메라 연결 후 한 번만 해상도 적용
                self?.applyVideoSettings(bitrate: self?.lastAppliedBitrate ?? 2_500_000)
            }
        }
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
        imagePicker.delegate = self
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
        self.rtmpStream = RTMPStream(connection: rtmpConnection)
        self.rtmpStream?.videoCapture(for: 0)?.isVideoMirrored = false
        
        let hkView = MTHKView(frame: view.bounds)
        hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
        hkView.attachStream(rtmpStream)
        
        self.containerView.addSubview(hkView)
    }
    
    // ✅ 스트리머 초기화 시 확실한 초기 설정
    func initStreamer(
        streamUrl: String,
        previewFps: Int,
        targetFps: Int,
        videoBitrateList: [Int]
    ) {
        // 1. 스트림 URL 저장
        let components = streamUrl.components(separatedBy: "/")
        if components.count > 1, let streamKey = components.last {
            let convertStreamUrl = components.dropLast().joined(separator: "/")
            lastStreamUrl = convertStreamUrl
            lastStreamKey = streamKey
            
            self.rtmpConnection.connect(convertStreamUrl)
            self.rtmpStream?.publish(streamKey)
        }

        // 2. 비트레이트 설정
        let bitrate: Int
        if videoBitrateList.count >= 3 {
            bitrate = videoBitrateList[1]
        } else if !videoBitrateList.isEmpty {
            bitrate = videoBitrateList[0]
        } else {
            bitrate = 2_500_000
        }

        // ✅ 3. 초기 해상도 설정 (한 번만)
        applyVideoSettings(bitrate: bitrate)

        // 4. 프레임 레이트
        self.rtmpStream?.frameRate = Float64(targetFps)

        // 5. 오디오 연결
        self.rtmpStream?.attachAudio(AVCaptureDevice.default(for: .audio)) { _, error in
            print("attachAudio" + (error != nil ? " error" : ""))
        }

        // 6. 카메라 연결
        self.rtmpStream?.attachCamera(
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            track: 0
        ) { [weak self] _, error in
            print("attachCamera" + (error != nil ? " error" : ""))
            if error == nil {
                // 카메라 연결 후 한 번만 해상도 적용
                self?.applyVideoSettings(bitrate: bitrate)
            }
        }
    }
    
    // ✅ 단순하고 확실한 해상도 설정 함수 (한 번만 적용)
    func applyVideoSettings(bitrate: Int = 2_500_000) {
        guard let stream = rtmpStream else { return }
        
        lastAppliedBitrate = bitrate
        
        print("🔧 해상도 720x1280 고정 적용")
        
        // 1. sessionPreset 설정
//        if let capture = stream.videoCapture(for: 0) {
//            capture.setSessionPreset(.hd1280x720)
//        }
        
        // 2. 해상도 고정
        let videoSettings = VideoCodecSettings(
            videoSize: fixedVideoSize, // 720x1280 고정
            bitRate: bitrate,
            profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel as String,
            scalingMode: .trim
        )
        
        stream.videoSettings = videoSettings
        stream.videoOrientation = .portrait
        
        print("✅ 해상도 설정 완료: \(fixedVideoSize)")
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

