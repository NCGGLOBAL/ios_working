//
//  PictureSelectScreen.m
//
//  Created by JungWoon Kwon on 2017. 9. 27..
//  Copyright © 2017년 JungWoon Kwon. All rights reserved.
//

#import "PictureSelectScreen.h"
#import "AppDelegate.h"
#import "SysUtils.h"
#import "DateUtils.h"
#import "Constants.h"
#import "JSON.h"
#import "PhotoBrowserScreen.h"
#import "JYBMultiImageView.h"
#import "ELCImagePickerController.h"
#import "UIImageButton.h"
#import "UIImage+MultiFormat.h"
#import "SessionManager.h"
#import "UIImageAdditions.h"


@interface PictureSelectScreen () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, JYBMultiImageViewDelegate, ELCImagePickerControllerDelegate> {
    
    NSMutableArray *_arrPictureImage;
    NSMutableArray *_arrPictureData;
    
    
    UIImage *_imageForInteraction;
    CGRect _fromRect;
    
    NSInteger _nBeginDragIndex;

    NSInteger _pageGbn;
    NSInteger _pageCnt;
}


@property (weak, nonatomic) IBOutlet JYBMultiImageView *multiImageView;


@end

@implementation PictureSelectScreen


@synthesize delegate = _delegate;
@synthesize pageGbn = _pageGbn;
@synthesize pageCnt = _pageCnt;


#define kScreenHeight [UIScreen mainScreen].bounds.size.height
#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define PADDING 10


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.navigationController) {
        [self.navigationController setToolbarHidden:YES animated:NO];
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    [SessionManager sharedSessionManager].transModGbn = @"0";

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)navLeftButtonTouchUp:(id)sender {
    [self dismissViewControllerAnimated:NO completion:nil];
}


- (IBAction)navRightButtonTouchUp:(id)sender {
    if (self.delegate && [self.delegate respondsToSelector:@selector(pictureResultData:)]) {
        [self.delegate pictureResultData:[SessionManager sharedSessionManager].transImageData];
    }
}


- (IBAction)cameraButtonClick:(id)sender {
    if ([_arrPictureImage count] >= 10) {
        [SysUtils showMessage:@"10개의 이미지만 등록 가능합니다."];
        return;
    }

    [self showImagePicker:UIImagePickerControllerSourceTypeCamera];
}


- (IBAction)photoButtonClick:(id)sender {
    ELCImagePickerController *elcPicker = [[ELCImagePickerController alloc] initImagePicker];
    elcPicker.imagePickerDelegate  = self;
    elcPicker.currentCount         = self.multiImageView.images_MARR.count;
    [self presentViewController:elcPicker animated:YES completion:nil];

    
}


