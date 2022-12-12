#import "FaceAndHand.h"

#import "mediapipe/objc/MPPGraph.h"
#include "mediapipe/framework/port/parse_text_proto.h"
#include "mediapipe/framework/formats/matrix_data.pb.h"
#include "mediapipe/modules/face_geometry/protos/face_geometry.pb.h"
#include "mediapipe/framework/formats/landmark.pb.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"

// 脸部识别
static NSString* const kGraphName = @"face_geometry_with_transform";
// 手部识别
static NSString* const kGraphName = @"hand_tracking_mobile_gpu";

static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kNumHandsInputSidePacket = "num_hands";
static const char* kMultiFaceGeometryStream = "multi_face_geometry";
static const char* kLandmarksOutputStream = "hand_landmarks";
static const int kNumHands = 2;

@interface FaceAndHand() <MPPGraphDelegate>

@property(nonatomic) MPPGraph* mediapipeGraph;

@end

@implementation FaceAndHand { }

#pragma mark - Cleanup methods

- (void)dealloc {
    self.mediapipeGraph.delegate = nil;
    [self.mediapipeGraph cancel];
    
    // Ignore errors since we're cleaning up.
    [self.mediapipeGraph closeAllInputStreamsWithError:nil];
    [self.mediapipeGraph waitUntilDoneWithError:nil];
}

#pragma mark - MediaPipe graph methods
// https://google.github.io/mediapipe/getting_started/hello_world_ios.html#using-a-mediapipe-graph-in-ios

+ (MPPGraph*)loadGraphFromResource:(NSString*)resource {
    // Load the graph config resource.
    NSError* configLoadError = nil;
    NSBundle* bundle = [NSBundle bundleForClass:[self class]];
    if (!resource || resource.length == 0) {
        return nil;
    }
    NSURL* graphURL = [bundle URLForResource:resource withExtension:@"binarypb"];
    NSData* data = [NSData dataWithContentsOfURL:graphURL options:0 error:&configLoadError];
    if (!data) {
        NSLog(@"Failed to load MediaPipe graph config: %@", configLoadError);
        return nil;
    }
    
    // Parse the graph config resource into mediapipe::CalculatorGraphConfig proto object.
    mediapipe::CalculatorGraphConfig config;
    config.ParseFromArray(data.bytes, data.length);

    // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
    MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];
    [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
    // add face output
    [newGraph addFrameOutputStream:kMultiFaceGeometryStream outputPacketType:MPPPacketTypeRaw];
    // add hand output
    [newGraph addFrameOutputStream:kLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];
    [newGraph setSidePacket:(mediapipe::MakePacket<int>(kNumHands)) named:kNumHandsInputSidePacket];
    return newGraph;
}

+ (MPPGraph*)loadGraphFromString:(NSString*)string {
    // Load the graph config resource.
    NSError* configLoadError = nil;
    
    if (!string || string.length == 0) {
        NSLog(@"Failed to load MediaPipe graph config: %@", configLoadError);
        return nil;
    }
    
    // Parse the graph config string into mediapipe::CalculatorGraphConfig proto object.
    mediapipe::CalculatorGraphConfig config = mediapipe::ParseTextProtoOrDie<mediapipe::CalculatorGraphConfig>(string.UTF8String);

    // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
    MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];

    [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
    [newGraph addFrameOutputStream:kMultiFaceGeometryStream outputPacketType:MPPPacketTypeRaw];

    return newGraph;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.mediapipeGraph = [[self class] loadGraphFromResource:kGraphName];
        self.mediapipeGraph.delegate = self;
        self.mediapipeGraph.maxFramesInFlight = 2;
    }
    return self;
}

- (instancetype)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        self.mediapipeGraph = [[self class] loadGraphFromString:string];
        self.mediapipeGraph.delegate = self;
        self.mediapipeGraph.maxFramesInFlight = 2;
    }
    return self;
}

- (void)startGraph {
    // Start running self.mediapipeGraph.
    NSError* error;
    if (![self.mediapipeGraph startWithError:&error]) {
        NSLog(@"Failed to start graph: %@", error);
    }
}

#pragma mark - MPPInputSourceDelegate methods

- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer timestamp:(CMTime)timestamp {
    
    mediapipe::Timestamp graphTimestamp(static_cast<mediapipe::TimestampBaseType>(
        mediapipe::Timestamp::kTimestampUnitsPerSecond * CMTimeGetSeconds(timestamp)));
    
    [self.mediapipeGraph sendPixelBuffer:imageBuffer
                              intoStream:kInputStream
                              packetType:MPPPacketTypePixelBuffer
                               timestamp:graphTimestamp];
}

#pragma mark - MPPGraphDelegate methods

// Receives CVPixelBufferRef from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer fromStream:(const std::string&)streamName {
    if (streamName == kOutputStream) {
        [_delegate tracker: self didOutputPixelBuffer: pixelBuffer];
    }
}

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const ::mediapipe::Packet&)packet
            fromStream:(const std::string&)streamName {
    if (streamName == kMultiFaceGeometryStream) {
        if (packet.IsEmpty()) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(trackerDidOutputWithNoFace:)]) {
                [self.delegate trackerDidOutputWithNoFace:self];
            }
            return;
        }
        
        // find the face_geometry with mediapipe
        const auto& multiFaceGeometry = packet.Get<std::vector<::mediapipe::face_geometry::FaceGeometry>>();
        
        for (int faceIndex = 0; faceIndex < multiFaceGeometry.size(); ++faceIndex) {
            const auto& faceGeometry = multiFaceGeometry[faceIndex];
            const auto& t = faceGeometry.pose_transform_matrix().packed_data();
            const auto& matrix = simd_matrix(
                (simd_float4){ t[0],  t[1],  t[2],  t[3] },
                (simd_float4){ t[4],  t[5],  t[6],  t[7] },
                (simd_float4){ t[8],  t[9],  t[10], t[11] },
                (simd_float4){ t[12], t[13], t[14], t[15] }
            );
            if (self.delegate && [self.delegate respondsToSelector:@selector(tracker:didOutputTransform:withFace:)]) {
                [self.delegate tracker:self didOutputTransform:matrix withFace:faceIndex];
            }
        }
        
    }else if (streamName == kLandmarksOutputStream) {
        if (packet.IsEmpty()) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(trackerDidOutputWithNoHand:)]) {
                [self.delegate trackerDidOutputWithNoHand:self];
            }
            return;
        }

        // find the hand landmark with mediapipe
        const auto& multiHandLandmarks = packet.Get<std::vector<::mediapipe::NormalizedLandmarkList>>();
        for (int handIndex = 0; handIndex < multiHandLandmarks.size(); ++handIndex) {
            const auto& landmarks = multiHandLandmarks[handIndex];
        
            NSLog(@"\tNumber of landmarks for hand[%d]: %d", handIndex, landmarks.landmark_size());
            
            for (int i = 0; i < landmarks.landmark_size(); ++i) {
                NSLog(@"\t\tLandmark[%d]: (%f, %f, %f)", i, landmarks.landmark(i).x(),
                    landmarks.landmark(i).y(), landmarks.landmark(i).z());
            }
        }
    }
}

@end
