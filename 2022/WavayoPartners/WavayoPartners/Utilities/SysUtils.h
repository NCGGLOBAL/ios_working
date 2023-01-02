

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>



@interface SysUtils : NSObject


+ (BOOL)isNull:(id) obj;
+ (NSString *)nullToVoid:(NSString *)aSource;
+ (void)showMessage:(NSString *)aMsg;
+ (void)showMessageWithOwner:(NSString *)aMsg owner:(id)aOwner;
+ (void)showMessageWithOwner:(NSString *)aMsg owner:(id)aOwner tag:(NSInteger)aTag;
+ (void)showWaitingSplash;
+ (void)closeWaitingSplash;
+ (NSInteger)getOSVersion;
+ (void)makeSoundEffect;

@end
