//
//  PictureSelectScreen.h
//
//  Created by JungWoon Kwon on 2017. 9. 27..
//  Copyright © 2017년 JungWoon Kwon. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PictureSelectDelegate <NSObject>
@optional
- (void)pictureResultData:(NSArray *)aData;
@end


@interface PictureSelectScreen : UIViewController


@property(nonatomic, assign) id<PictureSelectDelegate> delegate;
@property(nonatomic, assign) NSInteger pageGbn;
@property(nonatomic, assign) NSInteger pageCnt;

- (void)drowPhotoData:(NSArray *)aPhotoData;

@end
