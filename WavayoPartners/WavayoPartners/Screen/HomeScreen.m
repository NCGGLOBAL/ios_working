//
//  HomeScreen.m
//
//  Created by JungWoon Kwon on 2016. 5. 26..
//  Copyright © 2016년 JungWoon Kwon. All rights reserved.
//

#import "HomeScreen.h"
#import "SysUtils.h"
#import "DateUtils.h"
#import "AppDelegate.h"
#import "JSON.h"
#import "StrUtils.h"
#import "NSString+UUID.h"
#import "Constants.h"
#import "ZBarReaderViewController.h"
#import "NSData+Base64.h"
#import "PictureSelectScreen.h"
#import "SessionManager.h"
#import "SubWebViewScreen.h"
#import "SubWebViewScreen.h"

#import "NaverThirdPartyLoginConnection.h"
#import "NLoginThirdPartyOAuth20InAppBrowserViewController.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <KakaoOpenSDK/KakaoOpenSDK.h>


@interface HomeScreen () <UIWebViewDelegate, ZBarReaderDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, PictureSelectDelegate, SubWebViewScreenDelegate, NaverThirdPartyLoginConnectionDelegate> {
    NSString *_accessToken;
    NSString *_openid;
    NSString *imageUploadUrl;
    
    BOOL bFirstInit;
    
    NSString *_sCallback;
    NSString *_sTokenValue;
    NSInteger _nPageGbn;
    NSInteger _nImgCnt;
    NSInteger _cameraType;
    
    NSMutableArray *_arrLastAddPicture;
}

@end


@implementation HomeScreen

NSString* const kKeyOfWebActionKeyName                  = @"iwebaction";
NSString* const kKeyOfWebActionCode                     = @"action_code";
NSString* const kKeyOfWebActionParams                   = @"action_param";
NSString* const kKeyOfWebActionCallback                 = @"callBack";


#pragma mark-
#pragma mark LifeCycle Method
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.navigationController) {
        [self.navigationController setToolbarHidden:YES animated:NO];
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
}
    
    
- (void)viewDidLoad {
    [super viewDidLoad];

    bFirstInit = YES;
    
//    [_aiWaitting startAnimating];
//
//    [self.view addSubview:_vLoding];
//
//
//    if ([SysUtils isIPN5] == NO)
//        _ivLodingTemp.image = [UIImage imageNamed:@"bg480h.png"];
    
    
    
    NSURL *sUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@", (NSString *)kWebSiteUrl]];
    //NSURL *sUrl = [NSURL URLWithString:@"http://www.naver.com"];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:sUrl
                                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                            timeoutInterval:30.0f];


    NSString *sUserAgent = [_webMain stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];

    if ([SysUtils isNull:sUserAgent] == YES) {
        sUserAgent = [NSString stringWithFormat:kUserAgentFormat,
                        [[UIDevice currentDevice] model],
                        [[UIDevice currentDevice] systemName],
                        [[[UIDevice currentDevice] systemVersion] stringByReplacingOccurrencesOfString:@"." withString:@"_"]];
    }
    
    
    sUserAgent = [NSString stringWithFormat:@"%@;%@", sUserAgent, @"device=app"];

    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:sUserAgent, @"UserAgent", nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [_webMain setBackgroundColor:[UIColor whiteColor]];
    [_webMain setOpaque:NO];

    [_webMain loadRequest:request];
    
}

