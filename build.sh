#!/bin/bash

set -e

echo "Installing Flutter..."

git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:$(pwd)/flutter/bin"

flutter doctor
flutter pub get

# Build dart-define flags from Vercel environment variables.
# Only public-facing variables are passed to Flutter Web.
# Secrets (private keys, API keys) must NOT be embedded in the client.
DART_DEFINES=""
if [ -n "$CONVEX_SITE_URL" ]; then
  DART_DEFINES="$DART_DEFINES --dart-define=CONVEX_SITE_URL=$CONVEX_SITE_URL"
fi
if [ -n "$CONVEX_URL" ]; then
  DART_DEFINES="$DART_DEFINES --dart-define=CONVEX_URL=$CONVEX_URL"
fi
if [ -n "$USE_MAINNET" ]; then
  DART_DEFINES="$DART_DEFINES --dart-define=USE_MAINNET=$USE_MAINNET"
fi

echo "DART_DEFINES: $DART_DEFINES"

flutter build web --release $DART_DEFINES