- (void)drowPhotoData:(NSArray *)aPhotoData {
    _arrPictureImage    = [[NSMutableArray alloc] init];
    _arrPictureData     = [[NSMutableArray alloc] init];
    
    [_arrPictureImage removeAllObjects];
    [_arrPictureData removeAllObjects];

    NSDictionary *dicPhoto = nil;
    NSMutableDictionary *dicPicture = nil;
    UIImage *imgDown = nil;
    NSString *filePath = nil;
    NSString *fileName = nil;
    
//    for (NSInteger i=0; i <[aPhotoData count]; i++) {
//        dicPicture = [NSMutableDictionary dictionary];
//
//        dicPhoto = [aPhotoData objectAtIndex:i];
//        filePath = [dicPhoto objectForKey:@"imgUrl"];
//        fileName = [dicPhoto objectForKey:@"fileName"];
//        imgDown = [UIImage sd_imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:filePath]]];
//
//        [dicPicture setObject:fileName forKey:@"fileName"];
//        [dicPicture setObject:imgDown forKey:@"imageFile"];
//
//        if (imgDown) {
//            [_arrPictureImage addObject:dicPicture];
//        }
//    }

    if (_pageGbn == 1)  { //신규이면
        if ([[SessionManager sharedSessionManager].tempImageList count] > 0) {
            if (_pageCnt == 0 ) {
                [SessionManager sharedSessionManager].tempImageList = [NSMutableArray array];
                [SessionManager sharedSessionManager].transImageData = [NSMutableArray array];
            } else {
                for (NSInteger i=0; i < _pageCnt; i++) {
                    if ([[SessionManager sharedSessionManager].tempImageList count] < i)
                        break;
                    
                    [_arrPictureImage addObject:[[SessionManager sharedSessionManager].tempImageList objectAtIndex:i]];
                    [_arrPictureData addObject:[[SessionManager sharedSessionManager].transImageData objectAtIndex:i]];
                }
                
                [SessionManager sharedSessionManager].transImageData = [NSMutableArray arrayWithArray:_arrPictureImage];
                [SessionManager sharedSessionManager].transImageData = [NSMutableArray arrayWithArray:_arrPictureData];
            }
            
            //self.multiImageView.images_MARR = _arrPictureImage;
        }
    } else {
        for (NSInteger i=0; i <[aPhotoData count]; i++) {
            dicPhoto = [aPhotoData objectAtIndex:i];
            filePath = [dicPhoto objectForKey:@"imgUrl"];
            fileName = [dicPhoto objectForKey:@"fileName"];
            imgDown = [UIImage sd_imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:filePath]]];
            
            if (imgDown) {
                [_arrPictureImage addObject:imgDown];
            }
        }
        
        if ([_arrPictureImage count] > 0) {
            //self.multiImageView.images_MARR = _arrPictureImage;
            
            [SessionManager sharedSessionManager].tempImageList = [NSMutableArray arrayWithArray:_arrPictureImage];
            
            [_arrPictureData addObjectsFromArray:aPhotoData];
            
            [SessionManager sharedSessionManager].transImageData = [NSMutableArray arrayWithArray:_arrPictureData];
        } else {
            [SessionManager sharedSessionManager].transImageData = [NSMutableArray arrayWithArray:aPhotoData];
        }
        
    }
    
    
    
    [self performSelector:@selector(photoImageAferSetting)
               withObject:nil
               afterDelay:0.5];
}


- (void)photoImageAferSetting {
    self.multiImageView.delegate = self;
    self.multiImageView.bSelectLine = NO;

    self.multiImageView.images_MARR = _arrPictureImage;
    
    [SysUtils closeWaitingSplash];
}


- (void)showImagePicker:(UIImagePickerControllerSourceType)sourceType {
    UIImagePickerController *pictureCtrl = nil;
    
    @try {
        pictureCtrl = [[UIImagePickerController alloc] init];
        pictureCtrl.delegate = self;
        pictureCtrl.sourceType = UIImagePickerControllerSourceTypeCamera;
        pictureCtrl.allowsEditing = NO;

//        pictureCtrl.modalPresentationStyle = UIModalPresentationFullScreen;
//        pictureCtrl.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie, kUTTypeImage, nil];


        [self presentViewController:pictureCtrl animated:YES completion:nil];

        //        if (sourceType == UIImagePickerControllerSourceTypePhotoLibrary)
        //            [AppUtils settingTitle:pictureCtrl title:@""];
        
    }
    @catch (NSException * e) {
        [SysUtils showMessage:@"장치에서 카메라 기능을 지원하지 않습니다"];
        
    }
    @finally {
        
    }
    
}




//- (void)imagePickerController: (UIImagePickerController*) reader didFinishPickingMediaWithInfo: (NSDictionary*) info {
//    [reader dismissViewControllerAnimated:YES completion:nil];
//
//    UIImage *photoImage = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage];
//
//    //[self displayImages:[NSArray arrayWithObject:photoImage]];
//}






#pragma mark - JYBMultiImageView Delegate
- (void)addButtonDidTap {

}

- (void)multiImageBtn:(NSInteger)index withImage:(UIImage *)image
{
    // 图片放大显示，或删除等操作
    NSLog(@"index => %ld", (long)index);

    
    PhotoBrowserScreen *photoVC = [[PhotoBrowserScreen alloc] initWithPhotos:_arrPictureImage];
    [photoVC setBlock:^(NSArray *arrImage) {
        [self.multiImageView.images_MARR removeAllObjects];
        self.multiImageView.images_MARR = [NSMutableArray arrayWithArray:arrImage];
        
        [_arrPictureImage removeAllObjects];
        [_arrPictureImage addObjectsFromArray:arrImage];
        
        [SessionManager sharedSessionManager].tempImageList = _arrPictureImage;
        
    }];
    
    photoVC.index = index;
    
    [self.navigationController pushViewController:photoVC animated:YES];

}



