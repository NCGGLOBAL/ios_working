//
//  ViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/05/27.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import WebKit
import CoreLocation
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

class ViewController: UIViewController, WKUIDelegate,
WKNavigationDelegate, WKScriptMessageHandler, CLLocationManagerDelegate {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    @IBOutlet weak var backButton: UIButton!
    
    var webView: WKWebView!
    
    let kKeyOfWebActionKeyName = "iwebaction"
    let kKeyOfWebActionCode = "action_code"
    let kKeyOfWebActionParams = "action_param"
    let kKeyOfWebActionCallback = "callBack"
    let bridgeName = "ios"
    let liveScheme = "ncglive"
    
    var callback = ""
    
    let uniqueProcessPool = WKProcessPool()
    var locationManager: CLLocationManager!
    
    var app_scheme_arr : Array<String> = ["itms-appss://","ispmobile://","payco://","kakaotalk://","shinsegaeeasypayment://","lpayapp://","kb-acp://","hdcardappcardansimclick://","shinhan-sr-ansimclick://","lotteappcard://","cloudpay://","hanawalletmembers://","nhallonepayansimclick://","citimobileapp://","wooripay://","shinhan-sr-ansimclick-naverpay://","shinhan-sr-ansimclick-payco://","mpocket.online.ansimclick://",
        "kftc-bankpay://","lguthepay-xpay://","SmartBank2WB://","kb-bankpay://","nhb-bankpay://","mg-bankpay://","kn-bankpay://","com.wooricard.wcard://"]
    
    private struct Constants {
        static let callBackHandlerKey = "ios"
    }
    
    override func loadView() {
        super.loadView()
        
        let contentController = WKUserContentController()
        let config = WKWebViewConfiguration()
        let preferences = WKPreferences()
        preferences.setValue(true, forKey:"developerExtrasEnabled")
        preferences.javaScriptEnabled = true

        contentController.add(self, name: Constants.callBackHandlerKey)
        
        config.processPool = uniqueProcessPool
        config.userContentController = contentController
        config.preferences = preferences
        config.mediaTypesRequiringUserActionForPlayback = .audio
        config.allowsInlineMediaPlayback = true
        
        webView = WKWebView(frame: self.view.frame, configuration: config)
        
        webView.frame.size.height = self.view.frame.size.height - UIApplication.shared.statusBarFrame.height
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        // self.view = self.webView!
        self.containerView.addSubview(webView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if AppDelegate.LANDING_URL == "" {
            self.initWebView(urlString: AppDelegate.HOME_URL)
        } else {
            self.initWebView(urlString: AppDelegate.LANDING_URL)
        }
        
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if AppDelegate.QR_URL != "" {
            let vc = self.storyboard!.instantiateViewController(withIdentifier: "subWebViewController") as! SubWebViewController
            vc.urlString = AppDelegate.QR_URL
            self.navigationController?.pushViewController(vc, animated: true)
            AppDelegate.QR_URL = ""
        }
        navigationController?.isNavigationBarHidden = true
        if AppDelegate.isChangeImage {
            self.sendImageData()
            AppDelegate.isChangeImage = false
        }
    }
    
    func initWebView(urlString: String) {
        let url = URL(string: urlString)
        let request = URLRequest(url: url!, cachePolicy: .useProtocolCachePolicy)
        
        webView.load(request)
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
                case "ACT1002": // qrcode
                    performSegue(withIdentifier: "qrReaderSeque", sender: nil)
                    break
                    case "ACT1011": // 카메라 및 사진 라이브라러 호출
                        let token = actionParamObj?["token"] as? String
                        if token != AppDelegate.imageModel.token {
                            if AppDelegate.imageArray != nil && AppDelegate.imageArray.count > 0 {
                                AppDelegate.imageArray.removeAll()
                            }
                            if AppDelegate.ImageFileArray != nil && AppDelegate.ImageFileArray.count > 0 {
                                AppDelegate.ImageFileArray.removeAll()
                            }
                        }
                        
                        AppDelegate.imageModel.token = token
                        
                        AppDelegate.imageModel.pageGbn = actionParamObj?["pageGbn"] as? String // 1 : 신규페이지에서 진입, 2 : 수정페이지에서 진입
                        AppDelegate.imageModel.cnt = actionParamObj?["cnt"] as? Int
//                        for key in actionParamObj!.keys {
//                            print("key : \(key)")
//                        }

                        let values = Array(arrayLiteral: actionParamObj?["imgArr"])

                        for fchild in values {
                            let data = ImageData()
                            data.fileName = fchild?["fileName"] as? String
                            data.imgUrl = fchild?["imgUrl"] as? String
                            data.sort = fchild?["sort"] as? String
                            data.utype = fchild?["utype"] as? Int

                            AppDelegate.imageModel.imgArr?.append(data)
                            
                            if data.imgUrl != nil {
                                let imageFileData = ImageFileData()
                                imageFileData.fileName = data.fileName
                                imageFileData.imgUrl = data.imgUrl
                                AppDelegate.ImageFileArray.append(imageFileData)
                            }
                        }
                        
                        #if DEBUG
                        print("AppDelegate.imageModel.imgArr : \(AppDelegate.imageModel.imgArr)")
                        #endif
                        
                        let vc = self.storyboard!.instantiateViewController(withIdentifier: "imageSelectViewController") as! ImageSelectViewController
                        self.navigationController?.pushViewController(vc, animated: true)
                        break
                    break
                    case "ACT1012": // 사진 임시저장 통신
                        let token = actionParamObj?["token"] as? String
                        if token == nil {
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
                        
                        // add image data
                        var imageToUpload: UIImage? = nil // 업로드할 이미지
                        var imageData: Data? = nil // 업로드할 이미지 스트림
                        var sImageName: String? = nil

                        for item in AppDelegate.ImageFileArray {
                            imageData = imageToUpload?.jpegData(compressionQuality: 1.0)

                            if let data1 = "--\(boundary)\r\n".data(using: .utf8) {
                                body.append(data1)
                            }
                            if let data1 = "Content-Disposition: form-data; name=\"imgFile\"; filename=\"\(item.fileName ?? "")\"\r\n".data(using: .utf8) {
                                body.append(data1)
                            }
                            if let data1 = "Content-Type: image/jpeg\r\n\r\n".data(using: .utf8) {
                                body.append(data1)
                            }
                            body.append(item.image!)
                            if let data1 = "\r\n".data(using: .utf8) {
                                body.append(data1)
                            }
                        }
                        
                        if let data1 = "--\(boundary)--\r\n".data(using: .utf8) {
                            body.append(data1)
                        }
                        
                        let contentType = "multipart/form-data; boundary=\(boundary)"
                        urlRequest?.setValue(contentType, forHTTPHeaderField: "Content-Type")
                        urlRequest?.httpMethod = "POST"
                        urlRequest?.httpBody = body

                        #if DEBUG
                        print("params body : \(body)")
                        print("params urlRequest : \(urlRequest)")
                        #endif
                        
                        //Create task
                        let task = defaultSession.uploadTask(with: urlRequest! as URLRequest, from: body) { data, response, error in
                            //Handle your response here
                            if let error = error {
                                print("error : \(error)")
                            }
                            if let response = response {
                                print("response : \(response)")
                            }

                            if data != nil {
                                var sResultData: String? = nil
                                if let data = data {
                                    sResultData = String(data: data, encoding: .utf8)
                                    print("sResultData : \(sResultData ?? "")")
                                    do {
                                        print("jsonEncodedData : \(sResultData)")
                                        let javascript = "\(self.callback)('\(sResultData ?? "")')"     // set funcName parameter as a single quoted string
    //                                    print("jsonData : \(jsonData)")
                                        print("javascript : \(javascript)")

                                        // call back!
                                        self.webView.evaluateJavaScript(javascript) { (result, error) in
                                            print("result : \(String(describing: result))")
                                            print("error : \(error)")
                                        }
                                    } catch let error as NSError {
                                        print(error)
                                    }
                                }
                            }
                        }

                        task.resume()
                    break
                    case "ACT1013":
                        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                        var dic = Dictionary<String, String>()
                        dic.updateValue("IOS", forKey: "os")
                        dic.updateValue(AppDelegate.deviceId ?? "", forKey: "deviceId")
                        dic.updateValue(AppDelegate.pushkey, forKey: "pushkey")
                        dic.updateValue(version ?? "", forKey: "version")
                        #if DEBUG
                        print("dic : \(dic)")
                        print("deviceId : \(AppDelegate.deviceId)")
                        print("pushkey : \(AppDelegate.pushkey)")
                        print("version : \(version)")
                        #endif
                        do {
                          let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
                            let jsonEncodedData = jsonData.base64EncodedString()   // base64 eencode the data dictionary
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
                    case "ACT1016":
                        print("ACT1016 - 새 브라우저 창을 닫는 액션")
                    break
                case "ACT1020":
                    print("ACT1020 - sns로그인")
                    let snsType = actionParamObj?["snsType"] as? Int
                    if snsType == 2 {   // 카카오 로그인
                        // 카카오톡 설치 여부 확인
                        if (UserApi.isKakaoTalkLoginAvailable()) {
                            UserApi.shared.loginWithKakaoTalk {(oauthToken, error) in
                                if let error = error {
                                    print(error)
                                }
                                else {
                                    print("loginWithKakaoTalk() success.")
                                    //do something
//                                    _ = oauthToken
                                    UserApi.shared.me() {(user, error) in
                                        if let error = error {
                                            print(error)
                                        }
                                        else {
                                            print("me() success.")
                                            //do something
//                                            _ = user.
                                            let email = user?.kakaoAccount?.email ?? ""
                                            let nickname = user?.kakaoAccount?.profile?.nickname ?? ""
                                            let profileImagePath = user?.kakaoAccount?.profile?.profileImageUrl?.absoluteString ?? ""
                                            let thumnailPath = user?.kakaoAccount?.profile?.thumbnailImageUrl?.absoluteString ?? ""
                                            let id = String(user?.id ?? 0)
                                            var accountDic = Dictionary<String, String>()
                                            accountDic.updateValue(email, forKey: "email")
                                            accountDic.updateValue(nickname, forKey: "nickname")
                                            accountDic.updateValue(profileImagePath, forKey: "profileImagePath")
                                            accountDic.updateValue(thumnailPath, forKey: "thumnailPath")
                                            accountDic.updateValue(id, forKey: "id")
                                            do {
                                                let accountJsonData = try JSONSerialization.data(withJSONObject: accountDic, options: [])
//                                                let accountJsonEncodedData = accountJsonData.base64EncodedString()
                                                let accountDicString = String(data: accountJsonData, encoding: .utf8) ?? ""
                                                
                                                var dic = Dictionary<String, String>()
                                                dic.updateValue(oauthToken?.accessToken ?? "", forKey: "accessToken")
                                                dic.updateValue(accountDicString, forKey: "userInfo")
                                                #if DEBUG
                                                print("oauthToken : \(oauthToken?.accessToken ?? "")")
                                                print("userInfo : \(accountDicString)")
                                                #endif
                                                
                                                do {
                                                  let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
//                                                    let jsonEncodedData = jsonData.base64EncodedString()   // base64 eencode the data dictionary
                                                 let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                                                    let javascript = "\(self.callback)('\(stringValue)')"
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
                                            } catch let error as NSError {
                                                print(error)
                                            }
                                            
                                        }
                                    }
                                }
                            }
                        } else {
                            print("카카오 설치가 안되있습니다.")
                            if let url = URL(string: "itms-apps://itunes.apple.com/app/362057947"), UIApplication.shared.canOpenURL(url) {
                                if #available(iOS 10.0, *) {
                                    UIApplication.shared.open(url, options: [:], completionHandler: nil) }
                                else {
                                    UIApplication.shared.openURL(url)
                                }
                            }
                        }
                    }
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
                case "ACT1026": // 위치 정보 조회
                    locationManager = CLLocationManager()
                    locationManager.delegate = self
                    // foreground일때 위치추적 권한 요청
                    locationManager.requestWhenInUseAuthorization()
                    //  배터리에 맞게 권장되는 최적의 정확도
                    locationManager.desiredAccuracy = kCLLocationAccuracyBest
                    //  위치 업데이트
                    locationManager.startUpdatingLocation()
                    // 위, 경도 가져오기
                    let coordinate = locationManager.location?.coordinate
                    let latitude = coordinate?.latitude
                    let longitude = coordinate?.longitude
                    
                    // 전달
                    var dic = Dictionary<String, Any>()
                    dic.updateValue(AppDelegate.deviceId ?? "", forKey: "deviceId")
                    dic.updateValue(latitude ?? 0, forKey: "latitude")
                    dic.updateValue(longitude ?? 0, forKey: "longitude")
                    
                    do {
                      let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
                        let jsonEncodedData = jsonData.base64EncodedString()   // base64 eencode the data dictionary
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
                    
                case "ACT1032": // 홈으로 이동
                    self.initWebView(urlString: AppDelegate.HOME_URL)
                    break
                    
                    default:
                        print("디폴트를 꼭 해줘야 합니다.")
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var action: WKNavigationActionPolicy?

        guard let url = navigationAction.request.url else { return }

        let urlString = url.absoluteString
        print("#요청 URL -> " + urlString)

        for index in 0..<app_scheme_arr.count {
            let app_scheme = app_scheme_arr[index]
            let app_pass_yn = UIApplication.shared.canOpenURL(navigationAction.request.url!)
                        
            if(!urlString.hasPrefix(app_scheme)){continue;}
            
            print("#해당 앱 스킴 등록 여부 ->  ", app_pass_yn)

            if(app_pass_yn){ UIApplication.shared.open(navigationAction.request.url!, options: [:], completionHandler: nil)}
            else{noAppDialog()}
            
            break;
        }

        defer {
            decisionHandler(action ?? .allow)
        }

        guard let url = navigationAction.request.url else { return }

    #if DEBUG
        print("url : \(url)")
        print("url absoluteString: \(url.absoluteString)")
        print("url scheme: \(url.scheme)")
    #endif
        if (url.scheme?.elementsEqual(liveScheme))! {
            let vc = self.storyboard!.instantiateViewController(withIdentifier: "liveViewController") as! LiveViewController
            self.navigationController?.pushViewController(vc, animated: true)
        } else if (url.scheme?.elementsEqual(AppDelegate.openUrlSchemeKakao))! {
            UIApplication.shared.openURL(url)
        } else {
            if (urlString.contains("pf.kakao.com") ||
                urlString.contains("nid.naver.com") ||
                urlString.contains("m.facebook.com") ||
                urlString.contains("api.instagram.com") ||
                urlString.contains("accounts.kakao.com")) {
                self.backButton.isHidden = false
            } else {
                self.backButton.isHidden = true
            }
        }
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
    
    func noAppDialog(){
        let dialog = UIAlertController(title: "", message: "해당 앱이 설치 되어 있지 않습니다.", preferredStyle: .alert)

        let action = UIAlertAction(title: "OK", style: UIAlertAction.Style.default)
        dialog.addAction(action)
           
        self.present(dialog, animated: true, completion: nil)
    }
    
    func sendImageData(){
        do {
            let encoder = JSONEncoder()
            let jsonData = try? encoder.encode(AppDelegate.imageArray)

            if let jsonData = jsonData, let jsonString = String(data: jsonData, encoding: .utf8){
                let utf8str = jsonString.data(using: .utf8)

                let base64Encoded = utf8str?.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0)) ?? ""
                    print("Encoded: \(base64Encoded)")
            
                var dic = Dictionary<String, Any>()
                dic.updateValue("1", forKey: "resultcd")  // 변경사항 있을경우 : 1, 없을경우 : 0
                dic.updateValue(base64Encoded, forKey: "imgArr")
                dic.updateValue(AppDelegate.imageModel.token ?? "", forKey: "token")
                dic.updateValue(AppDelegate.imageModel.pageGbn ?? "1", forKey: "pageGbn")
                dic.updateValue(AppDelegate.imageArray.count, forKey: "cnt")
                print(jsonString)
                
                let calbackJsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
                let stringValue = String(data: calbackJsonData, encoding: .utf8) ?? ""
//                stringValue.replacingOccurrences(of: "\\", with: "")
                
                let dicJsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
                print("dicJsonData : \(dicJsonData)")
                let jsonEncodedData = dicJsonData.base64EncodedString()
                let javascript = "\(callback)('\(stringValue)')"
                print("javascript : \(javascript)")
                
                // call back!
                self.webView.evaluateJavaScript(javascript) { (result, error) in
                    print("result : \(String(describing: result))")
                    print("error : \(error)")
                }
            }
            
            } catch let error as NSError {
              print(error)
            }
    }
    
    @IBAction func onClickBackButton(_ sender: UIButton) {
        self.backButton.isHidden = true
        self.initWebView(urlString: AppDelegate.HOME_URL)
    }
}

