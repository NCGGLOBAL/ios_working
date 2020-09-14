//
//  AppDelegate.m
//
//  Created by JungWoon Kwon on 2016. 5. 26..
//  Copyright © 2016년 JungWoon Kwon. All rights reserved.
//

#import "AppDelegate.h"
#import "HomeScreen.h"
#import "GateViewScreen.h"
#import "PictureGateScreen.h"
#import "AGPushNoteView.h"
#import "SysUtils.h"
#import "Constants.h"
#import "JSON.h"
#import "NSString+UUID.h"
#import "PictureSelectScreen.h"
#import "PhotoBrowserScreen.h"

#import "NaverThirdPartyLoginConnection.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <KakaoOpenSDK/KakaoOpenSDK.h>


@interface AppDelegate () {
    HomeScreen *_vcHome;
    GateViewScreen *_ncGate;
    PictureGateScreen *_ncPictureGate;
    
    id              _ctrlSender;
    SEL             _ctrlReceiver;
    BOOL            _ctrlDismissAnimation;

}

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    
    [FIRApp configure];
    [FIRMessaging messaging].delegate = self;
    
    
    // 매신저 연동관련
//    [[FBSDKApplicationDelegate sharedInstance] application:application
//                             didFinishLaunchingWithOptions:launchOptions];
//    
//    [FBSDKSettings setAppID:kFacebookApiKey];
    [KOSession sharedSession].clientSecret = kKakaoApiKey;

    
    if ([UNUserNotificationCenter class] != nil) {
        // iOS 10 or later
        // For iOS 10 display notification (sent via APNS)
        UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert |
        UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
        [[UNUserNotificationCenter currentNotificationCenter]
         requestAuthorizationWithOptions:authOptions
         completionHandler:^(BOOL granted, NSError * _Nullable error) {
             // ...
         }];
    } else {
        // iOS 10 notifications aren't available; fall back to iOS 8-9 notifications.
        UIUserNotificationType allNotificationTypes =
        (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [application registerUserNotificationSettings:settings];
    }
    
    [application registerForRemoteNotifications];
    
    //    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
    
    //쿠키 및 캐시삭제
    //    [self httpClearCache];
    
    
    //최초 뷰를 처리
    _vcHome = [[HomeScreen alloc] initWithNibName:@"HomeScreen" bundle:nil];
    _vcHome.view.tag = 41;
    
    
    // 네비게이션 생성
    _ncGate = [[GateViewScreen alloc] initWithRootViewController:_vcHome];
    self.window.rootViewController = _ncGate;
    
    [self.window makeKeyAndVisible];
    
    
    
    if (launchOptions) { //launchOptions is not nil
        NSDictionary *userInfo = [launchOptions valueForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        NSDictionary *apsInfo = [userInfo objectForKey:@"aps"];
        
        if (apsInfo) { //apsInfo is not nil
            [self performSelector:@selector(pushReciveAferSetting:)
                       withObject:userInfo
                       afterDelay:1.0];
        }
    }
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {

}


- (void)applicationDidEnterBackground:(UIApplication *)application {

}


- (void)applicationWillEnterForeground:(UIApplication *)application {

}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    
    [KOSession handleDidBecomeActive];
}


- (void)applicationWillTerminate:(UIApplication *)application {

}


- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [FIRMessaging messaging].APNSToken = deviceToken;
    
    NSString* inDeviceTokenStr	= [deviceToken description];
    
    NSString* tokenString		= [[inDeviceTokenStr stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"< >"]]stringByReplacingOccurrencesOfString:@" " withString:@""];
    
#ifdef DEBUG
    NSLog(@"tokenString : %@", tokenString);
#endif
    
    //[self requestPushSetting:tokenString];
}


- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
#ifdef DEBUG
    NSLog(@"token register failed");
#endif
    
    
#if TARGET_IPHONE_SIMULATOR
    //    [[NSUserDefaults standardUserDefaults] setObject:@"SIMULATOR-TOKEN-1111111" forKey:@"pushtoken"];
#endif
}


- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
#ifdef DEBUG
    NSLog(@"===================================%@", userInfo);
#endif
    
    if (application.applicationState == UIApplicationStateActive) {
        NSDictionary *infoDic = [userInfo objectForKey:@"aps"];
        //1: 공지사항, 2:Service Status
        if (infoDic) {
            NSString *sMessage = [[infoDic objectForKey:@"alert"] objectForKey:@"body"];
            
            if (sMessage) {
                [AGPushNoteView showWithNotificationMessage:sMessage];
                [AGPushNoteView setMessageAction:^(NSString *message) {
                    //뱃지 초기화
                    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
                    
                    [self pushReciveAferSetting:userInfo];
                }];
                
                [self performSelector:@selector(pushViewClose)
                           withObject:nil
                           afterDelay:3.0];

            }
        }
        
    } else {
        [self pushReciveAferSetting:userInfo];
    }
}


- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    
    NSString *sUrl = [url absoluteString];
    
    if ([[sUrl lowercaseString] hasPrefix:[NSString stringWithFormat:@"%@://", kCommAppUrlScheme]] == YES) {
        
        if ([[url host] isEqualToString:kCheckResultPage]) {
            // 네이버앱으로부터 전달받은 url값을 NaverThirdPartyLoginConnection의 인스턴스에 전달
            NaverThirdPartyLoginConnection *thirdConnection = [NaverThirdPartyLoginConnection getSharedInstance];
            THIRDPARTYLOGIN_RECEIVE_TYPE resultType = [thirdConnection receiveAccessToken:url];
            
            if (SUCCESS == resultType) {
                NSLog(@"Getting auth code from NaverApp success!");
            } else {
                // 앱에서 resultType에 따라 실패 처리한다.
            }
            
            return YES;
        }
        
        sUrl = [sUrl stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@://", kCommAppUrlScheme] withString:@""];
        //sUrl = [NSString stringWithFormat:@"%@/%@?url=%@", kWebSiteUrl, @"addon/live/live_reg.asp", sUrl];
        [_vcHome webPageCall:sUrl];
        //[SysUtils showMessage:sUrl];
        return YES;
    } else if ([[sUrl lowercaseString] hasPrefix:[NSString stringWithFormat:@"fb%@://", kFacebookApiKey]] == YES) {
        if ([sourceApplication isEqualToString:@"com.facebook.Facebook"] == YES) {
            BOOL handled = [[FBSDKApplicationDelegate sharedInstance] application:application
                                                                          openURL:url
                                                                sourceApplication:sourceApplication
                                                                       annotation:annotation
                            ];
            
            
            
            // Add any custom logic here.
            return handled;
        }
    } else if ([[sUrl lowercaseString] hasPrefix:[NSString stringWithFormat:@"kakao%@://", kKakaoApiKey]] == YES) {
        if ([KOSession isKakaoAccountLoginCallback:url]) {
            return [KOSession handleOpenURL:url];
        } else {
            [SysUtils showMessage:@"call back return NO"];
        }
        
        return YES;
    }
    
    
    return YES;
}

- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    NSLog(@"FCM registration token: %@", fcmToken);
    
    [self requestPushSetting:fcmToken];
}

- (void)messaging:(FIRMessaging *)messaging didReceiveMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    NSLog(@"Received data message: %@", remoteMessage.appData);
}


- (void)pushViewClose {
    [AGPushNoteView close];
}


- (void)httpClearCache {
    NSHTTPCookieStorage * storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    for( NSHTTPCookie * cookie in [storage cookies] ) {
        [storage deleteCookie:cookie];
    }
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}


- (void)pushReciveAferSetting:(NSDictionary *)aUserInfo {
    NSString *sPushUid = [aUserInfo objectForKey:@"pushUid"];
    
    if ([SysUtils isNull:sPushUid] == NO)
        [_vcHome requestPushRecive:sPushUid];
    
    
    
    NSString *sNextPage = [aUserInfo objectForKey:@"url"];
    
    if ([SysUtils isNull:sNextPage] == NO)
        [_vcHome webPageCall:sNextPage];
    
}


- (void)requestPushSetting:(NSString *)sPushToken {
    NSString *sUrl = [NSString stringWithFormat:@"%@/%@", kWebSiteUrl, @"m/app/pushRegister.asp"];
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
    
    //Create an URLRequest
    NSURL *url = [NSURL URLWithString:sUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    
    NSMutableDictionary *dicParam = [NSMutableDictionary dictionary];
    [dicParam setObject:@"IPhone" forKey:@"os"];
    [dicParam setObject:[NSString uuid] forKey:@"deviceId"];
    [dicParam setObject:sPushToken forKey:@"pushKey"];
    [dicParam setObject:@"" forKey:@"memberKey"];
    
    [dicParam setObject:@"" forKey:@"appId"];
    [dicParam setObject:@"" forKey:@"userId"];
    [dicParam setObject:@"" forKey:@"channelId"];
    [dicParam setObject:@"" forKey:@"requestId"];
    
    //ASPSESSIONIDCSQSSBRT
    
    //Create POST Params and add it to HTTPBody
    NSString *params = [NSString stringWithFormat:@"%@", [dicParam JSONRepresentation]];
    
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody:[params dataUsingEncoding:NSUTF8StringEncoding]];
    [urlRequest setValue:@"text/html" forHTTPHeaderField:@"Content-Type"];
#if DEBUG
    NSLog(@"params : %@", params);
    NSLog(@"params : %@", urlRequest);
#endif
    
    //Create task
    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        //Handle your response here
        
#if DEBUG
        NSLog(@"error : %@", error);
        NSLog(@"response : %@", response);
        
        if (data) {
            NSError *jsonError;
            NSString *dicResData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
            
            
            NSString *jsonData = [dicResData JSONRepresentation];
            
            NSLog(@"jsonData : %@", jsonData);
            NSLog(@"jsonData : %@", jsonError);
            
            
            NSString *sResultData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            NSLog(@"sResultData : %@", sResultData);
        }
#endif
        
    }];
    
    [dataTask resume];
    
}


- (void)callPhotoMain {
    PictureSelectScreen *photoSelector = [[PictureSelectScreen alloc] initWithNibName:@"PictureSelectScreen" bundle:nil];
    //photoSelector.delegate = self;

    
    if (!_ncPictureGate) {
        _ncPictureGate = [[PictureGateScreen alloc] initWithRootViewController:photoSelector];
        [_ncPictureGate setNavigationBarHidden:NO animated:NO];
    }

    //[_ncGate presentViewController:_ncPictureGate animated:YES completion:nil];
    [_ncGate presentViewController:_ncPictureGate animated:YES completion:nil];
}




@end



