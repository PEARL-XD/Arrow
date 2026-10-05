import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/puzzle.dart';

void main() {
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());
  GameController unlocked() => GameController(levels)
    ..inventory.companions.addAll([1, 2, 3])
    ..completed.addAll(List.generate(61, (i) => i));
  for (final entry in {
    0: 3,
    14: 3,
    15: 2,
    44: 2,
    45: 1,
    59: 1,
    60: 1,
  }.entries) {
    test(
      'Level ${entry.key + 1} starts and restarts with ${entry.value} hearts',
      () {
        final game = unlocked()..reset(entry.key);
        expect(game.maxLives, entry.value);
        expect(game.lives, entry.value);
        final blocked = game.puzzle.arrows.firstWhere(
          (a) => game.puzzle.blockers(a, {}).isNotEmpty,
        );
        for (var i = 0; i < entry.value; i++) {
          expect(game.attempt(blocked.id), MoveResult.blocked);
          expect(game.lives, entry.value - i - 1);
        }
        expect(game.status, GameStatus.lost);
        expect(game.attempt(blocked.id), MoveResult.ignored);
        expect(game.lives, 0);
        final restored = GameController(levels)..restore(game.snapshot());
        expect(restored.status, GameStatus.lost);
        expect(restored.lives, 0);
        restored.reset();
        expect(restored.lives, entry.value);
        game.dispose();
        restored.dispose();
      },
    );
  }
  test('Upgrade caps old hearts, preserves spent hearts, coins and routes', () {
    for (final index in [15, 45, 60]) {
      final game = unlocked()..reset(index);
      game.rewards.coins = 150;
      final arrow = game.puzzle.available({}).first;
      game.attempt(arrow.id);
      game.finish(arrow.id, game.epoch);
      final save = game.snapshot()..['lives'] = 3;
      final restored = GameController(levels)..restore(save);
      expect(restored.lives, game.maxLives);
      expect(restored.removed, {arrow.id});
      expect(restored.rewards.coins, 150);
      save['lives'] = 1;
      restored.restore(save);
      expect(restored.lives, 1);
      game.dispose();
      restored.dispose();
    }
  });
  test(
    'Advancing across both thresholds and replaying an easy level uses its own limit',
    () {
      final game = unlocked();
      for (final index in [14, 44]) {
        game.reset(index);
        while (game.status == GameStatus.playing) {
          for (final id in game.puzzle.solve()!) {
            game.attempt(id);
            game.finish(id, game.epoch);
          }
        }
        expect(game.skip(), true);
        expect(game.lives, index == 14 ? 2 : 1);
      }
      game.reset(0);
      expect(game.lives, 3);
      game.dispose();
    },
  );
}