#pragma mark - ELCImagePickerController Delegate
- (void)elcImagePickerController:(ELCImagePickerController *)picker didFinishPickingMediaWithInfo:(NSArray *)info
{
    [self dismissViewControllerAnimated:YES completion:^{
        NSMutableArray *array = [NSMutableArray array];
        for (NSDictionary *dic in info) {
            UIImage *image = dic[UIImagePickerControllerOriginalImage];
            [array addObject:image];
        }
        [self addMoreImages:array];
    }];
}

- (void)elcImagePickerControllerDidCancel:(ELCImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ImagePicker Delegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [self dismissViewControllerAnimated:YES completion:^{
        UIImage *initialImage = [[info objectForKey:@"UIImagePickerControllerOriginalImage"] fixOrientation];

        [self addMoreImages:@[initialImage]];
        
//        NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
//        UIImage *takenImage;
//
//        if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) {
//            takenImage = (UIImage *)[info objectForKey: UIImagePickerControllerOriginalImage];
//
//            //UIImageWriteToSavedPhotosAlbum (takenImage, self, @selector(image:didFinishSavingWithError:contextInfo:) , nil);
//            UIImageWriteToSavedPhotosAlbum (takenImage, nil, nil , nil);
//        } else if ([mediaType isEqualToString:(NSString *)kUTTypeMovie]) {
//            NSString *moviePath = [[info objectForKey: UIImagePickerControllerMediaURL] path];
//            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum (moviePath))
//            {
//                UISaveVideoAtPathToSavedPhotosAlbum ( moviePath, nil, nil, nil);
//            }
//        }
        
        
    }];
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:NO completion:nil];
}


- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    [self addMoreImages:@[image]];
    
    if(!error){
        NSLog(@"Photo saved to library!");
    }
    else{
        NSLog(@"Saving failed :(");
    }
}



- (void)addMoreImages:(NSArray *)images {
    NSInteger nTotalCnt = [_arrPictureImage count];
    
    [SessionManager sharedSessionManager].transModGbn = @"1";
    
    NSMutableArray *arr = [NSMutableArray arrayWithArray:self.multiImageView.images_MARR];
    [arr addObjectsFromArray:images];
    [self.multiImageView.images_MARR removeAllObjects];
    self.multiImageView.images_MARR = arr;
    
    [_arrPictureImage removeAllObjects];
    [_arrPictureImage addObjectsFromArray:arr];

    NSMutableDictionary *dicData = nil;
    
    for (NSInteger i=0; i < [images count]; i++) {
        dicData = [[NSMutableDictionary alloc] init];
        [dicData setObject:@"" forKey:@"imgUrl"];
        [dicData setObject:[NSString stringWithFormat:@"%ld", nTotalCnt + i + 1] forKey:@"sort"];
        [dicData setObject:@"" forKey:@"fileName"];     //TODO: 이미지 이름
        [dicData setObject:@"1" forKey:@"utype"];
        
        [[SessionManager sharedSessionManager].transImageData addObject:dicData];
    }
    
    [SessionManager sharedSessionManager].tempImageList = _arrPictureImage;
}


- (void)dragImageStart:(NSInteger)index {
    _nBeginDragIndex = index;
}


- (void)dragImageChange:(NSInteger)index {

}


- (void)dragImageEnd:(NSInteger)index {

//    if (_nBeginDragIndex == index)
//        return;
//
//    UIImageButton *anotherBtn = nil;
//    UILabel *lblCount = nil;
//
//    NSArray *arrTemp = self.multiImageView.imageBtns_MARR;
//
//    for (NSInteger i=0; i < [arrTemp count]; i++) {
//        anotherBtn = (UIImageButton *)[arrTemp objectAtIndex:i];
//
//        lblCount = (UILabel *)[anotherBtn viewWithTag:9901];
//        lblCount.text = [NSString stringWithFormat:@"%ld", i+1];
//    }
}






@end
