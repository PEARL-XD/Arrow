import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/puzzle.dart';
import 'package:path_out/shop_catalog.dart';

void main() {
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());
  test(
    'Fresh inventory is free companion and classic; locked choices cannot equip',
    () {
      final game = GameController(levels);
      expect(game.inventory.companions, {0});
      expect(game.inventory.themes, {'classic'});
      game.chooseCompanion(3);
      expect(game.companionId, 0);
      expect(game.equipTheme('midnight'), false);
      expect(game.buyCompanion(1), false);
      expect(game.buyTheme('sakura'), false);
      expect(game.rewards.coins, 0);
      game.dispose();
    },
  );
  test(
    'Purchases charge once; invalid and insufficient purchases never debit',
    () {
      final game = GameController(levels);
      game.completed.add(14);
      game.rewards.coins = 750;
      expect(game.buyCompanion(1), true);
      expect(game.rewards.coins, 150);
      expect(game.buyCompanion(1), false);
      expect(game.buyCompanion(-1), false);
      expect(game.buyCompanion(99), false);
      expect(game.buyTheme('fake'), false);
      expect(game.buyTheme('sakura'), true);
      expect(game.buyTheme('sakura'), false);
      expect(game.rewards.coins, 0);
      game.chooseCompanion(1);
      expect(game.equipTheme('sakura'), true);
      expect(game.inventory.selectedTheme, 'sakura');
      expect(game.companionId, 1);
      game.dispose();
    },
  );
  test(
    'Ownership, equipped items and deducted balance survive restart and restore',
    () {
      final game = GameController(levels);
      game.completed.add(44);
      game.rewards.coins = 1500;
      game.buyCompanion(3);
      game.buyTheme('midnight');
      game.chooseCompanion(3);
      game.equipTheme('midnight');
      game.buyHint();
      game.reset();
      final restored = GameController(levels)..restore(game.snapshot());
      expect(restored.rewards.coins, 400);
      expect(restored.inventory.companions, {0, 3});
      expect(restored.inventory.themes, {'classic', 'midnight'});
      expect(restored.inventory.selectedTheme, 'midnight');
      expect(restored.companionId, 3);
      expect(restored.hints, 4);
      game.dispose();
      restored.dispose();
    },
  );
  test('Legacy saves keep all formerly free companions and progress', () {
    final game = GameController(levels)
      ..completed.add(0)
      ..reset(1);
    final legacy = game.snapshot()..remove('shop');
    legacy['companionId'] = 3;
    final restored = GameController(levels)..restore(legacy);
    expect(restored.inventory.companions, {0, 1, 2, 3});
    expect(restored.companionId, 3);
    expect(restored.index, 1);
    expect(restored.completed, {0});
    game.dispose();
    restored.dispose();
  });
  test(
    'Malformed cosmetic data falls back without discarding level progress',
    () {
      final game = GameController(levels)
        ..completed.add(0)
        ..reset(1);
      final save = game.snapshot();
      save['shop'] = {
        'companions': [0, -1, '2', 99],
        'themes': ['fake'],
        'selectedTheme': 'midnight',
      };
      save['companionId'] = 3;
      final restored = GameController(levels)..restore(save);
      expect(restored.index, 1);
      expect(restored.inventory.companions, {0});
      expect(restored.inventory.selectedTheme, 'classic');
      expect(restored.companionId, 0);
      game.dispose();
      restored.dispose();
    },
  );
  test('All arrow and hint palettes contrast against their board', () {
    for (final theme in puzzleThemes) {
      for (final ink in [theme.ink, theme.highlight]) {
        final luminances = [
          ink.computeLuminance(),
          theme.board.computeLuminance(),
        ]..sort();
        expect(
          (luminances.last + .05) / (luminances.first + .05),
          greaterThan(3),
          reason: theme.id,
        );
      }
    }
  });
}
