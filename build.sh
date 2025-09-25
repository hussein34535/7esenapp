#!/bin/bash
set -e

# Download and extract Flutter
echo "Downloading Flutter..."
curl -o flutter_linux_3.22.2-stable.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.2-stable.tar.xz
tar -xf flutter_linux_3.22.2-stable.tar.xz

# Run flutter commands using the full path
echo "Configuring Flutter and getting dependencies..."
./flutter/bin/flutter config --enable-web
./flutter/bin/flutter pub get

# Build the web app
echo "Building Flutter web app..."
./flutter/bin/flutter build web --release

echo "Build finished."
