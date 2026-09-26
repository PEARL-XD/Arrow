# Test first, then publish

This is a native Flutter app, not a WebView. The same Dart game and assets target Android and iOS. It runs offline. There are no ads, purchases, logins, analytics, or servers.

## Android testing on this Windows computer

1. Connect an Android phone with Developer options and USB debugging enabled. Authorize this computer on the phone.
2. In the project folder, run `flutter devices`, then `flutter run -d DEVICE_ID`.
3. Alternatively build `flutter build apk --debug` and transfer `build/app/outputs/flutter-apk/app-debug.apk` to your phone. Install it only on a test device you control. This debug build is not for the Play Store.
4. If an Android SDK license is required, review and accept it yourself with `flutter doctor --android-licenses`. No license acceptance is automated by this project.

## iPhone testing

A Mac with Xcode is required. Copy this project to the Mac, install Flutter, run `flutter pub get`, open `ios/Runner.xcworkspace`, select your signing team and an available bundle identifier, and run on your connected iPhone. You can also use an iOS simulator. iOS builds cannot be verified on this Windows host.

## Before either store submission

- Choose your publisher identity and permanent application/bundle ID. `com.example.path_out` is explicitly a development placeholder; do not publish with it.
- Play-test all 40 levels on real phones. The progression score is an authoring heuristic, not a measured player difficulty rating. Test small screens, pinch/drag versus tap, app background/resume, phone interruptions, haptics, reduced motion, saved progress and reinstall behavior.
- Replace development signing with your own Android upload key. Keep the keystore and passwords outside version control. Configure `android/key.properties` (see the example), then build `flutter build appbundle --release`.
- On a Mac, configure your Apple team, App Store bundle ID and signing; create an archive with `flutter build ipa --release`.
- Set your final app name, version/build number, support contact, screenshots and store descriptions. The included original icon is usable for testing and can be refined for release.
- Complete current store privacy, data-safety, content-rating and testing requirements for your account. This app stores puzzle progress and a haptics preference locally only; it does not collect or transmit user data. Confirm this remains true after adding future SDKs.
- Use Google Play internal testing and Apple TestFlight before a public release. Uploading requires your developer accounts and an explicit publication decision.

Official guides: https://docs.flutter.dev/deployment/android and https://docs.flutter.dev/deployment/ios

No store upload, account registration, paid service, production signing key, or publication is performed by this project.
