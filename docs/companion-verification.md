# Companion update verification — 0.3.0+3

Verified on Windows, 2026-09-28.

- `flutter analyze`: no issues.
- `flutter test --reporter expanded`: 67 tests passed.
- `flutter test integration_test/app_test.dart -d emulator-5562 --reporter expanded`: passed on a read-only Small_Phone Android emulator. Includes native movement, saves, progression, zoom, companion selection/persistence and leave/resume.
- Rebuilt normal `lib/main.dart` after the integration run, copied to `C:\CODE\Arrow\dist\path-out-android-0.3.0.apk`, installed successfully over the development app, and launched successfully.
- All 41 layouts are byte-for-byte unchanged compared with the level asset in the 0.2.0 APK.
- All four 1536×1024 sprite atlases are included in the APK and contain real alpha transparency.
- Inspected actual Flutter renders of gameplay, all four choices, a hint reaction and the goodbye dialog. No companion overlaps the board. Existing small-phone, landscape and tablet overflow tests pass; companion picker also passes at 320×568 with 160% text scaling.
- Existing 0.1.0/0.2.0 APKs and original user character sheets remain untouched.
- iOS source shares the implementation but was not compiled or device-tested here; macOS/Xcode is still required.

APK is a debug testing build, not a production-signed store release. Install over the previous development build instead of uninstalling to preserve local progress.
