//
//  SubWebViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/05/29.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import WebKit
import Alamofire

class SubWebViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {

    var webView: WKWebView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    var urlString = ""
    var uniqueProcessPool = WKProcessPool()
    var cookies = HTTPCookieStorage.shared.cookies ?? []
    let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 webview-type=sub"
    private struct Constants {
        static let callBackHandlerKey = "ios"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let contentController = WKUserContentController()
        let config = WKWebViewConfiguration()
        let preferences = WKPreferences()
        preferences.setValue(true, forKey:"developerExtrasEnabled")
        preferences.javaScriptEnabled = true

        contentController.add(self, name: Constants.callBackHandlerKey)
        
        config.userContentController = contentController
        config.preferences = preferences
        config.processPool = uniqueProcessPool
        for (cookie) in cookies {
            config.websiteDataStore.httpCookieStore.setCookie(cookie, completionHandler: nil)
        }
        
        webView = WKWebView(frame: self.view.frame, configuration: config)
        webView.frame.size.height = self.view.frame.size.height - UIApplication.shared.statusBarFrame.size.height
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.customUserAgent = userAgent
        
        // self.view = self.webView!
        self.containerView.addSubview(webView)
        
        self.initWebView()
        if AppDelegate.QR_URL != "" {
            AppDelegate.QR_URL = ""
        }
        // Do any additional setup after loading the view.
//        navigationController?.isNavigationBarHidden = false
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

        defer {
            decisionHandler(action ?? .allow)
        }

        guard let url = navigationAction.request.url else { return }

        let urlString = url.absoluteString
    #if DEBUG
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
//                print(dictionary)
                let actionCode = dictionary["action_code"] as? String
                print("actionCode : \(actionCode)")
                // param
                let actionParamArray = dictionary["action_param"] as? Array<Any>
                print("actionParamArray : \(actionParamArray)")
                let actionParamObj = actionParamArray?[0] as? Dictionary<String, AnyObject>
                print("actionParamObj : \(actionParamObj)")
                // callback
                let callback = dictionary["callBack"] as? String
                print("callBack : \(callback)")
                switch actionCode {
                    case "ACT1001": // 네이버 페이
                        
                    break
                    case "ACT1011": // 카메라 및 사진 라이브라러 호출
                        AppDelegate.imageModel.token = actionParamObj?["token"] as? String
                        AppDelegate.imageModel.pageGbn = actionParamObj?["pageGbn"] as? String // 1 : 신규페이지에서 진입, 2 : 수정페이지에서 진입
                        AppDelegate.imageModel.cnt = actionParamObj?["cnt"] as? Int
                        for key in actionParamObj!.keys {
                            print("key : \(key)")
                        }

                        let values = Array(arrayLiteral: actionParamObj?["imgArr"])

                        for fchild in values {
//                            for child in snapshot.children {
                                // firebase db를 jounal 형식으로 변환
//                                let fchild = child as! DataSnapshot
                            let data = ImageData()
                            data.fileName = fchild?["fileName"] as? String
                            data.imgUrl = fchild?["imgUrl"] as? String
                            data.sort = fchild?["sort"] as? String
                            data.utype = fchild?["utype"] as? Int

                            AppDelegate.imageModel.imgArr?.append(data)
                        }
                        print("AppDelegate.imageModel.imgArr : \(AppDelegate.imageModel.imgArr)")
//                        performSegue(withIdentifier: "imageSelectSegue", sender: nil)
                        let vc = self.storyboard!.instantiateViewController(withIdentifier: "imageSelectViewController") as! ImageSelectViewController
                        self.navigationController?.pushViewController(vc, animated: true)
                        break
                    break
                    case "ACT1012": // 사진 임시저장 통신
                        let token = actionParamObj?["token"] as? String
                        if token == nil {
                            return
                        }
                        let header: HTTPHeaders = [
                                    "Authorization": token!
                                ]
//                        [SysUtils showWaitingSplash];
                        let uploadUrl = AppDelegate.HOME_URL + "/m/app/"
                        let boundary = "WebKitFormBoundaryDCqbvCHcQvEfbSAa"

                        Alamofire.upload(
                            multipartFormData: { MultipartFormData in
                                if AppDelegate.imageArray.count == 0 {
                                    return
                                }
                                for item in AppDelegate.ImageFileArray {
                                    // 3. 이미지 데이터 원격저장소에 업로드 요청, resizing

                                    MultipartFormData.append(item.image!, withName: boundary, fileName: item.fileName!, mimeType: "image/jpeg")
                                }
                                }, to: uploadUrl, method: .post, headers: header) { (result) in

                                    switch result {
                                    case .success(let upload, _, _):

                                        upload.responseJSON { response in
                                           // getting success
                                            if (response.response?.statusCode)! >= 200 {
                                                print("succes : \(response.response)")
                                            }
                                        }

                                    case .failure(let encodingError): break
                                        // getting error
                                        print("encodingError : \(encodingError.localizedDescription)")
                                    }
                                }
                    break
                    case "ACT1015":
                        print("ACT1015 - 웹뷰 새창")
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
                    case "ACT1016":
                        print("ACT1016 - 새 브라우저 창을 닫는 액션")
                        self.navigationController?.popViewController(animated: true)
                    break
                    case "ACT1022":
                        print("ACT1022 - 전화걸기")
                        let token = actionParamObj?["tel"] as? String
                        if token == nil || token == "" {
                            return
                        }
                        let phoneCallURL = URL.init(string: token!)
                        let application:UIApplication = UIApplication.shared
                        
                        if (application.canOpenURL(phoneCallURL!)) {
                            application.open(phoneCallURL!, options: [:], completionHandler: nil)
                        }
                    break
                    case "ACT1023":
                        print("ACT1023 - 스타일뷰에 사용 byappsapi://bridge?shopidx=1111&mbridx=2222")
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
}
