# ARROW: THE LAST LANTERN — Flutter

An original native Android/iOS arrow-maze game. Puzzles and the earned-coin shop work offline. Optional rewarded ads use Google Mobile Ads on Android/iOS; all builds default to Google test ads, including TestFlight. Real-money purchases remain unconnected.

## Current: 1.0.0+1 — first-release baseline, AdMob testing

The source version has been reset for the first public release. Earlier version numbers below are development milestones, not published releases. For TestFlight, use a new build number for each upload of version 1.0.0; if that version has already been uploaded, continue above its latest build number rather than reusing 1.

Both platforms' supplied AdMob IDs are configured. Hint, 80-coin and revive buttons use native rewarded ads, not the old timer simulation. Consent is checked at startup and before requests; More options → Ad privacy options lets players revisit required choices. Keep `--dart-define=ARROW_TEST_ADS=true` in Codemagic/test builds. This is also the default when omitted, even in release mode. No test-ad revenue is earned. Follow [the testing and launch checklist](docs/monetization-setup.md). The older entries below describe earlier versions.

## Current source (1.0.0)

[Version one](docs/version-one.md): all four illustrated companion stories, **15 stages each**, plus the existing optional bonus challenge. All 80 supplied panels are integrated; twenty new fully occupied shaped boards extend the campaign to 60 story stages. Chapter bosses appear at 15/30/45/60. Existing saves, coins, purchases, routes and records are migrated. This completes the offline story build, not a store-published release; no APK, live ads or real-money checkout was produced.

Earlier source updates:

[Illustrated story update](docs/illustrated-story-0.8.1.md): the supplied 20 panels now tell Mira's chapter through individual illustrations and readable captions. Fixed Continue/Previous controls, Skip, gentle transitions and journal replay accompany progress-matched scenes.

[Mira: The Last Lantern](docs/story-0.8.md) adds a ten-stage story chapter, shaped boards, a two-stage checkpoint boss, skippable scenes, a journal and Lanternlight arrows. First clears pay 70 coins, replays 30, unpaid performance bonuses up to 30, and faster replay records another 5. Hints cost 80. Companion chapters cost 600/700/800 after the preceding chapter is cleared. Later chapters received their illustrated stories in version one. Old progress, purchases and active board geometry are preserved. **No APK, ads or real-money checkout in this update.**

[Independent arrow skins](docs/arrow-skins-0.7.md): Shop → Arrows now offers Classic, Neon, Fire, Ice and Sakura, with play-on-tap escape previews and saved ownership. Mix them with any board theme; effects are cosmetic and respect reduced motion. [Monetization research](docs/monetization-research.md) is a proposal only—no live ads or real-money payments are connected.

[Latest polish notes](docs/polish-0.6.md): a dedicated Shop icon, blossom/water/starfield theme art, 112 new companion lines, and level-based hearts (3 for levels 1–10, 2 for 11–30, 1 thereafter including the boss).

[Celebration and coin-shop notes](docs/shop-0.5.md): animated level-clear popup with a direct **Next** button, saved hint purchases, companion unlocks, and three purchasable coordinated themes. Open the shop with the bottom storefront icon, the coin balance, or **More options → Coin shop**. Existing saves keep their previously free companions. Speed rewards remain +10 below 45 seconds, +5 below 60 seconds, otherwise zero. No rewarded ads or real-money checkout. Hot-restart the Flutter project to test; no APK is supplied for this revision.

## Try the app

Latest source update: [version-one story notes](docs/version-one.md). Run or hot-restart Flutter on your emulator/debug device. From an existing save, select stage 1 through Levels and open More options → Story journal → The Last Lantern. The older downloadable APKs below do not include these changes.

The project root is `C:\CODE\Arrow`.

```powershell
flutter pub get
flutter devices
flutter run -d DEVICE_ID
```

