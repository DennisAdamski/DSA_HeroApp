#!/usr/bin/env bash
set -euo pipefail

if [[ "${OSTYPE:-}" != darwin* ]]; then
  echo "Error: This script must run on macOS."
  exit 1
fi

if [[ ! -f "pubspec.yaml" ]]; then
  echo "Error: Run this script from the repository root (pubspec.yaml missing)."
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Error: xcodebuild is not available. Install Xcode and open it once."
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter is not available in PATH."
  exit 1
fi

xcode_version="$(xcodebuild -version 2>/dev/null | awk '/Xcode/{print $2; exit}')"
xcode_major="${xcode_version%%.*}"
if [[ -z "${xcode_major}" || "${xcode_major}" -lt 15 ]]; then
  echo "Error: Xcode 15+ is required for the Swift Package Manager workflow."
  echo "Detected version: ${xcode_version:-unknown}"
  exit 1
fi

echo "Enabling Flutter Swift Package Manager support..."
flutter config --enable-swift-package-manager

echo "Refreshing Flutter project state..."
flutter clean
flutter pub get

echo "Applying iOS project migrations (config-only)..."
flutter build ios --config-only --simulator

if [[ -f "ios/Podfile" ]]; then
  echo "Error: ios/Podfile exists, but this repository is configured for SPM-first iOS dependencies."
  echo "Remove ios/Podfile and rerun this script."
  exit 1
fi

echo "Verifying Swift Package Manager integration markers..."
if command -v rg >/dev/null 2>&1; then
  if ! rg -n "FlutterGeneratedPluginSwiftPackage|XCLocalSwiftPackageReference" ios/Runner.xcodeproj/project.pbxproj; then
    echo "Error: SPM integration markers were not found in ios/Runner.xcodeproj/project.pbxproj."
    exit 1
  fi
else
  if ! grep -nE "FlutterGeneratedPluginSwiftPackage|XCLocalSwiftPackageReference" ios/Runner.xcodeproj/project.pbxproj; then
    echo "Error: SPM integration markers were not found in ios/Runner.xcodeproj/project.pbxproj."
    exit 1
  fi
fi

echo "iOS bootstrap (SPM-first) completed successfully."
