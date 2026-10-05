import 'dart:async';
import 'package:path_out/rewarded_ads.dart';

class FakeAdGateway implements AdGateway {
  bool consent = true;
  bool requiredPrivacy = true;
  bool updateFails = false;
  bool loadFails = false;
  int updates = 0, initializations = 0, privacyForms = 0, loads = 0;
  String? lastUnit;
  Completer<RewardVideo>? pendingLoad;
  FakeRewardVideo video = FakeRewardVideo();
  @override
  Future<void> updateConsent() async {
    updates++;
    if (updateFails) throw StateError('offline');
  }

  @override
  Future<bool> canRequestAds() async => consent;
  @override
  Future<bool> privacyRequired() async => requiredPrivacy;
  @override
  Future<void> showPrivacyOptions() async {
    privacyForms++;
  }

  @override
  Future<void> initialize() async {
    initializations++;
  }

  @override
  Future<RewardVideo> load(String unitId) async {
    loads++;
    lastUnit = unitId;
    if (loadFails) throw StateError('no fill');
    if (pendingLoad != null) return pendingLoad!.future;
    video = FakeRewardVideo();
    return video;
  }
}

class FakeRewardVideo implements RewardVideo {
  final result = Completer<bool>();
  int shows = 0, disposals = 0;
  void finish(bool earned) {
    if (!result.isCompleted) result.complete(earned);
  }

  @override
  Future<bool> show() {
    shows++;
    return result.future;
  }

  @override
  void dispose() {
    disposals++;
  }
}
