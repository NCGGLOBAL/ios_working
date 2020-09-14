

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface UIImage (UIImageAdditions)

+ (void) setInterpolationQuality:(CGInterpolationQuality) quality;
+ (CGInterpolationQuality) interpolationQuality;

+ (UIImage *)imageFromColor:(UIColor *)aColor withSize:(CGSize)aSize;
- (UIImage *)resizedImage:(CGSize)aNewSize interpolationQuality:(CGInterpolationQuality)aQuality;
- (UIImage *)imageByScalingAndCroppingForSize:(CGSize)aSize;
- (UIImage *) resizedImageByMagick: (NSString *) spec;
- (UIImage *) resizedImageByWidth:  (NSUInteger) width;
- (UIImage *) resizedImageByHeight: (NSUInteger) height;
- (UIImage *)fixOrientation;

@end
