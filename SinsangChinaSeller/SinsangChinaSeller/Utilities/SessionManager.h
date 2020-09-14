

#import <Foundation/Foundation.h>

@interface SessionManager : NSObject {
    NSMutableArray*     _tempImageList;
    NSMutableArray*     _transImageData;
    NSString*           _transModGbn;
}


@property (nonatomic, retain)   NSMutableArray* tempImageList;
@property (nonatomic, retain)   NSMutableArray* transImageData;
@property (nonatomic, copy)   NSString* transModGbn;

+ (SessionManager *)sharedSessionManager;

@end
