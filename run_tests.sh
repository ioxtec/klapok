#!/bin/bash

# Script to run Klapok tests from the command line.

set -euo pipefail

PROJECT="Klapok.xcodeproj"
SCHEME="Klapok"
DESTINATION="platform=macOS,arch=arm64"
TMP_ROOT="${TMPDIR:-/tmp}"
UNIT_DERIVED_DATA="${TMP_ROOT%/}/KlapokUnitTestsDerivedData"
UI_DERIVED_DATA="${TMP_ROOT%/}/KlapokUITestsDerivedData"

echo "Running Klapok unit and integration tests..."
xcodebuild test \
  -quiet \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -parallel-testing-enabled NO \
  -derivedDataPath "$UNIT_DERIVED_DATA" \
  -skip-testing:KlapokUITests \
  -only-testing:KlapokTests \
  CODE_SIGNING_ALLOWED=NO

echo ""
echo "Running Klapok UI smoke tests..."
xcodebuild test \
  -quiet \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -parallel-testing-enabled NO \
  -derivedDataPath "$UI_DERIVED_DATA" \
  -skip-testing:KlapokTests \
  -only-testing:KlapokUITests \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM=

echo ""
echo "All Klapok tests completed."







