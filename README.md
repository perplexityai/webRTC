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
.package(url: "https://github.com/perplexityai/webRTC.git", exact: "141.1.0")
```

## Building From Source

Requires `gn` and `ninja` on your `PATH`. Takes 30-60 minutes.

If you have [depot_tools](https://chromium.googlesource.com/chromium/tools/depot_tools.git), add them to your PATH. Otherwise, after the first fetch you can use the bundled tools from the checkout:

```bash
export PATH="$PWD/webrtc_build/src/buildtools/mac:$PWD/webrtc_build/src/third_party/ninja:$PATH"
```

```bash
# Full build: fetch source, build iOS + macOS, package xcframework
./build.sh

# Rebuild without re-fetching source
./build.sh --skip-fetch

# iOS only (skip macOS slices)
./build.sh --skip-macos
```

The script fetches M141 (`branch-heads/7151`), builds iOS slices (arm64 device + arm64/x64 simulator), builds macOS slices (arm64 + x86_64), assembles the xcframework, and prints the SPM checksum.

See `build.sh` for all the GN args and details.

### Troubleshooting

**`vpython3` / `python3_bin_reldir.txt` errors**: The script sets `VPYTHON_BYPASS` automatically to use system Python instead of depot_tools' managed Python. If you still see issues, ensure system `python3` is available.

**iOS build fails at license generation**: The `generate_licenses.py` step may fail with a JSON parse error after the xcframework is already built. This is non-critical — the xcframework at `out_ios_libs/WebRTC.xcframework` is valid. You can build macOS separately with `--skip-fetch --skip-ios` and then assemble manually.

**macOS codesign "bundle format is ambiguous"**: The build script automatically fixes Chromium's flat framework output into Apple's required versioned bundle structure (symlinks into `Versions/Current/`). This was the root cause of macOS signing failures in earlier builds.
