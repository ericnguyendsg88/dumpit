#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
xcodebuild -project Unload.xcodeproj -scheme "Unload macOS" -configuration Release -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
codesign --force --deep --sign - .build/Build/Products/Release/DumpIt.app
echo "Built .build/Build/Products/Release/DumpIt.app"
