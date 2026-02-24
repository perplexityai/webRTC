# WebRTC (Audio-Only Build)

Custom WebRTC build from M141 (`branch-heads/7151`) optimized for audio + data channel use cases.

## What's Included

- Audio codecs: Opus, G.711, G.722, PCM16B
- Audio processing module (AEC, NS, AGC)
- Data channels (SCTP)
- Full peer connection API (RTCPeerConnection, RTCSessionDescription, RTCIceCandidate, etc.)
- RTCAudioSession / RTCAudioSessionConfiguration (iOS)

## What's Stripped

Compared to the full WebRTC build:

| Feature | Status |
|---------|--------|
| H.264 (OpenH264) | Disabled (`rtc_use_h264=false`) |
| H.265/HEVC | Disabled (`rtc_use_h265=false`) |
| AV1 (libaom) | Disabled (`enable_libaom=false`) |
| dav1d decoder | Disabled |
| iLBC codec | Disabled (`rtc_include_ilbc=false`) |
| Protobuf | Disabled (`rtc_enable_protobuf=false`) |
| Metrics/tracing | Disabled |
| Tests/examples | Excluded |

Note: VP8/VP9 (libvpx) headers are still compiled for build graph compatibility but the video codec factories are not used when only audio tracks are created.

## Size Comparison

| Slice | Full Build (stasel M137) | This Build (M141) |
|-------|--------------------------|-------------------|
| ios-arm64 | ~11MB | **6.4MB** |
| Total xcframework | ~87MB | **39MB** |

## Platforms

- iOS 17.0+ (device arm64, simulator arm64/x86_64)
- macOS 13.5+ (arm64/x86_64)

## Installation (SPM)

```swift
.package(url: "https://github.com/bsudekum/webRTC.git", exact: "141.0.0-audio-only")
```

## Reproducing This Build

Built from WebRTC source at `branch-heads/7151` (M141) using:

```bash
# depot_tools + fetch webrtc_ios + gclient sync
# Then:
python3 tools_webrtc/ios/build_ios_libs.py \
  --build_config release \
  --arch device:arm64 simulator:arm64 simulator:x64 \
  --deployment-target 17.0 \
  --extra-gn-args \
    'treat_warnings_as_errors=false' \
    'rtc_include_tests=false' \
    'rtc_build_examples=false' \
    'rtc_build_tools=false' \
    'rtc_enable_protobuf=false' \
    'rtc_use_h264=false' \
    'rtc_use_h265=false' \
    'enable_libaom=false' \
    'rtc_include_dav1d_in_internal_decoder_factory=false' \
    'rtc_include_ilbc=false' \
    'rtc_enable_sctp=true' \
    'symbol_level=0' \
    'enable_stripping=true' \
    'rtc_disable_metrics=true' \
    'rtc_disable_trace_events=true' \
    'rtc_builtin_ssl_root_certificates=false'

# macOS slices built with gn gen + ninja (mac_framework_objc target)
# then assembled with xcodebuild -create-xcframework
```
