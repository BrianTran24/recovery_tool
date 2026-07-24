#!/bin/bash

# Exit on error
set -e

# Load environment variables from .env
if [ -f .env ]; then
    # Use a more robust way to load .env to avoid issues with spaces or special chars
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ Error: .env file not found at project root."
    echo "💡 Please create a .env file with APPLE_ID, APPLE_TEAM_ID, APPLE_PASSWORD, and NOTARY_PROFILE."
    exit 1
fi

# Check required variables
REQUIRED_VARS=("APPLE_ID" "APPLE_TEAM_ID" "APPLE_PASSWORD" "NOTARY_PROFILE")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: $var is not set in .env."
        exit 1
    fi
done

APP_NAME="Recovery SD Tool"
VERSION="1.0.0"
DMG_NAME="Recovery_SD_Tool_v${VERSION}.dmg"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"

echo "🔐 Step 0: Checking if notary profile exists..."
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &>/dev/null; then
    echo "❌ Error: Notary profile '$NOTARY_PROFILE' not found in Keychain."
    echo "💡 Please run the following command to create it first:"
    echo ""
    echo "xcrun notarytool store-credentials \"$NOTARY_PROFILE\" \\"
    echo "    --apple-id \"$APPLE_ID\" \\"
    echo "    --team-id \"$APPLE_TEAM_ID\" \\"
    echo "    --password \"$APPLE_PASSWORD\""
    echo ""
    exit 1
fi

echo "🚀 Step 1: Building Flutter macOS app in release mode with Developer ID..."
# Export variables as environment variables so Flutter/xcodebuild can pick them up
export CODE_SIGN_IDENTITY="477E99BBCDC9705AE5F3816C95ACC41503B0B40D"
export DEVELOPMENT_TEAM="${APPLE_TEAM_ID}"
export OTHER_CODE_SIGN_FLAGS="--timestamp"

flutter build macos --release --device-id=macos

echo "🔍 Step 1.5: Verifying binary for Hardened Runtime and Signing Identity..."
if ! codesign -dvvv "${APP_PATH}" 2>&1 | grep -q "runtime"; then
    echo "❌ Error: Hardened Runtime is not enabled for ${APP_NAME}."
    echo "💡 Please check your Xcode project settings or Release.xcconfig."
    exit 1
fi

if ! codesign -dvvv "${APP_PATH}" 2>&1 | grep -q "Authority=Developer ID Application"; then
    echo "❌ Error: ${APP_NAME} is not signed with a Developer ID Application certificate."
    echo "💡 Current signature info:"
    codesign -dvvv "${APP_PATH}" 2>&1 | grep "Authority"
    exit 1
fi

echo "📦 Step 2: Packaging DMG..."
# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null
then
    echo "❌ Error: 'create-dmg' is not installed."
    echo "💡 You can install it using: brew install create-dmg"
    exit 1
fi

# Remove existing DMG if it exists
if [ -f "${DMG_NAME}" ]; then
    rm "${DMG_NAME}"
fi

# Create DMG
create-dmg \
  --volname "${APP_NAME} Installer" \
  --volicon "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 200 190 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 600 185 \
  "${DMG_NAME}" \
  "${APP_PATH}"

echo "🖋️ Step 3: Signing the DMG..."
codesign --force --timestamp --options runtime --sign "Developer ID Application" "${DMG_NAME}"

echo "📤 Step 4: Submitting DMG to Apple for notarization..."
xcrun notarytool submit "${DMG_NAME}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

echo "🖋️ Step 5: Stapling the notarization ticket to DMG..."
xcrun stapler staple "${DMG_NAME}"

echo "✅ Step 6: Verifying final DMG notarization..."
spctl --assess -vv --type install "${DMG_NAME}"

echo "🏁 Process completed successfully! Output: ${DMG_NAME}"
