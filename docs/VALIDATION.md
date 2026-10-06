# Validation record

## 1.0.0+1 — 2026-10-06 SFX-only version and project cleanup

- Removed companion speech playback, its saved preference/menu item, voice
  service and bundled speech assets. Portraits, expressions, text dialogue,
  stories and all ten game sound effects are retained. Legacy saves containing
  the old voice preference restore normally; no player progress is reset.
- All 212 remaining/new unit/widget tests pass. Coverage includes actual SFX
  taps, pause/resume, hint and victory cues, muting, companion UI, save
  compatibility, stories, bosses, purchases and progression. The seven retired
  speech tests are archived with the deferred speech implementation.
- Full-project static analysis is clean. A fresh Android debug compilation
  succeeds with admin mode off and test ads on. Package inspection confirms
  exactly ten sound-effect WAVs and zero companion-audio entries.
- No device install, distribution, iOS compilation or store upload. The user
  can test through their usual emulator/device and Codemagic workflows.
- Old prototypes, promotional exports/tools, voice models/dependencies,
  recordings/auditions and obsolete update notes were moved to the recoverable
  `C:\CODE\Arrow archive\2026-10-06-sfx-only` folder outside the Flutter project.
  Current release/payment instructions and level-authoring tools remain.
  Approved expressive samples are preserved for a future version; the separate
  backend and payment/ad settings were not changed.

The records below are historical checks, not the current SFX-only feature set.

## 1.0.0+1 — 2026-10-06 companion voices

- Added 56 locally generated English speech clips: fourteen each for Mira,
  Elyra, Lumi and Raven, with separate synthetic voice profiles. Only recorded
  clips ship in the game; no speech model, paid service or network is required.
- All 217 unit/widget tests pass. Voice tests cover asset integrity, cooldowns,
  matching speech bubbles, boss and chapter story reveals, saved preferences,
  interruption, delayed startup, disposal and narrow-phone menu layout.
- Static analysis of `lib` and `test` is clean. Android debug compilation
  succeeds; the compiled package contains all 56 WAV clips and their manifest.
- Voices have a saved toggle independent of effects and haptics. Ordinary moves
  and idle chatter stay silent. Incidental lines have a twelve-second cooldown;
  voices stop on mute, hiding/switching companions, menus and backgrounding.
- No device install or distribution. Real speaker playback and iOS native
  compilation still require the user's phone / Codemagic checks. Automated
  widget playback is injected rather than played through native speakers.

## 1.0.0+1 — 2026-10-06 game sound effects

- Added ten original, sample-free PCM cues for escapes, good/nice/great moves,
  blocked taps, pause/resume, hints, wins/checkpoints and loss. All assets are
  bundled and validated for format, duration and conservative peak levels.
- All 210 unit/widget tests pass. New tests exercise actual arrow taps, ignored
  taps during flight, hints, pause/resume, victory, muting and persisted settings;
  service tests cover startup, interruption failures, background and disposal.
- Static analysis of `lib` and `test` is clean. Full-repository analysis still
  reports four existing style hints in the separate promotional-video renderer.
- Android debug native compilation succeeds with audioplayers 6.8.1. No device
  install or distribution. Native speaker playback and iOS compilation remain
  to be checked on the user's phone / Codemagic build; widget audio is injected.
- Sound effects default on, have a saved toggle independent of haptics, and
  stop on mute/background. iOS is configured to respect the silent switch.
  Low-latency Android players disable unnecessary frame-position polling.

## 1.0.0+1 — 2026-10-06 native coin purchases and wallet backend

- Flutter static analysis is clean; all 205 unit/widget tests pass. Native purchase callbacks are mocked: these results do not verify live Apple or Google checkout.
- Latest Android debug native compilation succeeds with admin testing disabled and test ads enabled. Build was not installed or distributed.
- Backend: all 17 tests pass; npm production dependency audit reports zero known vulnerabilities. Covers verification rules, receipt/account isolation, duplicate credit and debit, encrypted verification proofs, environment separation, delivery recovery and refund debt.
- Verified delayed paid revives cannot affect a different attempt after restarting, including when the new attempt has already been lost.
- Inspected the actual Flutter-rendered small-phone coin shop, including localized store prices, unavailable products and wallet controls. Updated the old placeholder payment footer.
- Checkout is disabled by default; AdMob remains in test mode. No cloud deployment, store product creation, real payment, device install or store upload occurred. iOS native compilation and both platforms' end-to-end sandbox purchases remain required.
- Source version stays 1.0.0+1 at the user's request; the older headings below record historical test builds. See `coin-purchases.md` and the backend's `SETUP.md` for the remaining release checks.

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
