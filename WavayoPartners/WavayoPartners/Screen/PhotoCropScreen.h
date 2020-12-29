//
//  PhotoCropScreen.h
//
//  Created by JungWoon Kwon on 2017. 12. 27..
//  Copyright © 2017년 JungWoon Kwon. All rights reserved.
//

#import <UIKit/UIKit.h>


@class PhotoCropScreen;

@protocol PhotoCropScreenDelegate <NSObject>

- (void)imageCropper:(PhotoCropScreen *)cropperViewController didFinished:(UIImage *)editedImage;
- (void)imageCropperDidCancel:(PhotoCropScreen *)cropperViewController;

@end


@interface PhotoCropScreen : UIViewController

@property (nonatomic, assign) NSInteger tag;
@property (nonatomic, assign) id<PhotoCropScreenDelegate> delegate;
@property (nonatomic, assign) CGRect cropFrame;

- (id)initWithImage:(UIImage *)originalImage cropFrame:(CGRect)cropFrame limitScaleRatio:(NSInteger)limitRatio;


@end



