#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Clone Flutter SDK (Stable Channel) if not exists
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add Flutter to PATH for the current session
export PATH="$PATH:$(pwd)/flutter/bin"

# Enable web support for Flutter
flutter config --enable-web

# Fetch project dependencies
flutter pub get

echo "Flutter installation and setup complete."