- (void)testSetting:(NSURLRequest *)request {
    [_webMain loadRequest:request];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if ([SysUtils isNull:request] == YES || [SysUtils isNull:[request URL]] == YES)
        return NO;
    
    
    NSString* sURLScheme	= [[request URL] scheme];
    NSString* sURL			= [[request URL] absoluteString];
    NSString* sEscapedURL	= nil;
    NSString* sDecodedURL	= nil;
    
    
    if (([SysUtils isNull:sURLScheme] == YES) || ([SysUtils isNull:sURL] == YES))
        return NO;
    
    
    sEscapedURL	= [sURL stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    
    if ([SysUtils isNull:sEscapedURL] == YES)
        return NO;
    
#if DEBUG
    NSLog(@"URL [%@]", sURL);
    NSLog(@"Escaped URL [%@]", sEscapedURL);
#endif
    
    if ([sURLScheme isEqualToString:kKeyOfWebActionKeyName] == YES) {
        sDecodedURL = [sEscapedURL stringByReplacingOccurrencesOfString:@"iwebaction:" withString:@""];
        
        if ([SysUtils isNull:sDecodedURL] == YES)
            return NO;
        
        [self parseWebAction:sDecodedURL];
    }
    
    return YES;
}


- (void)webViewDidStartLoad:(UIWebView *)webView {
#if DEBUG
    NSLog(@"webViewDidStartLoad");
#endif
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}


- (void)webViewDidFinishLoad:(UIWebView *)webView {
#if DEBUG
    NSLog(@"webViewDidFinishLoad");
#endif
    
    if (bFirstInit == YES) {
        //[_aiWaitting stopAnimating];
        
        //[_vLoding removeFromSuperview];
    }
    
    bFirstInit = NO;
    
    [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('dv_id', '%@');", @"localStorage.setItem", [NSString uuid]]];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}



- (void)parseWebAction:(NSString *)aSource {
    aSource = [aSource stringByReplacingOccurrencesOfString:@"/\"" withString:@"\\\""];
    
    NSDictionary* dicSource = [aSource JSONValue];
    
    
    if (([SysUtils isNull:dicSource] == YES) || (dicSource.count <= 0))
        return;
    
    
#if DEBUG
    NSLog(@"=================%@", [dicSource description]);
#endif
    
    
    NSString* sActionCode = [dicSource objectForKey:kKeyOfWebActionCode];
    
    
    if ([SysUtils isNull:sActionCode] == YES)
        return;
    
    
    // 콜백 함수를 저장한다.
    _sCallback  = [[SysUtils nullToVoid:[dicSource objectForKey:kKeyOfWebActionCallback]] trim];
    
    
    // 웹액션 코드에 따른 수행
    if ([sActionCode isEqualToString:@"ACT1001"] == YES)
        [self callPhotoMake:[dicSource objectForKey:kKeyOfWebActionParams]];
    else if ([sActionCode isEqualToString:@"ACT1002"] == YES)
        [self callQRCode:[dicSource objectForKey:kKeyOfWebActionParams]];
    else if ([sActionCode isEqualToString:@"ACT1003"] == YES)
        [self goWechatPay:[dicSource objectForKey:kKeyOfWebActionParams]];
    else if ([sActionCode isEqualToString:@"ACT1004"] == YES)
        [self customMakeSoundEffect];
    else if ([sActionCode isEqualToString:@"ACT1011"] == YES)
        [self callPhotoMake:[dicSource objectForKey:kKeyOfWebActionParams]];
    else if ([sActionCode isEqualToString:@"ACT1012"] == YES)
        [self transPhotoData:[dicSource objectForKey:kKeyOfWebActionParams]];
    else if ([sActionCode isEqualToString:@"ACT1013"] == YES)
        [self deviceInfoSetting];
    else if ([sActionCode isEqualToString:@"ACT1014"] == YES)
        [self openAppSchem:[dicSource objectForKey:kKeyOfWebActionParams]];
    else if ([sActionCode isEqualToString:@"ACT1015"] == YES)
        [self callSubWebview:[dicSource objectForKey:kKeyOfWebActionParams]];
    else if ([sActionCode isEqualToString:@"ACT1020"] == YES)
        [self callSNSLogin:[dicSource objectForKey:kKeyOfWebActionParams]];

    
}


- (void)callSNSLogin:(NSArray *)aParams {
    if ([SysUtils isNull:aParams] == YES)
        return;
    
    NSDictionary *dicData = [aParams objectAtIndex:0];
    
    NSInteger nSnsType = [[dicData objectForKey:@"snsType"] integerValue];      // 1: 네이버 로그인, 2:카카오 로그인, 3,facebook 로그인
    
    if (nSnsType == 1) {
        NaverThirdPartyLoginConnection *thirdConn = [NaverThirdPartyLoginConnection getSharedInstance];
        //    [thirdConn setOnlyPortraitSupportInIphone:YES];
        
        [thirdConn setServiceUrlScheme:kCommAppUrlScheme];
        [thirdConn setConsumerKey:kNaverConsumerKey];
        [thirdConn setConsumerSecret:kNaverConsumerSecret];
        [thirdConn setAppName:kCommServiceAppName];
        
        thirdConn.delegate = self;
        //[thirdConn requestAccessTokenWithRefreshToken];
        [thirdConn requestThirdPartyLogin];
        
    } else if (nSnsType == 2) {
        [[KOSession sharedSession] close];
        
        [[KOSession sharedSession] openWithCompletionHandler:^(NSError *error) {
            if ([[KOSession sharedSession] isOpen]) {
                
                [self requestKakaoProfile:[KOSession sharedSession].token.accessToken];
                //                NSDictionary *dicResult = [NSDictionary dictionaryWithObjectsAndKeys:[KOSession sharedSession].token.accessToken, @"accessToken", nil];
                //
                //                [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [dicResult JSONRepresentation]]];
                
            } else {
                // failed
                [SysUtils showMessage:NSLocalizedString(@"str_fail_auth", comment: "")];
            }
        } authType:(KOAuthType)KOAuthTypeTalk, nil];
        
        
    } else if (nSnsType == 3) {
        if ([FBSDKAccessToken currentAccessToken]) {
            NSDictionary *dicResult = [NSDictionary dictionaryWithObjectsAndKeys:[FBSDKAccessToken currentAccessToken].tokenString, @"accessToken", nil];
            
            [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [dicResult JSONRepresentation]]];
            
        } else {
            FBSDKLoginManager *loginManager = [[FBSDKLoginManager alloc] init];
            [loginManager logInWithReadPermissions:@[@"email"]
                                fromViewController:self
                                           handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
                                               //TODO: process error or result
                                               
                                               NSDictionary *dicResult = [NSDictionary dictionaryWithObjectsAndKeys:result.token.tokenString, @"accessToken", nil];
                                               
                                               [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [dicResult JSONRepresentation]]];
                                           }];
        }
    }
}


