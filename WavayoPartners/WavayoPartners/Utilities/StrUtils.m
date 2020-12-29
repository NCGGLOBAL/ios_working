

#import "StrUtils.h"
#import "SysUtils.h"
#import "NSString+UUID.h"
#import "NSData+AES256.h"
#import <CommonCrypto/CommonDigest.h>


@implementation NSString (StrUtils)


static const NSString *KEY_PREFIX_VALUE    = @"NCGlOBAL";

#pragma mark --
#pragma mark public function
- (NSString *)trim {
	return  [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}


- (NSString *)stringByURLEncode {
    CFStringRef stringRef = CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                    (CFStringRef)self,
                                                                    NULL,
                                                                    (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                    kCFStringEncodingUTF8 );
    
    NSString *retsultString = [NSString stringWithFormat:@"%@", (__bridge NSString *)stringRef];
    CFRelease(stringRef);
    
    return retsultString;
}

+ (NSString *)stringWithEncrytionFile_AES256:(NSString *)path {
    NSData *encData = [NSData dataWithContentsOfFile:path];
    return [encData decryptDataToString:encData withKey:[NSString getEncryptionKey]];
}


+ (NSString *)getEncryptionKey {
    NSString *key = [KEY_PREFIX_VALUE stringByAppendingString:[NSString uuid]];
    return [key sha512String];
}


- (NSString *)sha512String {
    if ([SysUtils isNull:self] == YES)
        return nil;
    
    const char *cStr = [self UTF8String];
    unsigned char result[CC_SHA512_DIGEST_LENGTH];
    CC_SHA512(cStr, strlen(cStr), result);
    
    
#if __has_feature(objc_arc)
    NSString *resultStr = [[NSString alloc] init];
#else
    NSString *resultStr = [[[NSString alloc] init] autorelease];
#endif
    
    
    for (NSInteger i = 0; i < 64; i++)
        resultStr = [resultStr stringByAppendingFormat:@"%@", [NSString stringWithFormat:@"%02X", result[i]]];
    
    return resultStr;
}


- (BOOL)writeToEncrytionFile_AES256:(NSString *)path {
    NSData *encData = [[NSData alloc] encryptStringToData:self withKey:[NSString getEncryptionKey]];
    return [encData writeToFile:path atomically:NO];
}



@end









