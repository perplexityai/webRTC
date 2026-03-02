#!/bin/bash
#
# Builds an audio-only WebRTC xcframework (iOS + macOS) from source.
#
# Prerequisites:
#   - depot_tools on PATH (https://chromium.googlesource.com/chromium/tools/depot_tools.git)
#   - Xcode command line tools
#
# Usage:
#   ./build.sh                     # Full build (fetch + build + package)
#   ./build.sh --skip-fetch        # Skip fetching source (if already checked out)
#   ./build.sh --skip-ios          # Skip iOS build
#   ./build.sh --skip-macos        # Skip macOS build
#
set -euo pipefail

BRANCH="branch-heads/7151"  # M141
IOS_DEPLOYMENT_TARGET="17.0"
MACOS_DEPLOYMENT_TARGET="13.5"
OUTPUT_DIR="out_xcframework"

SKIP_FETCH=false
SKIP_IOS=false
SKIP_MACOS=false

for arg in "$@"; do
  case $arg in
    --skip-fetch) SKIP_FETCH=true ;;
    --skip-ios)   SKIP_IOS=true ;;
    --skip-macos) SKIP_MACOS=true ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# Shared GN args for the audio-only build (no video codecs, no protobuf, no tests)
GN_ARGS=(
  'treat_warnings_as_errors=false'
  'rtc_include_tests=false'
  'rtc_build_examples=false'
  'rtc_build_tools=false'
  'rtc_enable_protobuf=false'
  'rtc_use_h264=false'
  'rtc_use_h265=false'
  'enable_libaom=false'
  'rtc_include_dav1d_in_internal_decoder_factory=false'
  'rtc_include_ilbc=false'
  'rtc_enable_sctp=true'
  'symbol_level=0'
  'enable_stripping=true'
  'rtc_disable_metrics=true'
  'rtc_disable_trace_events=true'
  'rtc_builtin_ssl_root_certificates=false'
)

# -- Preflight -----------------------------------------------------------

# Bypass depot_tools' managed vpython3 wrapper, which may be broken if
# python3_bin_reldir.txt is missing. System python3 works fine for gn/ninja.
export VPYTHON_BYPASS="manually managed python not supported by chrome operations"

if ! command -v gn &>/dev/null; then
  echo "Error: 'gn' not found. Add depot_tools to your PATH."
  echo "  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git"
  echo "  export PATH=\"\$PWD/depot_tools:\$PATH\""
  echo ""
  echo "  Alternatively, if you have an existing WebRTC checkout, use the bundled tools:"
  echo "  export PATH=\"\$PWD/webrtc_build/src/buildtools/mac:\$PWD/webrtc_build/src/third_party/ninja:\$PATH\""
  exit 1
fi

# -- Fetch ----------------------------------------------------------------

if [ "$SKIP_FETCH" = false ]; then
  echo "==> Fetching WebRTC source ($BRANCH)..."
  mkdir -p webrtc_build && cd webrtc_build
  if [ ! -d src ]; then
    fetch --nohooks webrtc_ios
  fi
  cd src
  git fetch origin "$BRANCH"
  git checkout FETCH_HEAD
  gclient sync --force --reset
else
  if [ ! -d webrtc_build/src ]; then
    echo "Error: webrtc_build/src not found. Run without --skip-fetch first."
    exit 1
  fi
  cd webrtc_build/src
fi

echo "==> WebRTC source ready at $(pwd)"

# -- iOS build ------------------------------------------------------------

if [ "$SKIP_IOS" = false ]; then
  echo "==> Building iOS slices (arm64 device, arm64+x64 simulator)..."
  python3 tools_webrtc/ios/build_ios_libs.py \
    --build_config release \
    --arch device:arm64 simulator:arm64 simulator:x64 \
    --deployment-target "$IOS_DEPLOYMENT_TARGET" \
    --extra-gn-args "${GN_ARGS[@]}"

  echo "==> iOS build complete: out_ios_libs/WebRTC.xcframework"
