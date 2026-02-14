#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

PROJECT="2txt.xcodeproj"
SCHEME="2txt"
SDK="macosx"

DD_DEBUG=".derivedData_ci_debug"
DD_RELEASE=".derivedData_ci_release"
DD_ANALYZE=".derivedData_ci_analyze"
DD_TESTS=".derivedData_ci_tests"
DD_ARCHIVE=".derivedData_ci_archive"
ARCHIVE_PATH=".archives/2txt-ci"

rm -rf "$DD_DEBUG" "$DD_RELEASE" "$DD_ANALYZE" "$DD_TESTS" "$DD_ARCHIVE" "$ARCHIVE_PATH"

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -sdk "$SDK" -derivedDataPath "$DD_DEBUG" clean build
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -sdk "$SDK" -derivedDataPath "$DD_RELEASE" build
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -sdk "$SDK" -derivedDataPath "$DD_ANALYZE" analyze
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -sdk "$SDK" -derivedDataPath "$DD_TESTS" test
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -sdk "$SDK" -derivedDataPath "$DD_ARCHIVE" archive -archivePath "$ARCHIVE_PATH"

printf '\nAll matrix checks passed.\n'
