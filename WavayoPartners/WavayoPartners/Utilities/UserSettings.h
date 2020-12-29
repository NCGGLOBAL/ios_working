


#import <Foundation/Foundation.h>


@interface UserSettings : NSObject {
    NSMutableDictionary*	userSettingsDic;
	BOOL					fileSaving;
}



+ (UserSettings*)sharedUserSettings;


@property (nonatomic, copy) NSArray* tempImageList;
@property (nonatomic, copy) NSArray* transImageData;
@property (nonatomic, copy) NSString* transModGbn;

@end
