//
//  AppDelegate.swift
//  UnniTv
//
//  Created by glediaer on 2020/05/27.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import UIKit
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    let gcmMessageIDKey = "gcm.message_id"
    static var HOME_URL = "https://live-n.co.kr"
    static let UPLOAD_URL = AppDelegate.HOME_URL + "/m/app/"
    static let PUSH_REG_URL = AppDelegate.HOME_URL + "/m/app/pushRegister.asp"
    static var LANDING_URL = ""
    static let deviceId = UIDevice.current.identifierForVendor?.uuidString
    static var QR_URL = ""
    static var pushkey = ""
    static var imageArray = Array<ImageData>()
    static var ImageFileArray = Array<ImageFileData>()
    static var imageModel = ImageModel()
    static var isChangeImage = false
    static let openUrlSchemeKakao = "kakaoplus"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // Use Firebase library to configure APIs
        FirebaseApp.configure()
        // [START set_messaging_delegate]
        Messaging.messaging().delegate = self
        Messaging.messaging().shouldEstablishDirectChannel = true
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
       Messaging.messaging().appDidReceiveMessage(userInfo)
      // Print message ID.
      if let messageID = userInfo[gcmMessageIDKey] {
        #if DEBUG
        print("Message ID: \(messageID)")
        #endif
      }

      // Print full message.
        #if DEBUG
        print(userInfo)
        #endif
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
      // If you are receiving a notification message while your app is in the background,
      // this callback will not be fired till the user taps on the notification launching the application.
      // TODO: Handle data of notification
      // With swizzling disabled you must let Messaging know about the message, for Analytics
       Messaging.messaging().appDidReceiveMessage(userInfo)
      // Print message ID.
      if let messageID = userInfo[gcmMessageIDKey] {
        #if DEBUG
        print("Message ID: \(messageID)")
        #endif
      }

      // Print full message.
        #if DEBUG
        print(userInfo)
        #endif

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
        #if DEBUG
        print("APNs token retrieved: \(deviceToken)")
        #endif
      // With swizzling disabled you must set the APNs token here.
       Messaging.messaging().apnsToken = deviceToken
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
        #if DEBUG
        print("open url : \(url.absoluteString)")
        #endif
//        if (AuthApi.isKakaoTalkLoginUrl(url)) {
//            return AuthController.handleOpenUrl(url: url)
//        }
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
     Messaging.messaging().appDidReceiveMessage(userInfo)
    // Print message ID.
    if let messageID = userInfo[gcmMessageIDKey] {
        #if DEBUG
        print("Message ID: \(messageID)")
        #endif
    }

    // Print full message.
    print(userInfo)

    // Change this to your preferred presentation option
    AppDelegate.LANDING_URL = userInfo["url"] as? String ?? AppDelegate.HOME_URL
    completionHandler([])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    // Print message ID.
    if let messageID = userInfo[gcmMessageIDKey] {
        #if DEBUG
        print("Message ID: \(messageID)")
        #endif
    }
    // Print full message.
    #if DEBUG
    print(userInfo)
    #endif
    AppDelegate.LANDING_URL = userInfo["url"] as? String ?? AppDelegate.HOME_URL
    completionHandler()
  }

}
// [END ios_10_message_handling]

extension AppDelegate : MessagingDelegate {
  // [START refresh_token]
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
    #if DEBUG
    print("Firebase registration token: \(fcmToken)")
    #endif
    AppDelegate.pushkey = fcmToken
    let dataDict:[String: String] = ["token": fcmToken]
    NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
    self.requestPushSetting()
    // TODO: If necessary send token to application server.
    // Note: This callback is fired at each app startup and whenever a new token is generated.
  }
  // [END refresh_token]
  // [START ios_10_data_message]
  // Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
  // To enable direct data messages, you can set Messaging.messaging().shouldEstablishDirectChannel to true.
  func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
    #if DEBUG
    print("Received data message: \(remoteMessage.appData)")
    #endif
  }
  // [END ios_10_data_message]
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

                #if DEBUG
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
                #endif

                })
                dataTask.resume()
                } catch let error as NSError {
                    print(error)
                }
        }
    }
}


