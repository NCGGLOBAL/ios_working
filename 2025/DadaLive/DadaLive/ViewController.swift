//
//  ViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/05/27.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import SafariServices
import WebKit
import CoreLocation

class ViewController: UIViewController, WKUIDelegate,
WKNavigationDelegate, WKScriptMessageHandler, CLLocationManagerDelegate, UIPageViewControllerDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SFSafariViewControllerDelegate {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    @IBOutlet weak var backButton: UIButton!
    
    var webView: WKWebView!
    private var safariViewController: SFSafariViewController?
    
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
        "kftc-bankpay://","lguthepay-xpay://","SmartBank2WB://","kb-bankpay://","nhb-bankpay://","mg-bankpay://","kn-bankpay://","com.wooricard.wcard://","newsmartpib://"]
    
    let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1"
    
    private struct Constants {
        static let callBackHandlerKey = "ios"
        static let TUTORIAL = "TUTORIAL"
    }
    
    let MAX_PAGE_COUNT = 2
    var currentSelectedPosition = 0
    
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
        webView.customUserAgent = userAgent
        
        // self.view = self.webView!
        self.containerView.addSubview(webView)
        //self.loadAppStoreVersion()
    }
    
    func loadAppStoreVersion() -> String {
        let bundleID = "com.creator.labangtv"
        let appStoreUrl = "http://itunes.apple.com/lookup?bundleId=\(bundleID)"
        guard let url = URL(string: appStoreUrl),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return ""
        }
                
        guard let appStoreVersion = results[0]["version"] as? String else {
            return ""
        }
                        
        return appStoreVersion
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        let ud = UserDefaults.standard
//        if ud.bool(forKey: Constants.TUTORIAL) == false {
//            self.initTutorial()
//            ud.set(true, forKey: Constants.TUTORIAL)
//        }
        
        if AppDelegate.LANDING_URL == "" {
            self.initWebView(urlString: AppDelegate.HOME_URL)
        } else {
            self.initWebView(urlString: AppDelegate.LANDING_URL)
            AppDelegate.LANDING_URL = ""
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
    
    var contentImages = ["bg_swipe1", "bg_swipe2"]
    var pageVC: UIPageViewController!
    func initTutorial() {
        // 페이지 뷰 컨트롤러 객체 생성
        self.pageVC = self.storyboard!.instantiateViewController(withIdentifier: "PageVC") as! UIPageViewController
        
        self.pageVC.dataSource = self
        
        // 페이지 뷰 컨트롤러의 기본 페이지 지정
        let startContentVC = self.getContentVC(atIndex: 0)!
        self.pageVC.setViewControllers([startContentVC], direction: .forward, animated: true)
        
        // 페이지 뷰 컨트롤러 출력 영역
//        self.pageVC.view.frame.origin = CGPoint(x: 0, y: 0)
//        self.pageVC.view.frame.size.width = self.view.frame.width
//        self.pageVC.view.frame.size.height = self.view.frame.height
        
        // 페이지 뷰 컨트롤러를 마스터 뷰 컨트롤러의 자식 뷰 컨트롤러로 지정
        self.addChild(self.pageVC)
        self.view.addSubview(self.pageVC.view)
        self.pageVC.didMove(toParent: self)
    }
    
    func getContentVC(atIndex idx: Int) -> UIViewController? {
        // stroyboard ID가 ContentsVC인 뷰 컨트롤러의 인스턴스 생성
        let pageVC = self.storyboard!.instantiateViewController(withIdentifier: "ContentsVC") as! TutorialContentsVC
        pageVC.imageFile = self.contentImages[idx]
        pageVC.pageIndex = idx
        pageVC.parentView = self.pageVC
        return pageVC
    }
    
    // 현재의 콘텐츠 뷰 컨트롤러보다 앞쪽에 올 콘텐츠 뷰 컨트롤러 객체
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        // 현재 페이지 인덱스
        guard var index = (viewController as! TutorialContentsVC).pageIndex else {
            return nil
        }
        // 인덱스가 맨 앞이면 nil
        guard index > 0 else {
            return nil
        }
        
        // 이전 페이지 인덱스
        index -= 1
        return self.getContentVC(atIndex: index)
    }
        
        // 현재의 콘텐츠 뷰 컨트롤러 뒤쪽에 올 콘텐츠 뷰 컨트롤러 객체
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        // 현재 페이지 인덱스
        guard var index = (viewController as! TutorialContentsVC).pageIndex else {
            return nil
        }
        
        
        // 다음 페이지 인덱스
        index += 1
    
        currentSelectedPosition = index
        
        // 인덱스는 배열 데이터의 크기보다 작아야함
        guard index < self.contentImages.count else {
            return nil
        }
        
        return self.getContentVC(atIndex: index)
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
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var action: WKNavigationActionPolicy?

        guard let url = navigationAction.request.url else { return }

        #if DEBUG
        print("🔵 [decidePolicyFor] 요청 URL: \(url.absoluteString)")
        #endif

        if isKakaoAuthURL(url) {
            #if DEBUG
            print("🔵 [decidePolicyFor] Kakao Auth URL 감지됨 - SFSafariViewController로 전환")
            #endif
            presentKakaoAuth(url: url)
            decisionHandler(.cancel)
            return
        }

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
    
