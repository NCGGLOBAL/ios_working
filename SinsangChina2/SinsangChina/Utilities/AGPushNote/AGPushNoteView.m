//  IAAPushNoteView.m

#import "AGPushNoteView.h"

#define bIOSOver6 (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1)

#define CLOSE_PUSH_SEC 5
#define SHOW_ANIM_DUR 0.5
#define HIDE_ANIM_DUR 0.35

@interface AGPushNoteView()
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UIView *containerView;

@property (strong, nonatomic) NSTimer *closeTimer;
@property (strong, nonatomic) NSString *currentMessage;
@property (strong, nonatomic) NSMutableArray *pendingPushArr;

@property (strong, nonatomic) void (^messageTapActionBlock)(NSString *message);
@end


@implementation AGPushNoteView

//Singleton instance
static AGPushNoteView *_sharedPushView;

+ (instancetype)sharedPushView {
    @synchronized([self class])	{
        if (!_sharedPushView) {
            NSArray *nibArr = [[NSBundle mainBundle] loadNibNamed: @"AGPushNoteView" owner:self options:nil];
            
            for (id currentObject in nibArr) {
                if ([currentObject isKindOfClass:[AGPushNoteView class]]) {
                    _sharedPushView = (AGPushNoteView *)currentObject;
                    break;
                }
            }
            
            [_sharedPushView setUpUI];
            
        }
        
        return _sharedPushView;
    }
    // to avoid compiler warning
    return nil;
}


+ (void)setDelegateForPushNote:(id<AGPushNoteViewDelegate>)delegate {
    [[AGPushNoteView sharedPushView] setPushNoteDelegate:delegate];
}


#pragma mark - Lifecycle (of sort)
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        CGRect f = self.frame;
        CGFloat width = [UIApplication sharedApplication].keyWindow.bounds.size.width;
        self.frame = CGRectMake(f.origin.x, f.origin.y, width, f.size.height);
    }
    return self;
}


- (void)setUpUI {
    CGRect f = self.frame;
    CGFloat width = [UIApplication sharedApplication].keyWindow.bounds.size.width;
    CGFloat height = bIOSOver6? 54: f.size.height;
    self.frame = CGRectMake(f.origin.x, -height, width, height);
    
    CGRect cvF = self.containerView.frame;
    self.containerView.frame = CGRectMake(cvF.origin.x, cvF.origin.y, self.frame.size.width, cvF.size.height);
    
    //OS Specific:
    if (bIOSOver6) {
        self.barTintColor = nil;
        self.translucent = YES;
        self.barStyle = UIBarStyleBlack;
    } else {
        [self setTintColor:[UIColor colorWithRed:5 green:31 blue:75 alpha:1]];
        [self.messageLabel setTextAlignment:NSTextAlignmentCenter];
        self.messageLabel.shadowColor = [UIColor blackColor];
    }
    
    self.layer.zPosition = MAXFLOAT;
    self.backgroundColor = [UIColor clearColor];
    self.multipleTouchEnabled = NO;
    self.exclusiveTouch = YES;
    
    UITapGestureRecognizer *msgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(messageTapAction)];
    self.messageLabel.userInteractionEnabled = YES;
    [self.messageLabel addGestureRecognizer:msgTap];
    

    [[UIApplication sharedApplication].delegate.window addSubview:[AGPushNoteView sharedPushView]];
}


+ (void)awake {
    if ([AGPushNoteView sharedPushView].frame.origin.y == 0) {
        [[UIApplication sharedApplication].delegate.window addSubview:[AGPushNoteView sharedPushView]];
    }
}


+ (void)showWithNotificationMessage:(NSString *)message {
    [AGPushNoteView showWithNotificationMessage:message completion:^{
        //Nothing.
    }];
}


