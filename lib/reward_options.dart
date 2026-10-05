import 'package:flutter/material.dart';
import 'game_controller.dart';
import 'rewarded_ads.dart';
export 'rewarded_ads.dart';

const coinPacks = [
  (id: 'coins_1500', amount: 1500, price: '₹49'),
  (id: 'coins_4000', amount: 4000, price: '₹99'),
];

bool _rewardBusy = false;

/// Keep the startup consent form above the game and story, with visible feedback
/// while Google's consent request is in progress. Failure never blocks play.
Future<void> prepareGameAds(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const _AdSetupDialog(),
);

class _AdSetupDialog extends StatefulWidget {
  const _AdSetupDialog();
  @override
  State<_AdSetupDialog> createState() => _AdSetupDialogState();
}

class _AdSetupDialogState extends State<_AdSetupDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await rewardAds.prepare();
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => const PopScope(
    canPop: false,
    child: AlertDialog(
      title: Text('Preparing privacy settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Checking your ad privacy choices. The game will still open if ads are unavailable.',
          ),
        ],
      ),
    ),
  );
}

/// The same real SDK flow is used by normal players and admin testers.
Future<bool> watchReward(
  BuildContext context,
  GameController game,
  RewardKind kind,
) async {
  if (_rewardBusy) return false;
  if (kind == RewardKind.hint && game.hints >= 999) return false;
  if (kind == RewardKind.revive && game.status != GameStatus.lost) return false;
  _rewardBusy = true;
  final epoch = game.epoch;
  try {
    final earned = await showDialog<AdOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RewardAdDialog(kind: kind),
    );
    if (!context.mounted) return false;
    if (earned != AdOutcome.earned) {
      final message = switch (earned) {
        AdOutcome.consentRequired =>
          'Ads could not start. Check your connection and Ad privacy options, then try again.',
        AdOutcome.unavailable =>
          'No ad is available right now. Please try again later. Nothing was charged.',
        AdOutcome.busy =>
          'Another ad is already loading. Please wait a moment.',
        _ => 'Ad closed without a reward. Nothing was charged.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }
    switch (kind) {
      case RewardKind.coins:
        game.grantAdCoins();
        return true;
      case RewardKind.hint:
        return game.grantAdHint();
      case RewardKind.revive:
        return game.epoch == epoch && game.revive(rewarded: true);
    }
  } finally {
    _rewardBusy = false;
  }
}

class _RewardAdDialog extends StatefulWidget {
  const _RewardAdDialog({required this.kind});
  final RewardKind kind;
  @override
  State<_RewardAdDialog> createState() => _RewardAdDialogState();
}

class _RewardAdDialogState extends State<_RewardAdDialog> {
  bool cancelled = false;
  bool presenting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final outcome = await rewardAds.watch(
        widget.kind,
        isActive: () =>
            mounted &&
            !cancelled &&
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
        onPresenting: () {
          if (mounted) setState(() => presenting = true);
        },
      );
      if (mounted && !cancelled) Navigator.pop(context, outcome);
    });
  }

  @override
  void dispose() {
    cancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: Text(rewardAds.testMode ? 'Google test ad' : 'Rewarded ad'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(switch (widget.kind) {
            RewardKind.coins => 'Reward: 80 coins',
            RewardKind.hint => 'Reward: 1 hint',
            RewardKind.revive => 'Reward: restore your hearts and continue',
          }, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            presenting
                ? 'Your reward will be checked when the ad closes.'
                : 'Loading an ad…',
          ),
          const SizedBox(height: 8),
          Text(adModeCaption, style: const TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('cancel-ad-loading'),
          onPressed: presenting
              ? null
              : () {
                  cancelled = true;
                  Navigator.pop(context, AdOutcome.cancelled);
                },
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

/// Reused in the coin shop and at an unaffordable chapter gate.
class CoinOptions extends StatefulWidget {
  const CoinOptions({super.key, required this.game});
  final GameController game;
  @override
  State<CoinOptions> createState() => _CoinOptionsState();
}

class _CoinOptionsState extends State<CoinOptions> {
  bool busy = false;
  String? message;
  Future<void> earn() async {
    if (busy) return;
    setState(() => busy = true);
    final earned = await watchReward(context, widget.game, RewardKind.coins);
    if (mounted) {
      setState(() {
        busy = false;
        message = earned
            ? '+80 coins added to your wallet.'
            : 'No reward claimed.';
      });
    }
  }

  Future<void> purchase(int amount, String price) async {
    if (busy || !widget.game.adminTesting) return;
    setState(() => busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test coin purchase'),
        content: Text(
          '$amount coins · planned price $price\n\nThis simulates the purchase flow. You will not be charged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-test-purchase'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simulate purchase'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final granted = confirmed == true && widget.game.grantTestCoinPack(amount);
    setState(() {
      busy = false;
      message = granted
          ? '+$amount test coins added. No charge.'
          : 'Purchase cancelled.';
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'A little more adventure',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        key: const Key('watch-coins-ad'),
        onPressed: !busy ? earn : null,
        icon: const Icon(Icons.ondemand_video_rounded),
        label: const Text('Watch an ad · +80 coins'),
      ),
      const SizedBox(height: 8),
      for (final pack in coinPacks)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FilledButton.tonalIcon(
            key: Key('coin-pack-${pack.amount}'),
            onPressed: !busy && widget.game.adminTesting
                ? () => purchase(pack.amount, pack.price)
                : null,
            icon: const Icon(Icons.toll_rounded),
            label: Text('${pack.amount} coins · ${pack.price}'),
          ),
        ),
      if (message != null) Text(message!, textAlign: TextAlign.center),
      Text(
        '$adModeCaption. ${widget.game.adminTesting ? 'Coin packs are simulations and never charge money.' : 'Coin purchases are not available yet. Replays also earn coins.'}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
      ),
    ],
  );
}
