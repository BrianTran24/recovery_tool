#!/bin/bash

# Exit on error
set -e

# Load environment variables from .env
if [ -f .env ]; then
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
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
ZIP_PATH="build/macos/Build/Products/Release/${APP_NAME}.zip"

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

echo "🚀 Step 1: Building Flutter macOS app in release mode..."
flutter build macos --release

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

echo "📦 Step 2: Compressing the application..."
if [ -f "${ZIP_PATH}" ]; then
    rm "${ZIP_PATH}"
fi
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "📤 Step 3: Submitting to Apple for notarization..."
xcrun notarytool submit "${ZIP_PATH}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

echo "🖋️ Step 4: Stapling the notarization ticket..."
xcrun stapler staple "${APP_PATH}"

echo "✅ Step 5: Verifying notarization..."
spctl --assess -vv --type install "${APP_PATH}"

echo "🏁 Notarization process completed successfully!"
