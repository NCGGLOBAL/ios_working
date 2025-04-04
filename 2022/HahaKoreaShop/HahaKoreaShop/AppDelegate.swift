//
//  AppDelegate.swift
//  UnniTv
//
//  Created by glediaer on 2020/05/27.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
//import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    let gcmMessageIDKey = "gcm.message_id"
    static let HOME_URL = "https://hahakoreashop.com"
    static let UPLOAD_URL = AppDelegate.HOME_URL + "/m/app/"
    static let PUSH_REG_URL = AppDelegate.HOME_URL + "/m/app/pushRegister.asp"
    static var LANDING_URL = ""
    static var QR_URL = ""
    static var pushkey = ""
    static var imageArray = Array<ImageData>()
    static var ImageFileArray = Array<ImageFileData>()
    static var imageModel = ImageModel()
    static var isChangeImage = false
    static let deviceId = UIDevice.current.identifierForVendor?.uuidString

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // Use Firebase library to configure APIs
//        FirebaseApp.configure()
//        // [START set_messaging_delegate]
//        Messaging.messaging().delegate = self
        // [END set_messaging_delegate]
        // Register for remote notifications. This shows a permission dialog on first run, to
        // show the dialog at a more appropriate time move this registration accordingly.
        // [START register_for_notifications]
        if #available(iOS 10.0, *) {
          // For iOS 10 display notification (sent via APNS)
          UNUserNotificationCenter.current().delegate = self

          let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
          UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: {_, _ in })
        } else {
          let settings: UIUserNotificationSettings =
          UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
          application.registerUserNotificationSettings(settings)
        }

        application.registerForRemoteNotifications()

        // [END register_for_notifications]
        
        return true
    }
    
    // [START receive_message]
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
      // If you are receiving a notification message while your app is in the background,
      // this callback will not be fired till the user taps on the notification launching the application.
      // TODO: Handle data of notification
      // With swizzling disabled you must let Messaging know about the message, for Analytics
//       Messaging.messaging().appDidReceiveMessage(userInfo)
      // Print message ID.
      if let messageID = userInfo[gcmMessageIDKey] {
        print("Message ID: \(messageID)")
      }

      // Print full message.
      print(userInfo)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
      // If you are receiving a notification message while your app is in the background,
      // this callback will not be fired till the user taps on the notification launching the application.
      // TODO: Handle data of notification
      // With swizzling disabled you must let Messaging know about the message, for Analytics
//       Messaging.messaging().appDidReceiveMessage(userInfo)
      // Print message ID.
      if let messageID = userInfo[gcmMessageIDKey] {
        print("Message ID: \(messageID)")
      }

      // Print full message.
      print(userInfo)

      completionHandler(UIBackgroundFetchResult.newData)
    }
    // [END receive_message]
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
      print("Unable to register for remote notifications: \(error.localizedDescription)")
    }

    // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
    // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
    // the FCM registration token.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      print("APNs token retrieved: \(deviceToken)")
    
      // With swizzling disabled you must set the APNs token here.
//       Messaging.messaging().apnsToken = deviceToken
        let tokenParts = deviceToken.map {
            data in String(format: "%02.2hhx", data)
        }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        AppDelegate.pushkey = token
        
        self.requestPushSetting()
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("open url : \(url.absoluteString)")
        UIApplication.shared.open(url, options: [:])
        return true
    }
}

// [START ios_10_message_handling]
@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {

  // Receive displayed notifications for iOS 10 devices.
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo

    // With swizzling disabled you must let Messaging know about the message, for Analytics
//     Messaging.messaging().appDidReceiveMessage(userInfo)
    // Print message ID.
    if let messageID = userInfo[gcmMessageIDKey] {
      print("Message ID: \(messageID)")
    }

    // Print full message.
    print(userInfo)
    guard let arrAPS = userInfo["aps"] as? [String: Any] else { return }
    let strUrl:String = arrAPS["url"] as? String ?? AppDelegate.HOME_URL
    
    AppDelegate.LANDING_URL = strUrl
    completionHandler([])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    // Print message ID.
    if let messageID = userInfo[gcmMessageIDKey] {
      print("Message ID: \(messageID)")
    }

    // Print full message.
    print(userInfo)
    guard let arrAPS = userInfo["aps"] as? [String: Any] else { return }
    let strUrl:String = arrAPS["url"] as? String ?? AppDelegate.HOME_URL
    
    AppDelegate.LANDING_URL = strUrl
    completionHandler()
  }
    
    func requestPushSetting() {
        let defaultConfigObject = URLSessionConfiguration.default
        let defaultSession = URLSession(configuration: defaultConfigObject, delegate: nil, delegateQueue: OperationQueue.main)

        //Create an URLRequest
        let url = URL(string: AppDelegate.PUSH_REG_URL)
        var urlRequest: URLRequest? = nil
        if let url = url {
            urlRequest = URLRequest(url: url)
            
            var dicParam: [AnyHashable : String] = [:]
            dicParam["os"] = "IPhone"
            dicParam["deviceId"] = AppDelegate.deviceId
            dicParam["pushKey"] = AppDelegate.pushkey
            dicParam["memberKey"] = ""

            dicParam["appId"] = ""
            dicParam["userId"] = ""
            dicParam["channelId"] = ""
            dicParam["requestId"] = ""
            
            //Create POST Params and add it to HTTPBody
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dicParam, options: [])
                let params = String(data: jsonData, encoding: .utf8) ?? ""
                
                urlRequest?.httpMethod = "POST"
                urlRequest?.httpBody = params.data(using: .utf8)
                urlRequest?.setValue("text/html", forHTTPHeaderField: "Content-Type")
                #if DEBUG
                print("params : \(params)")
                print("params : \(urlRequest)")

                #endif
                
                let dataTask = defaultSession.dataTask(with: urlRequest!, completionHandler: { data, response, error in
                    //Handle your response here

            
                    if let error = error {
                        print("error : \(error)")
                    }
                    if let response = response {
                        print("response : \(response)")
                    }

                    if data != nil {
                        var jsonError: Error?
                        var dicResData: String? = nil
                        do {
                            if let data = data {
                                dicResData = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? String
                            }
                        } catch let jsonError {
                        }


                        let jsonData = dicResData?.data(using: .utf8)

                        print("jsonData : \(jsonData ?? nil)")
                        if let jsonError = jsonError {
                            print("jsonData : \(jsonError)")
                        }


                        var sResultData: String? = nil
                        if let data = data {
                            sResultData = String(data: data, encoding: .utf8)
                        }

                        print("sResultData : \(sResultData ?? "")")
                    }
                })
                dataTask.resume()
                } catch let error as NSError {
                    print(error)
                }
            
        }
    }
}
// [END ios_10_message_handling]
