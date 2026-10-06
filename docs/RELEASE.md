# Test first, then publish

This is a native Flutter app, not a WebView. The same Dart game and assets target Android and iOS. Gameplay works offline; optional rewarded ads need a connection. Google Mobile Ads is integrated with TEST ADS ON by default in all build modes. Native coin purchases and a server wallet are implemented but require store products, credentials and hosting; checkout defaults OFF. See [coin purchases](coin-purchases.md) and [AdMob setup](monetization-setup.md) before testing or publishing; these services change the privacy disclosures needed for release.

## Android testing on this Windows computer

1. Connect an Android phone with Developer options and USB debugging enabled. Authorize this computer on the phone.
2. In the project folder, run `flutter devices`, then `flutter run -d DEVICE_ID`.
3. Alternatively build `flutter build apk --debug` and transfer `build/app/outputs/flutter-apk/app-debug.apk` to your phone. Install it only on a test device you control. This debug build is not for the Play Store.
4. If an Android SDK license is required, review and accept it yourself with `flutter doctor --android-licenses`. No license acceptance is automated by this project.

For the repeatable native smoke test, run `flutter test integration_test/app_test.dart -d DEVICE_ID --dart-define=PATH_OUT_ADMIN=false`. This clears the development app's normal saved puzzle progress before running. Afterwards rebuild the normal app with `flutter build apk --debug -t lib/main.dart --dart-define=PATH_OUT_ADMIN=false`; do not distribute the integration-test executable. Temporary debug testing controls and their separate save are documented in [admin-testing.md](admin-testing.md).

## iPhone testing

A macOS build environment with Xcode is required, which can be Codemagic rather than a personally owned Mac. Continue your existing Codemagic signing/TestFlight workflow, keep the bundle ID matching the existing App Store Connect app, run `flutter pub get`, and include `--dart-define=ARROW_TEST_ADS=true` in the build arguments. Use a new build number above the latest uploaded one. On a local Mac you can also run on a connected iPhone or simulator. iOS compilation and native ads cannot be verified on this Windows host.

## Before either store submission

- Choose your publisher identity and permanent application/bundle ID. `com.example.path_out` is explicitly a development placeholder; do not publish with it.
- Play-test all 60 story stages and the optional bonus on real phones. Difficulty metrics are authoring heuristics, not measured human difficulty. Test small screens, story navigation, pinch/drag versus tap, background/resume, phone interruptions, haptics, reduced motion, saved progress and reinstall behavior.
- Replace development signing with your own Android upload key. Keep the keystore and passwords outside version control. Configure `android/key.properties` (see the example), then build `flutter build appbundle --release`.
- On a Mac, configure your Apple team, App Store bundle ID and signing; create an archive with `flutter build ipa --release`.
- Set your final app name, version/build number, support contact, screenshots and store descriptions. The included original icon is usable for testing and can be refined for release.
- Complete current store privacy, data-safety, content-rating and testing requirements for your account. Game progress stays local, but the Google Mobile Ads SDK communicates with Google. Do not declare that the app collects no data. Review Google's current SDK disclosure guidance, configure UMP messages and publish a privacy policy. ATT tracking permission is not requested by this build; do not enable an IDFA/ATT message without adding and testing that separate flow.
- Use Google Play internal testing and Apple TestFlight before a public release. Uploading requires your developer accounts and an explicit publication decision.

Official guides: https://docs.flutter.dev/deployment/android and https://docs.flutter.dev/deployment/ios

No store upload, account registration, paid service, production signing key, or publication is performed by this project.
