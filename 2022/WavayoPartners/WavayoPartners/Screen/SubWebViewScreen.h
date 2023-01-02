//
//  SubWebViewScreen.h
//
//  Created by JungWoon Kwon on 2018. 1. 25..
//  Copyright © 2018년 JungWoon Kwon. All rights reserved.
//

#import <UIKit/UIKit.h>


@class SubWebViewScreen;

@protocol SubWebViewScreenDelegate <NSObject>

- (void)subWebResultData:(SubWebViewScreen *)subWebViewScreen didFinished:(NSString *)callBackName withData:(NSString *)resutlData;

@end


@interface SubWebViewScreen : UIViewController {
    __weak IBOutlet UIWebView *_webMain;
    
}


@property(nonatomic, assign) id<SubWebViewScreenDelegate> delegate;
@property (nonatomic, strong) NSString *requestUrl;


@end