For an Android test APK: `flutter build apk --debug`. The installable file is `build/app/outputs/flutter-apk/app-debug.apk`. This is a development build, not a store release. On a Mac, the same source can run on an iPhone or iOS simulator after Xcode/signing setup.

The updated test build is `dist/path-out-android-0.3.0.apk` for transfer to your Android phone. Open that file on the phone to install it over the earlier version and keep local progress. The earlier 0.1.0 and 0.2.0 APKs are retained as backups. Keep development builds separate from future signed store releases.

See [testing and release instructions](docs/RELEASE.md) before publishing. The application ID is a development placeholder; production signing and store setup intentionally remain under the owner's control. The Android release build refuses to silently use debug signing.

## Gameplay

Tap anywhere along an arrow. Its head travels straight forward; its tail follows the existing bends like a snake. Every cell along the forward escape lane must be free, including distant cells across a gap in a silhouette. A blocked tap costs one heart. Levels 1–10 start with three hearts, 11–30 with two, and level 31 onward (including the boss) with one. Three starter hints form a saved inventory; using a hint highlights a safe arrow without removing it. Restarting or changing level no longer refills hints. Five icon controls form a fixed bottom bar: Restart, Hint, Companions, Shop and Levels. Hint has a remaining-count badge. Use Levels to change to an unlocked puzzle; the win popup offers Next to continue immediately.

Pinch or use +/− to zoom up to 4×; drag to inspect. Fit resets the view. Haptics can be switched off. Reduced-motion preferences shorten escape animations. There is no time limit. Only level 1 is unlocked on a fresh install. Completing each level unlocks its successor, and previously completed levels remain replayable. The controller enforces locks as well as the menu. Completed levels and the current puzzle, lives, hints and haptics setting save locally. A mid-flight arrow is saved only after it finishes; backgrounding or closing cannot leave a half-removed route.

After level 40, **The Crown Keeper** unlocks: a crown-shaped boss puzzle with 80 arrows, the same movement rules, one heart and your saved hint balance. Its guard meter falls as arrows escape. Defeating it shows **New levels coming soon** and a replay-level button. It does not automatically wrap to level 1, and the completed ending survives reopening the app.

Updates preserve existing completion records. If an old unrestricted test save selected a level ahead of its earned unlocks, the game returns to the earliest incomplete level; old skipped selections do not unlock anything. Actual recorded wins are retained. Install an update over the previous APK with the same signature rather than uninstalling if you want to keep local progress.

## Companions

Choose **Companions** beneath the puzzle to select Mira, Elegant, Playful or Cool, based on the four supplied character sheets. Choose **No companion** to hide the feature. Your choice is saved. The larger reaction portrait and thought bubble have a dedicated area between the board and the fixed bottom controls.

Each of the four companions now has its own voice, with separate welcome, resting and event dialogue and non-repeating shuffled cycles. Successful moves get a brief happy expression and varied encouragement; freeing at least two previously blocked arrows can trigger occasional “Great move!” praise. Hints, blocked moves, losses, level wins and the boss win have appropriate expressions and supportive text. No voice or sound is included. Reduced-motion settings disable portrait transitions.

The top-right **More options → Take a break** menu (or Android Back from the puzzle) shows a cancelable goodbye confirmation. **Leave puzzle** returns to a resting screen; **Continue puzzle** keeps the same board, hints, lives and finished moves. No OS shutdown or forced app exit is performed. Closing from the OS does not show an in-game reaction.

Artwork assets and behavior notes are recorded in [companion artwork](docs/companion-artwork.md). The source sheets remain untouched. Chapter one has new story-shaped boards; the original first ten are preserved for old active saves. Later boards are unchanged.

## Forty-level progression

| Levels | Stage | Design intention |
|---|---|---|
| 1–8 | Beginner | Mira’s smaller story-shaped boards; first five have 10–22 arrows. |
| 9–10 | Chapter finale | Gate reveal and two-stage Lantern Keeper boss. |
| 11–16 | Easy | Existing varied puzzles; next companion must be owned. |
| 17–24 | Medium | Longer mixed routes and more interlocking blockers. |
| 25–32 | Hard | Denser visual tracing and deeper dependencies. |
| 33–40 | Expert | Large, densely twisted boards; up to 112 arrows. |