- (void)callSubWebview:(NSArray *)aParams {
    if ([SysUtils isNull:aParams] == YES)
        return;
    
    NSDictionary *dicData = [aParams objectAtIndex:0];
    
    NSString *sRequestUrl = [SysUtils nullToVoid:[dicData objectForKey:@"url"]];
    
    if ([SysUtils isNull:sRequestUrl] == YES)
        return;
    

    SubWebViewScreen *callScreen = [[SubWebViewScreen alloc] initWithNibName:@"SubWebViewScreen" bundle:nil];
    callScreen.delegate = self;
    callScreen.requestUrl = sRequestUrl;
    
    [self presentViewController:callScreen animated:YES completion:nil];
}


- (void)openAppSchem:(NSArray *)aParams {
    if ([SysUtils isNull:aParams] == YES)
        return;

    NSDictionary *dicData = [aParams objectAtIndex:0];
    
    NSString *sOpenUrl = [SysUtils nullToVoid:[dicData objectForKey:@"url"]];
    
    if ([SysUtils isNull:sOpenUrl] == YES)
        return;

    NSURL *url = [NSURL URLWithString:sOpenUrl];
    
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}


- (void)deviceInfoSetting {
    NSString *sCurrVer = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]; //현재 버전정보 가지고옴.
    
    NSDictionary *dicResult = [NSDictionary dictionaryWithObjectsAndKeys:@"i", @"device", [NSString uuid], @"deviceId", sCurrVer, @"version", nil];
    
    [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [dicResult JSONRepresentation]]];
}


- (void)callQRCode:(NSArray *)aParams {
    if ([SysUtils isNull:aParams] == YES)
        return;

    NSDictionary *dicData = [aParams objectAtIndex:0];
    
    _cameraType = 0;    // 0: QR, 1: 사진찍기
    
    NSString *sCameraType = [SysUtils nullToVoid:[dicData objectForKey:@"key_type"]];   // 0 :앞면, 1: 후면
    
    
    ZBarReaderViewController *reader = [ZBarReaderViewController new];
    reader.readerDelegate = self;
    reader.supportedOrientationsMask = ZBarOrientationMaskAll;
    
    if ([sCameraType isEqualToString:@"0"] == YES)
        reader.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    
    
    ZBarImageScanner *scanner = reader.scanner;
    // TODO: (optional) additional reader configuration here
    
    // EXAMPLE: disable rarely used I2/5 to improve performance
    [scanner setSymbology: ZBAR_I25
                   config: ZBAR_CFG_ENABLE
                       to: 0];
    
    
    [self presentViewController:reader animated:YES completion:nil];
}


- (void)goWechatPay:(NSArray *)aParams {
    if ([SysUtils isNull:aParams] == YES)
        return;
    
    NSDictionary *dicData = [aParams objectAtIndex:0];
    
    NSString *sRequestUrl = [SysUtils nullToVoid:[dicData objectForKey:@"request_url"]];
    
    if ([SysUtils isNull:sRequestUrl] == YES)
        return;
    
    NSURL *sUrl = [NSURL URLWithString:sRequestUrl];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:sUrl
                                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                            timeoutInterval:30.0f];
    
    
    NSString *sUserAgent = [_webMain stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    
    if ([SysUtils isNull:sUserAgent] == YES) {
        sUserAgent = [NSString stringWithFormat:kUserAgentFormat,
                      [[UIDevice currentDevice] model],
                      [[UIDevice currentDevice] systemName],
                      [[[UIDevice currentDevice] systemVersion] stringByReplacingOccurrencesOfString:@"." withString:@"_"]];
    }
    
    
    sUserAgent = [NSString stringWithFormat:@"%@;%@", sUserAgent, @"device=app"];
    //sUserAgent = [NSString stringWithFormat:@"%@;%@=%@", sUserAgent, @"deviceId", [NSString uuid]];
    
    NSDictionary *dic = @{@"UserAgent" : sUserAgent};
    [[NSUserDefaults standardUserDefaults] registerDefaults:dic];
    
    [request addValue:sUserAgent forHTTPHeaderField:@"User-Agent"];

    
    [_webMain loadRequest:request];
}


- (void)customMakeSoundEffect {
    [SysUtils makeSoundEffect];
}


