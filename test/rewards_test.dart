import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_out/rewards.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/puzzle.dart';

void main() {
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());
  void clear(GameController game) {
    for (final id in game.puzzle.solve(game.removed)!) {
      game.attempt(id);
      game.finish(id, game.epoch);
    }
  }

  test('Exact speed thresholds: strictly under 45 and 60 seconds', () {
    for (final entry in {
      0: 10,
      44999: 10,
      45000: 5,
      59999: 5,
      60000: 0,
      240000: 0,
    }.entries) {
      expect(speedBonus(entry.key), entry.value);
    }
  });
  test(
    'Slow clears still record time and pay base; fast replays pay only improvements',
    () {
      var now = 0;
      final game = GameController(levels, now: () => now);
      game.resumeTiming();
      now = 65000;
      clear(game);
      expect(game.rewards.lastSpeed, 0);
      expect(game.rewards.lastBase, 70);
      expect(game.rewards.bestTimes[0], 65000);
      final firstCoins = game.rewards.coins;
      game.reset();
      game.resumeTiming();
      now += 50000;
      clear(game);
      expect(game.rewards.lastBase, 30);
      expect(game.rewards.lastSpeed, 5);
      expect(game.rewards.coins, firstCoins + 40);
      game.reset();
      game.resumeTiming();
      now += 44999;
      clear(game);
      expect(game.rewards.lastSpeed, 5);
      expect(game.rewards.bestTimes[0], 44999);
      final coins = game.rewards.coins;
      game.reset();
      game.resumeTiming();
      now += 20000;
      clear(game);
      expect(game.rewards.lastSpeed, 0);
      expect(game.rewards.coins, coins + 35);
      expect(game.rewards.bestTimes[0], 20000);
      expect(game.rewards.lastTimes[0], 20000);
      expect(game.rewards.skill, lessThanOrEqualTo(20));
      game.dispose();
    },
  );
  test(
    'Paused time, background and restored sessions do not earn a fresh timer',
    () {
      var now = 0;
      final game = GameController(levels, now: () => now);
      game.resumeTiming();
      now = 30000;
      game.pauseTiming();
      now = 500000;
      expect(game.rewards.elapsed, 30000);
      final restored = GameController(levels, now: () => now)
        ..restore(game.snapshot());
      now += 50000;
      expect(restored.rewards.elapsed, 30000);
      restored.resumeTiming();
      now += 15000;
      clear(restored);
      expect(restored.rewards.elapsed, 45000);
      expect(restored.rewards.lastSpeed, 5);
      final again = GameController(levels)..restore(restored.snapshot());
      expect(again.rewards.coins, restored.rewards.coins);
      expect(again.rewards.bestTimes[0], 45000);
      expect(again.status, GameStatus.won);
      game.dispose();
      restored.dispose();
      again.dispose();
    },
  );
  test(
    'Hints are persistent inventory; purchases are atomic and cannot overdraw',
    () {
      final game = GameController(levels);
      game.hint();
      game.reset();
      expect(game.hints, 2);
      clear(game);
      game.skip();
      expect(game.hints, 2);
      game.rewards.coins = 79;
      final coins = game.rewards.coins;
      expect(game.buyHint(), isFalse);
      expect(game.rewards.coins, coins);
      game.rewards.coins = 160;
      expect(game.buyHint(), isTrue);
      expect(game.hints, 3);
      expect(game.buyHint(), isTrue);
      expect(game.rewards.coins, 0);
      expect(game.buyHint(), isFalse);
      expect(game.hints, 4);
      final restored = GameController(levels)..restore(game.snapshot());
      expect(restored.hints, 4);
      expect(restored.rewards.coins, 0);
      game.dispose();
      restored.dispose();
    },
  );
  test('Legacy partial attempts cannot claim a zero-second speed reward', () {
    final game = GameController(levels);
    final id = game.puzzle.available({}).first.id;
    game.attempt(id);
    game.finish(id, game.epoch);
    final oldSave = game.snapshot()..remove('rewards');
    final restored = GameController(levels)..restore(oldSave);
    clear(restored);
    expect(restored.rewards.eligible, isFalse);
    expect(restored.rewards.lastSpeed, 0);
    expect(restored.rewards.bestTimes, isEmpty);
    restored.reset();
    expect(restored.rewards.eligible, isTrue);
    game.dispose();
    restored.dispose();
  });
  test(
    'Restart discards unbanked move rewards; stale callbacks cannot pay twice',
    () {
      final game = GameController(levels);
      game.rewards.greatMove();
      expect(game.rewards.coins, 0);
      game.reset();
      expect(game.rewards.skill, 0);
      final id = game.puzzle.available({}).first.id;
      game.attempt(id);
      final token = game.epoch;
      game.reset();
      expect(game.finish(id, token), isFalse);
      expect(game.rewards.coins, 0);
      clear(game);
      final coins = game.rewards.coins;
      expect(game.finish(id, game.epoch), isFalse);
      expect(game.rewards.coins, coins);
      game.dispose();
    },
  );
}
