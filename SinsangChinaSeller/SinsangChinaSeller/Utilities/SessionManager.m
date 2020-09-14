

#import "SessionManager.h"
#import "DateUtils.h"


@implementation SessionManager


@synthesize tempImageList       = _tempImageList;
@synthesize transImageData      = _transImageData;
@synthesize transModGbn         = _transModGbn;

static SessionManager *sessionMgr = nil;


+ (SessionManager *)sharedSessionManager {
	if (sessionMgr == nil)
		sessionMgr = [[SessionManager alloc] init];
	
	return sessionMgr;
}



- (id)init {
	self = [super init];
	
	if (self != nil) {
        _tempImageList          = [NSMutableArray array];
        _transImageData         = [NSMutableArray array];
        _transModGbn            = nil;
    }
    
    return self;
}


- (id)copyWithZone:(NSZone *)zone {
	return self;
}





@end
