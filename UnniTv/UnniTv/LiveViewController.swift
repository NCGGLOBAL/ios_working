//
//  LiveViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/10/15.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import WebKit
import libksygpulive

class LiveViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {

    var webView: WKWebView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    let urlString = AppDelegate.HOME_URL + "/addon/wlive/TV_live_creator.asp"
    var uniqueProcessPool = WKProcessPool()
    var cookies = HTTPCookieStorage.shared.cookies ?? []
    let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 webview-type=sub"
    private struct Constants {
        static let callBackHandlerKey = "ios"
    }
    
    var kit: KSYGPUStreamerKit? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
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
        webView.frame.size.height = self.view.frame.size.height - UIApplication.shared.statusBarFrame.size.height
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.customUserAgent = userAgent
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        // self.view = self.webView!
        self.containerView.addSubview(webView)
        
        self.initWebView()
        if AppDelegate.QR_URL != "" {
            AppDelegate.QR_URL = ""
        }
        // Do any additional setup after loading the view.
//        navigationController?.isNavigationBarHidden = false
        initCamera()
        
        webView.allowsBackForwardNavigationGestures = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
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
                            kit?.switchCamera()
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
                                kit?.streamerBase.muteStream(true)
                            } else  {
                                kit?.streamerBase.muteStream(false)
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
                        var resultcd = "1"
                        if let val = actionParamObj?["key_type"] as? Int {
                            switch val {
                            case 0:
                                kit?.setupFilter(nil)
                                break
                            case 1:
                                let bf = KSYBeautifyFaceFilter()
                                kit?.setupFilter(bf)
                                break
//                            case 2:
//                                let bf = KSYBeautifyProFilter()
//                                kit?.setupFilter(bf)
//                                break
                            default:
                                kit?.setupFilter(nil)
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
                    case "ACT1030": // wlive 스트림키 전달 및 송출
                        var resultcd = "1"
                        if let streamUrl = actionParamObj?["stream_url"] as? String {
                            self.initStreamer(streamUrl: streamUrl)
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
                        self.navigationController?.popViewController(animated: true)
                    break
                    default:
                        print("디폴트를 꼭 해줘야 합니다.")
                }
            }
        }
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
        kit = KSYGPUStreamerKit.init(defaultCfg: ())

        kit?.cameraPosition = .front
        kit?.gpuOutputPixelFormat = kCVPixelFormatType_32BGRA
        kit?.capturePixelFormat = kCVPixelFormatType_32BGRA

        kit?.previewDimension =  self.view.frame.size//self.view.frame.size

        kit?.streamDimension = self.view.frame.size

        kit?.videoOrientation = .portrait
        kit?.previewOrientation = .portrait
        kit?.startPreview(self.view)
    }

    func initStreamer(streamUrl: String) {
        kit?.streamerBase.videoCodec = KSYVideoCodec.AUTO
        kit?.streamerBase.videoInitBitrate = Int32(1500)
        kit?.streamerBase.videoMaxBitrate = Int32(2500)
        kit?.streamerBase.videoMinBitrate = Int32(1000)
        kit?.streamerBase.audiokBPS = Int32(48)
        kit?.streamerBase.shouldEnableKSYStatModule = true
        kit?.streamerBase.videoFPS = Int32(15)
        kit?.streamerBase.maxKeyInterval = Float(3)
        kit?.videoOrientation = .portrait
        kit?.previewOrientation = .portrait
        kit?.streamDimension = CGSize(width: 720, height: 1280)

        kit?.streamerBase.videoCodec = KSYVideoCodec.AUTO
        kit?.streamerBase.videoInitBitrate = 1500
        kit?.streamerBase.videoMaxBitrate = 2500
        kit?.streamerBase.videoMinBitrate = 1000
        kit?.streamerBase.audiokBPS = 48
        kit?.streamerBase.shouldEnableKSYStatModule = true
        kit?.streamerBase.videoFPS = 15
        kit?.streamerBase.maxKeyInterval = 3

        kit?.videoProcessingCallback = { (buf) -> Void in

        }

        kit?.streamerBase.logBlock = { (str) -> Void in
            //            print(str ?? "")
        }

        let url = URL(string: streamUrl)
        kit?.streamerBase.startStream(url)
    }

}
