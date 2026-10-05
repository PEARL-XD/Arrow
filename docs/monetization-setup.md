# ARROW: THE LAST LANTERN — AdMob testing and launch checklist

Updated 2026-10-05. Source version is now 1.0.0+1 for the first public release; previous 1.1.x numbers were development milestones, not public releases.

## What changed

Google Mobile Ads 9.1.0 is installed. Both native app IDs and all six rewarded unit IDs are configured. The previous three-second ad simulation has been removed. All Android/iOS players, including non-admin TestFlight builds, can request ads. Gameplay, rewards and the existing saves are preserved.

TEST ADS ARE ON BY DEFAULT, INCLUDING PROFILE/RELEASE/TESTFLIGHT.
The compile-time flag is `ARROW_TEST_ADS`, default true. Admin mode is unrelated.
Use `--dart-define=ARROW_TEST_ADS=true` explicitly in every testing workflow.
Google's sample rewarded units are requested in this mode, not your live units.
The sample ad's displayed reward may differ; the game grants the placement reward below.
Test views earn no money and won't appear as production earnings in your account.

| Button | Game reward | Paid-coin alternative |
| --- | --- | --- |
| Hint | 1 saved hint | 80 coins |
| Coins | 80 coins | Replay stages |
| Revive | Restore chapter hearts, keep cleared paths | 200 coins |

Ad loading is on demand, with a loading/cancel dialog and a 25-second ad-load timeout. Cancelled loading discards any late ad. Only Google's earned-reward callback authorizes a reward, once, after dismissal. Failure, early dismissal, or tapping the watch button alone gives nothing. Revive also verifies the same attempt is still active. The game clock stays paused while these overlays are open. No forced interstitials or banners were added.

Consent updates at each app launch. A required UMP form is presented before the opening story. Ads initialize and load only when UMP allows requests; a failed update is not treated as consent (UMP may still permit requests from a valid previous session). More options → Ad privacy options opens the privacy form when required. SDK/connection problems don't prevent the puzzle from opening. The initial network check may briefly display a privacy-loading dialog.

## Your next steps: before device testing

1. In AdMob, finish the payment profile if the dashboard still asks. Submit personal/bank details only to Google, never into source code or this chat.
2. Publish a privacy-policy page describing the actual game and Google advertising. We still need your public policy URL and support contact. Do not reuse the earlier offline-only privacy description.
3. Open AdMob → Privacy & messaging. Create/publish the applicable messages for BOTH Android and iOS app entries, including the European regulations message if distributing there. Supply the public policy URL. Configure other regional messages as needed for your intended audience. This build uses UMP, but dashboard messages cannot be created by the code.
4. Do not enable an iOS IDFA/ATT explainer yet: this implementation does not request tracking permission or access IDFA itself. That is a separate optional implementation/review task. Native test ads can be tested without requesting ATT.
5. Transfer these project changes to the repository/branch that Codemagic actually builds, using your normal review/commit/push process. Nothing was pushed or uploaded by this change.
6. Keep your existing Codemagic Apple signing integration and bundle identifier. Do not replace an existing store app's identifier with a guessed new one. This local checkout still contains development placeholders; if Codemagic overrides them, keep that configuration.
7. Run `flutter pub get` in the workflow. Use Flutter compatible with this project's Dart ^3.12.2 (local verification uses Flutter 3.44.4) and a current compatible Xcode/macOS image. The iOS project uses Flutter's Swift Package Manager integration; the new plugin declares its native dependency. Do not manually add a second copy of the SDK.
8. Add `--dart-define=ARROW_TEST_ADS=true` to the EXISTING Flutter build command/Flutter workflow editor build arguments. A plain environment variable alone is not a Dart define. Do not remove your existing signing/export arguments.
9. The source baseline is 1.0.0+1. Use build 1 only if version 1.0.0 has no earlier uploaded builds. Otherwise set `--build-number` above the latest TestFlight build for version 1.0.0; increment it for each subsequent upload. Public App Store publication is not required for an uploaded build number to count as used. Keep `--build-name=1.0.0` while iterating toward the first release.
10. Build/upload through your existing Codemagic → App Store Connect → TestFlight process, then install the update. On Android use `flutter run --dart-define=ARROW_TEST_ADS=true` on your test device. A full restart/rebuild is required because a native plugin was added; hot reload is not enough.

No Codemagic credentials, App Store Connect keys, private signing files or bank details belong in the repository.

## Device test checklist

