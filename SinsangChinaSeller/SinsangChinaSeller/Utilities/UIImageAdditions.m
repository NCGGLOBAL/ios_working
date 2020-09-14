

#import "UIImageAdditions.h"
#import "SysUtils.h"
#import <CoreImage/CoreImage.h>

static CGInterpolationQuality _interpolationQuality = kCGInterpolationNone;


@implementation UIImage (UIImageAdditions)

+ (void)setInterpolationQuality:(CGInterpolationQuality)quality {
    _interpolationQuality = quality;
}


+ (CGInterpolationQuality)interpolationQuality {
    return _interpolationQuality;
}


// Returns an affine transform that takes into account the image orientation when drawing a scaled image
- (CGAffineTransform)transformForOrientation:(CGSize)newSize {
	CGAffineTransform transform = CGAffineTransformIdentity;
	
	switch (self.imageOrientation) {
		case UIImageOrientationDown:			// EXIF = 3
		case UIImageOrientationDownMirrored:	// EXIF = 4
			transform = CGAffineTransformTranslate(transform, newSize.width, newSize.height);
			transform = CGAffineTransformRotate(transform, M_PI);
			break;
			
		case UIImageOrientationLeft:			// EXIF = 6
		case UIImageOrientationLeftMirrored:	// EXIF = 5
			transform = CGAffineTransformTranslate(transform, newSize.width, 0);
			transform = CGAffineTransformRotate(transform, M_PI_2);
			break;
			
		case UIImageOrientationRight:		  // EXIF = 8
		case UIImageOrientationRightMirrored:  // EXIF = 7
			transform = CGAffineTransformTranslate(transform, 0, newSize.height);
			transform = CGAffineTransformRotate(transform, -M_PI_2);
			break;
	}
	
	switch (self.imageOrientation) {
		case UIImageOrientationUpMirrored:	 // EXIF = 2
		case UIImageOrientationDownMirrored:	// EXIF = 4
			transform = CGAffineTransformTranslate(transform, newSize.width, 0);
			transform = CGAffineTransformScale(transform, -1, 1);
			break;
			
		case UIImageOrientationLeftMirrored:	// EXIF = 5
		case UIImageOrientationRightMirrored:  // EXIF = 7
			transform = CGAffineTransformTranslate(transform, newSize.height, 0);
			transform = CGAffineTransformScale(transform, -1, 1);
			break;
	}
	
	return transform;
}


// Returns a copy of the image that has been transformed using the given affine transform and scaled to the new size
// The new image's orientation will be UIImageOrientationUp, regardless of the current image's orientation
// If the new size is not integral, it will be rounded up
- (UIImage *)resizedImage:(CGSize)newSize
				transform:(CGAffineTransform)transform
           drawTransposed:(BOOL)transpose
	 interpolationQuality:(CGInterpolationQuality)quality {
	CGRect newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height));
	CGRect transposedRect = CGRectMake(0, 0, newRect.size.height, newRect.size.width);
	CGImageRef imageRef = self.CGImage;
	
	// Build a context that's the same dimensions as the new size
	CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
	if((bitmapInfo == kCGImageAlphaLast) || (bitmapInfo == kCGImageAlphaNone))
		bitmapInfo = kCGImageAlphaNoneSkipLast;
	
	CGContextRef bitmap = CGBitmapContextCreate(NULL,
												newRect.size.width,
												newRect.size.height,
												CGImageGetBitsPerComponent(imageRef),
												0,
												CGImageGetColorSpace(imageRef),
												bitmapInfo);
	
	// Rotate and/or flip the image if required by its orientation
	CGContextConcatCTM(bitmap, transform);
	
	// Set the quality level to use when rescaling
	CGContextSetInterpolationQuality(bitmap, quality);
	
	// Draw into the context; this scales the image
	CGContextDrawImage(bitmap, transpose ? transposedRect : newRect, imageRef);
	
	// Get the resized image from the context and a UIImage
	CGImageRef newImageRef = CGBitmapContextCreateImage(bitmap);
	UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
	
	// Clean up
	CGContextRelease(bitmap);
	CGImageRelease(newImageRef);
	
	return newImage;
}

