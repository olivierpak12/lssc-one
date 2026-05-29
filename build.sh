#!/bin/bash

# Vercel build script for Flutter web app
# If Flutter is available, build; otherwise use pre-built files

if command -v flutter &> /dev/null; then
  echo "Flutter found, building..."
  flutter build web
else
  echo "Flutter not found, using pre-built files from build/web"
  # Pre-built files are already in build/web, nothing to do
  exit 0
fi
