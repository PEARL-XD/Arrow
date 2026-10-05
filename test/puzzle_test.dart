import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_out/puzzle.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/arrow_geometry.dart';
import 'package:path_out/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());
  test('60 story boards plus the bonus boss; gentle opening puzzles', () {
    expect(levels.length, 61);
    expect(levels.map((p) => p.name).toSet().length, 61);
    expect(levels.where((p) => p.isBoss).length, 5);
    expect(levels.last.isBoss, isTrue);
    expect(levels.take(8).every((p) => p.difficulty == 'Beginner'), isTrue);
    expect(levels.take(5).every((p) => p.arrows.length <= 25), isTrue);
  });
  test(
    'Archived campaign calibration and approved geometry remain recoverable',
    () {
      final metrics =
          jsonDecode(File('docs/level-metrics.json').readAsStringSync())
              as List;
      for (var i = 1; i < metrics.length; i++) {
        expect(
          metrics[i]['challenge'] as num,
          greaterThan(metrics[i - 1]['challenge'] as num),
        );
      }
      final originals = Puzzle.decode(
        File('tools/approved-boards.json').readAsStringSync(),
      );
      for (final original in originals) {
        final current = [
          ...levels,
          ...Puzzle.decode(
            File('assets/legacy-campaign-v08.json').readAsStringSync(),
          ),
          ...Puzzle.decode(
            File('assets/legacy-chapter-one.json').readAsStringSync(),
          ),
        ].firstWhere((p) => p.name == original.name);
        expect(current.mask, original.mask);
        expect(current.arrows.length, original.arrows.length);
        for (var i = 0; i < current.arrows.length; i++) {
          expect(current.arrows[i].cells, original.arrows[i].cells);
          expect(current.arrows[i].direction, original.arrows[i].direction);
        }
      }
    },
  );
  for (var i = 0; i < levels.length; i++) {
    final puzzle = levels[i];
    test('Level ${i + 1}: full coverage, no overlaps, heads aligned, solvable', () {
      puzzle.validate();
      expect(puzzle.arrows.map((a) => a.direction).toSet().length, 4);
      // Test this board in isolation; the two-stage controller has separate tests.
      final game = GameController([
        Puzzle(
          name: puzzle.name,
          difficulty: puzzle.difficulty,
          width: puzzle.width,
          height: puzzle.height,
          mask: puzzle.mask,
          arrows: puzzle.arrows,
        ),
      ]);
      final solution = puzzle.solve()!;
      expect(game.removed, isEmpty);
      for (final id in solution) {
        final arrow = puzzle.arrows.firstWhere((a) => a.id == id);
        expect(game.attempt(id), MoveResult.moving);
        expect(game.attempt(id), MoveResult.ignored);
        final occupied = puzzle.occupancy(game.removed)
          ..removeWhere((_, owner) => owner == id);
        // Sample the entire journey, including every bend and every forward cell.
        for (
          var distance = 0.0;
          distance <= exitDistance(puzzle, arrow);
          distance += .5
        ) {
          final points = movingPoints(arrow, distance);
          final length = List.generate(
            points.length - 1,
            (j) => (points[j + 1] - points[j]).distance,
          ).fold<double>(0, (sum, d) => sum + d);
          expect(
            length,
            closeTo(math.max(.45, arrow.cells.length - 1.0), .00001),
          );
          final head = points.last - cellPoint(arrow.head);
          expect(head.dx, closeTo(arrow.delta.x * distance, .00001));
          expect(head.dy, closeTo(arrow.delta.y * distance, .00001));
          for (var j = 1; j < points.length; j++) {
            final a = points[j - 1], b = points[j];
            // Unit lattice is orthogonal: all possible body collisions are cells.
            for (var k = 0; k <= (b - a).distance.ceil(); k++) {
              final step = math.min(k.toDouble(), (b - a).distance);
              final p = (b - a).distance == 0
                  ? a
                  : a + (b - a) / (b - a).distance * step;
              final x = p.dx - boardPadding, y = p.dy - boardPadding;
              if ((x - x.round()).abs() < .00001 &&
                  (y - y.round()).abs() < .00001) {
                expect(
                  occupied.containsKey((x: x.round(), y: y.round())),
                  isFalse,
                );
              }
            }
          }
        }
        expect(game.finish(id, game.epoch), isTrue);
      }
      expect(game.status, GameStatus.won);
      expect(game.completed, contains(0));
      game.dispose();
    });
  }
  test('A distant arrow across empty space blocks the forward ray', () {
    final arrow = ArrowRoute(
      id: 0,
      cells: [(x: 0, y: 0), (x: 1, y: 0)],
      direction: 0,
    );
    final p = Puzzle(
      name: 'Gap',
      difficulty: 'test',
      width: 6,
      height: 2,
      mask: [(x: 0, y: 0), (x: 1, y: 0), (x: 5, y: 0), (x: 5, y: 1)],
      arrows: [
        arrow,
        ArrowRoute(id: 1, cells: [(x: 5, y: 1), (x: 5, y: 0)], direction: 3),
      ],
    );
    expect(p.blockers(arrow, {}), {1});
    expect(p.blockers(arrow, {1}), isEmpty);
    p.validate();
  });
  test('Lives, hints, reset, skip, stale callbacks and progress restore', () {
    final game = GameController(levels);
    final blocked = game.puzzle.arrows.firstWhere(
      (a) => game.puzzle.blockers(a, {}).isNotEmpty,
    );
    for (var i = 0; i < 3; i++) {
      expect(game.attempt(blocked.id), MoveResult.blocked);
    }
    expect(game.status, GameStatus.lost);
    expect(game.hint(), isNull);
    game.reset();
    for (var i = 0; i < 3; i++) {
      expect(game.hint(), isNotNull);
    }
    expect(game.hint(), isNull);
    final id = game.puzzle.available({}).first.id, token = game.epoch;
    expect(game.attempt(id), MoveResult.moving);
    final inFlight = game.snapshot();
    expect(inFlight['removed'], isEmpty);
    expect(game.skip(), isFalse);
    game.reset();
    expect(game.finish(id, token), isFalse);
    expect(game.remaining, game.puzzle.arrows.length);
    final move = game.puzzle.available({}).first.id;
    game.attempt(move);
    game.finish(move, game.epoch);
    final restored = GameController(levels)..restore(game.snapshot());
    expect(restored.snapshot(), game.snapshot());
    restored.restore({'version': 1, 'index': 999});
    expect(restored.snapshot(), game.snapshot());
    expect(game.reset(levels.length - 1), isFalse);
    expect(game.skip(), isFalse);
    expect(game.index, 0);
    game.dispose();
    restored.dispose();
  });
  test(
    'Serialized saves restore latest progress and tolerate invalid JSON',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = ProgressStore(await SharedPreferences.getInstance());
      final game = GameController(levels);
      final first = store.save(game);
      game.completed.add(0);
      game.skip();
      await store.save(game);
      await first;
      final restored = GameController(levels);
      store.restore(restored);
      expect(restored.index, 1);
      await store.preferences.setString(ProgressStore.key, 'invalid json');
      store.restore(restored);
      expect(restored.index, 1);
      game.dispose();
      restored.dispose();
      store.saveFailed.dispose();
    },
  );
}
