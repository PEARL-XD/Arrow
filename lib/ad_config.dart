import 'package:flutter/foundation.dart';

enum RewardKind { coins, hint, revive }

/// Safe in debug, profile AND release (including TestFlight). Publishing live
/// ads requires an explicit build flag after the launch checklist is complete.
const adTestMode = bool.fromEnvironment('ARROW_TEST_ADS', defaultValue: true);

class AdConfig {
  const AdConfig({required this.platform, this.testMode = adTestMode});
  final TargetPlatform platform;
  final bool testMode;

  bool get supported =>
      !kIsWeb &&
      (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

  String unitId(RewardKind kind) {
    if (!supported) {
      throw UnsupportedError('Mobile ads require Android or iOS.');
    }
    if (testMode) {
      return platform == TargetPlatform.iOS
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-3940256099942544/5224354917';
    }
    final suffix = platform == TargetPlatform.iOS
        ? switch (kind) {
            RewardKind.coins => '7642273527',
            RewardKind.hint => '1221258846',
            RewardKind.revive => '7099262321',
          }
        : switch (kind) {
            RewardKind.coins => '3212997363',
            RewardKind.hint => '3157157048',
            RewardKind.revive => '9586834029',
          };
    return 'ca-app-pub-9318630710537182/$suffix';
  }
}