// Returns a rescaled copy of the image, taking into account its orientation
// The image will be scaled disproportionately if necessary to fit the bounds specified by the parameter
- (UIImage *)resizedImage:(CGSize)aNewSize interpolationQuality:(CGInterpolationQuality)aQuality {
	BOOL drawTransposed;
	
	switch (self.imageOrientation) {
		case UIImageOrientationLeft:
		case UIImageOrientationLeftMirrored:
		case UIImageOrientationRight:
		case UIImageOrientationRightMirrored:
			drawTransposed = YES;
			break;
			
		default:
			drawTransposed = NO;
	}
	
	return [self resizedImage:aNewSize
					transform:[self transformForOrientation:aNewSize]
               drawTransposed:drawTransposed
		 interpolationQuality:aQuality];
}


+ (UIImage *)imageFromColor:(UIColor *)aColor withSize:(CGSize)aSize {
    CGRect frame    = CGRectZero;
    frame.origin    = CGPointMake(0.0f, 0.0f);
    frame.size      = aSize;
    
    UIGraphicsBeginImageContext(frame.size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [aColor CGColor]);
    CGContextFillRect(context, frame);
    
    UIImage* imgCreated = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return imgCreated;
}


- (UIImage *)imageByScalingAndCroppingForSize:(CGSize)aSize {
    UIImage* imgSource          = self;
    UIImage* imgNew             = nil;
    CGFloat fSourceImageWidth   = self.size.width;
    CGFloat fSourceImageHeight  = self.size.height;
    CGFloat fNewImageWidth      = aSize.width;
    CGFloat fNewImageHeight     = aSize.height;
    CGFloat fScaleFactor        = 0.0f;
    CGFloat fScaledWidth        = fNewImageWidth;
    CGFloat fScaledHeight       = fNewImageHeight;
    CGPoint newImageOrigin      = CGPointZero;
    
    if (CGSizeEqualToSize(self.size, aSize) == NO) {
        CGFloat fWidthFactor    = fNewImageWidth / fSourceImageWidth;
        CGFloat fHeightFactor   = fNewImageHeight / fSourceImageHeight;
        
        if (fWidthFactor > fHeightFactor) {
            fScaleFactor        = fWidthFactor;
            newImageOrigin.y    = (fNewImageHeight - fScaledHeight) * 0.5f;
        } else {
            fScaleFactor = fHeightFactor;
            
            if (fWidthFactor < fHeightFactor)
                newImageOrigin.x = (fNewImageWidth - fScaledWidth) * 0.5f;
        }
        
        fScaledWidth    = fSourceImageWidth * fScaleFactor;
        fScaledHeight   = fSourceImageHeight * fScaleFactor;
    }
    
    UIGraphicsBeginImageContext(aSize);
    
    CGRect newImageFrame        = CGRectZero;
    newImageFrame.origin        = newImageOrigin;
    newImageFrame.size.width    = fScaledWidth;
    newImageFrame.size.height   = fScaledHeight;
    
    [self drawInRect:newImageFrame];
    
    imgNew = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return imgNew;
}


