import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_out/puzzle.dart';
import 'package:path_out/game_controller.dart';

void clear(GameController game) {
  while (game.status == GameStatus.playing) {
    for (final id in game.puzzle.solve(game.removed)!) {
      expect(game.attempt(id), MoveResult.moving);
      expect(game.finish(id, game.epoch), isTrue);
    }
  }
}

void main() {
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());
  final previous = Puzzle.decode(
    File('assets/legacy-campaign-v08.json').readAsStringSync(),
  );
  test('Fresh install cannot select or skip any locked level', () {
    final game = GameController(levels);
    expect(game.frontier, 0);
    final before = game.snapshot();
    for (var i = 1; i < levels.length; i++) {
      expect(game.isUnlocked(i), isFalse);
      expect(game.reset(i), isFalse);
      expect(game.snapshot(), before);
    }
    expect(game.skip(), isFalse);
    expect(game.reset(-1), isFalse);
    expect(game.reset(levels.length), isFalse);
    expect(game.snapshot(), before);
    game.dispose();
  });
  test(
    'Winning once unlocks exactly one successor and replay never relocks it',
    () {
      final game = GameController(levels);
      final order = game.puzzle.solve()!;
      for (final id in order.take(order.length - 1)) {
        game.attempt(id);
        game.finish(id, game.epoch);
      }
      expect(game.isUnlocked(1), isFalse);
      game.attempt(order.last);
      expect(game.isUnlocked(1), isFalse);
      game.finish(order.last, game.epoch);
      expect(game.isUnlocked(1), isTrue);
      expect(game.isUnlocked(2), isFalse);
      game.reset();
      expect(game.completed, contains(0));
      expect(game.isUnlocked(1), isTrue);
      expect(game.skip(), isTrue);
      expect(game.index, 1);
      expect(game.skip(), isFalse);
      game.dispose();
    },
  );
  test(
    'Complete campaign unlocks boss; boss victory persists without wrapping',
    () {
      final game = GameController(levels);
      for (var i = 0; i < 60; i++) {
        expect(game.index, i);
        expect(game.isUnlocked(60), isFalse);
        clear(game);
        if (i == 14 || i == 29 || i == 44) {
          expect(game.isUnlocked(i + 1), isFalse);
          expect(game.buyCompanion((i + 1) ~/ 15), isTrue);
        }
        expect(game.skip(), isTrue);
      }
      expect(game.index, 60);
      expect(game.isBoss, isTrue);
      expect(game.status, GameStatus.playing);
      expect(game.regularCompleted, 60);
      clear(game);
      expect(game.status, GameStatus.won);
      expect(game.canAdvance, isFalse);
      expect(game.skip(), isFalse);
      expect(game.index, 60);
      final restored = GameController(levels)..restore(game.snapshot());
      expect(restored.index, 60);
      expect(restored.status, GameStatus.won);
      expect(restored.completed.length, 61);
      expect(restored.reset(0), isTrue);
      expect(restored.isUnlocked(60), isTrue);
      game.dispose();
      restored.dispose();
    },
  );
  test(
    'Old unrestricted saves retain wins but skipped selections do not unlock levels',
    () {
      final game = GameController(levels);
      final old = {
        'version': 1,
        'index': 39,
        'lives': 2,
        'hints': 1,
        'removed': [0],
        'completed': [0, 1, 12, 39],
        'haptics': false,
      };
      game.restore(old);
      expect(game.index, 3);
      expect(game.frontier, 3);
      expect(game.completed, {0, 1, 2, 18, 59});
      expect(game.isUnlocked(60), isFalse);
      expect(game.removed, isEmpty);
      expect(game.lives, 3);
      expect(game.haptics, isFalse);
      final restored = GameController(levels)..restore(game.snapshot());
      expect(restored.snapshot(), game.snapshot());
      game.dispose();
      restored.dispose();
    },
  );
  test(
    'Existing valid in-progress and all-40-completed saves survive upgrade',
    () {
      final game = GameController(levels);
      game.restore({
        'version': 1,
        'index': 1,
        'lives': 2,
        'hints': 1,
        'removed': [0],
        'completed': [0],
        'haptics': true,
      });
      expect(game.index, 1);
      expect(game.removed, {0});
      expect(game.lives, 2);
      game.restore({
        'version': 1,
        'index': 39,
        'lives': 2,
        'hints': 1,
        'removed': previous[39].arrows.map((a) => a.id).toList(),
        'completed': List.generate(40, (i) => i),
        'haptics': true,
      });
      expect(game.status, GameStatus.won);
      expect(game.isUnlocked(60), isTrue);
      expect(game.skip(), isTrue);
      expect(game.isBoss, isTrue);
      game.dispose();
    },
  );
}