- (void)callPhotoMake:(NSArray *)aParams {
    if ([SysUtils isNull:aParams] == YES)
        return;
    
    NSDictionary *dicData = [aParams objectAtIndex:0];

    
    NSString *sTokenValue = [dicData objectForKey:@"token"];
    _nPageGbn = [[dicData objectForKey:@"pageGbn"] integerValue];
    _nImgCnt  = [[dicData objectForKey:@"cnt"] integerValue];
    
    if ([SysUtils isNull:sTokenValue] == YES)
        return;

    _sTokenValue = [sTokenValue copy];

    
    [SysUtils showWaitingSplash];

    NSArray *arrImage = [dicData objectForKey:@"imgArr"];

    [self performSelector:@selector(pictureScreenCall:)
               withObject:arrImage
               afterDelay:0.3];

    
    

    
}


- (void)pictureScreenCall:(NSArray *)aParam {
    PictureSelectScreen *photoSelector = [[PictureSelectScreen alloc] initWithNibName:@"PictureSelectScreen" bundle:nil];
    
    photoSelector.delegate = self;
    photoSelector.pageGbn = _nPageGbn;
    photoSelector.pageCnt = _nImgCnt;
    
    UINavigationController *ncPictureGate = [[UINavigationController alloc] initWithRootViewController:photoSelector];
    
    [self presentViewController:ncPictureGate animated:YES completion:nil];
    
    [photoSelector drowPhotoData:aParam];

}


- (void)transPhotoData:(NSArray *)aParams {
    if ([SysUtils isNull:aParams] == YES)
        return;
    
    NSDictionary *dicData = [aParams objectAtIndex:0];

    NSString *sTokenValue = [dicData objectForKey:@"token"];
    imageUploadUrl = [dicData objectForKey:@"domain"];
    
    
    if ([SysUtils isNull:sTokenValue] == YES)
        return;
    
//    if ([SysUtils isNull:_arrLastAddPicture] == YES)
//        return;
    
    
    [SysUtils showWaitingSplash];
    
//    NSString *sUrl = [NSString stringWithFormat:@"%@/%@", kWebSiteUrl, @"m/app/"];    //  http://osaka.wavayo.com/api/
    
    NSString *boundary = @"WebKitFormBoundaryDCqbvCHcQvEfbSAa";     // 업로드 바이너리 이름
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
    
    //Create an URLRequest
    if (imageUploadUrl == nil || [imageUploadUrl isEqual: @""]) {
        imageUploadUrl = kImageUploadUrl;
    }
    NSURL *url = [NSURL URLWithString:imageUploadUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    
    
    // post body
    NSMutableData *body = [NSMutableData data];
    
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", @"service"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", @"GOODSIMGSREG"] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", @"token"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", sTokenValue] dataUsingEncoding:NSUTF8StringEncoding]];
    
    
    // add image data
    UIImage *imageToUpload  = nil;  // 업로드할 이미지
    NSData *imageData       = nil;  // 업로드할 이미지 스트림
    NSString *sImageName    = nil;
    
    for (NSInteger i=0; i < [_arrLastAddPicture count]; i++) {
        sImageName = [[_arrLastAddPicture objectAtIndex:i] objectForKey:@"fileName"];
        
        imageToUpload = (UIImage *)[[_arrLastAddPicture objectAtIndex:i] objectForKey:@"imageData"];
        
        if (!imageToUpload)
            continue;
        
        imageData = UIImageJPEGRepresentation(imageToUpload, 1.0f);
        
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"imgFile\"; filename=\"%@\"\r\n", sImageName]dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:imageData];
        [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [urlRequest setValue:contentType forHTTPHeaderField: @"Content-Type"];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody:body];
    
    //[urlRequest setHTTPBody:[params dataUsingEncoding:NSUTF8StringEncoding]];
    //[urlRequest setValue:@"text/html" forHTTPHeaderField:@"Content-Type"];
#if DEBUG
    NSLog(@"params : %@", body);
    //NSLog(@"params : %@", params);
    NSLog(@"params : %@", urlRequest);
#endif
    
    //Create task
    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        //Handle your response here
        
        if (data) {
            [SysUtils closeWaitingSplash];
            
            //NSError *jsonError;
            //NSDictionary *dicResData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
            
            NSString *sResultData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            sResultData = [sResultData stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
            sResultData = [sResultData stringByReplacingOccurrencesOfString:@"\t" withString:@""];
            
            NSDictionary *dicResData = [sResultData JSONValue];
            
            [self performSelector:@selector(transAferMsg:)
                       withObject:dicResData
                       afterDelay:0.5];

            [SessionManager sharedSessionManager].tempImageList = [NSMutableArray array];
            [SessionManager sharedSessionManager].transImageData = [NSMutableArray array];
            [SessionManager sharedSessionManager].transModGbn = nil;
        }
        
        
    }];
    
    [dataTask resume];
    
}


