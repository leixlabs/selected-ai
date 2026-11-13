#!/usr/bin/env bash
#
# install.sh — Build and install the SelectedAI macOS app.
#
# Usage:
#   ./install.sh                  # build (Release) + self-sign + install to /Applications
#   INSTALL_DIR=~/Applications ./install.sh
#   SIGN_IDENTITY="My Cert" ./install.sh   # use a different self-signed cert
#
# Why self-sign (not "no signing"):
#   macOS TCC records the Accessibility permission by the app's SIGNING IDENTITY.
#   A fully unsigned / ad-hoc build is tracked by its binary hash, which changes
#   on every rebuild -> the granted permission is silently lost -> the toolbar
#   never appears. Signing with a STABLE self-signed cert (created once in
#   Keychain Access) keeps the identity constant, so the Accessibility grant
#   survives rebuilds and you only authorize once.
#
# One-time setup:
#   In Keychain Access: Certificate Assistant > Create a Certificate...
#     Name : SelectedAI Local   (or whatever you pass as SIGN_IDENTITY)
#     Type : Code Signing
#   Then set its Trust > Code Signing to "Always Trust".

set -euo pipefail

# ---- Resolve paths relative to this script --------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/src/selectedai"
PROJECT_FILE="$PROJECT_DIR/selectedai.xcodeproj"
TARGET="selectedai"
CONFIGURATION="Release"
BUILD_DIR="$SCRIPT_DIR/build"
XCODEBUILD="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"

# ---- Install location (override via env) -----------------------------------
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
APP_NAME="selectedai.app"

# Self-signed cert used to give the app a stable identity across rebuilds.
SIGN_IDENTITY="${SIGN_IDENTITY:-SelectedAI Local}"
ENTITLEMENTS="$PROJECT_DIR/selectedai/selectedai.entitlements"

echo "==> SelectedAI install (self-signed with '$SIGN_IDENTITY')"
echo "    Project : $PROJECT_FILE"
echo "    Target  : $TARGET ($CONFIGURATION)"
echo "    Install : $INSTALL_DIR"

# ---- Sanity checks ---------------------------------------------------------
if [ ! -d "$PROJECT_FILE" ]; then
  echo "ERROR: Xcode project not found at $PROJECT_FILE" >&2
  exit 1
fi

if [ ! -x "$XCODEBUILD" ]; then
  echo "ERROR: xcodebuild not found at $XCODEBUILD. Install Xcode." >&2
  exit 1
fi

if ! command -v codesign >/dev/null 2>&1; then
  echo "ERROR: codesign not found." >&2
  exit 1
fi

# ---- Build (skip Xcode signing; we sign ourselves below) -------------------
echo "==> Building (this may take a minute)..."
"$XCODEBUILD" \
  -project "$PROJECT_FILE" \
  -target "$TARGET" \
  -configuration "$CONFIGURATION" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
  build

APP_PATH="$BUILD_DIR/$APP_NAME"
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: built app not found at $APP_PATH" >&2
  exit 1
fi

# ---- Sign with a STABLE local identity -------------------------------------
# This is what makes the Accessibility grant persist across rebuilds.
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  echo "==> Signing with local certificate: $SIGN_IDENTITY"
  if [ -f "$ENTITLEMENTS" ]; then
    codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" \
      --sign "$SIGN_IDENTITY" "$APP_PATH"
  else
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_PATH"
  fi
else
  echo "WARNING: local cert '$SIGN_IDENTITY' not found in login keychain." >&2
  echo "         Falling back to ad-hoc signing (Accessibility grant will NOT" >&2
  echo "         survive rebuilds). To fix, create a Code Signing cert named" >&2
  echo "         '$SIGN_IDENTITY' in Keychain Access (set Trust > Code Signing" >&2
  echo "         to 'Always Trust'), then re-run this script." >&2
  codesign --force --deep --sign - "$APP_PATH"
fi

# ---- Install ---------------------------------------------------------------
echo "==> Installing to $INSTALL_DIR"
if [ -w "$INSTALL_DIR" ]; then
  cp -R "$APP_PATH" "$INSTALL_DIR/"
else
  sudo cp -R "$APP_PATH" "$INSTALL_DIR/"
  sudo chown -R "$(id -un):staff" "$INSTALL_DIR/$APP_NAME"
fi

DEST_APP="$INSTALL_DIR/$APP_NAME"

# Strip quarantine so the app can launch without Gatekeeper blocking.
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true

echo "==> Done. Launch with:"
echo "      open \"$DEST_APP\""
echo
echo "    IMPORTANT — authorize Accessibility ONCE (persists across rebuilds now):"
echo "      1. Open System Settings > Privacy & Security > Accessibility"
echo "      2. Add '$APP_NAME' and ENABLE it, then quit & relaunch the app."
echo "      3. (Fixed in code) it re-registers the AX observer automatically once granted."
echo
echo "    If you later change/recreate the '$SIGN_IDENTITY' cert, re-grant once more."
