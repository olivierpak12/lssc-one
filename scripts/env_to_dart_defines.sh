#!/bin/bash
# Reads .env file from project root and exports DART_DEFINES
# for use with flutter build/run --dart-define.
#
# Usage:
#   source scripts/env_to_dart_defines.sh
#   flutter run $DART_DEFINES
#   flutter build web --release $DART_DEFINES
#
# Only exports variables that are safe for Flutter Web (public).

set -e

ENV_FILE="$(dirname "$0")/../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Warning: .env file not found at $ENV_FILE"
  echo "Creating from .env.example if available..."
  EXAMPLE_FILE="$(dirname "$0")/../.env.example"
  if [ -f "$EXAMPLE_FILE" ]; then
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    echo "Created .env from .env.example"
  else
    echo "No .env or .env.example found. Using empty defaults."
  fi
fi

DART_DEFINES=""

if [ -f "$ENV_FILE" ]; then
  while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ ]] && continue
    [[ -z "$key" ]] && continue
    # Trim whitespace
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)

    case "$key" in
      CONVEX_SITE_URL|CONVEX_URL|USE_MAINNET)
        DART_DEFINES="$DART_DEFINES --dart-define=$key=$value"
        ;;
    esac
  done < "$ENV_FILE"
fi

export DART_DEFINES
echo "DART_DEFINES=$DART_DEFINES"
