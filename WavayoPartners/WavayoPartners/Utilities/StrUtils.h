

#import <Foundation/Foundation.h>


@interface NSString (StrUtils)

- (NSString *)trim;
- (NSString *)stringByURLEncode;
+ (NSString *)stringWithEncrytionFile_AES256:(NSString *)path;
- (BOOL)writeToEncrytionFile_AES256:(NSString*)path;

@end
