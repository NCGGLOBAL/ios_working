//
//  LiveViewController.swift
//  FlatLive
//
//  Created by glediaer on 2020/10/15.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import WebKit
import HaishinKit
import AVFoundation
import VideoToolbox
import CoreImage

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
    
    // ✅ 카메라 해상도 (카메라 사양에 맞게 동적으로 설정)
    private var cameraVideoSize: CGSize = CGSize(width: 1080, height: 1920) // 기본값
    private var lastStreamUrl: String?
    private var lastStreamKey: String?
    private var lastAppliedBitrate: Int = 2_500_000
    
    // ✅ 필터 관련 프로퍼티
    private var isFilterEnabled: Bool = false
    private var currentVideoEffect: VideoEffect?
    
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
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        } else if !url.absoluteString.hasPrefix("http://") && !url.absoluteString.hasPrefix("https://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
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
                                
                                // 카메라 전환 후 미러링 설정 적용
                                if let videoCapture = self?.rtmpStream?.videoCapture(for: 0) {
                                    if self?.currentCameraPosition == .front {
                                        // 전면 카메라는 기본적으로 미러링 활성화
                                        videoCapture.isVideoMirrored = true
                                        print("🔧 전면 카메라로 전환 - 미러링 활성화")
                                    } else {
                                        // 후면 카메라는 미러링 비활성화
                                        videoCapture.isVideoMirrored = false
                                        print("🔧 후면 카메라로 전환 - 미러링 비활성화")
                                    }
                                }
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
                    var resultcd = "1"
            
                        if let filterType = actionParamObj?["key_type"] as? Int {
                            DispatchQueue.main.async {
                                self.toggleCoreImageFilter(filterType: filterType)
                                
                                var dic = Dictionary<String, String>()
                                dic.updateValue(resultcd, forKey: "resultcd")
                                
                                do {
                                    let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                                    let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                                    let javascript = "\(callback)('\(stringValue)')"
                                    self.webView.evaluateJavaScript(javascript) { (result, error) in
                                        // 결과 처리
                                    }
                                } catch let error as NSError {
                                    print("Filter JSON error: \(error)")
                                }
                            }
                        }
                    
                    break
                    
                case "ACT1034": // 카메라 좌우 반전 제어
                    var resultcd = "1"
                    if let keyType = actionParamObj?["key_type"] as? String {
                        DispatchQueue.main.async {
                            self.toggleCameraMirror(keyType: keyType)
                            
                            var dic = Dictionary<String, String>()
                            dic.updateValue(resultcd, forKey: "resultcd")
                            
                            do {
                                let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                                let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                                let javascript = "\(callback)('\(stringValue)')"
#if DEBUG
                                print("ACT1034 jsonData : \(jsonData)")
                                print("ACT1034 javascript : \(javascript)")
#endif
                                self.webView.evaluateJavaScript(javascript) { (result, error) in
#if DEBUG
                                    print("ACT1034 result : \(String(describing: result))")
                                    print("ACT1034 error : \(String(describing: error))")
#endif
                                }
                            } catch let error as NSError {
                                print("ACT1034 JSON error: \(error)")
                            }
                        }
                    } else {
                        resultcd = "0"
                        var dic = Dictionary<String, String>()
                        dic.updateValue(resultcd, forKey: "resultcd")
                        
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                            let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                            let javascript = "\(callback)('\(stringValue)')"
                            self.webView.evaluateJavaScript(javascript) { (result, error) in
                                // 결과 처리
                            }
                        } catch let error as NSError {
                            print("ACT1034 JSON error: \(error)")
                        }
                    }
                    break
                case "ACT1030": // 스트림키 전달 및 송출
                    var resultcd = "1"
                    if let streamUrl = actionParamObj?["stream_url"] as? String {
                        let previewFps = actionParamObj?["previewFps"] as? Int ?? 30
                        let targetFps = actionParamObj?["targetFps"] as? Int ?? 30
                        
                        var videoBitrateList: [Int] = []
                        if let bitrateArray = actionParamObj?["setVideoKBitrate"] as? [Int] {
                            videoBitrateList = bitrateArray
                            print("📊 ACT1030 - setVideoKBitrate 배열 수신: \(bitrateArray) kbps")
                        } else if let singleBitrate = actionParamObj?["setVideoKBitrate"] as? Int {
                            videoBitrateList = [singleBitrate]
                            print("📊 ACT1030 - setVideoKBitrate 단일값 수신: \(singleBitrate) kbps")
                        } else {
                            videoBitrateList = [2_500_000]
                            print("📊 ACT1030 - setVideoKBitrate 기본값 사용: 2500 kbps")
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
    
    // ✅ 수정된 toggleCoreImageFilter 함수
    func toggleCoreImageFilter(filterType: Int) {
        guard let stream = rtmpStream else {
            print("❌ RTMPStream이 없습니다.")
            return
        }
        
        // 현재 필터 제거
        if let currentEffect = currentVideoEffect {
            stream.unregisterVideoEffect(currentEffect)
            currentVideoEffect = nil
            isFilterEnabled = false
        }
        
        // KSY_FILTER_BEAUTY_DISABLE (0) - 필터 비활성화
        if filterType == 0 {
            print("🎭 모든 필터 비활성화")
            return
        }
        
        let filter: CIFilter?
        
        switch filterType {
        case 1:
            filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(1.0, forKey: kCIInputRadiusKey)
            print("🎭 부드러운 뷰티 필터 적용")
            
        case 2:
            filter = CIFilter(name: "CIColorControls")
            filter?.setValue(0.2, forKey: kCIInputBrightnessKey)
            filter?.setValue(1.1, forKey: kCIInputContrastKey)
            print("🎭 피부 화이트닝 필터 적용")
            
        case 3:
            filter = CIFilter(name: "CIPhotoEffectInstant")
            print("🎭 일루전 뷰티 필터 적용")
            
        case 4: // ✅ 수정된 부분
            filter = CIFilter(name: "CISharpenLuminance")
            filter?.setValue(0.4, forKey: kCIInputSharpnessKey)
            print("🎭 샤프닝 필터 적용 (노이즈 감소 효과)")
            
        case 5:
            filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(0.8, forKey: kCIInputRadiusKey)
            print("🎭 매끄러운 뷰티 필터 적용")
            
        case 6:
            filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(1.5, forKey: kCIInputRadiusKey)
            print("🎭 확장 부드러운 필터 적용")
            
        case 7:
            filter = CIFilter(name: "CISharpenLuminance")
            filter?.setValue(0.6, forKey: kCIInputSharpnessKey)
            print("🎭 부드럽게 선명한 필터 적용")
            
        default:
            print("❌ 지원하지 않는 filterType: \(filterType)")
            return
        }
        
        // ✅ 필터 적용 (nil 체크 강화)
        guard let validFilter = filter else {
            print("❌ 필터 생성 실패")
            return
        }
        
        let videoEffect = CoreImageVideoEffect(filter: validFilter)
        
        // HaishinKit 1.9.9 API 사용
        stream.registerVideoEffect(videoEffect)
        
        currentVideoEffect = videoEffect
        isFilterEnabled = true
        print("✅ 필터 적용 완료: filterType \(filterType)")
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
                
                // 카메라 전환 후 미러링 설정 유지 (전면 카메라일 때만)
                if self?.currentCameraPosition == .front {
                    if let videoCapture = self?.rtmpStream?.videoCapture(for: 0) {
                        // 전면 카메라는 기본적으로 미러링 활성화 (거울처럼 보이게)
                        videoCapture.isVideoMirrored = true
                        print("🔧 전면 카메라 미러링 설정: 활성화")
                    }
                } else {
                    if let videoCapture = self?.rtmpStream?.videoCapture(for: 0) {
                        // 후면 카메라는 미러링 비활성화
                        videoCapture.isVideoMirrored = false
                        print("🔧 후면 카메라 미러링 설정: 비활성화")
                    }
                }
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
    
    // ✅ 카메라가 지원하는 최대 해상도 가져오기 (1280보다 높은 해상도, 세로 방향)
    func getMaxSupportedVideoSize(for cameraDevice: AVCaptureDevice?) -> CGSize {
        guard let device = cameraDevice else {
            // 기본값 반환 (1080p 세로)
            return CGSize(width: 1080, height: 1920)
        }
        
        // 카메라가 지원하는 모든 포맷 중에서 최대 해상도 찾기
        var maxSize = CGSize(width: 720, height: 1280)
        
        for format in device.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let width = Int(dimensions.width)
            let height = Int(dimensions.height)
            
            // 세로 방향 스트리밍이므로:
            // 1. 높이가 가로보다 커야 함 (height > width)
            // 2. 높이가 1280보다 커야 함
            // 3. 현재 최대값보다 높이가 커야 함
            if height > width && height > 1280 && height > Int(maxSize.height) {
                maxSize = CGSize(width: width, height: height)
            }
        }
        
        // 1280보다 높은 세로 방향 해상도를 찾지 못한 경우 기본값 사용
        if maxSize.height <= 1280 || maxSize.width >= maxSize.height {
            maxSize = CGSize(width: 1080, height: 1920)
        }
        
        print("📷 카메라 최대 지원 해상도 (세로 방향): \(Int(maxSize.width))x\(Int(maxSize.height))")
        return maxSize
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
        
        // 초기 카메라 미러링 설정 (기본값: 비활성화)
        if let videoCapture = self.rtmpStream?.videoCapture(for: 0) {
            videoCapture.isVideoMirrored = false
            print("🔧 초기 카메라 미러링 설정: 비활성화")
        }
        
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

        // 2. 비트레이트 설정 (setVideoKBitrate는 kbps 단위이므로 bps로 변환 필요)
        // iOS VideoCodecSettings는 bps (bits per second) 단위를 받음
        let bitrate: Int
        if videoBitrateList.count >= 3 {
            // 배열의 경우 중간값 사용
            let selectedKbps = videoBitrateList[1]
            bitrate = selectedKbps * 1000  // kbps를 bps로 변환
            print("📊 비트레이트 배열 [\(videoBitrateList[0]), \(videoBitrateList[1]), \(videoBitrateList[2])] kbps 중 중간값 \(selectedKbps) kbps 선택 → \(bitrate) bps")
        } else if !videoBitrateList.isEmpty {
            // 단일 값의 경우 첫 번째 값 사용
            let selectedKbps = videoBitrateList[0]
            bitrate = selectedKbps * 1000  // kbps를 bps로 변환
            print("📊 비트레이트 단일값 \(selectedKbps) kbps → \(bitrate) bps")
        } else {
            bitrate = 2_500_000  // 기본값 (2.5Mbps = 2,500,000 bps)
            print("📊 비트레이트 기본값 2500 kbps → 2500000 bps")
        }
        
        print("🔧 최종 비트레이트 설정: \(bitrate) bps (\(Double(bitrate) / 1_000_000) Mbps)")

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
                
                // 초기 카메라 미러링 설정 (전면 카메라 기본값: 활성화)
                if let videoCapture = self?.rtmpStream?.videoCapture(for: 0) {
                    videoCapture.isVideoMirrored = true
                    print("🔧 초기 전면 카메라 미러링 설정: 활성화")
                }
            }
        }
    }
    
    // ✅ 카메라 좌우 반전 제어 함수
    func toggleCameraMirror(keyType: String) {
        guard let stream = rtmpStream else {
            print("❌ RTMPStream이 없습니다.")
            return
        }
        
        // key_type이 "0"이면 미러링 비활성화, "1"이면 미러링 활성화
        let shouldMirror = keyType == "1"
        
        // HaishinKit에서 카메라 미러링 설정
        if let videoCapture = stream.videoCapture(for: 0) {
            videoCapture.isVideoMirrored = shouldMirror
            print("🔄 카메라 미러링 \(shouldMirror ? "활성화" : "비활성화") 완료")
        } else {
            print("❌ 비디오 캡처를 찾을 수 없습니다.")
        }
    }
    
    // ✅ 카메라 사양에 맞게 해상도 설정 (카메라가 지원하는 최대 해상도 사용)
    func applyVideoSettings(bitrate: Int = 2_500_000) {
        guard let stream = rtmpStream else { return }
        
        lastAppliedBitrate = bitrate
        
        // 카메라 디바이스 가져오기
        let cameraDevice = getCameraDevice(for: currentCameraPosition)
        
        // 카메라가 지원하는 최대 해상도 가져오기
        cameraVideoSize = getMaxSupportedVideoSize(for: cameraDevice)
        
        print("🔧 해상도 \(Int(cameraVideoSize.width))x\(Int(cameraVideoSize.height)) 적용 (카메라 사양 기준)")
        
        // 1. sessionPreset 설정 (카메라 해상도에 맞게)
        // 세로 방향이므로 높이를 기준으로 세션 프리셋 선택
        if cameraVideoSize.height >= 1920 {
            stream.sessionPreset = .hd1920x1080
        } else if cameraVideoSize.height >= 1280 {
            stream.sessionPreset = .hd1280x720
        } else {
            stream.sessionPreset = .hd1280x720 // 기본값
        }
        
        // 2. 해상도 설정 (카메라 사양에 맞게)
        let videoSettings = VideoCodecSettings(
            videoSize: cameraVideoSize, // 카메라가 지원하는 최대 해상도
            bitRate: bitrate,
            profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel as String,
            scalingMode: .trim
        )
        
        stream.videoSettings = videoSettings
        stream.videoOrientation = .portrait
        
        print("✅ 해상도 설정 완료: \(Int(cameraVideoSize.width))x\(Int(cameraVideoSize.height))")
    }
}

// ✅ VideoEffect 클래스는 그대로 유지
final class CoreImageVideoEffect: VideoEffect {
    private let filter: CIFilter
    
    init(filter: CIFilter) {
        self.filter = filter
        super.init()
    }
    
    override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage ?? image
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