+ (void)showWithNotificationMessage:(NSString *)message completion:(void (^)(void))completion {
    
    [AGPushNoteView sharedPushView].currentMessage = message;
    
    if (message) {
        [[AGPushNoteView sharedPushView].pendingPushArr addObject:message];
        
        [AGPushNoteView sharedPushView].messageLabel.text = message;
        [UIApplication sharedApplication].delegate.window.windowLevel = UIWindowLevelStatusBar;
        
        CGRect f = [AGPushNoteView sharedPushView].frame;
        [AGPushNoteView sharedPushView].frame = CGRectMake(f.origin.x, -f.size.height, f.size.width, f.size.height);
        [[UIApplication sharedApplication].delegate.window addSubview:[AGPushNoteView sharedPushView]];
        
        //Show
        [UIView animateWithDuration:SHOW_ANIM_DUR delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            CGRect f = [AGPushNoteView sharedPushView].frame;
            [AGPushNoteView sharedPushView].frame = CGRectMake(f.origin.x, 0, f.size.width, f.size.height);
        } completion:^(BOOL finished) {
            completion();
            if ([[AGPushNoteView sharedPushView].pushNoteDelegate respondsToSelector:@selector(pushNoteDidAppear)]) {
                [[AGPushNoteView sharedPushView].pushNoteDelegate pushNoteDidAppear];
            }
        }];
        
//Start timer (Currently not used to make sure user see & read the push...)
//        [AGPushNoteView sharedPushView].closeTimer = [NSTimer scheduledTimerWithTimeInterval:CLOSE_PUSH_SEC target:[IAAPushNoteView class] selector:@selector(close) userInfo:nil repeats:NO];
    }
}


+ (void)closeWitCompletion:(void (^)(void))completion {
    if ([[AGPushNoteView sharedPushView].pushNoteDelegate respondsToSelector:@selector(pushNoteWillDisappear)]) {
        [[AGPushNoteView sharedPushView].pushNoteDelegate pushNoteWillDisappear];
    }
    
    [[AGPushNoteView sharedPushView].closeTimer invalidate];
    
    [UIView animateWithDuration:HIDE_ANIM_DUR delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect f = [AGPushNoteView sharedPushView].frame;
        [AGPushNoteView sharedPushView].frame = CGRectMake(f.origin.x, -f.size.height, f.size.width, f.size.height);
    } completion:^(BOOL finished) {
        [[AGPushNoteView sharedPushView] handlePendingPushJumpWitCompletion:completion];
    }];
}


+ (void)close {
    [AGPushNoteView closeWitCompletion:^{
        //Nothing.
    }];
}



#pragma mark - Pending push managment
- (void)handlePendingPushJumpWitCompletion:(void (^)(void))completion {
    id lastObj = [self.pendingPushArr lastObject]; //Get myself
    if (lastObj) {
        [self.pendingPushArr removeObject:lastObj]; //Remove me from arr
        NSString *messagePendingPush = [self.pendingPushArr lastObject]; //Maybe get pending push
        if (messagePendingPush) { //If got something - remove from arr, - than show it.
            [self.pendingPushArr removeObject:messagePendingPush];
            [AGPushNoteView showWithNotificationMessage:messagePendingPush completion:completion];
        } else {
            [UIApplication sharedApplication].delegate.window.windowLevel = UIWindowLevelNormal;
        }
    }
}


- (NSMutableArray *)pendingPushArr {
    if (!_pendingPushArr) {
        _pendingPushArr = [[NSMutableArray alloc] init];
    }
    return _pendingPushArr;
}



#pragma mark - Actions
+ (void)setMessageAction:(void (^)(NSString *message))action {
    [AGPushNoteView sharedPushView].messageTapActionBlock = action;
}


- (void)messageTapAction {
    if (self.messageTapActionBlock) {
        self.messageTapActionBlock(self.currentMessage);
        [AGPushNoteView close];
    }
}


- (IBAction)closeActionItem:(UIBarButtonItem *)sender {
    [AGPushNoteView close];
}



@end