//    func showToast(message : String) {
//            let width_variable:CGFloat = 10
//            let toastLabel = UILabel(frame: CGRect(x: width_variable, y: self.view.frame.size.height-150, width: view.frame.size.width-2*width_variable, height: 35))
//            // 뷰가 위치할 위치를 지정해준다. 여기서는 아래로부터 100만큼 떨어져있고, 너비는 양쪽에 10만큼 여백을 가지며, 높이는 35로
//            toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
//            toastLabel.textColor = UIColor.white
//            toastLabel.textAlignment = .center;
//            toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
//            toastLabel.text = message
//            toastLabel.alpha = 1.0
//            toastLabel.layer.cornerRadius = 10;
//            toastLabel.clipsToBounds  =  true
//            self.view.addSubview(toastLabel)
//            UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
//                toastLabel.alpha = 0.0
//            }, completion: {(isCompleted) in
//                toastLabel.removeFromSuperview()
//            })
//        }
    
    // MARK: - Kakao Login Helper Methods
    private func isKakaoAuthURL(_ url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()
        // 카카오 도메인만 체크 (앱에 관계없이 동일하게 작동)
        let isKakaoDomain = urlString.contains("kauth.kakao.com") || urlString.contains("accounts.kakao.com")
        
        #if DEBUG
        if isKakaoDomain {
            print("🔵 [Kakao Auth] 감지된 URL: \(url.absoluteString)")
        }
        #endif
        
        return isKakaoDomain
    }
    
    private func presentKakaoAuth(url: URL) {
        #if DEBUG
        print("🔵 [Kakao Auth] SFSafariViewController 표시 시작: \(url.absoluteString)")
        #endif
        
        // 기존 SFSafariViewController가 있으면 닫기
        if let existingSafariVC = safariViewController {
            existingSafariVC.dismiss(animated: false, completion: nil)
        }
        
        let safariVC = SFSafariViewController(url: url)
        safariVC.modalPresentationStyle = .fullScreen
        safariVC.delegate = self
        safariViewController = safariVC
        
        DispatchQueue.main.async { [weak self] in
            self?.present(safariVC, animated: true, completion: nil)
            #if DEBUG
            print("🔵 [Kakao Auth] SFSafariViewController 표시 완료")
            #endif
        }
    }
    
    // MARK: - SFSafariViewControllerDelegate
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        #if DEBUG
        print("🔵 [Kakao Auth] SFSafariViewController 닫힘")
        #endif
        safariViewController = nil
    }
    
    @IBAction func onClickBackButton(_ sender: UIButton) {
        self.backButton.isHidden = true
        self.initWebView(urlString: AppDelegate.HOME_URL)
    }
}