- (void)transAferMsg:(NSDictionary *)aParams {
    if ([SysUtils isNull:aParams] == NO) {
        if ([aParams objectForKey:@"resCode"] && [[aParams objectForKey:@"resCode"] isEqualToString:@"0000"]) {
            
        }
        
        [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [aParams JSONRepresentation]]];
    } else {
        NSDictionary *dicResult = [NSDictionary dictionaryWithObjectsAndKeys:@"9999", @"resCode", NSLocalizedString(@"str_fail_network", comment: ""), @"resCode", nil];
        
        [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [dicResult JSONRepresentation]]];
    }
}


- (void)imagePickerController: (UIImagePickerController*) reader didFinishPickingMediaWithInfo: (NSDictionary*) info {
    [reader dismissViewControllerAnimated:YES completion:nil];
    
    if (_cameraType == 1) {
        UIImage *photoImage = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage];
        
        [self displayImages:[NSArray arrayWithObject:photoImage]];
        
        return;
    }

    
    if ([SysUtils isNull:_sCallback] == YES) {
        [SysUtils showMessage:@"not callback"];
        return;
    }
    
    // ADD: get the decode results
    id<NSFastEnumeration> results = [info objectForKey: ZBarReaderControllerResults];
    ZBarSymbol *symbol = nil;
    
    for (symbol in results)
        // EXAMPLE: just grab the first barcode
        break;
    
    NSLog(@"test : %@", symbol.data);
    
    
    NSDictionary *resultDic = [NSDictionary dictionaryWithObjectsAndKeys:symbol.data, @"returnCode", nil];
    
    [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [resultDic JSONRepresentation]]];
    
    
    // EXAMPLE: do something useful with the barcode data
//    resultText.text = symbol.data;
//    
//    // EXAMPLE: do something useful with the barcode image
//    resultImage.image = [info objectForKey: UIImagePickerControllerOriginalImage];
    
    // ADD: dismiss the controller (NB dismiss from the *reader*!)
    
    
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:NO completion:nil];
}


- (void)displayImages:(NSArray *)images {
    if ([SysUtils isNull:images] == YES)
        return;
   

    if ([SysUtils isNull:_sCallback] == YES) {
        [SysUtils showMessage:@"not callback"];
        return;
    }
    
    if ([images count] <= 0)
        return;
    
    NSMutableArray *arrResult   = [[NSMutableArray alloc] init];
    NSData * imageData          = nil;
    NSString *imageString       = nil;

    
//    CGFloat tempF = 50.0f;
    for (UIImage *image in images) {
        imageData = UIImageJPEGRepresentation(image, 0.6);
        //imageData = [NSData dataWithData:UIImagePNGRepresentation(image)];
        imageString = [(NSString *)[imageData base64EncodedString] stringByURLEncode];
        
        [arrResult addObject:imageString];
        
        
        //TODO:TEST
//        UIImageView *testImage = [[UIImageView alloc] initWithImage:image];
//        testImage.frame = CGRectMake(10.0f, tempF, 30.0f, 30.0f);
//        [_webMain addSubview:testImage];
//        
//        tempF += 40.0f;
    }
    
    
    [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [arrResult JSONRepresentation]]];
}


