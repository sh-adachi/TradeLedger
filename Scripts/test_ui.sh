#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
destination="${SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
result_path="Artifacts/UITests-$(date +%Y%m%d-%H%M%S).xcresult"
mkdir -p Artifacts
xcodebuild -project TradeLedger.xcodeproj -scheme TradeLedger \
  -destination "$destination" -derivedDataPath .derivedData \
  -parallel-testing-enabled NO -resultBundlePath "$result_path" \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee Artifacts/ui-tests.log
