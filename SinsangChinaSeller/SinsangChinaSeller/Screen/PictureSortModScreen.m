//
//  PictureSortModScreen.m
//
//  Created by JungWoon Kwon on 2017. 12. 26..
//  Copyright © 2017년 JungWoon Kwon. All rights reserved.
//

#import "PictureSortModScreen.h"
#import "JYBMultiImageView.h"
#import "UIImageButton.h"
#import "SessionManager.h"


@interface PictureSortModScreen () <JYBMultiImageViewDelegate> {
    NSMutableArray *_arrTemp;
    
    NSInteger _nBeginDragIndex;
    
    BOOL _bSortGbn;
}

@property (weak, nonatomic) IBOutlet JYBMultiImageView *multiImageView;

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;

@end

@implementation PictureSortModScreen

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.navigationController) {
        [self.navigationController setToolbarHidden:YES animated:NO];
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.multiImageView.delegate = self;
    self.multiImageView.bSelectLine = YES;
    [self.multiImageView.images_MARR removeAllObjects];
    
    [self.multiImageView addLongPressGesture];
    
    _arrTemp = [[NSMutableArray alloc] init];
    
    [self performSelector:@selector(photoImageAferSetting)
               withObject:nil
               afterDelay:0.5];
    
    _bSortGbn = NO;
    
    [self.titleLabel setText:NSLocalizedString(@"str_change_order", comment: "")];
    
    [self.doneButton setTitle:NSLocalizedString(@"str_done", comment: "") forState:UIControlStateNormal];
}


- (void)photoImageAferSetting {
    [_arrTemp removeAllObjects];
    [_arrTemp addObjectsFromArray:self.photoImage];
    
    self.multiImageView.images_MARR = _arrTemp;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


- (IBAction)leftButtonClick:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}


- (IBAction)rightButtonClick:(id)sender {
    if (self.block && _bSortGbn == YES) {
        [SessionManager sharedSessionManager].transModGbn = @"1";
        
        self.block(self.multiImageView.images_MARR);
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - JYBMultiImageView Delegate
- (void)addButtonDidTap {
//    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"" destructiveButtonTitle:nil otherButtonTitles:@"", @", nil];
//    [sheet showInView:self.view];
}

- (void)multiImageBtn:(NSInteger)index withImage:(UIImage *)image
{
    // 图片放大显示，或删除等操作
    NSLog(@"index => %ld", (long)index);
}



#pragma mark - ImagePicker Delegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [self dismissViewControllerAnimated:YES completion:^{
        [self addMoreImages:@[info[UIImagePickerControllerEditedImage]]];
    }];
}


- (void)addMoreImages:(NSArray *)images {

}


- (void)dragImageStart:(NSInteger)index {
    _nBeginDragIndex = index;
}


- (void)dragImageChange:(NSInteger)index {

}


- (void)dragImageEnd:(NSInteger)index {
    if (_nBeginDragIndex == index)
        return;
    
    UIImageButton *anotherBtn = nil;
    UILabel *lblCount = nil;
    
    NSArray *arrTemp = self.multiImageView.imageBtns_MARR;
    
    for (NSInteger i=0; i < [arrTemp count]; i++) {
        anotherBtn = (UIImageButton *)[arrTemp objectAtIndex:i];
        
        lblCount = (UILabel *)[anotherBtn viewWithTag:9901];
        lblCount.text = [NSString stringWithFormat:@"%ld", i+1];
    }

    _bSortGbn = YES;
    
    //NSDictionary *dicData = [[[SessionManager sharedSessionManager].transImageData objectAtIndex:_nBeginDragIndex] copy];
    NSMutableDictionary *dicData = [NSMutableDictionary dictionaryWithDictionary:[[SessionManager sharedSessionManager].transImageData objectAtIndex:_nBeginDragIndex]];
    
    [[SessionManager sharedSessionManager].transImageData removeObjectAtIndex:_nBeginDragIndex];
    [[SessionManager sharedSessionManager].transImageData insertObject:dicData atIndex:index];
}

@end