- (void)requestPushRecive:(NSString *)aPushUid {
    NSString *sUrl = [NSString stringWithFormat:@"%@/%@", kWebSiteUrl, @"m/app/pushReceive.asp"];
    
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
    
    //Create an URLRequest
    NSURL *url = [NSURL URLWithString:sUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    
    NSMutableDictionary *dicParam = [NSMutableDictionary dictionary];
    [dicParam setObject:aPushUid forKey:@"pushUid"];
    
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


- (void)webPageCall:(NSString *)aUrl {
    if ([SysUtils isNull:aUrl] == YES)
        return;
    
    NSURL* sUrl              = [NSURL URLWithString:aUrl];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:sUrl
                                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                            timeoutInterval:60.0f];
    
    NSString *sUserAgent = [_webMain stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    
    if ([SysUtils isNull:sUserAgent] == YES) {
        sUserAgent = [NSString stringWithFormat:kUserAgentFormat,
                      [[UIDevice currentDevice] model],
                      [[UIDevice currentDevice] systemName],
                      [[[UIDevice currentDevice] systemVersion] stringByReplacingOccurrencesOfString:@"." withString:@"_"]];
    }
    
    
    sUserAgent = [NSString stringWithFormat:@"%@;%@", sUserAgent, @"device=app"];
    //sUserAgent = [NSString stringWithFormat:@"%@;%@=%@", sUserAgent, @"deviceId", [NSString uuid]];
    
    
    NSDictionary *dic = @{@"UserAgent" : sUserAgent};
    [[NSUserDefaults standardUserDefaults] registerDefaults:dic];
    
    [request addValue:sUserAgent forHTTPHeaderField:@"User-Agent"];
    
    [_webMain loadRequest:request];
    
}


- (void)showImagePicker:(UIImagePickerControllerSourceType)sourceType {
    UIImagePickerController *pictureCtrl = nil;
    
    @try {
        pictureCtrl = [[UIImagePickerController alloc] init];
        pictureCtrl.delegate = self;
        pictureCtrl.sourceType = sourceType;
        pictureCtrl.allowsEditing = YES;
        
        [self presentViewController:pictureCtrl animated:YES completion:nil];
        
        //		if (sourceType == UIImagePickerControllerSourceTypePhotoLibrary)
        //			[AppUtils settingTitle:pictureCtrl title:@""];
        
    }
    @catch (NSException * e) {
        [SysUtils showMessage:NSLocalizedString(@"str_not_support_camera", comment: "")];
        
    }
    @finally {

    }

}


- (void)pictureResultData:(NSArray *)aData {
    if ([SysUtils isNull:_sTokenValue] == YES) {
        [SysUtils showMessage:NSLocalizedString(@"str_empty_token", comment: "")];
        return;
    }
    
    
    _arrLastAddPicture = [NSMutableArray array];
    
    NSString *sTransGbn = [SessionManager sharedSessionManager].transModGbn;
    
    if ([SysUtils isNull:sTransGbn] == YES)
        sTransGbn = @"0";

    NSMutableArray *arrTrandResult = [NSMutableArray array];
    NSDictionary *dicTemp = nil;
    NSString *sFileName = nil;
    
    
    NSString *sNowDate      = [[NSDate date] dateToString:@"yyyyMMddHHmmss" localeIdentifier:@"ko_kr"];
    NSString *sImageName    = nil;
    NSString *sUseType      = nil;
    
    //정렬시작
    for (NSInteger i=0; i<[aData count]; i++) {
        [[[SessionManager sharedSessionManager].transImageData objectAtIndex:i] setObject:[NSString stringWithFormat:@"%ld", i+1] forKey:@"sort"];
        
        // 이미지 이름을
        if ([SysUtils isNull:[[[SessionManager sharedSessionManager].transImageData objectAtIndex:i] objectForKey:@"fileName"]] == YES) {
            sImageName = [NSString stringWithFormat:@"%@_%ld.jpg", sNowDate, (long)i];  // 업로드 이미지 이름
        
            [[[SessionManager sharedSessionManager].transImageData objectAtIndex:i] setObject:sImageName forKey:@"fileName"];
        }
        
        
    }
    
    NSMutableDictionary *dicPhotoAllInfo = nil;
    
    for (NSInteger i=0; i<[[SessionManager sharedSessionManager].transImageData count]; i++) {
        dicTemp = [[SessionManager sharedSessionManager].transImageData objectAtIndex:i];
        [arrTrandResult addObject:dicTemp];
        
        sUseType = [dicTemp objectForKey:@"utype"];

        // 신규 이미지만 저장하자
        if ([SysUtils isNull:sUseType] == NO && [sUseType isEqualToString:@"1"] == YES) {
            dicPhotoAllInfo = [NSMutableDictionary dictionary];
            [dicPhotoAllInfo setObject:[[SessionManager sharedSessionManager].tempImageList objectAtIndex:i] forKey:@"imageData"];
            [dicPhotoAllInfo setObject:[dicTemp objectForKey:@"fileName"] forKey:@"fileName"];
            
            [_arrLastAddPicture addObject:dicPhotoAllInfo];
        }
    }
    
    NSMutableDictionary *resultDic = [[NSMutableDictionary alloc] init];
    [resultDic setObject:arrTrandResult forKey:@"imgArr"];
    [resultDic setObject:_sTokenValue forKey:@"token"];
    [resultDic setObject:sTransGbn forKey:@"resultcd"];         //0:서버저장필요. 1:변경없음 (web에 사진 수정 및 삭제가 발생시에 알려주는 bit 값)
    [resultDic setObject:[NSString stringWithFormat:@"%ld", (long)_nPageGbn] forKey:@"pageGbn"];
    [resultDic setObject:[NSString stringWithFormat:@"%ld", (long)[arrTrandResult count]] forKey:@"cnt"];
    
    [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [resultDic JSONRepresentation]]];
    
    
    [self dismissViewControllerAnimated:NO completion:nil];
}


- (void)subWebResultData:(SubWebViewScreen *)subWebViewScreen didFinished:(NSString *)callBackName withData:(NSString *)resutlData {
    [subWebViewScreen dismissViewControllerAnimated:YES completion:nil];
    
    [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", callBackName, resutlData]];
}


- (IBAction)testClick:(id)sender {
    _sCallback = @"dataReturn";
    
    NSDictionary *dicTest = [NSDictionary dictionaryWithObjectsAndKeys:@"1", @"key_type", nil];
    NSArray *arrTest = [NSArray arrayWithObject:dicTest];
    
    [self callQRCode:arrTest];

}



- (IBAction)testClick2:(id)sender {
    [SysUtils showWaitingSplash];

    _sCallback = @"callbackUploadApp";
    _sTokenValue = @"RLC8KN7Y2T0TMN6V0IUH";
    
    
    NSMutableArray *arrPhotoData = [[NSMutableArray alloc] init];
    [arrPhotoData addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                             @"http://osaka.wavayo.com/temp/1234567890/other/20171230210336_1.jpg", @"imgUrl",
                             @"20171230210336_1.jpg", @"fileName",
                             @"1", @"sort",
                             @"0", @"utype",
                             nil]];
    
    [arrPhotoData addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                             @"http://osaka.wavayo.com/temp/1234567890/other/20171230210336_2.jpg", @"imgUrl",
                             @"20171230210336_2.jpg", @"fileName",
                             @"2", @"sort",
                             @"0", @"utype",
                             nil]];
    
    [arrPhotoData addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                             @"http://osaka.wavayo.com/temp/1234567890/other/20171230210336_3.jpg", @"imgUrl",
                             @"20171230210336_3.jpg", @"fileName",
                             @"3", @"sort",
                             @"0", @"utype",
                             nil]];
    
    [arrPhotoData addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                             @"http://osaka.wavayo.com/temp/1234567890/other/20171230210336_4.jpg", @"imgUrl",
                             @"20171230210336_4.jpg", @"fileName",
                             @"4", @"sort",
                             @"0", @"utype",
                             nil]];
    
    [arrPhotoData addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                             @"http://osaka.wavayo.com/temp/1234567890/other/20171230210336_0.jpg", @"imgUrl",
                             @"20171230210336_0.jpg", @"fileName",
                             @"5", @"sort",
                             @"0", @"utype",
                             nil]];
    
    NSMutableDictionary *dicAllData = [[NSMutableDictionary alloc] init];
    [dicAllData setObject:@"RLC8KN7Y2T0TMN6V0IUH" forKey:@"token"];
    [dicAllData setObject:arrPhotoData forKey:@"imgArr"];
    
    _nPageGbn = 1;
    _nImgCnt = 0;
    
    [self performSelector:@selector(pictureScreenCall:)
               withObject:arrPhotoData
               afterDelay:0.3];

}