- (UIImage *) resizedImageByMagick: (NSString *) spec
{
    
    if([spec hasSuffix:@"!"]) {
        NSString *specWithoutSuffix = [spec substringToIndex: [spec length] - 1];
        NSArray *widthAndHeight = [specWithoutSuffix componentsSeparatedByString: @"x"];
        NSUInteger width = labs([[widthAndHeight objectAtIndex: 0] integerValue]);
        NSUInteger height = labs([[widthAndHeight objectAtIndex: 1] integerValue]);
        UIImage *newImage = [self resizedImageWithMinimumSize: CGSizeMake (width, height)];
        return [newImage drawImageInBounds: CGRectMake (0, 0, width, height)];
    }
    
    if([spec hasSuffix:@"#"]) {
        NSString *specWithoutSuffix = [spec substringToIndex: [spec length] - 1];
        NSArray *widthAndHeight = [specWithoutSuffix componentsSeparatedByString: @"x"];
        NSUInteger width = labs([[widthAndHeight objectAtIndex: 0] integerValue]);
        NSUInteger height = labs([[widthAndHeight objectAtIndex: 1] integerValue]);
        UIImage *newImage = [self resizedImageWithMinimumSize: CGSizeMake (width, height)];
        return [newImage croppedImageWithRect: CGRectMake ((newImage.size.width - width) / 2, (newImage.size.height - height) / 2, width, height)];
    }
    
    if([spec hasSuffix:@"^"]) {
        NSString *specWithoutSuffix = [spec substringToIndex: [spec length] - 1];
        NSArray *widthAndHeight = [specWithoutSuffix componentsSeparatedByString: @"x"];
        return [self resizedImageWithMinimumSize: CGSizeMake (labs([[widthAndHeight objectAtIndex: 0] integerValue]),
                                                              labs([[widthAndHeight objectAtIndex: 1] integerValue]))];
    }
    
    NSArray *widthAndHeight = [spec componentsSeparatedByString: @"x"];
    if ([widthAndHeight count] == 1) {
        return [self resizedImageByWidth: [spec integerValue]];
    }
    if ([[widthAndHeight objectAtIndex: 0] isEqualToString: @""]) {
        return [self resizedImageByHeight: labs([[widthAndHeight objectAtIndex: 1] integerValue])];
    }
    return [self resizedImageWithMaximumSize: CGSizeMake (labs([[widthAndHeight objectAtIndex: 0] integerValue]),
                                                          labs([[widthAndHeight objectAtIndex: 1] integerValue]))];
}

- (CGImageRef) CGImageWithCorrectOrientation CF_RETURNS_RETAINED
{
    if (self.imageOrientation == UIImageOrientationDown) {
        //retaining because caller expects to own the reference
        CGImageRef cgImage = [self CGImage];
        CGImageRetain(cgImage);
        return cgImage;
    }
    UIGraphicsBeginImageContextWithOptions(self.size, NO, 0.0);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, _interpolationQuality);
    
    if (self.imageOrientation == UIImageOrientationRight) {
        CGContextRotateCTM (context, 90 * M_PI/180);
    } else if (self.imageOrientation == UIImageOrientationLeft) {
        CGContextRotateCTM (context, -90 * M_PI/180);
    } else if (self.imageOrientation == UIImageOrientationUp) {
        CGContextRotateCTM (context, 180 * M_PI/180);
    }
    
    [self drawAtPoint:CGPointMake(0, 0)];
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIGraphicsEndImageContext();
    
    return cgImage;
}


- (UIImage *) resizedImageByWidth:  (NSUInteger) width
{
    CGImageRef imgRef = [self CGImageWithCorrectOrientation];
    CGFloat original_width  = CGImageGetWidth(imgRef);
    CGFloat original_height = CGImageGetHeight(imgRef);
    CGFloat ratio = width/original_width;
    CGImageRelease(imgRef);
    return [self drawImageInBounds: CGRectMake(0, 0, width, round(original_height * ratio))];
}

- (UIImage *) resizedImageByHeight:  (NSUInteger) height
{
    CGImageRef imgRef = [self CGImageWithCorrectOrientation];
    CGFloat original_width  = CGImageGetWidth(imgRef);
    CGFloat original_height = CGImageGetHeight(imgRef);
    CGFloat ratio = height/original_height;
    CGImageRelease(imgRef);
    return [self drawImageInBounds: CGRectMake(0, 0, round(original_width * ratio), height)];
}


- (UIImage *) resizedImageWithMinimumSize: (CGSize) size
{
    CGImageRef imgRef = [self CGImageWithCorrectOrientation];
    CGFloat original_width  = CGImageGetWidth(imgRef);
    CGFloat original_height = CGImageGetHeight(imgRef);
    CGFloat width_ratio = size.width / original_width;
    CGFloat height_ratio = size.height / original_height;
    CGFloat scale_ratio = width_ratio > height_ratio ? width_ratio : height_ratio;
    CGImageRelease(imgRef);
    return [self drawImageInBounds: CGRectMake(0, 0, round(original_width * scale_ratio), round(original_height * scale_ratio))];
}

