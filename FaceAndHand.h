#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#include <simd/simd.h>

@class FaceAndHand;

@protocol FaceAndHandDelegate <NSObject>
- (void)tracker:(FaceAndHand *)tracker didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)tracker:(FaceAndHand *)tracker didOutputTransform:(simd_float4x4)transform withFace:(NSInteger)index;
- (void)trackerDidOutputWithNoFace:(FaceAndHand *)tracker;
- (void)trackerDidOutputWithNoHand:(FaceAndHand *)tracker;
@end



@interface FaceAndHand : NSObject

- (instancetype)init;
- (instancetype)initWithString: (NSString *)string;
- (void)startGraph;
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer timestamp:(CMTime)timestamp;
@property (weak, nonatomic) id <MPPBFaceGeometryDelegate> delegate;

@end
