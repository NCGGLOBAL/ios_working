//
//  SubWebViewScreen.m
//
//  Created by JungWoon Kwon on 2018. 1. 25..
//  Copyright © 2018년 JungWoon Kwon. All rights reserved.
//

#import "SubWebViewScreen.h"
#import "SysUtils.h"
#import "StrUtils.h"
#import "JSON.h"
#import "Constants.h"
#import "NSString+UUID.h"


@interface SubWebViewScreen () {
    NSString *_sCallback;
}

@end

@implementation SubWebViewScreen

@synthesize delegate = _delegate;
@synthesize requestUrl = _requestUrl;

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
    
    
    //_requestUrl = @"https://www.facebook.com/dialog/share?app_id=145634995501895&display=popup&href=https%3A%2F%2Fdevelopers.facebook.com%2Fdocs%2F&redirect_uri=https%3A%2F%2Fdevelopers.facebook.com%2Ftools%2Fexplorer";
    //_requestUrl = @"https://www.facebook.com/sharer.php?u=http://soho.wavayo.com/sns/scrap_facebook.asp?guid=135541&mode=G&redirect_uri=https%3A%2F%2Fdevelopers.facebook.com%2Ftools%2Fexplorer";
    
    NSURL *sUrl = [NSURL URLWithString:_requestUrl];
    
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
    
    
    [_webMain loadRequest:request];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark-
#pragma mark LifeCycle Method
- (IBAction)closeButtonClick:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}



#pragma mark-
#pragma mark Private Method
- (void)parseWebAction:(NSString *)aSource {
    aSource = [aSource stringByReplacingOccurrencesOfString:@"/\"" withString:@"\\\""];
    
    NSDictionary* dicSource = [aSource JSONValue];
    
    
    if (([SysUtils isNull:dicSource] == YES) || (dicSource.count <= 0))
        return;
    
    
#if DEBUG
    NSLog(@"=================%@", [dicSource description]);
#endif
    
    
    NSString* sActionCode = [dicSource objectForKey:@"action_code"];
    
    
    if ([SysUtils isNull:sActionCode] == YES)
        return;
    
    
    // 콜백 함수를 저장한다.
    _sCallback  = [[SysUtils nullToVoid:[dicSource objectForKey:@"callBack"]] trim];
    
    
    // 웹액션 코드에 따른 수행
    if ([sActionCode isEqualToString:@"ACT1016"] == YES) {
        [self callMainWebPage:[dicSource objectForKey:@"action_param"]];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}


- (void)callMainWebPage:(NSArray *)aParams {
    if ([SysUtils isNull:aParams] == YES)
        return;
    
    NSDictionary *dicData = [aParams objectAtIndex:0];
    
    NSString *sCallBackName = [SysUtils nullToVoid:[dicData objectForKey:@"callScript"]];
    
    if ([SysUtils isNull:sCallBackName] == YES)
        return;

    NSString *sCallBackParam = [SysUtils nullToVoid:[dicData objectForKey:@"callObj"]];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(subWebResultData:didFinished:withData:)]) {
        [self.delegate subWebResultData:self didFinished:sCallBackName withData:sCallBackParam];
    }

}



- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if ([SysUtils isNull:request] == YES || [SysUtils isNull:[request URL]] == YES)
        return NO;
    
    
    NSString* sURLScheme    = [[request URL] scheme];
    NSString* sURL            = [[request URL] absoluteString];
    NSString* sEscapedURL    = nil;
    NSString* sDecodedURL    = nil;
    
    
    if (([SysUtils isNull:sURLScheme] == YES) || ([SysUtils isNull:sURL] == YES))
        return NO;
    
    
    sEscapedURL    = [sURL stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    
    if ([SysUtils isNull:sEscapedURL] == YES)
        return NO;
    
#if DEBUG
    NSLog(@"URL [%@]", sURL);
    NSLog(@"Escaped URL [%@]", sEscapedURL);
#endif
    
    if ([sURLScheme isEqualToString:@"iwebaction"] == YES) {
        sDecodedURL = [sEscapedURL stringByReplacingOccurrencesOfString:@"iwebaction:" withString:@""];
        
        if ([SysUtils isNull:sDecodedURL] == YES)
            return NO;
        
        [self parseWebAction:sDecodedURL];
    }
    
//    NSRange range = [sEscapedURL rangeOfString:@"close?"];
//
//    if (range.location != NSNotFound) {
//        [self dismissViewControllerAnimated:YES completion:nil];
//    }
    
    
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
    [_webMain stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('dv_id', '%@');", @"localStorage.setItem", [NSString uuid]]];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    
    NSString *html = [_webMain stringByEvaluatingJavaScriptFromString:@"document.documentElement.innerHTML"];
    
    NSRange range = [html rangeOfString:@"window.close()"];

    if (range.location != NSNotFound) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }

}


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}



@end