- (UIImage *) resizedImageWithMaximumSize: (CGSize) size
{
    CGImageRef imgRef = [self CGImageWithCorrectOrientation];
    CGFloat original_width  = CGImageGetWidth(imgRef);
    CGFloat original_height = CGImageGetHeight(imgRef);
    CGFloat width_ratio = size.width / original_width;
    CGFloat height_ratio = size.height / original_height;
    CGFloat scale_ratio = width_ratio < height_ratio ? width_ratio : height_ratio;
    CGImageRelease(imgRef);
    return [self drawImageInBounds: CGRectMake(0, 0, round(original_width * scale_ratio), round(original_height * scale_ratio))];
}


- (UIImage *) drawImageInBounds: (CGRect) bounds
{
    UIGraphicsBeginImageContextWithOptions(bounds.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, _interpolationQuality);
    [self drawInRect: bounds];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resizedImage;
}

- (UIImage*) croppedImageWithRect: (CGRect) rect {
    
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, _interpolationQuality);
    CGRect drawRect = CGRectMake(-rect.origin.x, -rect.origin.y, self.size.width, self.size.height);
    CGContextClipToRect(context, CGRectMake(0, 0, rect.size.width, rect.size.height));
    [self drawInRect:drawRect];
    UIImage* subImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return subImage;
}



- (UIImage *)fixOrientation {
    
    
    
    // No-op if the orientation is already correct
    
    if (self.imageOrientation == UIImageOrientationUp) return self;
    
    
    
    // We need to calculate the proper transformation to make the image upright.
    
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    
    
    switch (self.imageOrientation) {
            
        case UIImageOrientationDown:
            
        case UIImageOrientationDownMirrored:
            
            transform = CGAffineTransformTranslate(transform, self.size.width, self.size.height);
            
            transform = CGAffineTransformRotate(transform, M_PI);
            
            break;
            
            
            
        case UIImageOrientationLeft:
            
        case UIImageOrientationLeftMirrored:
            
            transform = CGAffineTransformTranslate(transform, self.size.width, 0);
            
            transform = CGAffineTransformRotate(transform, M_PI_2);
            
            break;
            
            
            
        case UIImageOrientationRight:
            
        case UIImageOrientationRightMirrored:
            
            transform = CGAffineTransformTranslate(transform, 0, self.size.height);
            
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            
            break;
            
        case UIImageOrientationUp:
            
        case UIImageOrientationUpMirrored:
            
            break;
            
    }
    
    
    
    switch (self.imageOrientation) {
            
        case UIImageOrientationUpMirrored:
            
        case UIImageOrientationDownMirrored:
            
            transform = CGAffineTransformTranslate(transform, self.size.width, 0);
            
            transform = CGAffineTransformScale(transform, -1, 1);
            
            break;
            
            
            
        case UIImageOrientationLeftMirrored:
            
        case UIImageOrientationRightMirrored:
            
            transform = CGAffineTransformTranslate(transform, self.size.height, 0);
            
            transform = CGAffineTransformScale(transform, -1, 1);
            
            break;
            
        case UIImageOrientationUp:
            
        case UIImageOrientationDown:
            
        case UIImageOrientationLeft:
            
        case UIImageOrientationRight:
            
            break;
            
    }
    
    
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    
    // calculated above.
    
    CGContextRef ctx = CGBitmapContextCreate(NULL, self.size.width, self.size.height,
                                             
                                             CGImageGetBitsPerComponent(self.CGImage), 0,
                                             
                                             CGImageGetColorSpace(self.CGImage),
                                             
                                             CGImageGetBitmapInfo(self.CGImage));
    
    CGContextConcatCTM(ctx, transform);
    
    switch (self.imageOrientation) {
            
        case UIImageOrientationLeft:
            
        case UIImageOrientationLeftMirrored:
            
        case UIImageOrientationRight:
            
        case UIImageOrientationRightMirrored:
            
            // Grr...
            
            CGContextDrawImage(ctx, CGRectMake(0,0,self.size.height,self.size.width), self.CGImage);
            
            break;
            
            
            
        default:
            
            CGContextDrawImage(ctx, CGRectMake(0,0,self.size.width,self.size.height), self.CGImage);
            
            break;
            
    }
    
    
    
    // And now we just create a new UIImage from the drawing context
    
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    
    CGContextRelease(ctx);
    
    CGImageRelease(cgimg);
    
    return img;
    
}


@end
