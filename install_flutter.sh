#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Download Flutter SDK
curl -o flutter_linux_3.22.2-stable.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.2-stable.tar.xz

# Extract Flutter SDK
tar -xf flutter_linux_3.22.2-stable.tar.xz

# Add Flutter to PATH for the current session
export PATH="$PATH:$(pwd)/flutter/bin"

# Enable web support for Flutter
flutter config --enable-web

# Fetch project dependencies
flutter pub get

echo "Flutter installation and setup complete."
