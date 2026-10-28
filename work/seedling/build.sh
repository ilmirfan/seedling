#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p build/Seedling.app/Contents/{MacOS,Resources,Frameworks} build/module-cache
swiftc -parse-as-library -swift-version 5 -target arm64-apple-macosx14.0 -module-cache-path build/module-cache -O Sources/*.swift -o build/Seedling.app/Contents/MacOS/Seedling
cp Info.plist build/Seedling.app/Contents/Info.plist
cp Assets/Seedling.png Assets/Seedling-header.png Assets/Seedling.icns build/Seedling.app/Contents/Resources/
python3 bundle_engine.py
codesign --force --sign - build/Seedling.app
printf 'Built %s/build/Seedling.app\n' "$PWD"
