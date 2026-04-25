#!/bin/bash

# Script to run Fluttro tests from the command line.

set -euo pipefail

PROJECT="Fluttro.xcodeproj"
SCHEME="Fluttro"
DESTINATION="platform=macOS,arch=arm64"
TMP_ROOT="${TMPDIR:-/tmp}"
UNIT_DERIVED_DATA="${TMP_ROOT%/}/FluttroUnitTestsDerivedData"
UI_DERIVED_DATA="${TMP_ROOT%/}/FluttroUITestsDerivedData"

echo "Running Fluttro unit and integration tests..."
xcodebuild test \
  -quiet \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$UNIT_DERIVED_DATA" \
  -skip-testing:FluttroUITests \
  -only-testing:FluttroTests \
  CODE_SIGNING_ALLOWED=NO

echo ""
echo "Running Fluttro UI smoke tests..."
xcodebuild test \
  -quiet \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$UI_DERIVED_DATA" \
  -skip-testing:FluttroTests \
  -only-testing:FluttroUITests \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM=

echo ""
echo "All Fluttro tests completed."







