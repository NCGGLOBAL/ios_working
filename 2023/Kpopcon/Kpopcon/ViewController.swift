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
import LightCompressor
import MobileCoreServices  // for kUTTypeMovie
import AVKit

class ViewController: UIViewController, WKUIDelegate,
WKNavigationDelegate, WKScriptMessageHandler, CLLocationManagerDelegate, UIPageViewControllerDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    @IBOutlet weak var uploadIndicatorView: UIActivityIndicatorView!
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
    var cookies = HTTPCookieStorage.shared.cookies ?? []
    
    var app_scheme_arr : Array<String> = ["itms-appss://","ispmobile://","payco://","kakaotalk://","shinsegaeeasypayment://","lpayapp://","kb-acp://","hdcardappcardansimclick://","shinhan-sr-ansimclick://","lotteappcard://","cloudpay://","hanawalletmembers://","nhallonepayansimclick://","citimobileapp://","wooripay://","shinhan-sr-ansimclick-naverpay://","shinhan-sr-ansimclick-payco://","mpocket.online.ansimclick://",
        "kftc-bankpay://","lguthepay-xpay://","SmartBank2WB://","kb-bankpay://","nhb-bankpay://","mg-bankpay://","kn-bankpay://","com.wooricard.wcard://","newsmartpib://"]
    
    let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1"
    
    private struct Constants {
        static let callBackHandlerKey = "ios"
        static let TUTORIAL = "TUTORIAL"
    }
    
    let MAX_PAGE_COUNT = 2
    var currentSelectedPosition = 0
    let VIDEO_LIMIT_TIME: TimeInterval = 2 * 60  // 2분을 초 단위로 변환한 값입니다 (120초)
    var videoUrl: URL?
    private var compression: Compression?
    private var compressedUrl: URL?
    
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
        
        for (cookie) in cookies {
            config.websiteDataStore.httpCookieStore.setCookie(cookie, completionHandler: nil)
        }
        
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
        
        if AppDelegate.VIDEO_THUMBNAIL_UIImage != nil {
            // 썸네일 이미지 업로드
            self.postThumbImageData()
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
        var request = URLRequest(url: url!, cachePolicy: .useProtocolCachePolicy)
        
        let headers = HTTPCookie.requestHeaderFields(with: cookies)
        
        for (name, value) in headers {
            request.addValue(value, forHTTPHeaderField: name)
        }
        
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
                    
                case "ACT1038": // 가로보기, 세로보기
                    let keyType = actionParamObj?["key_type"] as? String
                    if keyType == "0" {
                        if #available(iOS 16.0, *) {
                            view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                        } else {
                            // Fallback on earlier versions
                        }
                    } else {
                        if #available(iOS 16.0, *) {
                            view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
                        } else {
                            // Fallback on earlier versions
                        }
                    }
                    // call back!
                    let javascript = "\(self.callback)"
                    // call back!
                    self.webView.evaluateJavaScript(javascript) { (result, error) in
                        print("result : \(String(describing: result))")
                        print("error : \(error)")
                    }
                    break
                    
                case "ACT1039": // 영상 선택후 압축, 썸네일 이미지 전달
                    let bitrate = actionParamObj?["bitrate"] as? Int

                    self.pickVideo()
                    break
                    
                case "ACT1040": // "영상 파일 업로드"
                    let url = actionParamObj?["url"] as? String
                    let key = actionParamObj?["key"] as? String
                    let token = actionParamObj?["token"] as? String
                    
                    if url == nil {
                        return
                    }
                    
                    self.uploadIndicatorView.isHidden = false
                    self.uploadIndicatorView.startAnimating()
                    self.showToast(message: "업로드 시작.시간이 걸리니 대기해주세요")
                    let sendUrl = URL(string: url!)
                    
                    self.uploadVideo(videoURL: (self.compressedUrl ?? self.videoUrl)!, to: sendUrl!, token: token!, key: key!) { result in
                        
                        var dic = [String: String]()
                        
                        switch result {
                        case .success(let responseURL):
                            print("Video uploaded successfully. Response URL: \(responseURL)")
                            
                            dic["result"] = "1"
                            self.sendWebViewEvaluateJavaScript(dic: dic)
                            
                            DispatchQueue.main.async {
                                self.uploadIndicatorView.stopAnimating()
                                self.showToast(message: "업로드 성공했습니다.")
                            }
                            break
                        case .failure(let error):
                            print("Failed to upload video: \(error.localizedDescription)")
                            dic["result"] = "-1"
                            self.sendWebViewEvaluateJavaScript(dic: dic)
                            
                            DispatchQueue.main.async {
                                self.uploadIndicatorView.stopAnimating()
                                self.showToast(message: "업로드 실패했습니다.")
                            }
                            break
                        }
                    }
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
    
    func pickVideo() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .savedPhotosAlbum
        imagePicker.mediaTypes = [kUTTypeMovie as String]  // 필터링하여 동영상만 선택할 수 있습니다.
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        // 동영상 추출
        // mediaType과 url을 옵셔널 체이닝을 이용하여 안전하게 추출합니다.
        if let mediaType = info[.mediaType] as? String,
           mediaType == kUTTypeMovie as String,
           let url = info[.mediaURL] as? URL {
            // AVAsset을 사용하여 동영상 파일의 재생 시간을 가져옵니다.
            let asset = AVAsset(url: url)
            let durationInSeconds = CMTimeGetSeconds(asset.duration)
            // 재생시간 2분 이상 시간은 토스트 노출
            if (durationInSeconds > VIDEO_LIMIT_TIME) {
                self.showToast(message: "영상시간을 2분이내로 줄여주세요")
                return
            }
            // 300MB 이상이면 리턴
            if (!self.checkVideoFileSize(at: url)) {
                return
            }
            self.videoUrl = url
            // 비디오 썸네일 뷰컨트롤러 이동
            let vc = self.storyboard!.instantiateViewController(withIdentifier: "VideoThumbViewController") as! VideoThumbViewController
            vc.videoUrl = url
            self.navigationController?.pushViewController(vc, animated: true)
        } else {
            print("선택된 미디어가 동영상이 아닙니다.")
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
        }
        
        picker.dismiss(animated: true, completion: nil)
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
    
    func postThumbImageData() {
        do {
            if let imageData = AppDelegate.VIDEO_THUMBNAIL_UIImage!.pngData() {
                let base64String = imageData.base64EncodedString()
                
                // 결과 출력
                print("썸네일 데이터를 Base64 문자열로 변환:")
                print(base64String)
                
                var myDict = [String: Any]()
                do {
                    myDict["type"] = "0"
                    myDict["thumbData"] = base64String
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: myDict, options: [])
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        let jsFunction = "\(callback)('\(jsonString)')" // JavaScript 함수와 Base64 문자열 인수를 포함하는 문자열 생성
                        print("jsFunction: \(jsFunction)")
                        webView.evaluateJavaScript(jsFunction, completionHandler: { (result, error) in
                            if let error = error {
                                print("비디오 썸네일 업로드 실패 Error: \(error.localizedDescription)")
                            } else {
                                print("비디오 썸네일 업로드 완료 Result: \(result ?? "")")
                                self.checkArchveVidio()
                            }
                        })
                    }
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
        } catch {
            print("썸네일 데이터를 가져오는 도중 오류 발생: \(error)")
        }
        
    }
    
    func sendWebViewEvaluateJavaScript(dic: Dictionary<String, Any>?) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let jsFunction = "\(callback)('\(jsonString)')" // JavaScript 함수와 Base64 문자열 인수를 포함하는 문자열 생성
                print("sendWebViewEvaluateJavaScript jsFunction : \(jsFunction)")
                DispatchQueue.main.async {
                    self.webView.evaluateJavaScript(jsFunction, completionHandler: { (result, error) in
                        if let error = error {
                            print("evaluateJavaScript Error: \(error.localizedDescription)")
                        } else {
                            print("evaluateJavaScript Result: \(result ?? "")")
                        }
                    })
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    func showToast(message : String) {
            let width_variable:CGFloat = 10
            let toastLabel = UILabel(frame: CGRect(x: width_variable, y: self.view.frame.size.height-150, width: view.frame.size.width-2*width_variable, height: 35))
            // 뷰가 위치할 위치를 지정해준다. 여기서는 아래로부터 100만큼 떨어져있고, 너비는 양쪽에 10만큼 여백을 가지며, 높이는 35로
            toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            toastLabel.textColor = UIColor.white
            toastLabel.textAlignment = .center;
            toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
            toastLabel.text = message
            toastLabel.alpha = 1.0
            toastLabel.layer.cornerRadius = 10;
            toastLabel.clipsToBounds  =  true
            self.view.addSubview(toastLabel)
            UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0.0
            }, completion: {(isCompleted) in
                toastLabel.removeFromSuperview()
            })
        }
    
    func checkVideoFileSize(at url: URL) -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                // 파일 사이즈를 바이트 단위로 가져왔습니다. 필요에 따라 다른 단위로 변환할 수 있습니다.
                print("비디오 파일 용량: \(fileSize) bytes")
                
                // 예시로 용량 제한을 넘지 않았는지 체크할 수 있습니다.
                let maxFileSize: Int64 = 300 * 1024 * 1024  // 예시: 100MB (실제로 필요에 따라 달라질 수 있음)
                if fileSize > maxFileSize {
                    self.showToast(message: "영상 용량은 100M미만으로 등록해 주세요.")
                    return false
                } else {
                    print("파일 크기가 허용된 최대 용량 내에 있습니다.")
                }
            } else {
                print("파일 크기를 가져올 수 없습니다.")
            }
        } catch {
            print("파일 속성을 가져오는 도중 에러가 발생했습니다: \(error.localizedDescription)")
        }
        return true
    }
    
    func videoArchive() {
        // Declare destination path and remove anything exists in it
        let destinationPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("compressed.mp4")
        try? FileManager.default.removeItem(at: destinationPath)
        
        let videoCompressor = LightCompressor()
        
        self.compression = videoCompressor.compressVideo(videos: [.init(source: self.videoUrl!, destination: destinationPath, configuration: .init(quality: VideoQuality.very_high, videoBitrateInMbps: 5, disableAudio: false, keepOriginalResolution: false, videoSize: CGSize(width: 360, height: 480) ))],
                                                   progressQueue: .main,
                                                   progressHandler: { progress in
                                                    DispatchQueue.main.async { [unowned self] in
//                                                        self.progressBar.progress = Float(progress.fractionCompleted)
//                                                        self.progressLabel.text = "\(String(format: "%.0f", progress.fractionCompleted * 100))%"
                                                    }},
                                                   
                                                   completion: {[weak self] result in
                                                    guard let `self` = self else { return }
                                                    
                                                    switch result {
                                                        
                                                    case .onSuccess(let index, let path):
                                                        self.compressedUrl = path
//                                                        DispatchQueue.main.async { [unowned self] in
//                                                            self.sizeAfterCompression.isHidden = false
//                                                            self.duration.isHidden = false
//                                                            self.progressBar.isHidden = true
//                                                            self.progressLabel.isHidden = true
//                                                            
//                                                            self.sizeAfterCompression.text = "Size after compression: \(path.fileSizeInMB())"
//                                                            self.duration.text = "Duration: \(String(format: "%.2f", startingPoint.timeIntervalSinceNow * -1)) seconds"
//                                                            
//                                                            PHPhotoLibrary.shared().performChanges({
//                                                                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: path)
//                                                            })
//                                                        }
                                                        print("비디오 압축 onSuccess : \(self.compressedUrl)")
                                                        var dic = [String: Any]()
                                                        dic["type"] = "1"
                                                    
                                                        self.sendWebViewEvaluateJavaScript(dic: dic)
                                                        
                                                        break
                                                        
                                                    case .onStart:
//                                                        self.progressBar.isHidden = false
//                                                        self.progressLabel.isHidden = false
//                                                        self.sizeAfterCompression.isHidden = true
//                                                        self.duration.isHidden = true
                                                        //self.originalSize.visiblity(gone: false)
                                                        print("비디오 압축 onStart")
                                                        break
                                                        
                                                    case .onFailure(let index, let error):
//                                                        self.progressBar.isHidden = true
//                                                        self.progressLabel.isHidden = false
//                                                        self.progressLabel.text = (error as! CompressionError).title
                                                        print("비디오 압축 onFailure")
                                                        break
                                                        
                                                    case .onCancelled:
                                                        print("---------------------------")
                                                        print("비디오 압축 Cancelled")
                                                        print("---------------------------")
                                                    }
        })
    }

    func uploadVideo(videoURL: URL, to serverURL: URL, token: String, key: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // 1. 비디오 파일을 Data로 변환
        guard let videoData = try? Data(contentsOf: videoURL) else {
            completion(.failure(NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read video data"])))
            return
        }
        
        // 2. URLRequest 설정
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        
        // 3. 멀티파트 요청 설정
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 4. 멀티파트 데이터 생성
        var body = Data()
        let fileName = videoURL.lastPathComponent
        let mimeType = "video/mp4" // 업로드할 비디오의 MIME 타입

        // 비디오 파일 데이터
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 추가 파라미터 추가
        let videoParam: [String: String] = [
            "token": token,
            "key": key
        ]
        
        for (key, value) in videoParam {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // 5. 업로드 시작
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "UploadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Server error or invalid response"])))
                return
            }
            
            // 서버 응답에서 URL을 반환한다고 가정
            guard let data = data, let responseURL = URL(dataRepresentation: data, relativeTo: nil) else {
                completion(.failure(NSError(domain: "UploadError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse server response"])))
                return
            }
            
            completion(.success(responseURL))
        }
        
        task.resume()
    }
    
    func checkArchveVidio() {
        // 압축여부 체크
        print("checkArchveVidio 함수 시작")
        let asset = AVAsset(url: self.videoUrl!)
            let track = asset.tracks(withMediaType: .video).first
            
            if let track = track {
                let size = track.naturalSize
                var width = size.width
                var height = size.height
                print("비디오 해상도: \(width) x \(height)")
                var dic = [String: String]()
                dic["type"] = "1"
                if (width > height) { // 가로영상
                    print("가로영상")
                    if height > 720 {
                        width = width * 720 / height
                        height = 720
                    } else {
                        self.sendWebViewEvaluateJavaScript(dic: dic)
                        return
                    }
                } else {    // 세로 영상
                    print("세로 영상")
                    if width > 720 {
                        height = height * 720 / height
                        width = 720
                    } else {
                        self.sendWebViewEvaluateJavaScript(dic: dic)
                        return
                    }
                }
                
                // 비디오 파일 압축
                // https://github.com/AbedElazizShe/LightCompressor_iOS
                self.videoArchive()
            } else {
                print("비디오 트랙을 찾을 수 없습니다.")
            }
    }

    
    @IBAction func onClickBackButton(_ sender: UIButton) {
        self.backButton.isHidden = true
        self.initWebView(urlString: AppDelegate.HOME_URL)
    }
}

// Helper extension to append data to `Data`
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
