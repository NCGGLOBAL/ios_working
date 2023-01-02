
#import "SysUtils.h"
#import "AppDelegate.h"

@implementation SysUtils


#define APP_DELEGATE        ((AppDelegate *)[[UIApplication sharedApplication] delegate])


static const NSInteger kTagOfSplashView   = 4443;


+ (BOOL)isNull:(id)obj {
	if (obj == nil || obj == [NSNull null])
		return YES;
	
	// obj가 NSString이거나 NSString을 상속받은 객체일 경우 empty string을 체크한다.
	if ([obj isKindOfClass:[NSString class]] == YES) {
		if ([(NSString *)obj isEqualToString:@""] == YES)
			return YES;
	}
	
	return NO;
}


+ (NSString *)nullToVoid:(NSString *)aSource {
	if ([self isNull:aSource] == YES)
		return @"";
	
	return aSource;
}


+ (void)showMessage:(NSString *)aMsg {
	[self showMessageWithOwner:aMsg owner:nil tag:0];
}


+ (void)showMessageWithOwner:(NSString *)aMsg owner:(id)aOwner {
	[self showMessageWithOwner:aMsg owner:aOwner tag:0];
}


+ (void)showMessageWithOwner:(NSString *)aMsg owner:(id)aOwner tag:(NSInteger)aTag {
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"str_guide", comment: "")
													message:aMsg
												   delegate:aOwner
                                        cancelButtonTitle:NSLocalizedString(@"str_confirm", comment: "")
										  otherButtonTitles:nil];
	
	alert.tag = aTag;
	
	[alert show];
    
#if !__has_feature(objc_arc)
	[alert release];
#endif
}


+ (void)showWaitingSplash {
    UIView* vSplash = (UIView *)[[UIApplication sharedApplication].keyWindow viewWithTag:kTagOfSplashView];
    
    if ([SysUtils isNull:vSplash] == NO)
        return;
    
    vSplash                 = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    vSplash.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6f];
    vSplash.tag             = kTagOfSplashView;
    
    CGRect indicatorFrame   = [UIApplication sharedApplication].keyWindow.frame;
    indicatorFrame.origin   = [UIApplication sharedApplication].keyWindow.center;
    indicatorFrame.origin.x = indicatorFrame.origin.x - 18.5f;
    indicatorFrame.origin.y = indicatorFrame.origin.y - 18.5f;
    indicatorFrame.size     = CGSizeMake(37.0f, 37.0f);
    
    UIActivityIndicatorView* avIndicator    = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    avIndicator.frame                       = indicatorFrame;
    
    [avIndicator startAnimating];
    [vSplash addSubview:avIndicator];
    
#if !__has_feature(objc_arc)
    [avIndicator release];
#endif
    
    [[UIApplication sharedApplication].keyWindow addSubview:vSplash];
    [[UIApplication sharedApplication].keyWindow bringSubviewToFront:vSplash];
}


+ (void)closeWaitingSplash {
    UIView* vSplash = (UIView *)[[UIApplication sharedApplication].keyWindow viewWithTag:kTagOfSplashView];
    vSplash.backgroundColor = [UIColor clearColor];
    
    if ([SysUtils isNull:vSplash] == YES)
        return;
    
    [vSplash removeFromSuperview];
}


+ (NSInteger)getOSVersion {
    
    NSString* sOSVersion = [[[UIDevice currentDevice] systemVersion] stringByReplacingOccurrencesOfString:@"." withString:@"0"];
    
    if ([sOSVersion integerValue] < 10000)		// iOS 4.1부터는 버전 번호 자릿수가 3자리여서,
        return [sOSVersion integerValue] * 100;	// 5자리로 맞춰준다.
    else
        return [sOSVersion integerValue];
}


+ (void)makeSoundEffect {
    NSString *path  = [[NSBundle mainBundle] pathForResource:@"beep-beep" ofType:@"aiff"];
    NSURL *pathURL = [NSURL fileURLWithPath : path];
    
    SystemSoundID audioEffect;
    AudioServicesCreateSystemSoundID((__bridge CFURLRef) pathURL, &audioEffect);
    AudioServicesPlaySystemSound(audioEffect);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        AudioServicesDisposeSystemSoundID(audioEffect);
    });
    
}



//+ (void)showWaitingSplash {
//    
//    //UIView* vSplash = (UIView *)[[UIApplication sharedApplication].keyWindow viewWithTag:kTagOfSplashView];
//    UIView* vSplash = (UIView *)[APP_DELEGATE.window viewWithTag:kTagOfSplashView];
//    
//    if ([SysUtils isNull:vSplash] == NO)
//        return;
//    
//    vSplash                 = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
//    vSplash.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6f];
//    vSplash.tag             = kTagOfSplashView;
//    
//    //    CGRect indicatorFrame   = [UIApplication sharedApplication].keyWindow.frame;
//    //    indicatorFrame.origin   = [UIApplication sharedApplication].keyWindow.center;
//    
//    CGPoint centerPoint = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).window.center;
//    
//    UIActivityIndicatorView* avIndicator    = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
//    //avIndicator.frame                       = indicatorFrame;
//    avIndicator.center = centerPoint;
//    
//    [avIndicator startAnimating];
//    [vSplash addSubview:avIndicator];
//    
//#if !__has_feature(objc_arc)
//    [avIndicator release];
//#endif
//    
//    [APP_DELEGATE.window addSubview:vSplash];
//    [APP_DELEGATE.window bringSubviewToFront:vSplash];
//    
//    //    [[UIApplication sharedApplication].keyWindow addSubview:vSplash];
//    //    [[UIApplication sharedApplication].keyWindow bringSubviewToFront:vSplash];
//}
//
//
//+ (void)closeWaitingSplash {
//    //UIView* vSplash = (UIView *)[[UIApplication sharedApplication].keyWindow viewWithTag:kTagOfSplashView];
//    UIView* vSplash = (UIView *)[APP_DELEGATE.window viewWithTag:kTagOfSplashView];
//    
//    if ([SysUtils isNull:vSplash] == YES)
//        return;
//    
//    [vSplash removeFromSuperview];
//}




@end



