import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_out/rewarded_ads.dart';
import 'fake_ads.dart';

class StubSdkAd implements RewardedAd {
  @override
  FullScreenContentCallback<RewardedAd>? fullScreenContentCallback;
  OnUserEarnedRewardCallback? reward;
  int disposals = 0;
  @override
  Future<void> show({
    required OnUserEarnedRewardCallback onUserEarnedReward,
  }) async {
    reward = onUserEarnedReward;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('All build modes default to Google test units, not publisher units', () {
    expect(adTestMode, isTrue);
    for (final kind in RewardKind.values) {
      expect(
        const AdConfig(platform: TargetPlatform.android).unitId(kind),
        'ca-app-pub-3940256099942544/5224354917',
      );
      expect(
        const AdConfig(platform: TargetPlatform.iOS).unitId(kind),
        'ca-app-pub-3940256099942544/1712485313',
      );
    }
  });

  test('Production IDs match the supplied platform and placement', () {
    for (final row in [
      (TargetPlatform.android, RewardKind.coins, '3212997363'),
      (TargetPlatform.android, RewardKind.hint, '3157157048'),
      (TargetPlatform.android, RewardKind.revive, '9586834029'),
      (TargetPlatform.iOS, RewardKind.coins, '7642273527'),
      (TargetPlatform.iOS, RewardKind.hint, '1221258846'),
      (TargetPlatform.iOS, RewardKind.revive, '7099262321'),
    ]) {
      expect(
        AdConfig(platform: row.$1, testMode: false).unitId(row.$2),
        'ca-app-pub-9318630710537182/${row.$3}',
      );
    }
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('ca-app-pub-9318630710537182~3838759880'),
    );
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      contains('ca-app-pub-9318630710537182~4017803410'),
    );
  });

  late FakeAdGateway gateway;
  late RewardedAds service;
  setUp(() {
    gateway = FakeAdGateway();
    service = RewardedAds(
      gateway: gateway,
      config: const AdConfig(platform: TargetPlatform.android),
    );
  });
  Future<AdOutcome> watch({bool Function()? active}) => service.watch(
    RewardKind.coins,
    isActive: active ?? () => true,
    onPresenting: () {},
  );
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('Consent blocks SDK initialization and ad requests', () async {
    gateway.consent = false;
    expect(await watch(), AdOutcome.consentRequired);
    expect(gateway.loads, 0);
    expect(gateway.initializations, 0);
  });
  test('Consent update failure never implies permission', () async {
    gateway.updateFails = true;
    gateway.consent = false;
    expect(await watch(), AdOutcome.consentRequired);
    expect(gateway.loads, 0);
    gateway.consent = true;
    expect(await service.prepare(), isTrue);
    expect(gateway.initializations, 1);
  });
  test(
    'Concurrent preparation coalesces, successful session initializes once',
    () async {
      expect(await Future.wait([service.prepare(), service.prepare()]), [
        true,
        true,
      ]);
      await service.prepare();
      expect(gateway.updates, 1);
      expect(gateway.initializations, 1);
    },
  );
  test(
    'Concurrent displays rejected; reward and ad disposal happen once',
    () async {
      final pending = watch();
      await tick();
      expect(await watch(), AdOutcome.busy);
      expect(gateway.loads, 1);
      gateway.video.finish(true);
      gateway.video.finish(true);
      expect(await pending, AdOutcome.earned);
      expect(gateway.video.disposals, 1);
    },
  );
  test('Dismissal without reward pays nothing', () async {
    final pending = watch();
    await tick();
    gateway.video.finish(false);
    expect(await pending, AdOutcome.cancelled);
  });
  test('Load failure releases busy state so player can retry', () async {
    gateway.loadFails = true;
    expect(await watch(), AdOutcome.unavailable);
    gateway.loadFails = false;
    final pending = watch();
    await tick();
    gateway.video.finish(true);
    expect(await pending, AdOutcome.earned);
  });
  test(
    'Cancel or leave while loading disposes late ad without showing it',
    () async {
      gateway.pendingLoad = Completer<RewardVideo>();
      var active = true;
      final pending = watch(active: () => active);
      await tick();
      active = false;
      final video = FakeRewardVideo();
      gateway.pendingLoad!.complete(video);
      expect(await pending, AdOutcome.cancelled);
      expect(video.shows, 0);
      expect(video.disposals, 1);
    },
  );
  test(
    'Consent checked again after load; revoked consent discards ad',
    () async {
      gateway.pendingLoad = Completer<RewardVideo>();
      final pending = watch();
      await tick();
      gateway.consent = false;
      final video = FakeRewardVideo();
      gateway.pendingLoad!.complete(video);
      expect(await pending, AdOutcome.consentRequired);
      expect(video.shows, 0);
      expect(video.disposals, 1);
    },
  );
  test('Privacy options supported and respect native requirement', () async {
    await service.privacyOptions();
    expect(gateway.privacyForms, 1);
    gateway.requiredPrivacy = false;
    await service.privacyOptions();
    expect(gateway.privacyForms, 1);
  });
  test('Unsupported platform never invokes native plugin', () async {
    service = RewardedAds(
      gateway: gateway,
      config: const AdConfig(platform: TargetPlatform.windows),
    );
    expect(await watch(), AdOutcome.unavailable);
    expect(gateway.updates, 0);
  });
  test(
    'Native earned callback duplicates grant only one completion after dismissal',
    () async {
      final sdk = StubSdkAd();
      final video = GoogleRewardVideo(sdk);
      var completed = false;
      final pending = video.show().then((earned) {
        completed = true;
        return earned;
      });
      sdk.reward!(sdk, RewardItem(1, 'test'));
      sdk.reward!(sdk, RewardItem(1, 'test'));
      await tick();
      expect(completed, isFalse);
      sdk.fullScreenContentCallback!.onAdDismissedFullScreenContent!(sdk);
      expect(await pending, isTrue);
      video.dispose();
      video.dispose();
      expect(sdk.disposals, 1);
    },
  );
  test('Native dismissal ignores late reward callback', () async {
    final sdk = StubSdkAd();
    final video = GoogleRewardVideo(sdk);
    final pending = video.show();
    sdk.fullScreenContentCallback!.onAdDismissedFullScreenContent!(sdk);
    sdk.reward!(sdk, RewardItem(1, 'test'));
    expect(await pending, isFalse);
    video.dispose();
  });
  test('Native failure-to-show cannot grant a reward', () async {
    final sdk = StubSdkAd();
    final video = GoogleRewardVideo(sdk);
    final pending = video.show();
    sdk.fullScreenContentCallback!.onAdFailedToShowFullScreenContent!(
      sdk,
      AdError(1, 'test', 'failed'),
    );
    sdk.reward!(sdk, RewardItem(1, 'test'));
    expect(await pending, isFalse);
    video.dispose();
  });
}
