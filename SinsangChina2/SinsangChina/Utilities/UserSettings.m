

#import "UserSettings.h"
#import "JSON.h"
#import "SysUtils.h"
#import "StrUtils.h"


static NSString *userSettingSaveFileName	= @"userSettings.json";
static UserSettings *sharedUserSettings		= nil;

@interface UserSettings()

- (id)initSingleton;
- (void)fileSave;

@end


@implementation UserSettings


#pragma mark -
#pragma mark private Method
- (id)initSingleton {
	fileSaving			= NO;
	
	if (self = [super init]) {
		NSString *filePath			= [NSString stringWithFormat:@"%@/Documents/%@", NSHomeDirectory(), userSettingSaveFileName];
		NSString *jsonSourceString	= [NSString stringWithEncrytionFile_AES256:filePath];
		
		if ([SysUtils isNull:jsonSourceString] == NO)
			userSettingsDic = [[NSMutableDictionary alloc] initWithDictionary:[jsonSourceString JSONValue]];
		
		if ([SysUtils isNull:userSettingsDic] == YES) {
			userSettingsDic         = [[NSMutableDictionary alloc] init];
		}
		
		fileSaving = YES;
	}
	
	return self;
}


- (void)fileSave {
	if (fileSaving == YES) {
		NSString *userSettingsString	= [userSettingsDic JSONRepresentation];
		NSString *filePath				= [NSString stringWithFormat:@"%@/Documents/%@", NSHomeDirectory(), userSettingSaveFileName];
		
		[userSettingsString writeToEncrytionFile_AES256:filePath];
	}
    
}



#pragma mark -
#pragma mark LifeCycle Method
+ (UserSettings*)sharedUserSettings {
    if (!sharedUserSettings)
        sharedUserSettings = [[super allocWithZone: NULL] initSingleton];
	
    return sharedUserSettings;
}


+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedUserSettings] copy];
}


- (id)copyWithZone:(NSZone *)zone {
    return self;
}


#pragma mark -
#pragma mark property getter setter
- (void)setTempImageList:(NSArray *)aAcctData {
    [userSettingsDic setObject:aAcctData forKey:@"IMAGE_DATA"];
    [self fileSave];
}


- (NSString *)tempImageList {
    return [userSettingsDic objectForKey:@"IMAGE_DATA"];
}


- (void)setTransImageData:(NSArray *)aAcctData {
    [userSettingsDic setObject:aAcctData forKey:@"TRANS_IMAGE_DATA"];
    //[self fileSave];
}


- (NSString *)transImageData {
    return [userSettingsDic objectForKey:@"TRANS_IMAGE_DATA"];
}


- (void)setTransModGbn:(NSArray *)aAcctData {
    [userSettingsDic setObject:aAcctData forKey:@"TRANS_GBN_DATA"];
    //[self fileSave];
}


- (NSString *)transModGbn {
    return [userSettingsDic objectForKey:@"TRANS_GBN_DATA"];
}



@end