fi

# -- macOS build ----------------------------------------------------------

build_mac_slice() {
  local cpu=$1
  local out_dir="out/mac_${cpu}"

  echo "==> Building macOS $cpu..."
  gn gen "$out_dir" --args="
    target_os=\"mac\"
    target_cpu=\"$cpu\"
    is_debug=false
    is_component_build=false
    use_custom_libcxx=false
    rtc_enable_symbol_export=true
    mac_deployment_target=\"$MACOS_DEPLOYMENT_TARGET\"
    $(printf '%s\n' "${GN_ARGS[@]}")
  "
  ninja -C "$out_dir" mac_framework_objc
}

if [ "$SKIP_MACOS" = false ]; then
  build_mac_slice arm64
  build_mac_slice x64

  echo "==> Creating fat macOS framework..."
  rm -rf out/mac_fat
  mkdir -p out/mac_fat
  cp -R out/mac_arm64/WebRTC.framework out/mac_fat/WebRTC.framework
  # The macOS framework uses a versioned bundle structure where the binary
  # lives at Versions/A/WebRTC (not at the top level like iOS).
  lipo -create \
    out/mac_arm64/WebRTC.framework/Versions/A/WebRTC \
    out/mac_x64/WebRTC.framework/Versions/A/WebRTC \
    -output out/mac_fat/WebRTC.framework/Versions/A/WebRTC

  # Fix macOS versioned bundle structure.
  # Chromium's build outputs a flat framework (all files at top level), but macOS
  # requires versioned bundles with symlinks. Without this, codesign fails with
  # "bundle format is ambiguous" and the app can't be signed.
  echo "==> Fixing macOS framework bundle structure..."
  MAC_FW="out/mac_fat/WebRTC.framework"

  # Replace top-level real files/dirs with symlinks into Versions/Current/
  for item in WebRTC Headers Modules Resources; do
    if [ -e "$MAC_FW/$item" ] && [ ! -L "$MAC_FW/$item" ]; then
      rm -rf "$MAC_FW/$item"
      ln -s "Versions/Current/$item" "$MAC_FW/$item"
    fi
  done

  # Ad-hoc sign the framework so Xcode can re-sign it during CodeSignOnCopy
  codesign --force --sign - "$MAC_FW"

  echo "==> macOS build complete: out/mac_fat/WebRTC.framework"
fi

# -- Assemble xcframework -------------------------------------------------

echo "==> Assembling xcframework..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

FRAMEWORK_ARGS=()

if [ "$SKIP_IOS" = false ]; then
  FRAMEWORK_ARGS+=(-framework out_ios_libs/WebRTC.xcframework/ios-arm64/WebRTC.framework)
  FRAMEWORK_ARGS+=(-framework out_ios_libs/WebRTC.xcframework/ios-arm64_x86_64-simulator/WebRTC.framework)
fi

if [ "$SKIP_MACOS" = false ]; then
  FRAMEWORK_ARGS+=(-framework out/mac_fat/WebRTC.framework)
fi

xcodebuild -create-xcframework \
  "${FRAMEWORK_ARGS[@]}" \
  -output "$OUTPUT_DIR/WebRTC.xcframework"

# -- Package for SPM -----------------------------------------------------

echo "==> Packaging for SPM..."
cd "$OUTPUT_DIR"
zip -ry WebRTC.xcframework.zip WebRTC.xcframework
CHECKSUM=$(swift package compute-checksum WebRTC.xcframework.zip)

echo ""
echo "============================================"
echo "  Build complete!"
echo "============================================"
echo ""
echo "  xcframework: $(pwd)/WebRTC.xcframework"
echo "  zip:         $(pwd)/WebRTC.xcframework.zip"
echo "  checksum:    $CHECKSUM"
echo ""
echo "  Next steps:"
echo "  1. Upload WebRTC.xcframework.zip as a GitHub release asset"
echo "  2. Update Package.swift checksum to: $CHECKSUM"
echo ""
