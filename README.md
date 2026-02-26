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
.package(url: "https://github.com/perplexityai/webRTC.git", exact: "141.0.0-audio-only")
```

## Building From Source

Building WebRTC from source requires Google's `depot_tools` toolchain and takes 30-60 minutes depending on your machine. The steps below produce the same xcframework hosted in this repo's GitHub release.

### Prerequisites

```bash
# Install depot_tools (Google's build toolchain)
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PWD/depot_tools:$PATH"
```

### 1. Fetch WebRTC source

```bash
mkdir webrtc_build && cd webrtc_build
fetch --nohooks webrtc_ios
cd src
git checkout branch-heads/7151  # M141
gclient sync
```

### 2. Build iOS slices (device + simulator)

```bash
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
```

This produces `out_ios_libs/WebRTC.xcframework` with three iOS slices (device arm64, simulator arm64, simulator x86_64).

### 3. Build macOS slices (arm64 + x86_64)

The iOS build script doesn't support macOS, so macOS slices are built manually with `gn` + `ninja`.

For each architecture (`arm64` and `x64`):

```bash
# arm64
gn gen out/mac_arm64 --args='
  target_os="mac"
  target_cpu="arm64"
  is_debug=false
  is_component_build=false
  rtc_include_tests=false
  rtc_build_examples=false
  rtc_build_tools=false
  rtc_enable_protobuf=false
  rtc_use_h264=false
  rtc_use_h265=false
  enable_libaom=false
  rtc_include_dav1d_in_internal_decoder_factory=false
  rtc_include_ilbc=false
  rtc_enable_sctp=true
  symbol_level=0
  enable_stripping=true
  rtc_disable_metrics=true
  rtc_disable_trace_events=true
  rtc_builtin_ssl_root_certificates=false
  treat_warnings_as_errors=false
  mac_deployment_target="13.5"
'
ninja -C out/mac_arm64 mac_framework_objc

# x86_64
gn gen out/mac_x64 --args='
  target_os="mac"
  target_cpu="x64"
  is_debug=false
  is_component_build=false
  rtc_include_tests=false
  rtc_build_examples=false
  rtc_build_tools=false
  rtc_enable_protobuf=false
  rtc_use_h264=false
  rtc_use_h265=false
  enable_libaom=false
  rtc_include_dav1d_in_internal_decoder_factory=false
  rtc_include_ilbc=false
  rtc_enable_sctp=true
  symbol_level=0
  enable_stripping=true
  rtc_disable_metrics=true
  rtc_disable_trace_events=true
  rtc_builtin_ssl_root_certificates=false
  treat_warnings_as_errors=false
  mac_deployment_target="13.5"
'
ninja -C out/mac_x64 mac_framework_objc
```

Then create a fat macOS framework:

```bash
cp -R out/mac_arm64/WebRTC.framework out/mac_fat/WebRTC.framework
lipo -create \
  out/mac_arm64/WebRTC.framework/WebRTC \
  out/mac_x64/WebRTC.framework/WebRTC \
  -output out/mac_fat/WebRTC.framework/WebRTC
```

### 4. Assemble the xcframework

Combine the iOS xcframework slices with the macOS fat framework:

```bash
xcodebuild -create-xcframework \
  -framework out_ios_libs/WebRTC.xcframework/ios-arm64/WebRTC.framework \
  -framework out_ios_libs/WebRTC.xcframework/ios-arm64_x86_64-simulator/WebRTC.framework \
  -framework out/mac_fat/WebRTC.framework \
  -output WebRTC.xcframework
```

### 5. Package for SPM

```bash
# Zip the xcframework
zip -ry WebRTC.xcframework.zip WebRTC.xcframework

# Get the checksum for Package.swift
swift package compute-checksum WebRTC.xcframework.zip
```

Upload `WebRTC.xcframework.zip` as a GitHub release asset and update the `checksum` in `Package.swift`.

### Troubleshooting

- **`fetch` hangs or fails**: Make sure `depot_tools` is on your `PATH` and run `gclient` once to bootstrap.
- **Ninja build errors about missing files**: Run `gclient sync` again — the checkout may be incomplete.
- **`mac_framework_objc` target not found**: Make sure `target_os="mac"` is set in the gn args. The target only exists for macOS builds.
- **Bitcode errors**: WebRTC no longer supports bitcode. This is expected for Xcode 14+.
