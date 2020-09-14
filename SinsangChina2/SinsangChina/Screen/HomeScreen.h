//
//  HomeScreen.h
//
//  Created by JungWoon Kwon on 2016. 5. 26..
//  Copyright © 2016년 JungWoon Kwon. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HomeScreen : UIViewController {
    __weak IBOutlet UIWebView *_webMain;
    __weak IBOutlet UIImageView *_ivLodingTemp;
    __weak IBOutlet UIActivityIndicatorView *_aiWaitting;
    
}

- (void)requestPushRecive:(NSString *)aPushUid;
- (void)webPageCall:(NSString *)aUrl;

@end
