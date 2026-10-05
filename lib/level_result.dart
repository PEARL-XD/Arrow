import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'rewarded_ads.dart';
import 'game_controller.dart';
import 'rewards.dart';
import 'campaign.dart';
import 'story.dart';

/// Presentation only. Rewards have already been banked by the controller.
class LevelResult extends StatefulWidget {
  const LevelResult({
    super.key,
    required this.game,
    required this.onContinue,
    this.onReviveCoins,
    this.onReviveAd,
    this.onGetCoins,
  });
  final GameController game;
  final VoidCallback onContinue;
  final VoidCallback? onReviveCoins, onReviveAd, onGetCoins;
  @override
  State<LevelResult> createState() => _LevelResultState();
}

class _LevelResultState extends State<LevelResult>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.value = 1;
    } else if (!started) {
      animation.forward();
    }
    started = true;
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final won = game.status == GameStatus.won;
    final bossWon = won && game.index == storyLevelCount;
    final chapterWon = won && game.chapterEnd;
    final bossNext = won && game.index == game.regularLevelCount - 1;
    final gold = const Color(0xFF9C641B);
    return ColoredBox(
      color: const Color(0xFF24334D).withValues(alpha: .16),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            if (won && !MediaQuery.disableAnimationsOf(context))
              IgnorePointer(
                child: CustomPaint(painter: _Celebration(animation.value)),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Opacity(
                  opacity: (animation.value * 4).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale:
                        .88 +
                        .12 *
                            Curves.easeOutBack.transform(
                              (animation.value * 2.5).clamp(0.0, 1.0),
                            ),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
        child: Container(
          key: const Key('level-result-popup'),
          width: 380,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF6DE), Colors.white, Colors.white],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won ? Icons.emoji_events_rounded : Icons.refresh_rounded,
                size: 42,
                color: won ? gold : const Color(0xFF506BDF),
              ),
              const SizedBox(height: 4),
              Text(
                won
                    ? (chapterWon
                          ? 'Chapter complete!'
                          : bossWon
                          ? 'Boss defeated!'
                          : bossNext
                          ? 'Final challenge unlocked'
                          : 'Level cleared!')
                    : 'A fresh look?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF24334D),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                won
                    ? (chapterWon
                          ? '${storyTitles[game.index ~/ chapterLength]} · a memory to keep'
                          : bossWon
                          ? 'New levels coming soon'
                          : bossNext
                          ? 'One final crown awaits.'
                          : '${game.puzzle.name} · beautifully untangled')
                    : 'No hearts left. Take a breath and try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              if (won) ...[
                const SizedBox(height: 12),
                Text(
                  game.rewards.eligible
                      ? 'Time  ${formatTime(game.rewards.elapsed)}'
                      : 'Time unavailable for this older attempt',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '+${game.rewards.lastTotal} coins',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: gold,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 5,
                  children: [
                    for (final entry in {
                      'Clear': game.rewards.lastBase,
                      'Speed': game.rewards.lastSpeed,
                      'Skill': game.rewards.lastSkill,
                      'Best': game.rewards.lastRecord,
                    }.entries)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4FA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entry.key} +${entry.value}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Speed targets: ${formatTime(bonusTargets(game.index).gold)} / ${formatTime(bonusTargets(game.index).silver)}',
                  style: const TextStyle(fontSize: 10),
                ),
                const SizedBox(height: 6),
                Text(
                  game.rewards.lastBase == 30
                      ? 'Replay reward + unpaid bonuses + personal best'
                      : 'Coins added to your wallet',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
              if (won && game.index == chapterLength - 1) ...[
                const SizedBox(height: 10),
                const Text(
                  'Keepsake earned: Lanternlight arrows',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF87500B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Your story is saved in Mira’s journal.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
              if (won && game.lastHintEarned) ...[
                const SizedBox(height: 10),
                const Text(
                  '+1 hint · two levels cleared!',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              if (!won) ...[
                const SizedBox(height: 12),
                Text(
                  '${game.rewards.coins} coins · revive keeps your cleared arrows',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('revive-coins'),
                  onPressed: game.rewards.coins >= GameController.revivePrice
                      ? widget.onReviveCoins
                      : null,
                  icon: const Icon(Icons.health_and_safety_rounded),
                  label: const Text('Revive · 200 coins'),
                ),
                OutlinedButton.icon(
                  key: const Key('revive-ad'),
                  onPressed: widget.onReviveAd,
                  icon: const Icon(Icons.ondemand_video_rounded),
                  label: const Text('Watch an ad · revive'),
                ),
                Text(adModeCaption, style: TextStyle(fontSize: 10)),
                if (game.rewards.coins < GameController.revivePrice)
                  TextButton(
                    onPressed: widget.onGetCoins,
                    child: const Text('Get more coins'),
                  ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('result-continue'),
                  onPressed: widget.onContinue,
                  icon: Icon(
                    won
                        ? (bossWon
                              ? Icons.grid_view_rounded
                              : Icons.arrow_forward_rounded)
                        : Icons.refresh_rounded,
                  ),
                  label: Text(
                    won
                        ? (chapterWon
                              ? 'Continue journey'
                              : bossWon
                              ? 'Replay a level'
                              : bossNext
                              ? 'Face the boss'
                              : 'Next')
                        : game.bossPhase == 1
                        ? 'Retry from checkpoint'
                        : 'Try again',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Celebration extends CustomPainter {
  _Celebration(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 1) return;
    const colors = [
      Color(0xFFE5AE46),
      Color(0xFF8193ED),
      Color(0xFFDF84A3),
      Color(0xFF69B9AA),
    ];
    final fade = (1 - progress).clamp(0.0, 1.0);
    for (var i = 0; i < 38; i++) {
      final angle = i * 2.39996;
      final radius = progress * size.width * (.4 + (i % 5) * .09);
      final center = Offset(
        size.width / 2 + math.cos(angle) * radius,
        size.height * .38 + math.sin(angle) * radius + progress * progress * 80,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle + progress * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -5, 6, 10),
          const Radius.circular(2),
        ),
        Paint()..color = colors[i % colors.length].withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Celebration oldDelegate) =>
      progress != oldDelegate.progress;
}
