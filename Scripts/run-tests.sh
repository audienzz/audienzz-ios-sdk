#!/usr/bin/env bash
# Runs the SPM test target.
#
# `xcodebuild test` in the repo root does not work: ExampleApp.xcworkspace sits next to
# Package.swift and xcodebuild prefers the workspace, whose AudienzziOSSDK scheme has no test
# bundle ("no test bundles available to test"). Building a directory that contains only the
# package makes xcodebuild pick up the package's own scheme instead.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-platform=iOS Simulator,name=iPhone 17}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# The podspec is linked so a test can read it: it and AUSDKVersion are two independent literals
# that must agree, and nothing else enforces that.
for entry in Package.swift Package.resolved Sources Tests AudienzziOSSDK.podspec; do
    ln -s "$REPO/$entry" "$WORKDIR/$entry"
done

cd "$WORKDIR"
xcodebuild test -scheme AudienzziOSSDK -destination "$DEST"
