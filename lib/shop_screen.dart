import 'package:flutter/material.dart';
import 'companions.dart';
import 'game_controller.dart';
import 'shop_catalog.dart';
import 'theme_art.dart';
import 'arrow_skins.dart';
import 'arrow_preview.dart';
import 'reward_options.dart';
import 'rewards.dart';

Future<void> showCoinShop(
  BuildContext context,
  GameController game, {
  int tab = 0,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => CoinShop(game: game, initialTab: tab),
);

class CoinShop extends StatefulWidget {
  const CoinShop({super.key, required this.game, this.initialTab = 0});
  final GameController game;
  final int initialTab;
  @override
  State<CoinShop> createState() => _CoinShopState();
}

class _CoinShopState extends State<CoinShop> {
  final scroll = ScrollController();
  late int tab = widget.initialTab;
  String? message;
  bool confirming = false;
  GameController get game => widget.game;

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> purchase(String name, int price, bool Function() buy) async {
    if (confirming) return;
    confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Buy $name?'),
        content: Text(
          'Spend $price coins?\nYour balance: ${game.rewards.coins} coins.\n\n${nextChapterReminder(price)}No real money is used.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm purchase'),
          ),
        ],
      ),
    );
    confirming = false;
    if (!mounted || confirmed != true) return;
    final success = buy();
    setState(
      () => message = success
          ? '$name purchased!${name == '1 hint'
                ? ' Ready when you need it.'
                : companionNames.contains(name)
                ? ' She will join you in her chapter.'
                : ' Tap Use to equip.'}'
          : 'Purchase not made. Check your balance or ownership.',
    );
  }

  Widget buyButton(
    String id,
    String name,
    int price,
    bool Function() buy, {
    bool available = true,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        key: Key('buy-$id'),
        onPressed: available
            ? () {
                if (game.rewards.coins < price) {
                  setState(() {
                    tab = 4;
                    message =
                        '${price - game.rewards.coins} more coins needed for $name.';
                  });
                  if (scroll.hasClients) scroll.jumpTo(0);
                } else {
                  purchase(name, price, buy);
                }
              }
            : null,
        icon: const Icon(Icons.toll_rounded, size: 18),
        label: Text('$price coins'),
      ),
      if (available && game.rewards.coins < price)
        Text(
          '${price - game.rewards.coins} more coins needed',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
    ],
  );

  String nextChapterReminder(int price) {
    for (var id = 1; id < companionPrices.length; id++) {
      if (!game.inventory.companions.contains(id)) {
        return 'Next companion story: ${companionPrices[id]} coins. After this purchase: ${game.rewards.coins - price}.\n\n';
      }
    }
    return '';
  }

  Widget card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE2E7F0)),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: ListenableBuilder(
        listenable: game,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Coin shop',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close shop',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.toll_rounded,
                    color: Color(0xFF9C641B),
                    size: 22,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${game.rewards.coins} coins',
                      key: const Key('shop-balance'),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        key: Key('shop-tab-$i'),
                        label: Text(
                          [
                            'Hints',
                            'Companions',
                            'Themes',
                            'Arrows',
                            'Coins',
                          ][i],
                        ),
                        selected: tab == i,
                        onSelected: (_) => setState(() {
                          if (scroll.hasClients) scroll.jumpTo(0);
                          tab = i;
                          message = null;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF286853)),
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('shop-scroll'),
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tab == 0) ...[
                      card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.lightbulb_rounded,
                              size: 58,
                              color: Color(0xFFAE7820),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'A little nudge',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${game.hints} hints saved',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add one hint to highlight a safe arrow. Your hints stay with you between levels.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            buyButton(
                              'hint',
                              '1 hint',
                              80,
                              game.buyHint,
                              available: game.hints < 999,
                            ),
                            OutlinedButton.icon(
                              key: const Key('watch-hint-ad'),
                              onPressed: game.hints < 999 && !confirming
                                  ? () async {
                                      setState(() => confirming = true);
                                      final earned = await watchReward(
                                        context,
                                        game,
                                        RewardKind.hint,
                                      );
                                      if (mounted) {
                                        setState(() {
                                          confirming = false;
                                          message = earned
                                              ? '+1 hint added.'
                                              : 'No reward claimed.';
                                        });
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.ondemand_video_rounded),
                              label: const Text('Watch an ad · +1 hint'),
                            ),
                            Text(
                              adModeCaption,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11),
                            ),
                            if (game.hints >= 999)
                              const Text(
                                'Hint storage is full.',
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                      card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Earn as you untangle',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'First clear: +70 coins\nEvery replay: +30 coins\nThis level: under ${formatTime(bonusTargets(game.index).gold)}: +10\nUnder ${formatTime(bonusTargets(game.index).silver)}: +5\nGreat moves: +4 each, up to +20\nFaster personal best on replay: +5\nEvery two clears: +1 hint',
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Replays pay the base plus only unpaid speed/skill improvements. Beating your best time adds 5 more. There is no time penalty. Later chapters and bosses allow more time.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (tab == 1) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Each companion includes her fifteen-stage illustrated chapter. Defeat the preceding boss, then unlock with earned coins. Your chapter companion joins automatically when you enter her story. All four stories are available offline.',
                        ),
                      ),
                      for (var i = 0; i < companionNames.length; i++)
                        companionCard(i),
                    ],
                    if (tab == 2) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Matching arrows, board and background. A new look, never a gameplay advantage.',
                        ),
                      ),
                      for (final theme in puzzleThemes) themeCard(theme),
                    ],
                    if (tab == 3) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Mix any arrow skin with your board. Previewing on ${game.inventory.theme.name}. Distinct colours and head shapes stay visible while resting, with extra effects during escape.',
                        ),
                      ),
                      for (final skin in arrowSkins) arrowCard(skin),
                    ],
                    if (tab == 4) card(CoinOptions(game: game)),
                    const Text(
                      'Purchases and coins are saved on this device. Real payments are not connected.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget arrowCard(ArrowSkin skin) {
    final owned = game.inventory.arrows.contains(skin.id);
    final selected = game.inventory.selectedArrow == skin.id;
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            skin.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ArrowSkinPreview(
            key: ValueKey(skin.id),
            skin: skin,
            theme: game.inventory.theme,
          ),
          Text(skin.description),
          const SizedBox(height: 12),
          if (owned)
            OutlinedButton.icon(
              key: Key('use-arrow-${skin.id}'),
              onPressed: selected
                  ? null
                  : () {
                      game.equipArrowSkin(skin.id);
                      setState(() => message = '${skin.name} arrows equipped.');
                    },
              icon: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.north_east_rounded,
              ),
              label: Text(selected ? 'Equipped' : 'Use arrows'),
            )
          else if (skin.id == 'lantern')
            const Text(
              'Complete Mira’s chapter to earn this keepsake. Not sold for coins.',
              textAlign: TextAlign.center,
            )
          else
            buyButton(
              'arrow-${skin.id}',
              '${skin.name} arrows',
              skin.price,
              () => game.buyArrowSkin(skin.id),
            ),
        ],
      ),
    );
  }

  Widget companionCard(int id) {
    final owned = game.inventory.companions.contains(id);
    final selected = game.companionVisible && game.companionId == id;
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CompanionPortrait(
              id: id,
              mood: CompanionMood.cheer,
              size: 136,
            ),
          ),
          Text(
            companionNames[id],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            [
              'Warm, encouraging and full of heart.',
              'Calm words and a little elegance.',
              'Big energy for every little victory.',
              'Short, sharp and quietly confident.',
            ][id],
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '“${companionDialogue[id][CompanionEvent.great]!.first}”',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: companionColors[id],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          if (owned)
            OutlinedButton.icon(
              key: Key('use-companion-$id'),
              onPressed: null,
              icon: Icon(
                selected ? Icons.check_circle_rounded : Icons.face_rounded,
              ),
              label: Text(
                selected
                    ? 'Current companion'
                    : 'Unlocked · joins in her chapter',
              ),
            )
          else
            buyButton(
              'companion-$id',
              companionNames[id],
              companionPrices[id],
              () => game.buyCompanion(id),
              available: game.companionAvailable(id),
            ),
          if (!owned && !game.companionAvailable(id))
            Text(
              'Finish chapter $id to meet this companion.',
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget themeCard(PuzzleTheme theme) {
    final owned = game.inventory.themes.contains(theme.id);
    final selected = game.inventory.selectedTheme == theme.id;
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 116,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(painter: _ThemePreview(theme)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            theme.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(theme.description),
          const SizedBox(height: 12),
          if (owned)
            OutlinedButton.icon(
              key: Key('use-theme-${theme.id}'),
              onPressed: selected
                  ? null
                  : () {
                      game.equipTheme(theme.id);
                      setState(() => message = '${theme.name} equipped.');
                    },
              icon: Icon(
                selected ? Icons.check_circle_rounded : Icons.palette_outlined,
              ),
              label: Text(selected ? 'Equipped' : 'Use theme'),
            )
          else
            buyButton(
              'theme-${theme.id}',
              theme.name,
              theme.price,
              () => game.buyTheme(theme.id),
            ),
        ],
      ),
    );
  }
}

class _ThemePreview extends CustomPainter {
  _ThemePreview(this.theme);
  final PuzzleTheme theme;
  @override
  void paint(Canvas canvas, Size size) {
    paintThemeSurface(canvas, size, theme);
    for (var x = 12.0; x < size.width; x += 16) {
      for (var y = 12.0; y < size.height; y += 16) {
        canvas.drawCircle(Offset(x, y), 1.2, Paint()..color = theme.dots);
      }
    }
    final pen = Paint()
      ..color = theme.ink
      ..shader = themeArrowShader(theme, Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final x = size.width * .6;
    canvas.drawPath(
      Path()
        ..moveTo(24, 68)
        ..lineTo(56, 68)
        ..lineTo(56, 28)
        ..lineTo(x, 28)
        ..moveTo(x - 8, 22)
        ..lineTo(x, 28)
        ..lineTo(x - 8, 34),
      pen,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 24, 24)
        ..lineTo(size.width - 24, 68)
        ..lineTo(x, 68)
        ..moveTo(x + 8, 62)
        ..lineTo(x, 68)
        ..lineTo(x + 8, 74),
      pen,
    );
  }

  @override
  bool shouldRepaint(_ThemePreview oldDelegate) => oldDelegate.theme != theme;
}
