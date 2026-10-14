# Klapok

A macOS app for screen capture, screen recording, and quick image and video editing.

Capture a screen, window, or region, then crop images, add annotations, trim recordings, and export the result. Video annotations have independent timing on the edited timeline. Edited files can be copied to the clipboard or revealed in Finder.

## Development

Open `Klapok.xcodeproj` in Xcode. The project targets macOS 15.5 or later.

Run `./script/build_and_run.sh` to build and launch the app. Run `./run_tests.sh` for unit, integration, and UI tests. Screen recording features require permission in System Settings.
