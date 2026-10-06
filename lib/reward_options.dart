import 'package:flutter/material.dart';
import 'game_controller.dart';
import 'rewarded_ads.dart';
import 'coin_purchases.dart';
import 'wallet_api.dart';
export 'coin_purchases.dart' show coinPacks;
export 'rewarded_ads.dart';

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
  CoinPurchases? get purchases =>
      coinPurchases?.game == widget.game ? coinPurchases : null;
  @override
  void initState() {
    super.initState();
    purchases?.addListener(updated);
  }

  void updated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    purchases?.removeListener(updated);
    super.dispose();
  }

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

  Future<void> walletRecovery() async {
    final service = purchases;
    if (service == null) return;
    final input = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wallet recovery'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Save this key privately before buying coins. Anyone with it can access your purchased-coin wallet. It does not back up level progress or earned coins.',
              ),
              const SizedBox(height: 12),
              if (service.api.token != null)
                SelectableText(
                  service.api.token!,
                  style: const TextStyle(fontSize: 12),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: input,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Restore an existing wallet key',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Restore wallet'),
          ),
        ],
      ),
    );
    // Let the dialog finish its closing animation before releasing its controller.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    input.dispose();
    if (key == null || !mounted) return;
    try {
      await service.recover(key);
      message = 'Purchased wallet restored.';
    } catch (_) {
      message = 'Wallet could not be restored. Check the key and connection.';
    }
    if (mounted) setState(() {});
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
            onPressed: busy
                ? null
                : widget.game.adminTesting
                ? () => purchase(pack.amount, pack.price)
                : purchases?.ready == true &&
                      purchases?.purchasing == false &&
                      purchases?.products.containsKey(pack.id) == true
                ? () => purchases!.buy(pack.id)
                : null,
            icon: const Icon(Icons.toll_rounded),
            label: Text(
              '${pack.amount} coins · ${widget.game.adminTesting ? pack.price : purchases?.products[pack.id]?.price ?? 'Unavailable'}',
            ),
          ),
        ),
      if (message != null) Text(message!, textAlign: TextAlign.center),
      if (!widget.game.adminTesting) ...[
        Text(
          purchases?.message ?? 'Coin purchases are not configured yet.',
          textAlign: TextAlign.center,
        ),
        if (purchases?.loading == true || purchases?.purchasing == true)
          const LinearProgressIndicator(),
        if (purchases?.enabled == true && purchases?.api.configured == true)
          TextButton(
            onPressed: purchases?.loading == true ? null : purchases?.retry,
            child: const Text('Retry / sync'),
          ),
        if (purchases?.enabled == true && purchases?.api.configured == true)
          TextButton(
            onPressed: purchases!.purchasing || purchases!.loading
                ? null
                : walletRecovery,
            child: const Text('Wallet recovery'),
          ),
        if (purchases?.api.accountId != null) ...[
          if (purchases!.debt > 0)
            Text(
              'A refunded purchase left ${purchases!.debt} coins already used. Future coin purchases settle this amount first.',
              textAlign: TextAlign.center,
            ),
          Text(
            'Earned: ${widget.game.rewards.coins} · Purchased: ${purchases!.balance}',
            textAlign: TextAlign.center,
          ),
          const Text(
            'Purchased coins require an internet connection to spend. Save your recovery key before reinstalling.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11),
          ),
        ],
      ],
      Text(
        '$adModeCaption. ${widget.game.adminTesting
            ? 'Coin packs are simulations and never charge money.'
            : storeEnvironment == 'sandbox'
            ? 'Test setup: use a store test account. Check the store payment sheet before confirming. Replays also earn coins.'
            : 'Prices and payment confirmation come from your app store. Replays also earn coins.'}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
      ),
    ],
  );
}
