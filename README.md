# ARROW: THE LAST LANTERN — Flutter

Native Android/iOS arrow-maze game with four illustrated companion stories,
15 stages each, chapter bosses, and an optional bonus challenge. The project
root is `C:\CODE\Arrow`; the coin-verification backend is a separate project
at `C:\CODE\Arrow backend`.

## Current version: 1.0.0+1 — sound effects only

Companions retain their portraits, expressions, distinct written dialogue,
thought bubbles and stories. **No companion speech is played or bundled.**
The ten game sound effects remain: arrow escapes, successful/blocked moves,
hints, pause/resume, victories and loss. More options → Turn sounds off/on
controls effects independently of haptics; the preference is saved.

Voice auditions are deferred to a later version. Approved samples and the
previous implementation are preserved outside this app in
`C:\CODE\Arrow archive\2026-10-06-sfx-only`. That recovery folder also contains
old web prototypes, promotional exports/tools, obsolete build copies and
historical update notes. Nothing in it is required to compile this version.

## Run and check

```powershell
flutter pub get
flutter run -d DEVICE_ID
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
```

Use your existing emulator/device workflow. iOS compilation, signing and
device testing require macOS/Xcode or your Codemagic workflow. TestFlight
uploads need a new build number above the latest uploaded build; the source
baseline is not authorization to reuse an already uploaded number.

## Gameplay and companions

Tap a route whose arrowhead has a clear exit lane. Its head moves straight
forward and the tail follows the bends like a snake. Every playable cell is
occupied exactly once at the start. Blocked taps cost a heart. Hints highlight
a safe arrow, without removing it; restart does not refill the hint inventory.

Stages unlock through completion. Later story chapters require purchasing
their companion with earned coins; chapter transitions select the appropriate
companion. Previously earned progress, purchases, records and active boards
remain compatible. The story journal replays discovered scenes. Debug admin
controls use a separate testing save; see [admin testing](docs/admin-testing.md).

## Launch and payments

Rewarded hint, 80-coin and revive placements use Google Mobile Ads. All build
modes default to **test ads**, including TestFlight. Keep
`--dart-define=ARROW_TEST_ADS=true` for testing; test ads earn no revenue.

Native coin purchases and the verification backend are implemented, but
checkout defaults off until store products, credentials and hosting are set
up. These settings were not changed during audio cleanup.

- [Release and Codemagic checks](docs/RELEASE.md)
- [AdMob consent, testing and launch setup](docs/monetization-setup.md)
- [Coin purchases and backend setup](docs/coin-purchases.md)
- [Validation record](docs/VALIDATION.md)
- [Companion artwork provenance](docs/companion-artwork.md)

## Project layout

- `lib/`: puzzle rules, rendering, progression, companions, shops and services.
- `assets/`: boards, companion/story art and the ten sound-effect WAVs.
- `android/`, `ios/`: native platform projects.
- `test/`, `integration_test/`: automated checks and native smoke tests.
- `tools/`: offline level/icon authoring and sound-effect generation utilities.
- `docs/`: current setup instructions, validation and level metrics.

`tools/audio/generate_sounds.py` reproduces the original effects. Level-authoring
utilities remain for future development; do not regenerate shipped boards
without planning save compatibility. Generated build caches and test previews
are ignored by Git and are not source assets.
