//
//  PhotoBrowserScreen.h
//
//  Created by JungWoon Kwon on 2017. 12. 26..
//  Copyright © 2017년 JungWoon Kwon. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "MWPhotoBrowser.h"


@interface PhotoBrowserScreen : MWPhotoBrowser {
    __weak IBOutlet UIView *_vMenuList;
    __weak IBOutlet UIView *_vTopMenu;
    __weak IBOutlet UILabel *_lblTitle;
    
}

@property (nonatomic, assign) NSInteger index;

@property (nonatomic, copy) void(^block)(NSArray *);

@end