- (IBAction)testAct1012:(id)sender {

}



- (void)presentWebviewControllerWithRequest:(NSURLRequest *)urlRequest   {
    // FormSheet모달위에 FullScreen모달이 뜰 떄 애니메이션이 이상하게 동작하여 애니메이션이 없도록 함
    NLoginThirdPartyOAuth20InAppBrowserViewController *inAppBrowserViewController = [[NLoginThirdPartyOAuth20InAppBrowserViewController alloc] initWithRequest:urlRequest];
    inAppBrowserViewController.parentOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
    [self presentViewController:inAppBrowserViewController animated:NO completion:nil];
    
}


#pragma mark-
#pragma mark NaverThirdPartyLoginConnectionDelegate
- (void)oauth20ConnectionDidOpenInAppBrowserForOAuth:(NSURLRequest *)request {
    [self presentWebviewControllerWithRequest:request];
}


- (void)oauth20Connection:(NaverThirdPartyLoginConnection *)oauthConnection didFailWithError:(NSError *)error {
    NSLog(@"error : %@", error);
}


- (void)requestNaverProfile:(NSString *)aToken {
    if ([SysUtils isNull:_sCallback] == YES) {
        [SysUtils showMessage:@"not callback"];
        return;
    }
    
    //NSString *sUrl = @"https://apis.naver.com/nidlogin/nid/getUserProfile.xml";
    NSString *sUrl = @"https://openapi.naver.com/v1/nid/me";
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
    
    //Create an URLRequest
    NSURL *url = [NSURL URLWithString:sUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    
    
    NSString *sHeaderToken = [NSString stringWithFormat:@"Bearer %@", aToken];
    
    [urlRequest setHTTPMethod:@"GET"];
    [urlRequest setValue:sHeaderToken forHTTPHeaderField:@"Authorization"];
#if DEBUG
    NSLog(@"params : %@", urlRequest);
#endif
    
    //Create task
    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        //Handle your response here
        
#if DEBUG
        NSLog(@"error : %@", error);
        NSLog(@"response : %@", response);
#endif
        
        if (data) {
            
            NSError *jsonError;
            NSString *dicResData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
            
            
            NSString *jsonData = [dicResData JSONRepresentation];
            
#if DEBUG
            NSLog(@"jsonData : %@", jsonData);
            NSLog(@"jsonData : %@", jsonError);
#endif
            
            NSDictionary *dicData = [jsonData JSONValue];
            
            NSDictionary *dicResult = [NSDictionary dictionaryWithObjectsAndKeys:aToken, @"accessToken", dicData, @"userInfo", nil];
            
            [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [dicResult JSONRepresentation]]];
            
            //[UserSettings sharedUserSettings].naverToken = aToken;
        }
        
    }];
    
    [dataTask resume];
    
}


