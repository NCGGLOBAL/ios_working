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
import RTMPHaishinKit
import AVFoundation
import VideoToolbox
import CoreImage
import Combine

class LiveViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var webView: WKWebView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    let urlString = AppDelegate.HOME_URL + "/addon/wlive/TV_live_creator.asp"
    var uniqueProcessPool = WKProcessPool()
    var cookies: [HTTPCookie] = []
    let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1 webview-type=sub"
    private struct Constants {
        static let callBackHandlerKey = "ios"
    }
    
    // ✅ HaishinKit 2.0.0 객체
    private var mixer: MediaMixer!
    private var rtmpConnection: RTMPConnection!
    private var rtmpStream: RTMPStream!
    private var hkView: MTHKView!
    
    var currentCameraPosition: AVCaptureDevice.Position = .front
    
    // ✅ 카메라 해상도 (카메라 사양에 맞게 동적으로 설정)
    private var cameraVideoSize: CGSize = CGSize(width: 1080, height: 1920) // 기본값
    private var lastStreamUrl: String?
    private var lastStreamKey: String?
    private var lastAppliedBitrate: Int = 2_500_000
    
    // ✅ 필터 관련 프로퍼티 (HaishinKit 2.2.3에서 정상 작동 확인)
    private var isFilterEnabled: Bool = false
    private var currentVideoEffect: VideoEffect?
    
    // ✅ Combine cancellables
    private var cancellables: Set<AnyCancellable> = []
    
    var callback = ""
    
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
        
        // ✅ HaishinKit 2.0.0: MediaMixer 시작 및 카메라/오디오 재연결
        if mixer != nil && rtmpStream != nil {
            Task {
                await mixer.startRunning()
                print("✅ MediaMixer 재시작됨")
            }
            
            attachCameraDevice()
            attachMicrophone()
            
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // ✅ HaishinKit 2.0.0: MediaMixer 중지
        if mixer != nil {
            Task {
                await mixer.stopRunning()
                print("✅ MediaMixer 중지됨")
            }
            
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // ✅ HaishinKit 2.0.0: 스트림 종료
        if rtmpStream != nil && rtmpConnection != nil {
            Task {
                do {
                    try await rtmpStream.close()
                    try await rtmpConnection.close()
                    
                    try await mixer.attachVideo(nil, track: 0)
                    try await mixer.attachAudio(nil, track: 0)
                    
                    await mixer.stopRunning()
                    print("✅ 스트림 종료 완료")
                } catch {
                    print("❌ 스트림 종료 오류: \(error)")
                }
            }
            
            UIApplication.shared.isIdleTimerDisabled = false
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // ✅ HaishinKit 2.0.0: 백그라운드/포그라운드 처리
    @objc func appWillEnterForeground() {
        print("[App State] 포그라운드 진입")
        
        guard mixer != nil, rtmpStream != nil, rtmpConnection != nil else { return }
        
        Task {
            // RTMP 연결이 끊어진 경우 재연결
            let isConnected = await rtmpConnection.connected
            if !isConnected && lastStreamUrl != nil && lastStreamKey != nil {
                do {
                    let _ = try await rtmpConnection.connect(lastStreamUrl!)
                    try await rtmpStream.publish(lastStreamKey!)
                    print("✅ RTMP 재연결 완료")
                } catch {
                    print("❌ RTMP 재연결 오류: \(error)")
                }
            }
        }
        
        UIApplication.shared.isIdleTimerDisabled = true
    }

    @objc func appDidEnterBackground() {
        print("[App State] 백그라운드 진입")
        
        // HaishinKit 2.0.0에서는 자동으로 백그라운드 처리됨
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
                
                callback = dictionary["callBack"] as? String ?? ""
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
                case "ACT1027": // ✅ HaishinKit 2.0.0: 전/후면 카메라 제어
                    var resultcd = "1"
                    if let _ = actionParamObj?["key_type"] {
                        currentCameraPosition = (currentCameraPosition == .back) ? .front : .back
                        
                        Task {
                            do {
                                let camera = self.getCameraDevice(for: self.currentCameraPosition)
                                try await self.mixer.attachVideo(camera, track: 0)
                                
                                print("✅ 카메라 전환 완료: \(self.currentCameraPosition == .front ? "전면" : "후면")")
                                
                                // 해상도 적용
                                await self.applyVideoSettings(bitrate: self.lastAppliedBitrate)
                                
                                // 미러링 설정
                                try await self.mixer.configuration(video: 0) { unit in
                                    if self.currentCameraPosition == .front {
                                        unit.isVideoMirrored = true
                                        print("🔧 전면 카메라로 전환 - 미러링 활성화")
                                    } else {
                                        unit.isVideoMirrored = false
                                        print("🔧 후면 카메라로 전환 - 미러링 비활성화")
                                    }
                                }
                            } catch {
                                print("❌ 카메라 전환 오류: \(error)")
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
                case "ACT1029": // ✅ HaishinKit 2.2.3: VideoEffect 필터 기능 활성화
                    var resultcd = "1"
                    
                    if let filterType = actionParamObj?["key_type"] as? Int {
                        print("🎨 ACT1029 필터 요청: filterType = \(filterType)")
                        
                        DispatchQueue.main.async {
                            self.toggleCoreImageFilter(filterType: filterType)
                            
                            var dic = Dictionary<String, String>()
                            dic.updateValue(resultcd, forKey: "resultcd")
                            
                            do {
                                let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                                let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                                let javascript = "\(self.callback)('\(stringValue)')"
                                self.webView.evaluateJavaScript(javascript) { (result, error) in
                                    print("ACT1029 result : \(String(describing: result))")
                                    print("ACT1029 error : \(String(describing: error))")
                                }
                            } catch let error as NSError {
                                print("❌ ACT1029 JSON error: \(error)")
                            }
                        }
                    } else {
                        print("⚠️ ACT1029: key_type이 없습니다")
                        
                        var dic = Dictionary<String, String>()
                        dic.updateValue("0", forKey: "resultcd")
                        
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                            let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                            let javascript = "\(callback)('\(stringValue)')"
                            self.webView.evaluateJavaScript(javascript) { (result, error) in
                                // 결과 처리
                            }
                        } catch let error as NSError {
                            print("❌ ACT1029 JSON error: \(error)")
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
                                let javascript = "\(self.callback)('\(stringValue)')"
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
                case "ACT1035": // ✅ wlive 카메라 영상 송출 중지
                    var resultcd = "1"
                    Task {
                        do {
                            if self.rtmpStream != nil {
                                try await self.rtmpStream.close()
                            }
                            if self.rtmpConnection != nil {
                                try await self.rtmpConnection.close()
                            }
                            // 자동 재연결 방지
                            self.lastStreamUrl = nil
                            self.lastStreamKey = nil
                            print("✅ ACT1035: 송출 중지 완료")
                        } catch {
                            resultcd = "0"
                            print("❌ ACT1035 송출 중지 오류: \(error)")
                        }

                        if !self.callback.isEmpty {
                            var dic = Dictionary<String, String>()
                            dic.updateValue(resultcd, forKey: "resultcd")
                            do {
                                let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                                let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                                let javascript = "\(self.callback)('\(stringValue)')"
                                self.webView.evaluateJavaScript(javascript) { (result, error) in
                                    // 결과 처리
                                }
                            } catch let error as NSError {
                                print("ACT1035 JSON error: \(error)")
                            }
                        } else {
                            print("⚠️ ACT1035: callback 없음 (응답 생략)")
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
    
    // ✅ HaishinKit 2.2.3: VideoEffect를 사용한 필터 기능
    func toggleCoreImageFilter(filterType: Int) {
        guard hkView != nil, mixer != nil else {
            print("❌ MTHKView 또는 MediaMixer가 없습니다.")
            return
        }
        
        Task { @MainActor in
            // 현재 필터 제거 (프리뷰)
            if let currentEffect = currentVideoEffect {
                let removedPreview = hkView.unregisterVideoEffect(currentEffect)
                print("🎭 프리뷰 필터 제거됨: \(removedPreview)")
            }
            
            // 현재 필터 제거 (스트리밍)
            if let currentEffect = currentVideoEffect {
                Task { @ScreenActor in
                    let removedStream = mixer.screen.unregisterVideoEffect(currentEffect)
                    print("🎭 스트리밍 필터 제거됨: \(removedStream)")
                }
            }
            
            currentVideoEffect = nil
            isFilterEnabled = false
            
            // KSY_FILTER_BEAUTY_DISABLE (0) - 필터 비활성화
            if filterType == 0 {
                print("🎭 모든 필터 비활성화 완료")
                return
            }
            
            let filter: CIFilter?
            
            switch filterType {
            case 1:
                // 💄 뷰티 필터 (피부 부드럽게 + 밝기 조정)
                filter = CIFilter(name: "CIColorControls")
                filter?.setValue(0.15, forKey: kCIInputBrightnessKey) // 밝기 증가
                filter?.setValue(1.05, forKey: kCIInputContrastKey) // 대비 약간 증가
                filter?.setValue(0.95, forKey: kCIInputSaturationKey) // 채도 약간 감소 (자연스러운 피부톤)
                print("💄 뷰티 필터 적용 (피부 부드럽게 + 밝기 조정)")
                
            case 2:
                filter = CIFilter(name: "CIColorControls")
                filter?.setValue(0.2, forKey: kCIInputBrightnessKey)
                filter?.setValue(1.1, forKey: kCIInputContrastKey)
                print("🎭 피부 화이트닝 필터 적용")
                
            case 3:
                filter = CIFilter(name: "CIPhotoEffectInstant")
                print("🎭 일루전 뷰티 필터 적용")
                
            case 4:
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
            
            guard let validFilter = filter else {
                print("❌ 필터 생성 실패")
                return
            }
            
            let videoEffect = CoreImageVideoEffect(filter: validFilter)
            
            // HaishinKit 2.2.3: 프리뷰에 필터 적용 (MTHKView)
            let registeredPreview = hkView.registerVideoEffect(videoEffect)
            print("📱 프리뷰 필터 등록: \(registeredPreview)")
            
            // HaishinKit 2.2.3: 스트리밍에 필터 적용 (MediaMixer.screen)
            Task { @ScreenActor in
                let registeredStream = mixer.screen.registerVideoEffect(videoEffect)
                print("📡 스트리밍 필터 등록: \(registeredStream)")
            }
            
            if registeredPreview {
                currentVideoEffect = videoEffect
                isFilterEnabled = true
                print("✅ 필터 적용 완료: filterType \(filterType) (프리뷰 + 스트리밍)")
            } else {
                print("❌ 필터 등록 실패 (이미 등록되어 있음)")
            }
        }
    }


    
    
    // ✅ HaishinKit 2.0.0: async/await로 카메라 연결
    func attachCameraDevice() {
        Task {
            do {
                let cameraDevice = getCameraDevice(for: currentCameraPosition)
                try await mixer.attachVideo(cameraDevice, track: 0)
                
                print("✅ 카메라 연결 완료")
                
                // 카메라 연결 후 해상도 적용
                await applyVideoSettings(bitrate: lastAppliedBitrate)
                
                // 미러링 설정
                try await mixer.configuration(video: 0) { unit in
                    if self.currentCameraPosition == .front {
                        unit.isVideoMirrored = true
                        print("🔧 전면 카메라 미러링: 활성화")
                    } else {
                        unit.isVideoMirrored = false
                        print("🔧 후면 카메라 미러링: 비활성화")
                    }
                }
            } catch {
                print("❌ 카메라 연결 오류: \(error)")
            }
        }
    }
    
    func attachMicrophone() {
        Task {
            do {
                let audioDevice = AVCaptureDevice.default(for: .audio)
                try await mixer.attachAudio(audioDevice, track: 0)
                print("✅ 마이크 연결 완료")
            } catch {
                print("❌ 마이크 연결 오류: \(error)")
            }
        }
    }
    
    func detachMicrophone() {
        Task {
            do {
                try await mixer.attachAudio(nil, track: 0)
                print("✅ 마이크 연결 해제 완료")
            } catch {
                print("❌ 마이크 연결 해제 오류: \(error)")
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
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                if let imageUrl = info[UIImagePickerController.InfoKey.imageURL] as? URL {
                    let imageName = imageUrl.lastPathComponent
                    print(imageName) // "example.jpg"
                    var myDict = [String: Any]()
                    if let imageData = image.pngData() {
                        let base64String = imageData.base64EncodedString()
                        myDict["fData"] = base64String
                        myDict["fName"] = imageName
                    }
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: myDict, options: [])
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            let jsFunction = "\(callback)('\(jsonString)')" // JavaScript 함수와 Base64 문자열 인수를 포함하는 문자열 생성
                            // webView는 UIWebView 또는 WKWebView 객체입니다.
                            webView.evaluateJavaScript(jsFunction, completionHandler: { (result, error) in
                                if let error = error {
                                    print("Error: \(error.localizedDescription)")
                                } else {
                                    print("Result: \(result ?? "")")
                                }
                            })
                        }
                    } catch {
                        print("Error: \(error.localizedDescription)")
                    }
                }
            }
            picker.dismiss(animated: true, completion: nil)
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
        // ✅ HaishinKit 2.0.0: MediaMixer와 RTMPStream 초기화
        mixer = MediaMixer()
        rtmpConnection = RTMPConnection()
        rtmpStream = RTMPStream(connection: rtmpConnection)
        
        // ✅ HaishinKit 2.2.3: VideoEffect를 위해 offscreen 모드 설정 (필수!)
        var videoSettings = VideoMixerSettings()
        videoSettings.mode = .offscreen  // passthrough 대신 offscreen 사용
        mixer.setVideoMixerSettings(videoSettings)
        print("✅ VideoMixerSettings: offscreen 모드 설정 완료 (필터 적용 가능)")
        
        currentCameraPosition = .front
        
        // ✅ HaishinKit 2.0.0: MTHKView 생성 및 설정
        hkView = MTHKView(frame: view.bounds)
        hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        // ✅ HaishinKit 2.0.0: output 연결 (mixer → stream → view)
        mixer.addOutput(rtmpStream)
        rtmpStream.addOutput(hkView)
        
        // ✅ MediaMixer 시작 (카메라 캡처 시작을 위해 필수!)
        Task {
            await mixer.startRunning()
            print("✅ MediaMixer 시작됨")
        }
        
        // ✅ 뷰를 containerView 맨 뒤에 추가 (웹뷰가 위에 표시되도록)
        self.containerView.insertSubview(hkView, at: 0)
        
        print("✅ MediaMixer, RTMPStream, MTHKView 초기화 완료")
    }
    
    // ✅ HaishinKit 2.0.0: async/await로 스트리머 초기화
    func initStreamer(
        streamUrl: String,
        previewFps: Int,
        targetFps: Int,
        videoBitrateList: [Int]
    ) {
        Task {
            do {
                // 1. 스트림 URL 파싱
                let components = streamUrl.components(separatedBy: "/")
                guard components.count > 1, let streamKey = components.last else {
                    print("❌ 잘못된 스트림 URL: \(streamUrl)")
                    return
                }
                let convertStreamUrl = components.dropLast().joined(separator: "/")
                lastStreamUrl = convertStreamUrl
                lastStreamKey = streamKey
                
                // 2. 비트레이트 설정 (setVideoKBitrate는 kbps 단위이므로 bps로 변환 필요)
                let bitrate: Int
                if videoBitrateList.count >= 3 {
                    let selectedKbps = videoBitrateList[1]
                    bitrate = selectedKbps * 1000
                    print("📊 비트레이트 배열 [\(videoBitrateList[0]), \(videoBitrateList[1]), \(videoBitrateList[2])] kbps 중 중간값 \(selectedKbps) kbps 선택 → \(bitrate) bps")
                } else if !videoBitrateList.isEmpty {
                    let selectedKbps = videoBitrateList[0]
                    bitrate = selectedKbps * 1000
                    print("📊 비트레이트 단일값 \(selectedKbps) kbps → \(bitrate) bps")
                } else {
                    bitrate = 2_500_000
                    print("📊 비트레이트 기본값 2500 kbps → 2500000 bps")
                }
                
                print("🔧 최종 비트레이트 설정: \(bitrate) bps (\(Double(bitrate) / 1_000_000) Mbps)")
                
                // 3. 카메라 연결 (프레임 레이트는 카메라 연결 후 설정)
                let cameraDevice = getCameraDevice(for: currentCameraPosition)
                try await mixer.attachVideo(cameraDevice, track: 0)
                print("✅ 카메라 연결 완료")
                
                // 4. 프레임 레이트 설정
                try await mixer.configuration(video: 0) { unit in
                    unit.preferredVideoStabilizationMode = .off
                    // 프레임 레이트는 VideoCodecSettings에서 설정됨
                }
                
                // 5. 해상도 및 비트레이트 설정
                await applyVideoSettings(bitrate: bitrate)
                
                // 6. 오디오 연결
                let audioDevice = AVCaptureDevice.default(for: .audio)
                try await mixer.attachAudio(audioDevice, track: 0)
                print("✅ 오디오 연결 완료")
                
                // 7. 미러링 설정
                try await mixer.configuration(video: 0) { unit in
                    if self.currentCameraPosition == .front {
                        unit.isVideoMirrored = true
                        print("🔧 초기 전면 카메라 미러링: 활성화")
                    } else {
                        unit.isVideoMirrored = false
                        print("🔧 초기 후면 카메라 미러링: 비활성화")
                    }
                    unit.videoOrientation = .portrait
                }
                
                // 8. RTMP 연결 및 publish
                let _ = try await rtmpConnection.connect(convertStreamUrl)
                print("✅ RTMP 연결 완료: \(convertStreamUrl)")
                
                try await rtmpStream.publish(streamKey)
                print("✅ RTMP 스트리밍 시작: \(streamKey)")
                
            } catch RTMPConnection.Error.requestFailed(let response) {
                print("❌ RTMP 연결 실패: \(response)")
            } catch RTMPStream.Error.requestFailed(let response) {
                print("❌ RTMP 스트림 실패: \(response)")
            } catch {
                print("❌ 스트리머 초기화 오류: \(error)")
            }
        }
    }
    
    // ✅ HaishinKit 2.0.0: 카메라 좌우 반전 제어
    func toggleCameraMirror(keyType: String) {
        guard mixer != nil else {
            print("❌ MediaMixer가 없습니다.")
            return
        }
        
        // key_type이 "0"이면 미러링 비활성화, "1"이면 미러링 활성화
        let shouldMirror = keyType == "1"
        
        Task {
            do {
                try await mixer.configuration(video: 0) { unit in
                    unit.isVideoMirrored = shouldMirror
                    print("🔄 카메라 미러링 \(shouldMirror ? "활성화" : "비활성화") 완료")
                }
            } catch {
                print("❌ 미러링 설정 오류: \(error)")
            }
        }
    }
    
    // ✅ HaishinKit 2.0.0: async 함수로 변경
    func applyVideoSettings(bitrate: Int = 2_500_000) async {
        lastAppliedBitrate = bitrate
        
        // 카메라 디바이스 가져오기
        let cameraDevice = getCameraDevice(for: currentCameraPosition)
        
        // 카메라가 지원하는 최대 해상도 가져오기
        cameraVideoSize = getMaxSupportedVideoSize(for: cameraDevice)
        
        print("🔧 해상도 \(Int(cameraVideoSize.width))x\(Int(cameraVideoSize.height)) 적용 (카메라 사양 기준)")
        
        // 1. sessionPreset 설정 (카메라 해상도에 맞게)
        // 세로 방향이므로 높이를 기준으로 세션 프리셋 선택
        let preset: AVCaptureSession.Preset
        if cameraVideoSize.height >= 1920 {
            preset = .hd1920x1080
        } else if cameraVideoSize.height >= 1280 {
            preset = .hd1280x720
        } else {
            preset = .hd1280x720 // 기본값
        }
        
        await mixer.setSessionPreset(preset)
        
        // 2. 해상도 설정 (카메라 사양에 맞게)
        let videoSettings = VideoCodecSettings(
            videoSize: cameraVideoSize, // 카메라가 지원하는 최대 해상도
            bitRate: bitrate,
            profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel as String,
            scalingMode: .trim
        )
        
        do {
            try await rtmpStream.setVideoSettings(videoSettings)
            
            // HaishinKit 2.0.0에서는 mixer에서 orientation 설정
            try await mixer.configuration(video: 0) { unit in
                unit.videoOrientation = .portrait
            }
            
            print("✅ 해상도 설정 완료: \(Int(cameraVideoSize.width))x\(Int(cameraVideoSize.height))")
        } catch {
            print("❌ 비디오 설정 오류: \(error)")
        }
    }
}

// ✅ HaishinKit 2.2.3 VideoEffect 구현
final class CoreImageVideoEffect: VideoEffect {
    let filter: CIFilter
    
    init(filter: CIFilter) {
        self.filter = filter
    }
    
    func execute(_ image: CIImage) -> CIImage {
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






