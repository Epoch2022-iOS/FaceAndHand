load("@build_bazel_rules_apple//apple:ios.bzl", "ios_framework")

ios_framework(
    name = "FaceAndHand",
    hdrs = [
        "FaceAndHand",
    ],
    infoplists = ["Info.plist"],
    bundle_id = "com.mediapipe.prebuilt.facegeometry",
    families = ["iphone", "ipad"],
    minimum_os_version = "12.0",
    deps = [
        ":MPPBFaceGeometryFramework",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "FaceAndHandFramework",
    srcs = [
        "FaceAndHand",
    ],
    hdrs = [
        "FaceAndHand",
    ],
    copts = ["-std=c++17"],
    data = [
        "//mediapipe/modules/face_detection:face_detection_short_range.tflite",
        "//mediapipe/modules/face_landmark:face_landmark.tflite",
        "//mediapipe/modules/face_geometry/data:geometry_pipeline_metadata_landmarks.binarypb",
        "//mediapipe/examples/ios/prebuilt/facegeometry/graphs:face_geometry_with_transform.binarypb",
  	"//mediapipe/graphs/hand_tracking:hand_tracking_mobile_gpu.binarypb",
        "//mediapipe/modules/hand_landmark:hand_landmark_full.tflite",
        "//mediapipe/modules/hand_landmark:handedness.txt",
        "//mediapipe/modules/palm_detection:palm_detection_full.tflite",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit",
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/objc:mediapipe_input_sources_ios",
        "//mediapipe/objc:mediapipe_layer_renderer",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/framework/port:parse_text_proto",
            "//mediapipe/examples/ios/prebuilt/facegeometry/graphs:face_geometry_with_transform_calculators",
	    "//mediapipe/graphs/hand_tracking:mobile_calculators",
            "//mediapipe/framework/formats:landmark_cc_proto",
        ],
    }),
)