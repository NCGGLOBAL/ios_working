//
//  PhotoBrowserScreen.m
//
//  Created by JungWoon Kwon on 2017. 12. 26..
//  Copyright © 2017년 JungWoon Kwon. All rights reserved.
//

#import "PhotoBrowserScreen.h"
#import "PictureSortModScreen.h"
#import "PhotoCropScreen.h"
#import "SessionManager.h"


@interface PhotoBrowserScreen () <MWPhotoBrowserDelegate, PhotoCropScreenDelegate> {

}

@property (nonatomic, strong) NSMutableArray *photos;
@property (nonatomic, strong) NSMutableArray *originImage;

@property (weak, nonatomic) IBOutlet UIButton *deleteButton;
@property (weak, nonatomic) IBOutlet UIButton *editButton;
@property (weak, nonatomic) IBOutlet UIButton *changeOrderButton;


@end

@implementation PhotoBrowserScreen


#define ORIGINAL_MAX_WIDTH 640.0f


#pragma mark - LifeCycle
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.navigationController) {
        [self.navigationController setToolbarHidden:YES animated:NO];
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = self;
    //self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"驳回" style:UIBarButtonItemStylePlain target:self action:@selector(rightBarButtonItemAction)];
    
    [self.view bringSubviewToFront:_vTopMenu];
    [self.view bringSubviewToFront:_vMenuList];
    
    [self setCurrentPhotoIndex:self.index];
    
    [self titleSetting];
}

- (id)initWithPhotos:(NSArray *)photosArray
{
    self.originImage = [NSMutableArray arrayWithArray:photosArray];
    
    NSMutableArray *array = [NSMutableArray array];
    for (NSInteger i = 0; i < photosArray.count; i++) {
        if ([photosArray[i] isKindOfClass:[UIImage class]]) {
            [array addObject:[MWPhoto photoWithImage:photosArray[i]]];
        } else {
            [array addObject:[MWPhoto photoWithURL:[NSURL URLWithString:photosArray[i]]]];
        }
    }
    photosArray = [array copy];
    if (self = [super initWithPhotos:photosArray]) {
        [self.photos addObjectsFromArray: photosArray];
    }
    return self;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)titleSetting {
    _lblTitle.text = [NSString stringWithFormat:@"%@(%ld/%lu)", NSLocalizedString(@"str_detail_view", comment: ""), (long)self.index + 1, (unsigned long)[self.originImage count]];
    
    [_editButton setTitle:NSLocalizedString(@"str_edit", comment: "") forState:UIControlStateNormal];
    [_deleteButton setTitle:NSLocalizedString(@"str_delete", comment: "") forState:UIControlStateNormal];
    [_changeOrderButton setTitle:NSLocalizedString(@"str_change_order", comment: "") forState:UIControlStateNormal];
}


#pragma mark - ....
- (NSMutableArray *)photos {
    if (!_photos) {
        _photos = [NSMutableArray array];
    }
    return _photos;
}


#pragma mark - buttonAction
- (void)rightBarButtonItemAction
{
    id <MWPhoto> photo = [self photoBrowser:self photoAtIndex:self.index];
    UIImage *image = [self imageForPhoto:photo];
    if (self.block) {
        //self.block(image);
    }
    [self.navigationController popViewControllerAnimated:YES];
}


- (UIImage *)imageForPhoto:(id<MWPhoto>)photo {
    if (photo) {
        // Get image or obtain in background
        if ([photo underlyingImage]) {
            return [photo underlyingImage];
        } else {
            [photo loadUnderlyingImageAndNotify];
        }
    }
    return nil;
}

#pragma mark - MWPhotoBrowserDelegate
- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return self.photos.count;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser didDisplayPhotoAtIndex:(NSUInteger)index {
    self.index = index;
    
    [self performSelector:@selector(titleSetting)
               withObject:nil
               afterDelay:0.3];

    
    NSLog(@"Did start viewing photo at index %lu", (unsigned long)index);
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    
    if (index < self.photos.count) {
        return [self.photos objectAtIndex:index];
    }
    return nil;
}


- (IBAction)navLeftButtonTouchUp:(id)sender {
    if (self.block) {
        self.block(self.originImage);
    }

    //[self dismissViewControllerAnimated:NO completion:nil];
    [self.navigationController popViewControllerAnimated:YES];
}


- (IBAction)photoModClicked:(id)sender {
    
    id <MWPhoto> photo = [self photoBrowser:self photoAtIndex:self.index];
    UIImage *portraitImg = [self imageForPhoto:photo];

    
    portraitImg = [self imageByScalingToMaxSize:portraitImg];
    // present the cropper view controller
    PhotoCropScreen *imgCropperVC = [[PhotoCropScreen alloc] initWithImage:portraitImg cropFrame:CGRectMake(0, 100.0f, self.view.frame.size.width, self.view.frame.size.width) limitScaleRatio:3.0];
    imgCropperVC.delegate = self;

    [self.navigationController pushViewController:imgCropperVC animated:YES];
    
}

