//
//  SubWebViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/05/29.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import WebKit

class SubWebViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var webView: WKWebView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    @IBOutlet weak var backButton: UIButton!
    
    var urlString = ""
    var uniqueProcessPool = WKProcessPool()
    var cookies = HTTPCookieStorage.shared.cookies ?? []
    let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1 webview-type=sub"
    private struct Constants {
        static let callBackHandlerKey = "ios"
    }
    var callback = ""
    
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
        
        // self.view = self.webView!
        self.containerView.addSubview(webView)
        
        self.initWebView()
        if AppDelegate.QR_URL != "" {
            AppDelegate.QR_URL = ""
        }
        // Do any additional setup after loading the view.
//        navigationController?.isNavigationBarHidden = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if AppDelegate.isChangeImage {
            self.sendImageData()
            AppDelegate.isChangeImage = false
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
        
        let urlScheme = url.scheme
        let urlString = url.absoluteString
        let decodeString = urlString
        #if DEBUG
            print("url : \(url)")
            print("url absoluteString: \(url.absoluteString)")
            print("url scheme: \(url.scheme)")
        #endif
        if (url.scheme?.elementsEqual(AppDelegate.openUrlSchemeKakao))! {
            UIApplication.shared.openURL(url)
        } else {
            if (urlString.contains("pf.kakao.com") ||
                urlString.contains("nid.naver.com") ||
                urlString.contains("m.facebook.com") ||
                urlString.contains("api.instagram.com") ||
                urlString.contains("band.us") ||
                urlString.contains("twitter.com") ||
                urlString.contains("accounts.kakao.com")) {
                self.backButton.isHidden = false
            } else {
                self.backButton.isHidden = true
            }
        }
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
                callback = dictionary["callBack"] as? String ?? ""
                #if DEBUG
                print("callBack : \(callback)")
                #endif
                
                switch actionCode {
                    case "ACT1001": // 네이버 페이
                    break
                    case "ACT1011": // 카메라 및 사진 라이브라러 호출
                        AppDelegate.imageModel.token = actionParamObj?["token"] as? String
                        AppDelegate.imageModel.pageGbn = actionParamObj?["pageGbn"] as? String // 1 : 신규페이지에서 진입, 2 : 수정페이지에서 진입
                        AppDelegate.imageModel.cnt = actionParamObj?["cnt"] as? Int

                    if let values = actionParamObj?["imgArr"] as? Array<Any> {
                        values.forEach { dictionary in
                            let data = ImageData()
                            let dict = dictionary as? Dictionary<String, AnyObject>
                            data.fileName = dict?["fileName"] as? String
                            data.imgUrl = dict?["imgUrl"] as? String
                            data.sort = dict?["sort"] as? String
                            data.utype = dict?["utype"] as? Int

                            AppDelegate.imageModel.imgArr?.append(data)

                            if data.imgUrl != nil {
                                let imageFileData = ImageFileData()
                                imageFileData.fileName = data.fileName
                                imageFileData.imgUrl = data.imgUrl
                                AppDelegate.ImageFileArray.append(imageFileData)
                            }
                        }
                    }
                        
                        #if DEBUG
                        print("AppDelegate.imageModel.imgArr : \(AppDelegate.imageModel.imgArr)")
                        #endif
                        
                        let vc = self.storyboard!.instantiateViewController(withIdentifier: "imageSelectViewController") as! ImageSelectViewController
                        self.navigationController?.pushViewController(vc, animated: true)
                    break
                    case "ACT1012": // 사진 임시저장 통신
                        let token = actionParamObj?["token"] as? String
                        if token == nil {
                            return
                        }
                        
                        // 업로드할 이미지가 있는지 확인 (Android와 동일)
                        let hasImagesToUpload = AppDelegate.ImageFileArray.contains { $0.image != nil }
                        if !hasImagesToUpload {
                            let javascript = "\(self.callback)(\"-1\")"
                            self.webView.evaluateJavaScript(javascript, completionHandler: nil)
                            return
                        }
                        
                        let boundary = "WebKitFormBoundaryDCqbvCHcQvEfbSAa" // 업로드 바이너리 이름
                        
                        let defaultConfigObject = URLSessionConfiguration.default
                        let defaultSession = URLSession(configuration: defaultConfigObject, delegate: nil, delegateQueue: OperationQueue.main)
                        
                        //Create an URLRequest
                        let url = URL(string: AppDelegate.UPLOAD_URL)
                        var urlRequest: NSMutableURLRequest? = nil
                        if let url = url {
                            urlRequest = NSMutableURLRequest(url: url)
                        }

                        // post body
                        var body = Data()

                        if let data1 = "--\(boundary)\r\n".data(using: .utf8) {
                            body.append(data1)
                        }
                        if let data1 = "Content-Disposition: form-data; name=\"\("service")\"\r\n\r\n".data(using: .utf8) {
                            body.append(data1)
                        }
                        if let data1 = "\("GOODSIMGSREG")\r\n".data(using: .utf8) {
                            body.append(data1)
                        }

                        if let data1 = "--\(boundary)\r\n".data(using: .utf8) {
                            body.append(data1)
                        }
                        if let data1 = "Content-Disposition: form-data; name=\"\("token")\"\r\n\r\n".data(using: .utf8) {
                            body.append(data1)
                        }
                        if let data1 = "\(token)\r\n".data(using: .utf8) {
                            body.append(data1)
                        }
                        
                        // add image data (imgUrl만 있고 image가 nil인 항목은 서버 기존 이미지이므로 스킵)
                        var uploadCount = 0
                        for item in AppDelegate.ImageFileArray {
                            guard let imageData = item.image else { continue }

                            if let data1 = "--\(boundary)\r\n".data(using: .utf8) {
                                body.append(data1)
                            }
                            let fileName = item.fileName ?? "image.jpg"
                            if let data1 = "Content-Disposition: form-data; name=\"imgFile\"; filename=\"\(fileName)\"\r\n".data(using: .utf8) {
                                body.append(data1)
                            }
                            if let data1 = "Content-Type: image/jpeg\r\n\r\n".data(using: .utf8) {
                                body.append(data1)
                            }
                            body.append(imageData)
                            if let data1 = "\r\n".data(using: .utf8) {
                                body.append(data1)
                            }
                            uploadCount += 1
                            #if DEBUG
                            print("[ACT1012 업로드] 파일: \(fileName), 크기: \(imageData.count) bytes")
                            #endif
                        }
                        #if DEBUG
                        print("[ACT1012 업로드] 총 \(uploadCount)개 파일, body 크기: \(body.count) bytes")
                        #endif
                        
                        if let data1 = "--\(boundary)--\r\n".data(using: .utf8) {
                            body.append(data1)
                        }
                        
                        let contentType = "multipart/form-data; boundary=\(boundary)"
                        urlRequest?.setValue(contentType, forHTTPHeaderField: "Content-Type")
                        urlRequest?.httpMethod = "POST"
                        // uploadTask(with:from:) 사용 시 httpBody 설정하지 않음 (중복 시 에러 발생)

                        #if DEBUG
                        print("params body : \(body)")
                        print("params urlRequest : \(urlRequest)")
                        #endif
                        
                        //Create task
                        let task = defaultSession.uploadTask(with: urlRequest! as URLRequest, from: body) { data, response, error in
                            //Handle your response here
                            #if DEBUG
                            if let error = error {
                                print("error : \(error)")
                            }
                            if let response = response {
                                print("response : \(response)")
                            }
                            #endif

                            if let data = data, let sResultData = String(data: data, encoding: .utf8) {
                                #if DEBUG
                                print("[ACT1012 응답] \(sResultData)")
                                if let httpResponse = response as? HTTPURLResponse {
                                    print("[ACT1012 응답] statusCode: \(httpResponse.statusCode)")
                                }
                                #endif
                                // 서버가 imgUrl을 반환하지 않으면 업로드 성공 시 클라이언트에서 imgUrl 생성 (웹 썸네일 표시용)
                                var callbackJson = sResultData
                                if let jsonData = sResultData.data(using: .utf8),
                                   var resDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                                   (resDict["resCode"] as? String) == "0000",
                                   resDict["imgArr"] == nil {
                                    let baseImageUrl = "\(AppDelegate.HOME_URL)/data/greenmother/photo"
                                    var imgArr: [[String: Any]] = []
                                    var sortIndex = 1
                                    for item in AppDelegate.ImageFileArray {
                                        guard item.image != nil else { continue }
                                        let fileName = item.fileName ?? "image.jpg"
                                        let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileName
                                        let imgUrl = "\(baseImageUrl)/\(token ?? "")/\(encodedFileName)"
                                        imgArr.append([
                                            "fileName": fileName,
                                            "imgUrl": imgUrl,
                                            "sort": sortIndex,
                                            "utype": 1
                                        ])
                                        item.imgUrl = imgUrl
                                        if let arrIdx = AppDelegate.imageArray.firstIndex(where: { $0.fileName == item.fileName }) {
                                            AppDelegate.imageArray[arrIdx].imgUrl = imgUrl
                                        }
                                        sortIndex += 1
                                    }
                                    resDict["imgArr"] = imgArr
                                    if let mergedData = try? JSONSerialization.data(withJSONObject: resDict),
                                       let mergedStr = String(data: mergedData, encoding: .utf8) {
                                        callbackJson = mergedStr
                                        #if DEBUG
                                        print("[ACT1012] imgUrl 생성됨: \(imgArr)")
                                        #endif
                                    }
                                }
                                let javascript = "\(self.callback)(\(callbackJson))"
                                DispatchQueue.main.async {
                                    self.webView.evaluateJavaScript(javascript) { (result, error) in
                                        #if DEBUG
                                        print("result : \(String(describing: result))")
                                        print("error : \(String(describing: error))")
                                        #endif
                                    }
                                }
                            }
                        }

                        task.resume()
                    break
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
                    case "ACT1016":
                        print("ACT1016 - 새 브라우저 창을 닫는 액션")
                        self.navigationController?.popViewController(animated: true)
                    break
                case "ACT1020":
                    print("ACT1020 - sns로그인")
                    let snsType = actionParamObj?["snsType"] as? Int
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
                case "ACT1031": // 창 닫기
                    self.dismiss(animated: true, completion: nil)
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
    
    func uploadPhoto() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self //3
        // imagePicker.allowsEditing = true
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
    func sendImageData(){
        do {
            if AppDelegate.imageArray.count > 0 {
                var dic = Dictionary<String, Any>()
                dic.updateValue("1", forKey: "resultcd")
                var imgArr: [[String: Any]] = []
                for (index, item) in AppDelegate.imageArray.enumerated() {
                    var dict: [String: Any] = [:]
                    dict["fileName"] = item.fileName ?? ""
                    dict["imgUrl"] = item.imgUrl ?? ""
                    dict["sort"] = Int(item.sort ?? "\(index + 1)") ?? (index + 1)
                    dict["utype"] = item.utype ?? 1
                    imgArr.append(dict)
                }
                dic.updateValue(imgArr, forKey: "imgArr")
                dic.updateValue(AppDelegate.imageModel.token ?? "", forKey: "token")
                dic.updateValue(AppDelegate.imageModel.pageGbn ?? "1", forKey: "pageGbn")
                dic.updateValue(AppDelegate.imageArray.count, forKey: "cnt")
                let jsonDataForCallback = try JSONSerialization.data(withJSONObject: dic, options: [])
                let jsonString = String(data: jsonDataForCallback, encoding: .utf8) ?? ""
                let javascript = "\(callback)(\(jsonString))"
                DispatchQueue.main.async {
                    self.webView.evaluateJavaScript(javascript) { (result, error) in
                        #if DEBUG
                        print("cameraReturnApp result : \(String(describing: result))")
                        print("cameraReturnApp error : \(String(describing: error))")
                        #endif
                    }
                }
            }
        } catch let error as NSError {
            print(error)
        }
    }
    
    @IBAction func onClickBackButton(_ sender: UIButton) {
        self.backButton.isHidden = true
        self.navigationController?.popViewController(animated: true)
    }
}
