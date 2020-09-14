

#import "NSString+UUID.h"
#import "SSKeychain.h"
#import "SysUtils.h"

@implementation NSString (UUID)


+ (NSString *)uuid {
    NSString *uuidString = nil;
    
    uuidString = [SSKeychain passwordForService:@"com.vikingsmarket.nc" account:@"NCGLOBAL_USER_VER_1"];
    
    if([uuidString length] < 1) {
        // iOS 6+
        if ([UIDevice instancesRespondToSelector:@selector(identifierForVendor)]) {
            uuidString = [NSString stringWithFormat:@"%@",[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
        } else {
            
            CFUUIDRef uuid = CFUUIDCreate(NULL);
            if (uuid) {
                CFStringRef identifier = CFUUIDCreateString(NULL, uuid);
                CFRelease(uuid);
                uuidString = [NSString stringWithFormat:@"%@",CFBridgingRelease(identifier)];
            }
        }
        
        [SSKeychain setPassword:uuidString forService:@"com.vikingsmarket.nc" account:@"NCGLOBAL_USER_VER_1"];
    }
    
    return [uuidString copy];
}



@end
