import 'package:flutter/material.dart';
import 'companions.dart';
import 'game_controller.dart';
import 'shop_catalog.dart';
import 'campaign.dart';
import 'story.dart';
import 'reward_options.dart';

/// Returns the chapter's starting index, -1 for practice, or null to stay put.
Future<int?> showChapterGate(
  BuildContext context,
  GameController game,
  int id,
) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: ListenableBuilder(
        listenable: game,
        builder: (context, _) {
          final owned = game.inventory.companions.contains(id);
          final price = companionPrices[id];
          final short = (price - game.coins).clamp(0, price);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompanionPortrait(
                id: id,
                mood: CompanionMood.thinking,
                size: 130,
              ),
              const SizedBox(height: 12),
              Text(
                id == 1 ? 'Beyond the garden' : storyTitles[id],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                id == 1
                    ? '“Your lantern is awake. That means my garden is next.”'
                    : chapterInvitations[id],
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Meet ${storyNames[id]}. Includes this companion, her fifteen-stage illustrated story and chapter boss.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your balance: ${game.coins} coins',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (!owned)
                Text(
                  'Unlock: $price coins${short > 0 ? ' · $short more needed' : ''}',
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('unlock-chapter'),
                onPressed: owned || short == 0
                    ? () async {
                        final success =
                            owned || await game.spendCoins('companion:$id');
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pop(context, id * chapterLength);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                game.walletError ??
                                    'Could not unlock. Please try again.',
                              ),
                            ),
                          );
                        }
                      }
                    : null,
                icon: Icon(owned ? Icons.arrow_forward : Icons.lock_open),
                label: Text(
                  owned ? 'Continue chapter' : 'Unlock for $price coins',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, -1),
                icon: const Icon(Icons.replay),
                label: const Text('Replay levels · earn 30 coins per clear'),
              ),
              const Text(
                'Unpaid bonus improvements and faster personal bests earn extra. You can always continue earning offline.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (!owned && short > 0) CoinOptions(game: game),
            ],
          );
        },
      ),
    ),
  ),
);
