#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="src/MeloNX/MeloNX.xcodeproj"
SCHEME="${SCHEME:-MeloNX}"
CONFIGURATION="${CONFIGURATION:-Archive}"
SDK="${SDK:-iphoneos}"
DERIVED_DATA="${DERIVED_DATA:-build/Derived}"
OUTPUT_IPA="${OUTPUT_IPA:-build/melonx.ipa}"
BUILD_LOG="${BUILD_LOG:-build/build.log}"
APP_NAME="${APP_NAME:-MeloNX Mod}"
APP_VERSION="${APP_VERSION:-1.0.0}"
APP_VERSION_INFO="${APP_VERSION_INFO:-Fork}"
APP_ICONS_DIR="src/MeloNX/MeloNX/Assets/26-AppIcons"
EXCLUDED_ASSETS_DIR="build/excluded-assets"
MOVED_APP_ICONS_DIR="$EXCLUDED_ASSETS_DIR/26-AppIcons"

usage() {
    cat <<'EOF'
Usage:
  ./scripts/build-ipa.sh

Optional environment variables:
  APP_NAME          App name shown on iOS Home Screen. Default: MeloNX Mod
  APP_VERSION       CFBundleShortVersionString / marketing version. Default: 1.0.0
  APP_VERSION_INFO  Extra fork label stored in LCVersionInfo. Default: Fork
  OUTPUT_IPA        Output IPA path. Default: build/melonx.ipa
  DERIVED_DATA      Xcode DerivedData path. Default: build/Derived
  CONFIGURATION     Xcode configuration. Default: Archive
  SDK               Xcode SDK. Default: iphoneos

Examples:
  APP_NAME="MeloNX Mod" APP_VERSION="1.0.1" ./scripts/build-ipa.sh
  APP_NAME="MeloNX Test" APP_VERSION="1.0.1-beta1" OUTPUT_IPA="build/melonx-test.ipa" ./scripts/build-ipa.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

restore_assets() {
    if [[ -d "$MOVED_APP_ICONS_DIR" && ! -d "$APP_ICONS_DIR" ]]; then
        mkdir -p "$(dirname "$APP_ICONS_DIR")"
        mv "$MOVED_APP_ICONS_DIR" "$APP_ICONS_DIR"
    fi
}

trap restore_assets EXIT INT TERM

mkdir -p build "$EXCLUDED_ASSETS_DIR"

if [[ -d "$APP_ICONS_DIR" ]]; then
    rm -rf "$MOVED_APP_ICONS_DIR"
    mv "$APP_ICONS_DIR" "$MOVED_APP_ICONS_DIR"
fi

export PATH="$HOME/.dotnet:$PATH"

echo "Building $SCHEME ($CONFIGURATION, $SDK)..."
echo "App name: $APP_NAME"
echo "App version: $APP_VERSION $APP_VERSION_INFO"
xcodebuild build \
    -quiet \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' \
    MARKETING_VERSION="$APP_VERSION" \
    INFOPLIST_KEY_CFBundleDisplayName="$APP_NAME" \
    INFOPLIST_KEY_CFBundleName="$APP_NAME" \
    INFOPLIST_KEY_LCVersionInfo="$APP_VERSION_INFO" \
    2>&1 | tee "$BUILD_LOG"

restore_assets

APP_PATH="$(find "$DERIVED_DATA/Build/Products" -maxdepth 3 -name 'MeloNX.app' -type d | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
    echo "error: MeloNX.app not found under $DERIVED_DATA/Build/Products" >&2
    exit 1
fi

rm -rf build/Payload "$OUTPUT_IPA"
mkdir -p build/Payload
cp -R "$APP_PATH" build/Payload/

echo "Packaging $OUTPUT_IPA..."
(cd build && /usr/bin/zip -qry "$(basename "$OUTPUT_IPA")" Payload)

echo "IPA created: $ROOT_DIR/$OUTPUT_IPA"
ls -lh "$OUTPUT_IPA"

echo "Bundle info:"
/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' build/Payload/MeloNX.app/Info.plist || true
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/Payload/MeloNX.app/Info.plist || true
/usr/libexec/PlistBuddy -c 'Print :LCVersionInfo' build/Payload/MeloNX.app/Info.plist || true
