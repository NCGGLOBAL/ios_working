//
//  ViewController.swift
//  UnniTv
//
//  Created by glediaer on 2020/05/27.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import WebKit
import Alamofire
import CoreLocation

class ViewController: UIViewController, WKUIDelegate,
WKNavigationDelegate, WKScriptMessageHandler, CLLocationManagerDelegate {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    @IBOutlet weak var backButton: UIButton!
    
    var webView: WKWebView!
    
    let kKeyOfWebActionKeyName = "iwebaction";
    let kKeyOfWebActionCode = "action_code";
    let kKeyOfWebActionParams = "action_param";
    let kKeyOfWebActionCallback = "callBack";
    let bridgeName = "ios"
    var callback = ""
    let openUrlSchemeKakao = "kakaoplus"
    
    let uniqueProcessPool = WKProcessPool()
    var locationManager: CLLocationManager!

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
        
        webView = WKWebView(frame: self.view.frame, configuration: config)
        webView.frame.size.height = self.view.frame.size.height - UIApplication.shared.statusBarFrame.height
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        // self.view = self.webView!
        self.containerView.addSubview(webView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initWebView(urlString: AppDelegate.HOME_URL)
        
//        print("deviceId : \(deviceId)")
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
    
//    @available(iOS 8.0, *)
//    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Swift.Void){
//        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
//        let otherAction = UIAlertAction(title: "OK", style: .default, handler: {action in completionHandler()})
//        alert.addAction(otherAction)
//            
//        self.present(alert, animated: true, completion: nil)
//    }

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
                callback = dictionary["callBack"] as? String ?? ""
                print("callBack : \(callback)")
                switch actionCode {
                    case "ACT1001": // 네이버 페이
                        
                    break
                case "ACT1002": // qrcode
                    performSegue(withIdentifier: "qrReaderSeque", sender: nil)
                    break
                    case "ACT1011": // 카메라 및 사진 라이브라러 호출
                        AppDelegate.imageModel.token = actionParamObj?["token"] as? String
                        AppDelegate.imageModel.pageGbn = actionParamObj?["pageGbn"] as? String // 1 : 신규페이지에서 진입, 2 : 수정페이지에서 진입
                        AppDelegate.imageModel.cnt = actionParamObj?["cnt"] as? Int
                        for key in actionParamObj!.keys {
                            print("key : \(key)")
                        }
                        
//                        let jsonString = actionParamObj?["imgArr"] as? String
//                        let decoder = JSONDecoder()
//                        var data = jsonString?.data(using: .utf8)
//                        if let data = data, let imageData = try? decoder.decode(ImageData.self, from: data) {
//
//                            print(imageData.fileName)//Zedd
//
//                            print(imageData.imgUrl)//100
//
//                        }
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
                            
                            if data.imgUrl != nil {
                                let imageFileData = ImageFileData()
                                imageFileData.fileName = data.fileName
                                imageFileData.imgUrl = data.imgUrl
                                AppDelegate.ImageFileArray.append(imageFileData)
                            }
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
                        
                        let boundary = "WebKitFormBoundaryDCqbvCHcQvEfbSAa" // 업로드 바이너리 이름
                        
                        let header: HTTPHeaders = [
                                    "Authorization": token!,
                                    "content-type": "multipart/form-data;boundary=" + boundary
                                ]
//                        [SysUtils showWaitingSplash];
                        let uploadUrl = AppDelegate.HOME_URL + "/m/app/"
                        
                        let defaultConfigObject = URLSessionConfiguration.default
                        let defaultSession = URLSession(configuration: defaultConfigObject, delegate: nil, delegateQueue: OperationQueue.main)
                        
                        //Create an URLRequest
                        let url = URL(string: uploadUrl)
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
//                            sImageName = (arrLastAddPicture[i] as? [AnyHashable : Any])["fileName"] as? String
//
//                            imageToUpload = arrLastAddPicture[i]["imageData"] as? UIImage
//
//                            if imageToUpload == nil {
//                                continue
//                            }

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

                        //[urlRequest setHTTPBody:[params dataUsingEncoding:NSUTF8StringEncoding]];
                        //[urlRequest setValue:@"text/html" forHTTPHeaderField:@"Content-Type"];
                        #if DEBUG
                        print("params : \(body)")
                        //NSLog(@"params : %@", params);
                        print("params : \(urlRequest)")
                        #endif
                        
                        //Create task
                        let session = URLSession.shared
//                        let task = defaultSession.uploadTask(with: urlRequest! as URLRequest, from: body)
//                        let task = defaultSession.uploadTask(with: urlRequest! as URLRequest, from: body) { data, res, error in
//
//                          /// 1: 실제로 비동기로 동작하는 업로드 동작 때문에, 완료핸들러의 처리 후에는
//                          //     런루프를 멈춰서 프로그램이 종료할 수 있게 해주어야 한다.
//                          defer {
//                            CFRunLoopStop(CFRunLoopGetMain())
//                          }
//
//                          // 에러 체크
//                          guard error == nil else {
//                            print("Error: \(error!.localizedDescription)")
//                            return
//                          }
//
//                          // 서버로부터 응답이 제대로 내려왔는지 체크
//                          // 응답값은 URLResponse? 인데,
//                          // 이를 HTTPURLResponse로 캐스팅해서 statusCode를 확인한다.
//                          if let res= res as? HTTPURLResponse,
//                              res.statusCode != 200 {
//                             print("Server failed")
//                          }
//
//                          if let data = data, let message = String(data:data, encoding:.utf8)
//                          {
//                             pritn(message)
//                          }
//                        }

                        let task = defaultSession.uploadTask(with: urlRequest! as URLRequest, from: body) { data, res, error in
                                //Handle your response here

                                if data != nil {
//                                    SysUtils.closeWaitingSplash()

                                    //NSError *jsonError;
                                    //NSDictionary *dicResData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];

                                    var sResultData: String? = nil
                                    if let data = data {
                                        sResultData = String(data: data, encoding: .utf8)
                                    }
//                                    sResultData = sResultData?.replacingOccurrences(of: "\r\n", with: "")
//                                    sResultData = sResultData?.replacingOccurrences(of: "\t", with: "")
//
//                                    let dicResData = sResultData?.jsonValue()
//
//                                    self.perform(#selector(transAferMsg(_:)), with: dicResData, afterDelay: 0.5)
//
//                                    SessionManager.shared().tempImageList = []
//                                       SessionManager.shared().transImageData = []
//                                       SessionManager.shared().transModGbn = nil
                            }
                        }

                        task.resume()
//                        Alamofire.upload(
//                            multipartFormData: { MultipartFormData in
//                                if AppDelegate.imageArray.count == 0 {
//                                    return
//                                }
//                                for item in AppDelegate.ImageFileArray {
//                                    // 3. 이미지 데이터 원격저장소에 업로드 요청, resizing
//                                    print("image fileName : \(item.fileName)")
//                                    print("image item : \(item.image)")
//                                    MultipartFormData.append(item.image!, withName: boundary, fileName: item.fileName ?? "testImage", mimeType: "image/jpeg")
//                                }
//                                }, to: uploadUrl, method: .post, headers: header) { (result) in
//
//                                    switch result {
//                                    case .success(let upload, _, _):
//
//                                        upload.responseJSON { response in
//                                           // getting success
//                                            if (response.response?.statusCode)! >= 200 {
//                                                print("succes : \(response.response)")
//                                            }
//                                        }
//
//                                    case .failure(let encodingError): break
//                                        // getting error
//                                        print("encodingError : \(encodingError.localizedDescription)")
//                                    }
//                                }
                    break
                    case "ACT1013":
                        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                        var dic = Dictionary<String, String>()
                        dic.updateValue("IOS", forKey: "os")
                        dic.updateValue(AppDelegate.deviceId ?? "", forKey: "deviceId")
                        dic.updateValue(AppDelegate.pushkey, forKey: "pushkey")
                        dic.updateValue(version ?? "", forKey: "version")
                        print("dic : \(dic)")
                        print("deviceId : \(AppDelegate.deviceId)")
                        print("pushkey : \(AppDelegate.pushkey)")
                        print("version : \(version)")
                        do {
                          let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
                            let jsonEncodedData = jsonData.base64EncodedString()   // base64 eencode the data dictionary
                         let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
                         print("jsonEncodedData : \(jsonEncodedData)")
                            let javascript = "\(callback)('\(stringValue)')"     // set funcName parameter as a single quoted string
                            print("jsonData : \(jsonData)")
                            print("javascript : \(javascript)")
                            
    //                      webView?.evaluateJavaScript(javascript, completionHandler: nil)
                            // call back!
                            self.webView.evaluateJavaScript(javascript) { (result, error) in
                                print("result : \(String(describing: result))")
                                print("error : \(error)")
                            }
                        } catch let error as NSError {
                            print(error)
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
                    case "ACT1016":
                        print("ACT1016 - 새 브라우저 창을 닫는 액션")
                        
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
                     print("jsonEncodedData : \(jsonEncodedData)")
                        let javascript = "\(callback)('\(stringValue)')"     // set funcName parameter as a single quoted string
                        print("jsonData : \(jsonData)")
                        print("javascript : \(javascript)")
                        
//                      webView?.evaluateJavaScript(javascript, completionHandler: nil)
                        // call back!
                        self.webView.evaluateJavaScript(javascript) { (result, error) in
                            print("result : \(String(describing: result))")
                            print("error : \(error)")
                        }
                    } catch let error as NSError {
                        print(error)
                    }
                    break
                    
                    default:
                        print("디폴트를 꼭 해줘야 합니다.")
                }
            }
        }
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
        if (urlString.contains("pf.kakao.com") ||
            urlString.contains("nid.naver.com") ||
            urlString.contains("m.facebook.com") ||
            urlString.contains("accounts.kakao.com")) {
            self.backButton.isHidden = false
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
    
    func sendImageData(){
        print("sendImageData")
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
                var stringValue = String(data: calbackJsonData, encoding: .utf8) ?? ""
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
            
//            let data = try JSONEncoder().encode(AppDelegate.imageArray)
//            let ImageArrayString = String(data: data, encoding: .utf8)!
//            print("string array :  \(ImageArrayString.debugDescription)") // "[\"1\",\"2\",\"3\",\"4\",\"5\"]"
//            var dic = Dictionary<String, Any>()
//            dic.updateValue("1", forKey: "resultcd")  // 변경사항 있을경우 : 1, 없을경우 : 0
//            dic.updateValue(ImageArrayString, forKey: "imgArr")
//            dic.updateValue(AppDelegate.imageModel.token ?? "", forKey: "token")
//            dic.updateValue(AppDelegate.imageModel.pageGbn ?? "1", forKey: "pageGbn")
//            dic.updateValue(AppDelegate.imageArray.count, forKey: "cnt")
//
//            let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])  // serialize the data dictionary
//            let stringValue = String(data: jsonData, encoding: .utf8) ?? ""
//                let javascript = "\(callback)('\(stringValue)')"     // set funcName parameter as a single quoted string
//                print("jsonData : \(jsonData)")
//                print("javascript : \(javascript)")
//
//                // call back!
//                self.webView.evaluateJavaScript(javascript) { (result, error) in
//                    print("result : \(String(describing: result))")
//                    print("error : \(error)")
//                }
            } catch let error as NSError {
              print(error)
            }
    }
    
    @IBAction func onClickBackButton(_ sender: UIButton) {
        self.backButton.isHidden = true
        self.initWebView(urlString: AppDelegate.HOME_URL)
    }
}

