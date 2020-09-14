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
#import "SysUtils.h"
#import "Constants.h"
#import "JSON.h"
#import "NSString+UUID.h"
#import "PictureSelectScreen.h"
#import "PhotoBrowserScreen.h"

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
}


- (void)applicationWillTerminate:(UIApplication *)application {

}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
#ifdef DEBUG
    NSLog(@"token register failed");
#endif
    
    
#if TARGET_IPHONE_SIMULATOR
    //    [[NSUserDefaults standardUserDefaults] setObject:@"SIMULATOR-TOKEN-1111111" forKey:@"pushtoken"];
#endif
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    
    NSString *sUrl = [url absoluteString];
    
    if ([[sUrl lowercaseString] hasPrefix:[NSString stringWithFormat:@"%@://", kCommAppUrlScheme]] == YES) {
        
        sUrl = [sUrl stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@://", kCommAppUrlScheme] withString:@""];
        //sUrl = [NSString stringWithFormat:@"%@/%@?url=%@", kWebSiteUrl, @"addon/live/live_reg.asp", sUrl];
        [_vcHome webPageCall:sUrl];
        //[SysUtils showMessage:sUrl];
        return YES;
    }
    
    
    return YES;
}

- (void)httpClearCache {
    NSHTTPCookieStorage * storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    for( NSHTTPCookie * cookie in [storage cookies] ) {
        [storage deleteCookie:cookie];
    }
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
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



