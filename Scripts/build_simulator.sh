#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
destination="${SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
mkdir -p Artifacts
xcodebuild -project TradeLedger.xcodeproj -scheme TradeLedger \
  -destination "$destination" -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee Artifacts/build.log