- Connect to the internet. Allow the initial privacy check/form to finish. No form may be required in your region; that alone is not an error.
- Open Shop → Hints and watch the test ad. Complete Google's reward condition and dismiss: hint count increases exactly once.
- Open Shop → Coins and complete a test ad: balance increases by exactly 80.
- Lose a level, watch a test revive ad: hearts return, cleared arrows and elapsed puzzle time remain.
- Close an ad before its reward is earned: no reward. Cancelling ad loading also earns nothing.
- Turn off the network: gameplay remains usable; an ad failure should show a friendly message without charging coins.
- Tap watch repeatedly: no overlapping ads or duplicate grants.
- Background/resume during loading and during playback; check the clock and return to the same puzzle.
- More options → Ad privacy options: required form opens, or the app explains that Google does not currently require it.
- Check small screens and real iPhone playback. TestFlight is a release build: ad buttons work, but debug-only admin skip, coin top-up and fake purchases remain disabled.

Automated tests use a fake native gateway and controlled SDK callbacks, not real ad requests. Android compilation is checked locally. Successful compilation is not proof of native ad fill/playback. iOS compilation, consent presentation and real Google test-ad playback still require your devices/Codemagic.

## Configuration reference

| Platform | App ID |
| --- | --- |
| Android | ca-app-pub-9318630710537182~3838759880 |
| iOS | ca-app-pub-9318630710537182~4017803410 |

All production ad-unit IDs share prefix `ca-app-pub-9318630710537182/`:

| Platform | Hint suffix | Coins suffix | Revive suffix |
| --- | --- | --- | --- |
| Android | 3157157048 | 3212997363 | 9586834029 |
| iOS | 1221258846 | 7642273527 | 7099262321 |

Test IDs:
- Android: ca-app-pub-3940256099942544/5224354917
- iOS: ca-app-pub-3940256099942544/1712485313

Code: `lib/ad_config.dart`, `lib/rewarded_ads.dart`, `lib/reward_options.dart`.
Android app metadata: `android/app/src/main/AndroidManifest.xml`.
iOS app metadata and Google's published SKAdNetwork list: `ios/Runner/Info.plist`.
Display name is now ARROW: THE LAST LANTERN. Internal Dart package and persistent save keys were deliberately not renamed.

## Before enabling live ads — not done by this change

- Choose/confirm permanent Android/iOS application identifiers and production signing.
- Resolve AdMob payment/account warnings.
- Complete store privacy/Data Safety declarations for the included SDK, audience/age settings and required consent setup.
- Publish developer website and privacy policy. In AdMob → Apps → View all apps → app-ads.txt, copy YOUR provided snippet and host it at the developer website's /app-ads.txt. Add that website to the public store listing.
- Link the public store listing to the corresponding AdMob entry, verify app ownership, and complete Google's readiness review. TestFlight alone isn't a public listing.
- Verify reward behavior, offline handling, background/resume and consent on Android and iPhone.
- Only when ready for production, build a separate production workflow with `--dart-define=ARROW_TEST_ADS=false`. This activates the six production units above. Keep the testing workflow TRUE. TestFlight does not automatically identify ads as test traffic.
- Never click your own live ads or encourage artificial viewing/clicks to generate revenue.
- Consider server-side reward verification and a server-backed wallet before scaling or selling currency. This version still stores coins locally and is not tamper-proof.

## Coin purchases are separate and still unavailable in normal builds

AdMob does not process purchases. The ₹49 / 1,500 coins and ₹99 / 4,000 coins packs are still admin-only simulations, clearly labelled as no-charge. They are disabled in normal and TestFlight builds. No billing SDK, receipt validation or real charge was added.

To implement them later: create consumable store products `coins_1500` and `coins_4000` in both stores, confirm supported Indian price points, integrate official Flutter `in_app_purchase`, display the store-provided localized price, verify purchases on a backend, credit each transaction once and complete/acknowledge it. Test using each store's sandbox.

## Official references

- [Google Flutter setup](https://developers.google.com/admob/flutter/quick-start)
- [Rewarded lifecycle and test units](https://developers.google.com/admob/flutter/rewarded)
- [UMP privacy messages and consent](https://developers.google.com/admob/flutter/privacy)
- [iOS native configuration](https://developers.google.com/admob/ios/quick-start)
- [AdMob app verification](https://support.google.com/admob/answer/14538460?hl=en)
- [app-ads.txt hosting](https://support.google.com/admob/answer/9363762?hl=en)
- [Codemagic Flutter/TestFlight](https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/)
- [Flutter store purchases](https://pub.dev/packages/in_app_purchase)