- (IBAction)photoDeleteClicked:(id)sender {
    
    UIAlertController * alert=   [UIAlertController
                                  alertControllerWithTitle:@"안내"
                                  message:NSLocalizedString(@"str_delete_photo", comment: "")
                                  preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelBtn = [UIAlertAction
                         actionWithTitle:NSLocalizedString(@"str_cancel", comment: "")
                         style:UIAlertActionStyleDefault
                         handler:^(UIAlertAction * action)
                         {
                             //[alert dismissViewControllerAnimated:YES completion:nil];
                             
                         }];
    UIAlertAction* deleteBtn = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"str_delete", comment: "")
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action)
                             {

                                 [alert dismissViewControllerAnimated:YES completion:nil];
                                 
                                 [SessionManager sharedSessionManager].transModGbn = @"1";
                                 
                                 [self.photos removeObjectAtIndex:self.index];
                                 [self.originImage removeObjectAtIndex:self.index];
                                 
                                 [[SessionManager sharedSessionManager].transImageData removeObjectAtIndex:self.index];
                                 
                                 if ([self.photos count] <= 0) {
                                     if (self.block) {
                                         self.block(self.originImage);
                                     }

                                     [self. navigationController popViewControllerAnimated:YES];
                                 } else {
                                     [self reloadData];
                                     
                                     [self titleSetting];
                                 }

                                 
                                 
                                 
                             }];
    
    [alert addAction:cancelBtn];
    [alert addAction:deleteBtn];

    [self presentViewController:alert animated:YES completion:nil];
    
    
    
}

- (IBAction)photoSortClicked:(id)sender {
    PictureSortModScreen *controller = [[PictureSortModScreen alloc] initWithNibName:@"PictureSortModScreen" bundle:nil];
    controller.photoImage = self.originImage;
    [controller setBlock:^(NSArray *arrImage) {
        [self.originImage removeAllObjects];
        [self.photos removeAllObjects];
        
        [self.originImage addObjectsFromArray:arrImage];
        
        NSMutableArray *photosArray = [NSMutableArray array];
        for (NSInteger i = 0; i < arrImage.count; i++) {
            if ([arrImage[i] isKindOfClass:[UIImage class]]) {
                [photosArray addObject:[MWPhoto photoWithImage:arrImage[i]]];
            } else {
                [photosArray addObject:[MWPhoto photoWithURL:[NSURL URLWithString:arrImage[i]]]];
            }
        }

        [self.photos addObjectsFromArray: photosArray];
        
        [self reloadData];
    }];

    [self.navigationController pushViewController:controller animated:YES];

}




#pragma mark image scale utility
- (UIImage *)imageByScalingToMaxSize:(UIImage *)sourceImage {
    if (sourceImage.size.width < ORIGINAL_MAX_WIDTH) return sourceImage;
    CGFloat btWidth = 0.0f;
    CGFloat btHeight = 0.0f;
    if (sourceImage.size.width > sourceImage.size.height) {
        btHeight = ORIGINAL_MAX_WIDTH;
        btWidth = sourceImage.size.width * (ORIGINAL_MAX_WIDTH / sourceImage.size.height);
    } else {
        btWidth = ORIGINAL_MAX_WIDTH;
        btHeight = sourceImage.size.height * (ORIGINAL_MAX_WIDTH / sourceImage.size.width);
    }
    CGSize targetSize = CGSizeMake(btWidth, btHeight);
    return [self imageByScalingAndCroppingForSourceImage:sourceImage targetSize:targetSize];
}

- (UIImage *)imageByScalingAndCroppingForSourceImage:(UIImage *)sourceImage targetSize:(CGSize)targetSize {
    UIImage *newImage = nil;
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;
    CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);
    if (CGSizeEqualToSize(imageSize, targetSize) == NO)
    {
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;
        
        if (widthFactor > heightFactor)
            scaleFactor = widthFactor; // scale to fit height
        else
            scaleFactor = heightFactor; // scale to fit width
        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;
        
        // center the image
        if (widthFactor > heightFactor)
        {
            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
        }
        else
            if (widthFactor < heightFactor)
            {
                thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
            }
    }
    UIGraphicsBeginImageContext(targetSize); // this will crop
    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;
    
    [sourceImage drawInRect:thumbnailRect];
    
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    if(newImage == nil) NSLog(@"could not scale image");
    
    //pop the context to get back to the default
    UIGraphicsEndImageContext();
    return newImage;
}


- (void)imageCropper:(PhotoCropScreen *)cropperViewController didFinished:(UIImage *)editedImage {
    [self.photos replaceObjectAtIndex:self.index withObject:[MWPhoto photoWithImage:editedImage]];
    [self.originImage replaceObjectAtIndex:self.index withObject:editedImage];
    
    [[[SessionManager sharedSessionManager].transImageData objectAtIndex:self.index] setObject:@"" forKey:@"fileName"];
    
    [self reloadData];
}


- (void)imageCropperDidCancel:(PhotoCropScreen *)cropperViewController {
    
}







@end
