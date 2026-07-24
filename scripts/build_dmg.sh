#!/bin/bash

# Exit on error
set -e

APP_NAME="recovery_tool"
VERSION="1.0.0"
DMG_NAME="RecoverySD_Tool_v${VERSION}.dmg"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"

echo "🚀 Building Flutter macOS app in release mode..."
flutter build macos --release

echo "📦 Packaging DMG..."

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

echo "✅ DMG created successfully: ${DMG_NAME}"
