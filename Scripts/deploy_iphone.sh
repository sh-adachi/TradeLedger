#!/bin/bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: ./Scripts/deploy_iphone.sh <iPhone UDID> <Apple Development Team ID>"
    echo "Builds, installs, and launches TradeLedger on the specified connected iPhone."
    echo "List connected devices: xcrun xctrace list devices"
    exit 0
fi
if [[ $# -ne 2 || ! "$1" =~ ^[A-Za-z0-9-]+$ || ! "$2" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "Usage: ./Scripts/deploy_iphone.sh <iPhone UDID> <10-character Team ID>" >&2
    exit 2
fi

cd "$(dirname "$0")/.."
tradeledger_device="$1"
tradeledger_team="$2"
tradeledger_build=".build/device"
mkdir -p Artifacts

# Explicit device deployment: Xcode account credentials, code signing, and
# a trusted iPhone with Developer Mode enabled are required.
xcodebuild -project TradeLedger.xcodeproj -scheme TradeLedger \
    -configuration Debug -destination "id=$tradeledger_device" \
    -derivedDataPath "$tradeledger_build" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    "DEVELOPMENT_TEAM=$tradeledger_team" build 2>&1 | tee Artifacts/device-build.log

xcrun devicectl device install app --device "$tradeledger_device" \
    "$tradeledger_build/Build/Products/Debug-iphoneos/TradeLedger.app" \
    2>&1 | tee Artifacts/device-install.log

xcrun devicectl device process launch --device "$tradeledger_device" \
    dev.adachi.tradeledger 2>&1 | tee Artifacts/device-launch.log
