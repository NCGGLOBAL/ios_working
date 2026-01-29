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
    
    // ✅ 카메라 해상도 (720p HD 화질)
    private var cameraVideoSize: CGSize = CGSize(width: 720, height: 1280) // offscreen 모드
    private var lastStreamUrl: String?
    private var lastStreamKey: String?
    private var lastAppliedBitrate: Int = 2_500_000
    
    // ✅ 필터 관련 프로퍼티 (HaishinKit 2.2.3에서 정상 작동 확인)
    private var isFilterEnabled: Bool = false
    private var currentVideoEffect: VideoEffect?
    private var filterTask: Task<Void, Never>? // 필터 적용 Task 관리
    private var sliderUpdateWorkItem: DispatchWorkItem?
    private var customFilterPanel: UIView?
    private var brightnessSlider: UISlider?
    private var saturationSlider: UISlider?
    private var contrastSlider: UISlider?
    private var blurSlider: UISlider?
    private var sharpenSlider: UISlider?
    private var noiseSlider: UISlider?
    private var sliderValueLabels: [ObjectIdentifier: UILabel] = [:]
    private var sliderStepValues: [ObjectIdentifier: Float] = [:]
    private var arrowButtonTargets: [ObjectIdentifier: UISlider] = [:]
    private var sliderProgressViews: [ObjectIdentifier: UIProgressView] = [:]
    private var customAdjustEffect: CustomAdjustVideoEffect?
    private var lastCustomOptions: CustomFilterOptions?
    private var isUpdatingFilterUI: Bool = false
    private var panelPanStartFrame: CGRect = .zero
    private var panelPanStartTransform: CGAffineTransform = .identity

    // ✅ 커스텀 필터 옵션 (ACT1029, key_type=99)
    fileprivate struct CustomFilterOptions: CustomStringConvertible, Equatable {
        let brightness: Double
        let saturation: Double
        let contrast: Double
        let blur: Double
        let sharpen: Double
        let noise: Double

        init?(dictionary: [String: Any]) {
            let normalized = dictionary.reduce(into: [String: Any]()) { result, item in
                result[item.key.lowercased()] = item.value
            }

            func value(_ key: String) -> Double? {
                return Self.parseDouble(normalized[key])
            }

            brightness = Self.clamp(value("brightness") ?? 0.0, min: -1.0, max: 1.0)
            saturation = Self.clamp(value("saturation") ?? 1.0, min: 0.0, max: 2.0)
            contrast = Self.clamp(value("contrast") ?? 1.0, min: 0.0, max: 4.0)
            blur = Self.clamp(value("blur") ?? 0.0, min: 0.0, max: 20.0)
            sharpen = Self.clamp(value("sharpen") ?? 0.0, min: 0.0, max: 2.0)
            noise = Self.clamp(value("noise") ?? 0.0, min: 0.0, max: 1.0)
        }

        private static func parseDouble(_ value: Any?) -> Double? {
            if let number = value as? NSNumber {
                return number.doubleValue
            }
            if let string = value as? String {
                return Double(string)
            }
            return nil
        }

        private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
            return Swift.max(min, Swift.min(max, value))
        }

        var description: String {
            return "brightness=\(brightness), saturation=\(saturation), contrast=\(contrast), blur=\(blur), sharpen=\(sharpen), noise=\(noise)"
        }

        func isNearlyEqual(to other: CustomFilterOptions, epsilon: Double = 0.0001) -> Bool {
            return abs(brightness - other.brightness) < epsilon &&
                abs(saturation - other.saturation) < epsilon &&
                abs(contrast - other.contrast) < epsilon &&
                abs(blur - other.blur) < epsilon &&
                abs(sharpen - other.sharpen) < epsilon &&
                abs(noise - other.noise) < epsilon
        }
    }
    
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

        setupCustomFilterUI()
        
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
                    
                    let filterType: Int?
                    if let keyTypeInt = actionParamObj?["key_type"] as? Int {
                        filterType = keyTypeInt
                    } else if let keyTypeString = actionParamObj?["key_type"] as? String,
                              let keyTypeInt = Int(keyTypeString) {
                        filterType = keyTypeInt
                    } else {
                        filterType = nil
                    }

                    if let filterType = filterType {
                        print("🎨 ACT1029 필터 요청: filterType = \(filterType)")
                        
                        DispatchQueue.main.async {
                            var customOptions: CustomFilterOptions?

                            var appliedFilterType = filterType

                            if filterType == 99 {
                                if let options = actionParamObj?["options"] as? [String: Any] {
                                    customOptions = CustomFilterOptions(dictionary: options)
                                } else {
                                    print("⚠️ ACT1029: options가 없습니다 (custom filter)")
                                }
                            }

                            self.toggleCoreImageFilter(filterType: appliedFilterType, options: customOptions)
                            
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
    
    // ✅ HaishinKit 2.2.3: VideoEffect를 사용한 필터 기능 (메모리 최적화)
    fileprivate func toggleCoreImageFilter(filterType: Int, options: CustomFilterOptions? = nil) {
        guard hkView != nil, mixer != nil else {
            print("❌ MTHKView 또는 MediaMixer가 없습니다.")
            return
        }
        
        // ✅ 이전 필터 적용 Task 취소 (중복 방지)
        filterTask?.cancel()
        
        filterTask = Task { @MainActor in
            // ✅ 1단계: 현재 필터 완전히 제거
            if let currentEffect = currentVideoEffect {
                let removedPreview = hkView.unregisterVideoEffect(currentEffect)
                print("🎭 프리뷰 필터 제거됨: \(removedPreview)")
                
                Task { @ScreenActor in
                    let removedStream = mixer.screen.unregisterVideoEffect(currentEffect)
                    print("🎭 스트리밍 필터 제거됨: \(removedStream)")
                }
                
                // ✅ 메모리 정리 대기 (CMBufferQueue 안정화)
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            
            currentVideoEffect = nil
            isFilterEnabled = false
            
            // ✅ 2단계: 필터 0번이면 여기서 종료 (비활성화)
            if filterType == 0 {
                print("🎭 모든 필터 비활성화 완료")
                if let defaults = defaultCustomOptions() {
                    updateCustomFilterUI(with: defaults)
                }
                return
            }
            
            // ✅ 3단계: Task 취소 확인
            if Task.isCancelled {
                print("⚠️ 필터 적용 취소됨")
                return
            }
            
            var filter: CIFilter?
            var videoEffect: VideoEffect?
            var presetOptions: CustomFilterOptions?
            
            switch filterType {
            case 1:
                // KSY_FILTER_BEAUTY_SOFT - 부드러운 뷰티 (뽀샤시)
                filter = CIFilter(name: "CIGaussianBlur")
                filter?.setValue(1.5, forKey: kCIInputRadiusKey)
                print("🎭 [1] BEAUTY_SOFT - 부드러운 뷰티 (뽀샤시)")
                presetOptions = CustomFilterOptions(dictionary: ["blur": 1.5])
                
            case 2:
                // KSY_FILTER_BEAUTY_SKINWHITEN - 피부 화이트닝 (밝고 맑게)
                filter = CIFilter(name: "CIColorControls")
                filter?.setValue(0.3, forKey: kCIInputBrightnessKey)
                filter?.setValue(1.15, forKey: kCIInputContrastKey)
                filter?.setValue(1.05, forKey: kCIInputSaturationKey)
                print("🎭 [2] BEAUTY_SKINWHITEN - 피부 화이트닝")
                presetOptions = CustomFilterOptions(dictionary: [
                    "brightness": 0.3,
                    "contrast": 1.15,
                    "saturation": 1.05
                ])
                
            case 3:
                // KSY_FILTER_BEAUTY_ILLUSION - 일루전 뷰티 (분위기)
                filter = CIFilter(name: "CIPhotoEffectInstant")
                print("🎭 [3] BEAUTY_ILLUSION - 일루전 뷰티")
                presetOptions = defaultCustomOptions()
                
            case 4:
                // KSY_FILTER_BEAUTY_DENOISE - 노이즈 제거 (깨끗하게)
                filter = CIFilter(name: "CINoiseReduction")
                filter?.setValue(0.03, forKey: "inputNoiseLevel")
                filter?.setValue(0.5, forKey: "inputSharpness")
                print("🎭 [4] BEAUTY_DENOISE - 노이즈 제거")
                presetOptions = CustomFilterOptions(dictionary: [
                    "noise": 0.03,
                    "sharpen": 0.5
                ])
                
            case 5:
                // KSY_FILTER_BEAUTY_SMOOTH - 매끄러운 (뽀얗게)
                filter = CIFilter(name: "CIGaussianBlur")
                filter?.setValue(2.0, forKey: kCIInputRadiusKey)
                print("🎭 [5] BEAUTY_SMOOTH - 매끄러운 필터")
                presetOptions = CustomFilterOptions(dictionary: ["blur": 2.0])
                
            case 6:
                // KSY_FILTER_BEAUTY_SOFT_EXT - 확장 부드러움 (극강 뽀샤시)
                filter = CIFilter(name: "CIGaussianBlur")
                filter?.setValue(3.0, forKey: kCIInputRadiusKey)
                print("🎭 [6] BEAUTY_SOFT_EXT - 확장 부드러움")
                presetOptions = CustomFilterOptions(dictionary: ["blur": 3.0])
                
            case 7:
                // KSY_FILTER_BEAUTY_SOFT_SHARPEN - 부드럽게 선명한 (균형)
                filter = CIFilter(name: "CISharpenLuminance")
                filter?.setValue(0.5, forKey: kCIInputSharpnessKey)
                print("🎭 [7] BEAUTY_SOFT_SHARPEN - 부드럽게 선명한")
                presetOptions = CustomFilterOptions(dictionary: ["sharpen": 0.5])
                
            case 8:
                // KSY_FILTER_BEAUTY_PRO - 뷰티 프로 (자연스러운 뷰티)
                filter = CIFilter(name: "CIColorControls")
                filter?.setValue(0.25, forKey: kCIInputBrightnessKey)
                filter?.setValue(1.1, forKey: kCIInputContrastKey)
                filter?.setValue(1.1, forKey: kCIInputSaturationKey)
                print("🎭 [8] BEAUTY_PRO - 뷰티 프로")
                presetOptions = CustomFilterOptions(dictionary: [
                    "brightness": 0.25,
                    "contrast": 1.1,
                    "saturation": 1.1
                ])
                
            case 9:
                // KSY_FILTER_BEAUTY_PRO1 - 뷰티 프로1 (화사하게)
                filter = CIFilter(name: "CIColorControls")
                filter?.setValue(0.35, forKey: kCIInputBrightnessKey)
                filter?.setValue(1.15, forKey: kCIInputContrastKey)
                filter?.setValue(1.15, forKey: kCIInputSaturationKey)
                print("🎭 [9] BEAUTY_PRO1 - 뷰티 프로1 (화사)")
                presetOptions = CustomFilterOptions(dictionary: [
                    "brightness": 0.35,
                    "contrast": 1.15,
                    "saturation": 1.15
                ])
                
            case 10:
                // KSY_FILTER_BEAUTY_PRO2 - 뷰티 프로2 (뽀얗게)
                filter = CIFilter(name: "CIGaussianBlur")
                filter?.setValue(2.5, forKey: kCIInputRadiusKey)
                print("🎭 [10] BEAUTY_PRO2 - 뷰티 프로2 (뽀얗게)")
                presetOptions = CustomFilterOptions(dictionary: ["blur": 2.5])
                
            case 11:
                // KSY_FILTER_BEAUTY_PRO3 - 뷰티 프로3 (맑고 선명하게)
                filter = CIFilter(name: "CISharpenLuminance")
                filter?.setValue(0.7, forKey: kCIInputSharpnessKey)
                print("🎭 [11] BEAUTY_PRO3 - 뷰티 프로3 (선명)")
                presetOptions = CustomFilterOptions(dictionary: ["sharpen": 0.7])
                
            case 12:
                // KSY_FILTER_BEAUTY_PRO4 - 뷰티 프로4 (종합 최강 뷰티)
                filter = CIFilter(name: "CIColorControls")
                filter?.setValue(0.3, forKey: kCIInputBrightnessKey)
                filter?.setValue(1.25, forKey: kCIInputContrastKey)
                filter?.setValue(1.2, forKey: kCIInputSaturationKey)
                print("🎭 [12] BEAUTY_PRO4 - 뷰티 프로4 (최강)")
                presetOptions = CustomFilterOptions(dictionary: [
                    "brightness": 0.3,
                    "contrast": 1.25,
                    "saturation": 1.2
                ])

            case 99:
                // ✅ 커스텀 필터 (options 기반)
                guard let options = options else {
                    print("⚠️ 커스텀 필터 옵션이 없습니다.")
                    return
                }
                if let existing = customAdjustEffect {
                    existing.updateOptions(options)
                    videoEffect = existing
                } else {
                    let effect = CustomAdjustVideoEffect(options: options)
                    customAdjustEffect = effect
                    videoEffect = effect
                }
                print("🎛️ [99] CUSTOM_FILTER 적용: \(options)")
                
            default:
                print("❌ 지원하지 않는 filterType: \(filterType)")
                return
            }

            if let appliedOptions = options ?? presetOptions {
                updateCustomFilterUI(with: appliedOptions)
            }

            if videoEffect == nil {
                guard let validFilter = filter else {
                    print("❌ 필터 생성 실패")
                    return
                }
                videoEffect = CoreImageVideoEffect(filter: validFilter)
            }
            
            // ✅ 4단계: Task 취소 확인
            if Task.isCancelled {
                print("⚠️ 필터 적용 취소됨")
                return
            }
            guard let finalEffect = videoEffect else {
                print("❌ 필터 적용 실패 (VideoEffect 없음)")
                return
            }
            
            // ✅ 5단계: 프리뷰에 필터 적용 (메모리 안정화 후)
            let registeredPreview = hkView.registerVideoEffect(finalEffect)
            print("📱 프리뷰 필터 등록: \(registeredPreview)")
            
            // ✅ 6단계: 스트리밍에 필터 적용 (약간의 딜레이로 메모리 분산)
            Task { @ScreenActor in
                try? await Task.sleep(nanoseconds: 30_000_000) // 30ms 대기
                let registeredStream = mixer.screen.registerVideoEffect(finalEffect)
                print("📡 스트리밍 필터 등록: \(registeredStream)")
            }
            
            if registeredPreview {
                currentVideoEffect = finalEffect
                isFilterEnabled = true
                print("✅ 필터 적용 완료: filterType \(filterType) (메모리 최적화)")
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
    
    // ✅ 카메라가 지원하는 최대 해상도 가져오기 (720p HD)
    func getMaxSupportedVideoSize(for cameraDevice: AVCaptureDevice?) -> CGSize {
        guard let device = cameraDevice else {
            // 기본값 반환 (720p HD)
            return CGSize(width: 720, height: 1280)
        }
        
        // ✅ 720p HD 화질
        let maxSize = CGSize(width: 720, height: 1280)
        
        print("📷 카메라 해상도 (720p HD): \(Int(maxSize.width))x\(Int(maxSize.height))")
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
        
        // ✅ HaishinKit 2.2.3: offscreen 모드로 스트리밍에도 필터 전송
        var videoSettings = VideoMixerSettings()
        videoSettings.mode = .offscreen  // 스트리밍 필터 전송을 위해 필수
        mixer.setVideoMixerSettings(videoSettings)
        print("✅ VideoMixerSettings: offscreen 모드 (720p HD)")
        
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

    // ✅ 커스텀 필터 UI (프리뷰 위 슬라이더)
    private func setupCustomFilterUI() {
        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        panel.layer.cornerRadius = 10
        panel.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let (brightnessRow, brightness) = makeSliderRow(
            title: "Brightness",
            min: -1.0,
            max: 1.0,
            value: 0.0
        )
        let (saturationRow, saturation) = makeSliderRow(
            title: "Saturation",
            min: 0.0,
            max: 2.0,
            value: 1.0
        )
        let (contrastRow, contrast) = makeSliderRow(
            title: "Contrast",
            min: 0.0,
            max: 4.0,
            value: 1.0
        )
        let (blurRow, blur) = makeSliderRow(
            title: "Blur",
            min: 0.0,
            max: 20.0,
            value: 0.0
        )
        let (sharpenRow, sharpen) = makeSliderRow(
            title: "Sharpen",
            min: 0.0,
            max: 2.0,
            value: 0.0
        )
        let (noiseRow, noise) = makeSliderRow(
            title: "Noise",
            min: 0.0,
            max: 1.0,
            value: 0.0
        )

        [brightnessRow, saturationRow, contrastRow, blurRow, sharpenRow, noiseRow].forEach {
            stack.addArrangedSubview($0)
        }

        panel.addSubview(stack)
        view.addSubview(panel)

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            panel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            panel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),

            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12)
        ])

        brightnessSlider = brightness
        saturationSlider = saturation
        contrastSlider = contrast
        blurSlider = blur
        sharpenSlider = sharpen
        noiseSlider = noise
        customFilterPanel = panel

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(onCustomFilterPanelPanned(_:)))
        panel.addGestureRecognizer(panGesture)
    }

    private func makeSliderRow(title: String, min: Float, max: Float, value: Float) -> (UIStackView, UISlider) {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let rangeLabel = UILabel()
        rangeLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        rangeLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        rangeLabel.textAlignment = .center
        rangeLabel.widthAnchor.constraint(equalToConstant: 90).isActive = true
        rangeLabel.text = String(format: "%.2f~%.2f", min, max)

        let slider = UISlider()
        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = value
        slider.isHidden = true

        let valueLabel = UILabel()
        valueLabel.textColor = .white
        valueLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        valueLabel.textAlignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
        valueLabel.text = String(format: "%.2f", value)

        let progress = UIProgressView(progressViewStyle: .default)
        progress.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        progress.progressTintColor = UIColor.systemGreen
        progress.widthAnchor.constraint(equalToConstant: 70).isActive = true
        progress.progress = normalizedProgress(value: value, min: min, max: max)

        let minusButton = UIButton(type: .system)
        minusButton.setTitle("◀", for: .normal)
        minusButton.tintColor = .white
        minusButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        minusButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        minusButton.layer.cornerRadius = 4
        minusButton.clipsToBounds = true
        minusButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        minusButton.heightAnchor.constraint(equalToConstant: 22).isActive = true
        minusButton.tag = -1
        minusButton.addTarget(self, action: #selector(onArrowButtonTapped(_:)), for: .touchUpInside)

        let plusButton = UIButton(type: .system)
        plusButton.setTitle("▶", for: .normal)
        plusButton.tintColor = .white
        plusButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        plusButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        plusButton.layer.cornerRadius = 4
        plusButton.clipsToBounds = true
        plusButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        plusButton.heightAnchor.constraint(equalToConstant: 22).isActive = true
        plusButton.tag = 1
        plusButton.addTarget(self, action: #selector(onArrowButtonTapped(_:)), for: .touchUpInside)

        sliderValueLabels[ObjectIdentifier(slider)] = valueLabel
        sliderProgressViews[ObjectIdentifier(slider)] = progress
        arrowButtonTargets[ObjectIdentifier(minusButton)] = slider
        arrowButtonTargets[ObjectIdentifier(plusButton)] = slider

        let row = UIStackView(arrangedSubviews: [titleLabel, rangeLabel, progress, minusButton, valueLabel, plusButton])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return (row, slider)
    }

    @objc private func onCustomSliderChanged(_ sender: UISlider) {
        let step = stepForSlider(sender)
        let snappedValue = snapValue(sender.value, step: step)
        if sender.value != snappedValue {
            sender.value = snappedValue
        }
        if let label = sliderValueLabels[ObjectIdentifier(sender)] {
            label.text = String(format: "%.2f", sender.value)
        }
        if let progress = sliderProgressViews[ObjectIdentifier(sender)] {
            progress.progress = normalizedProgress(value: sender.value, min: sender.minimumValue, max: sender.maximumValue)
        }
        scheduleCustomFilterUpdate()
    }

    @objc private func onArrowButtonTapped(_ sender: UIButton) {
        guard let slider = arrowButtonTargets[ObjectIdentifier(sender)] else {
            return
        }
        let step = stepForSlider(slider)
        let delta = step * Float(sender.tag)
        let newValue = snapValue(slider.value + delta, step: step)
        slider.value = min(slider.maximumValue, max(slider.minimumValue, newValue))

        if let label = sliderValueLabels[ObjectIdentifier(slider)] {
            label.text = String(format: "%.2f", slider.value)
        }
        if let progress = sliderProgressViews[ObjectIdentifier(slider)] {
            progress.progress = normalizedProgress(value: slider.value, min: slider.minimumValue, max: slider.maximumValue)
        }
        scheduleCustomFilterUpdate()
    }

    private func stepForSlider(_ slider: UISlider) -> Float {
        switch slider {
        case brightnessSlider:
            return 0.05
        case saturationSlider:
            return 0.05
        case contrastSlider:
            return 0.1
        case blurSlider:
            return 0.5
        case sharpenSlider:
            return 0.05
        case noiseSlider:
            return 0.01
        default:
            return 0.05
        }
    }

    private func snapValue(_ value: Float, step: Float) -> Float {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    private func normalizedProgress(value: Float, min: Float, max: Float) -> Float {
        guard max > min else { return 0 }
        return (value - min) / (max - min)
    }

    private func defaultCustomOptions() -> CustomFilterOptions? {
        return CustomFilterOptions(dictionary: [
            "brightness": 0.0,
            "saturation": 1.0,
            "contrast": 1.0,
            "blur": 0.0,
            "sharpen": 0.0,
            "noise": 0.0
        ])
    }

    private func updateCustomFilterUI(with options: CustomFilterOptions) {
        isUpdatingFilterUI = true
        defer { isUpdatingFilterUI = false }

        if let slider = brightnessSlider {
            slider.value = Float(options.brightness)
            sliderValueLabels[ObjectIdentifier(slider)]?.text = String(format: "%.2f", slider.value)
            sliderProgressViews[ObjectIdentifier(slider)]?.progress = normalizedProgress(
                value: slider.value,
                min: slider.minimumValue,
                max: slider.maximumValue
            )
        }
        if let slider = saturationSlider {
            slider.value = Float(options.saturation)
            sliderValueLabels[ObjectIdentifier(slider)]?.text = String(format: "%.2f", slider.value)
            sliderProgressViews[ObjectIdentifier(slider)]?.progress = normalizedProgress(
                value: slider.value,
                min: slider.minimumValue,
                max: slider.maximumValue
            )
        }
        if let slider = contrastSlider {
            slider.value = Float(options.contrast)
            sliderValueLabels[ObjectIdentifier(slider)]?.text = String(format: "%.2f", slider.value)
            sliderProgressViews[ObjectIdentifier(slider)]?.progress = normalizedProgress(
                value: slider.value,
                min: slider.minimumValue,
                max: slider.maximumValue
            )
        }
        if let slider = blurSlider {
            slider.value = Float(options.blur)
            sliderValueLabels[ObjectIdentifier(slider)]?.text = String(format: "%.2f", slider.value)
            sliderProgressViews[ObjectIdentifier(slider)]?.progress = normalizedProgress(
                value: slider.value,
                min: slider.minimumValue,
                max: slider.maximumValue
            )
        }
        if let slider = sharpenSlider {
            slider.value = Float(options.sharpen)
            sliderValueLabels[ObjectIdentifier(slider)]?.text = String(format: "%.2f", slider.value)
            sliderProgressViews[ObjectIdentifier(slider)]?.progress = normalizedProgress(
                value: slider.value,
                min: slider.minimumValue,
                max: slider.maximumValue
            )
        }
        if let slider = noiseSlider {
            slider.value = Float(options.noise)
            sliderValueLabels[ObjectIdentifier(slider)]?.text = String(format: "%.2f", slider.value)
            sliderProgressViews[ObjectIdentifier(slider)]?.progress = normalizedProgress(
                value: slider.value,
                min: slider.minimumValue,
                max: slider.maximumValue
            )
        }
    }

    @objc private func onCustomFilterPanelPanned(_ gesture: UIPanGestureRecognizer) {
        guard let panel = customFilterPanel else { return }
        let translation = gesture.translation(in: view)

        if gesture.state == .began {
            panelPanStartFrame = panel.frame
            panelPanStartTransform = panel.transform
        }

        let safeFrame = view.safeAreaLayoutGuide.layoutFrame.insetBy(dx: 8, dy: 8)
        var newFrame = panelPanStartFrame.offsetBy(dx: translation.x, dy: translation.y)
        var dx = translation.x
        var dy = translation.y

        if newFrame.minX < safeFrame.minX {
            dx += safeFrame.minX - newFrame.minX
        }
        if newFrame.maxX > safeFrame.maxX {
            dx -= newFrame.maxX - safeFrame.maxX
        }
        if newFrame.minY < safeFrame.minY {
            dy += safeFrame.minY - newFrame.minY
        }
        if newFrame.maxY > safeFrame.maxY {
            dy -= newFrame.maxY - safeFrame.maxY
        }

        newFrame = panelPanStartFrame.offsetBy(dx: dx, dy: dy)
        panel.transform = panelPanStartTransform.translatedBy(x: dx, y: dy)
    }

    private func scheduleCustomFilterUpdate() {
        sliderUpdateWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.applyCustomFilterFromSliders()
        }
        sliderUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func applyCustomFilterFromSliders() {
        if isUpdatingFilterUI {
            return
        }
        guard
            let brightness = brightnessSlider?.value,
            let saturation = saturationSlider?.value,
            let contrast = contrastSlider?.value,
            let blur = blurSlider?.value,
            let sharpen = sharpenSlider?.value,
            let noise = noiseSlider?.value
        else {
            return
        }

        let optionsDict: [String: Any] = [
            "brightness": brightness,
            "saturation": saturation,
            "contrast": contrast,
            "blur": blur,
            "sharpen": sharpen,
            "noise": noise
        ]

        guard let options = CustomFilterOptions(dictionary: optionsDict) else {
            print("⚠️ 커스텀 필터 옵션 파싱 실패")
            return
        }

        if let last = lastCustomOptions, last.isNearlyEqual(to: options) {
            return
        }
        lastCustomOptions = options

        if let current = customAdjustEffect, currentVideoEffect === current {
            current.updateOptions(options)
            return
        }

        let effect = CustomAdjustVideoEffect(options: options)
        customAdjustEffect = effect
        toggleCoreImageFilter(filterType: 99, options: options)
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
        
        // 1. sessionPreset 설정 (720p HD)
        await mixer.setSessionPreset(.hd1280x720)
        
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

// ✅ 커스텀 파라미터 기반 VideoEffect (ACT1029: key_type=99)
final class CustomAdjustVideoEffect: VideoEffect {
    private var options: LiveViewController.CustomFilterOptions

    fileprivate init(options: LiveViewController.CustomFilterOptions) {
        self.options = options
    }

    fileprivate func updateOptions(_ options: LiveViewController.CustomFilterOptions) {
        self.options = options
    }

    func execute(_ image: CIImage) -> CIImage {
        var currentImage = image

        // 1) Blur
        if options.blur > 0 {
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(currentImage, forKey: kCIInputImageKey)
                blurFilter.setValue(options.blur, forKey: kCIInputRadiusKey)
                if let output = blurFilter.outputImage {
                    currentImage = output
                }
            }
        }

        // 2) Noise reduction
        if options.noise > 0 {
            if let noiseFilter = CIFilter(name: "CINoiseReduction") {
                noiseFilter.setValue(currentImage, forKey: kCIInputImageKey)
                noiseFilter.setValue(options.noise, forKey: "inputNoiseLevel")
                noiseFilter.setValue(options.sharpen, forKey: "inputSharpness")
                if let output = noiseFilter.outputImage {
                    currentImage = output
                }
            }
        }

        // 3) Color controls (brightness/contrast/saturation)
        if let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(currentImage, forKey: kCIInputImageKey)
            colorFilter.setValue(options.brightness, forKey: kCIInputBrightnessKey)
            colorFilter.setValue(options.contrast, forKey: kCIInputContrastKey)
            colorFilter.setValue(options.saturation, forKey: kCIInputSaturationKey)
            if let output = colorFilter.outputImage {
                currentImage = output
            }
        }

        // 4) Sharpen
        if options.sharpen > 0 {
            if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
                sharpenFilter.setValue(currentImage, forKey: kCIInputImageKey)
                sharpenFilter.setValue(options.sharpen, forKey: kCIInputSharpnessKey)
                if let output = sharpenFilter.outputImage {
                    currentImage = output
                }
            }
        }

        return currentImage
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


