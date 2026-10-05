import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';

export 'ad_config.dart';

abstract interface class RewardVideo {
  Future<bool> show();
  void dispose();
}

/// Separates native SDK calls from the reward lifecycle so failures and duplicate
/// callbacks can be tested without requesting real advertising.
abstract interface class AdGateway {
  Future<void> updateConsent();
  Future<bool> canRequestAds();
  Future<bool> privacyRequired();
  Future<void> showPrivacyOptions();
  Future<void> initialize();
  Future<RewardVideo> load(String unitId);
}

class GoogleAdGateway implements AdGateway {
  @override
  Future<void> updateConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!updated.isCompleted) updated.complete();
      },
      (error) {
        if (!updated.isCompleted) updated.completeError(error);
      },
    );
    await updated.future.timeout(const Duration(seconds: 20));
    // Do not time out a form while the player is making a privacy choice.
    FormError? formError;
    await ConsentForm.loadAndShowConsentFormIfRequired(
      (error) => formError = error,
    );
    if (formError != null) throw formError!;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<bool> privacyRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() async {
    FormError? formError;
    await ConsentForm.showPrivacyOptionsForm((error) => formError = error);
    if (formError != null) throw formError!;
  }

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize().timeout(const Duration(seconds: 35));
  }

  @override
  Future<RewardVideo> load(String unitId) async {
    final result = Completer<RewardVideo>();
    var expired = false;
    try {
      unawaited(
        RewardedAd.load(
          adUnitId: unitId,
          request: const AdRequest(),
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) {
              if (expired || result.isCompleted) {
                unawaited(ad.dispose());
              } else {
                result.complete(GoogleRewardVideo(ad));
              }
            },
            onAdFailedToLoad: (error) {
              if (!expired && !result.isCompleted) result.completeError(error);
            },
          ),
        ).catchError((Object error, StackTrace stack) {
          if (!expired && !result.isCompleted) {
            result.completeError(error, stack);
          }
        }),
      );
      return await result.future.timeout(const Duration(seconds: 25));
    } finally {
      expired = true;
    }
  }
}

class GoogleRewardVideo implements RewardVideo {
  GoogleRewardVideo(this.ad);
  final RewardedAd ad;
  bool _disposed = false;

  @override
  Future<bool> show() async {
    final result = Completer<bool>();
    var earned = false;
    var closed = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (_) {
        closed = true;
        if (!result.isCompleted) result.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        closed = true;
        if (!result.isCompleted) result.complete(false);
      },
    );
    await ad.show(
      onUserEarnedReward: (_, reward) {
        // Latch once; dismissal alone never earns a reward. Ignore late callbacks.
        if (!closed) earned = true;
      },
    );
    return result.future;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(ad.dispose());
  }
}

enum AdOutcome { earned, cancelled, unavailable, busy, consentRequired }

class RewardedAds {
  RewardedAds({required this.gateway, required this.config});
  final AdGateway gateway;
  final AdConfig config;
  bool _busy = false;
  bool _initialized = false;
  bool _consentUpdated = false;
  Future<bool>? _preparing;
  bool get supported => config.supported;
  bool get testMode => config.testMode;

  Future<bool> prepare() => _preparing ??= _prepare().whenComplete(() {
    _preparing = null;
  });

  Future<bool> _prepare() async {
    if (!supported) return false;
    try {
      if (!_consentUpdated) {
        try {
          await gateway.updateConsent();
          _consentUpdated = true;
        } catch (_) {
          // UMP may still allow requests using valid consent from an earlier
          // session. Never infer consent from the error or our own saved flag.
        }
      }
      if (!await gateway.canRequestAds()) return false;
      if (!_initialized) {
        await gateway.initialize();
        _initialized = true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<AdOutcome> watch(
    RewardKind kind, {
    required bool Function() isActive,
    required VoidCallback onPresenting,
  }) async {
    if (_busy) return AdOutcome.busy;
    if (!supported) return AdOutcome.unavailable;
    _busy = true;
    RewardVideo? video;
    try {
      if (!await prepare()) return AdOutcome.consentRequired;
      if (!isActive()) return AdOutcome.cancelled;
      video = await gateway.load(config.unitId(kind));
      if (!isActive()) return AdOutcome.cancelled;
      if (!await gateway.canRequestAds()) return AdOutcome.consentRequired;
      if (!isActive()) return AdOutcome.cancelled;
      onPresenting();
      return await video.show() ? AdOutcome.earned : AdOutcome.cancelled;
    } catch (_) {
      return AdOutcome.unavailable;
    } finally {
      video?.dispose();
      _busy = false;
    }
  }

  Future<String> privacyOptions() async {
    if (_busy) return 'Please finish the current ad first.';
    if (!supported) {
      return 'Ad privacy options are available on Android and iOS.';
    }
    _busy = true;
    try {
      await prepare();
      if (!await gateway.privacyRequired()) {
        return 'Google does not currently require an ad privacy form for this device.';
      }
      await gateway.showPrivacyOptions();
      return 'Your ad privacy choices have been updated.';
    } catch (_) {
      return 'Privacy options could not load. Check your connection and try again.';
    } finally {
      _busy = false;
    }
  }
}

/// Tests replace this with a deterministic gateway; production never simulates.
RewardedAds rewardAds = RewardedAds(
  gateway: GoogleAdGateway(),
  config: AdConfig(platform: defaultTargetPlatform),
);

String get adModeCaption => rewardAds.testMode
    ? 'Google test ads · no advertising revenue'
    : 'Optional ad · reward after completion';