- (void)requestKakaoProfile:(NSString *)aToken {
    if ([SysUtils isNull:_sCallback] == YES) {
        [SysUtils showMessage:@"not callback"];
        return;
    }
    
    
    
    [KOSessionTask userMeTaskWithCompletion:^(NSError *error, KOUserMe *me) {
        if (error) {
            // fail
            [SysUtils showMessage:NSLocalizedString(@"str_fail_auth", comment: "")];
        } else {
            // success
            
            NSString *sUserID = me.ID;
            NSString *sNickName = me.nickname;
            NSString *sProfileImageURL = [me.profileImageURL absoluteString];
            NSString *sThumbnailImageURL = [me.thumbnailImageURL absoluteString];
            NSString *sEmail = [SysUtils nullToVoid:me.account.email];
            
            NSMutableDictionary *dicData = [NSMutableDictionary dictionary];
            [dicData setObject:sEmail forKey:@"email"];
            [dicData setObject:sNickName forKey:@"nickname"];
            [dicData setObject:sProfileImageURL forKey:@"profileImagePath"];
            [dicData setObject:sThumbnailImageURL forKey:@"thumnailPath"];
            [dicData setObject:sUserID forKey:@"id"];
            
            NSDictionary *dicResult = [NSDictionary dictionaryWithObjectsAndKeys:aToken, @"accessToken", dicData, @"userInfo", nil];
            
            [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [dicResult JSONRepresentation]]];
            
        }
    }];
    
    
    
    return;
    
    
    
    
    
    
    //    //NSString *sUrl = @"https://apis.naver.com/nidlogin/nid/getUserProfile.xml";
    //    NSString *sUrl = @"https://kapi.kakao.com/v2/user/me";
    //
    //    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    //    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
    //
    //    //Create an URLRequest
    //    NSURL *url = [NSURL URLWithString:sUrl];
    //    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    //
    //
    //    NSString *sHeaderToken = [NSString stringWithFormat:@"Bearer %@", aToken];
    //
    //    [urlRequest setHTTPMethod:@"GET"];
    //    [urlRequest setValue:sHeaderToken forHTTPHeaderField:@"Authorization"];
    //#if DEBUG
    //    NSLog(@"params : %@", urlRequest);
    //#endif
    //
    //    //Create task
    //    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    //        //Handle your response here
    //
    //#if DEBUG
    //        NSLog(@"error : %@", error);
    //        NSLog(@"response : %@", response);
    //#endif
    //
    //        if (data) {
    //
    //            NSError *jsonError;
    //            NSString *dicResData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
    //
    //
    //            NSString *jsonData = [dicResData JSONRepresentation];
    //
    //#if DEBUG
    //            NSLog(@"jsonData : %@", jsonData);
    //            NSLog(@"jsonData : %@", jsonError);
    //#endif
    //
    //            NSDictionary *dicData = [jsonData JSONValue];
    //
    //            NSDictionary *dicResult = [NSDictionary dictionaryWithObjectsAndKeys:aToken, @"accessToken", dicData, @"userInfo", nil];
    //
    //            [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [dicResult JSONRepresentation]]];
    //
    //            //[UserSettings sharedUserSettings].naverToken = aToken;
    //        }
    //
    //    }];
    //
    //    [dataTask resume];
    
}


- (void)oauth20ConnectionDidFinishRequestACTokenWithAuthCode {
    NSLog(@"oauth20ConnectionDidFinishRequestACTokenWithAuthCode");
    
    
    NaverThirdPartyLoginConnection *thirdConn = [NaverThirdPartyLoginConnection getSharedInstance];
    
    //    NSLog(@"thirdConn.accessToken : %@", thirdConn.accessToken);
    //    NSLog(@"thirdConn.accessTokenExpireDate : %@", thirdConn.accessTokenExpireDate);
    //    NSLog(@"thirdConn.refreshToken : %@", thirdConn.refreshToken);
    
    [self requestNaverProfile:thirdConn.accessToken];
    
    //    NSDictionary *dicResult = [NSDictionary dictionaryWithObjectsAndKeys:thirdConn.accessToken, @"accessToken", nil];
    //
    //    [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [dicResult JSONRepresentation]]];
    
    
}


- (void)oauth20ConnectionDidFinishRequestACTokenWithRefreshToken {
    NSLog(@"oauth20ConnectionDidFinishRequestACTokenWithRefreshToken");
    
    NaverThirdPartyLoginConnection *thirdConn = [NaverThirdPartyLoginConnection getSharedInstance];
    
    [self requestNaverProfile:thirdConn.accessToken];
    
    //    NSDictionary *dicResult = [NSDictionary dictionaryWithObjectsAndKeys:thirdConn.accessToken, @"accessToken", nil];
    //
    //    [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');", _sCallback, [dicResult JSONRepresentation]]];
    
}


- (void)oauth20ConnectionDidFinishDeleteToken {
    NSLog(@"oauth20ConnectionDidFinishDeleteToken");
}


@end


