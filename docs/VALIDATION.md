# Validation record

## 1.1.1+13 — 2026-10-05 AdMob integration

- Flutter 3.44.4 / Dart 3.12.2, google_mobile_ads 9.1.0.
- 184 unit/widget tests pass; static analysis clean; Android debug native compilation succeeds with test ads explicitly enabled.
- Tests cover all six supplied IDs, test-default selection, consent denial/update errors, initialization coalescing, concurrent requests, load failures, cancelled/late loads, consent revoked during loading, disposal, native earned/dismiss/failure callback ordering, non-admin hint/coin/revive and stale-attempt protection.
- Existing story, boss, shop, geometry and persistence tests retained. Startup test uses injected consent gateway; no real ad requests in automated tests.
- Flutter-rendered coin-shop view inspected for the updated ad/purchase labels.
- No device install, live ads, real earnings, purchase charges, remote push or TestFlight upload performed. Actual Google test-video playback and UMP forms need device verification; iOS compilation needs the user's Codemagic/macOS environment.
- [Setup and test instructions](monetization-setup.md). Earlier validation records below describe previous versions.

Checked on Windows with Flutter 3.44.4 / Dart 3.12.2.

Version 0.2.0: the regular 40 level objects were compared against the level asset extracted from the previously delivered 0.1.0 APK and match exactly. Only the boss is appended.

- Static analysis: no issues.
- Unit/widget suite: 60 tests pass. All 40 regular layouts plus the boss validate and solve, with every playable point occupied exactly once and no overlapping routes. Snake geometry is sampled along every solved escape. The five approved layouts are geometrically unchanged. The composite campaign difficulty score increases through the 40 regular levels.
- Progression: a fresh install opens only level 1; locked selection and forward navigation are rejected by the controller. A full first win unlocks the next level; replay never relocks it. Tests walk the entire campaign into the boss and verify that its completion restores the ending instead of wrapping. Legacy skipped selections are migrated to the earliest incomplete level without discarding recorded wins.
- UI coverage: native touch, blocked-tap lives, animation completion, hints, restart/skip cancellation, level selection, help, zoom and small-phone/landscape/tablet layouts.
- Native Android integration: passed on the installed Small Phone emulator. Exercised native startup, arrow movement, preferences persistence/restore, hint, restart, skip, zoom and fit.
- Rendering: actual Flutter-rendered phone views, the locked level picker, crown-shaped boss and coming-soon ending were inspected. Previews are in `work/flutter-previews`.
- Android debug APK: built successfully. Use the normal `lib/main.dart` build, not an integration-test APK.
- Version 0.2.0 Android integration: passed with guarded navigation and first-win unlocking. The normal app was rebuilt afterwards and copied to `dist/path-out-android-0.2.0.apk`; its packaged asset was checked for 40 regular boards plus the boss.
- Normal APK cold start: installed separately, selected level 2, force-stopped and relaunched. Level 2 was restored from the Android preferences file. The installable copy is `dist/path-out-android-test.apk`.

## Still requires testing/decisions

- A physical Android phone and an iPhone, including background/resume behavior and real-device performance.
- macOS/Xcode compilation, Apple signing and iOS device testing. These cannot be completed on the Windows host.
- Human play-testing of the difficulty curve. The ordering is a mathematical authoring estimate, not a claim that every player will find each next board harder.
- Permanent application IDs, private release keys, store accounts, privacy/content forms, store listing and approval. No public upload has occurred.

The development version is suitable for local testing; it is not a signed, reviewed store release.