Every board occupies **100% of its playable cells exactly once**. Shapes are actual cell masks, not background pictures. Story shapes add lantern, arch, leaf, envelope, kite, flower, key and gate. Approved prototypes at stages 16, 22, 36 and 38 are unchanged; the former stage-9 prototype is preserved in the legacy chapter-one asset.

The original campaign calibration used dependency depth, bends, route count, cell count and initially blocked fraction, recorded in `docs/level-metrics.json`. Story chapter metrics are now in `docs/mira-metrics.json`; the boss deliberately peaks before the next chapter. These are provisional estimates, not measured human difficulty.

## Architecture

- `assets/levels.json` — 40 fixed campaign boards plus one fixed boss, not runtime random generation.
- `lib/puzzle.dart` — immutable routes, occupancy, whole-lane blocking, solver and validation.
- `lib/game_controller.dart` — lives, hints, progression and stale-animation protection.
- `lib/arrow_geometry.dart` — snake movement and precise path hit testing.
- `lib/board.dart` — native `CustomPainter` rendering, arrowhead geometry and semantic actions.
- `lib/game_screen.dart` — responsive controls, touch/zoom, feedback and level selection.
- `lib/companions.dart` — sprite atlas display, optional companion picker and transient cosmetic reactions.
- `lib/storage.dart` — serialized local saves with corruption/failure handling.
- `lib/main.dart` — startup, assets and Material app theme.
- `android/`, `ios/` — native platform projects and original launcher icons.
- `tools/` — optional offline Node authoring utilities; none are part of the app runtime.

## Checks

```powershell
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
```

Run the native integration check on a connected development device with `flutter test integration_test/app_test.dart -d DEVICE_ID --dart-define=PATH_OUT_ADMIN=false`. It exercises the actual platform app and preferences plugin, and resets only this development app's progress key at the start.

Story/reward update: [1.1 notes](docs/engagement-1.1.md). Ad and purchase demos and live setup: [monetization guide](docs/monetization-setup.md).

Temporary debug-only admin controls: [testing guide](docs/admin-testing.md). Debug launches currently include a test Skip button and top up a separate testing balance to 10,000 coins; normal player saves and release builds are unaffected.

Tests solve every board; assert exact coverage, non-overlap, head direction, path continuity and all four directions; sample each escape for constant body length and collision-free snake motion; check state isolation, lives/hints, persistence, restart/skip during animation, native touch, level selection and layout at small-phone, landscape and tablet sizes. Actual Flutter-rendered preview screens are generated by widget tests into `work/flutter-previews`.

The static analyzer, tests and Android debug build can run on Windows. iOS compilation and device testing require macOS/Xcode. A passing solver is not a substitute for human play-testing or store review.

## Authoring more levels

`node tools/build-campaign.cjs` deterministically regenerates the campaign and metrics. It preserves `tools/approved-boards.json`, generates new fully partitioned masks, validates them with an independent reference engine and sorts them by challenge. Inspect all geometry and rerun Flutter tests after changes. Do not regenerate a shipped pack without planning saved-progress compatibility.

The boss is appended from `tools/boss-board.json` without changing the regular campaign. `node tools/append-boss.cjs` authors that crown and updates the appended boss only. Its validation metrics are in `docs/boss-metrics.json`.

`tools/create-brand.cjs` draws the original launcher icon into both platform asset catalogs. Pass an installed `sharp` module path if it is not locally available. This tool is not needed to build the app.

## Previous prototype

The obsolete HTML/CSS/browser-game files were removed from the active root only after Flutter validation. A byte-verified recovery copy remains in `work/html-prototype`; older backups are unchanged. This directory is excluded from source control and is not packaged in the app. Nothing was permanently erased from that backup.
