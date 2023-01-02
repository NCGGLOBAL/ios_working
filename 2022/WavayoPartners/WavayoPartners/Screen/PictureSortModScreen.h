//
//  PictureSortModScreen.h
//
//  Created by JungWoon Kwon on 2017. 12. 26..
//  Copyright © 2017년 JungWoon Kwon. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PictureSortModScreen : UIViewController

@property (nonatomic, strong) NSArray *photoImage;

@property (nonatomic, copy) void(^block)(NSArray *);

@end
