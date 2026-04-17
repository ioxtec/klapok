#!/bin/bash

# Script to run Fluttro tests from command line

echo "🧪 Running Fluttro Tests..."
echo ""

# Run unit tests
echo "📦 Running Unit Tests..."
xcodebuild test \
  -project Fluttro.xcodeproj \
  -scheme Fluttro \
  -destination 'platform=macOS' \
  -only-testing:FluttroTests 2>&1 | xcpretty

# Run UI tests (optional - comment out if you don't want to run UI tests)
# echo ""
# echo "🖥️  Running UI Tests..."
# xcodebuild test \
#   -project Fluttro.xcodeproj \
#   -scheme Fluttro \
#   -destination 'platform=macOS' \
#   -only-testing:FluttroUITests 2>&1 | xcpretty

echo ""
echo "✅ Tests completed!"








