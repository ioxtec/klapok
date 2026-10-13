#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_build="${TMPDIR:-/tmp}/KlapokEditorDevelopment"
task_mode="${1:-run}"
pkill -x Klapok >/dev/null 2>&1 || true
xcodebuild -quiet -project "$task_root/Klapok.xcodeproj" -scheme Klapok -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$task_build" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=
task_app="$task_build/Build/Products/Debug/Klapok.app"
case "$task_mode" in
  run) open -n "$task_app" ;;
  --verify) open -n "$task_app"; sleep 1; pgrep -x Klapok >/dev/null ;;
  --debug) lldb -- "$task_app/Contents/MacOS/Klapok" ;;
  --logs|--telemetry) open -n "$task_app"; /usr/bin/log stream --info --style compact --predicate 'process == "Klapok"' ;;
  *) exit 2 ;;
esac
