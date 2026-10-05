import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_out/companions.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/puzzle.dart';

void main() {
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());

  testWidgets(
    'Streaks, halfway and last-heart reactions are contextual and reset',
    (tester) async {
      for (var id = 0; id < 4; id++) {
        final reactions = CompanionReactions()..selectCharacter(id);
        reactions.welcome(lives: 1);
        expect(
          companionDialogue[id][CompanionEvent.challenge],
          contains(reactions.line),
        );
        reactions.newPuzzle();
        for (var i = 0; i < 5; i++) {
          reactions.moved(0, remaining: 20);
        }
        expect(
          companionDialogue[id][CompanionEvent.streak],
          contains(reactions.line),
        );
        reactions.blocked(lives: 1);
        expect(
          companionDialogue[id][CompanionEvent.lastHeart],
          contains(reactions.line),
        );
        reactions.moved(0, remaining: 20);
        expect(
          companionDialogue[id][CompanionEvent.move],
          contains(reactions.line),
        );
        reactions.moved(0, remaining: 10, total: 20);
        expect(
          companionDialogue[id][CompanionEvent.halfway],
          contains(reactions.line),
        );
        reactions.moved(0, remaining: 9, total: 20);
        expect(
          companionDialogue[id][CompanionEvent.halfway],
          isNot(contains(reactions.line)),
        );
        reactions.newPuzzle();
        reactions.moved(0, remaining: 10, total: 20);
        expect(
          companionDialogue[id][CompanionEvent.halfway],
          contains(reactions.line),
        );
        reactions.dispose();
      }
    },
  );

  test(
    'All four voices have separate welcome and resting dialogue with no repeat cycle',
    () {
      final reactions = CompanionReactions();
      final welcomes = <String>{};
      final moves = <String>{};
      for (var id = 0; id < 4; id++) {
        reactions.selectCharacter(id);
        for (final event in CompanionEvent.values) {
          final lines = companionDialogue[id][event]!;
          final seen = <String>{};
          for (var i = 0; i < lines.length; i++) {
            seen.add(reactions.nextLine(event));
          }
          expect(seen.length, lines.length);
        }
        welcomes.add(reactions.nextLine(CompanionEvent.welcome));
        moves.add(reactions.nextLine(CompanionEvent.move));
        for (final line in companionDialogue[id][CompanionEvent.idle]!) {
          expect(line.toLowerCase(), isNot(contains('ready')));
          expect(
            companionDialogue[id][CompanionEvent.welcome],
            isNot(contains(line)),
          );
        }
      }
      expect(welcomes.length, 4);
      expect(moves.length, 4);
      reactions.dispose();
    },
  );

  test(
    'Comment categories do not repeat before exhaustion or across reshuffles',
    () {
      final reactions = CompanionReactions();
      for (final event in CompanionEvent.values) {
        final count = companionComments[event]!.length;
        String? previous;
        for (var cycle = 0; cycle < 3; cycle++) {
          final seen = <String>{};
          for (var i = 0; i < count; i++) {
            final line = reactions.nextLine(event);
            expect(line, isNot(previous));
            expect(seen.add(line), isTrue);
            previous = line;
          }
          expect(seen, companionComments[event]!.toSet());
        }
      }
      reactions.dispose();
    },
  );

  testWidgets(
    'New puzzles retain comment history; near-finish lines are contextual',
    (tester) async {
      final reactions = CompanionReactions();
      reactions.moved(0, remaining: 10);
      final first = reactions.line;
      reactions.newPuzzle();
      reactions.moved(0, remaining: 10);
      expect(reactions.line, isNot(first));
      reactions.moved(0, remaining: 3);
      expect(companionComments[CompanionEvent.close], contains(reactions.line));
      final win = reactions.stableLine(CompanionEvent.win);
      expect(reactions.stableLine(CompanionEvent.win), win);
      reactions.newPuzzle();
      expect(reactions.stableLine(CompanionEvent.win), isNot(win));
      reactions.dispose();
    },
  );

  test(
    'All companions and hidden preference survive a save without changing gameplay',
    () {
      for (var id = 0; id < 4; id++) {
        final game = GameController(levels);
        game.rewards.coins = 800;
        if (id != 0) game.completed.add(id * 15 - 1);
        if (id != 0) game.buyCompanion(id);
        final arrow = game.puzzle.available({}).first;
        game.attempt(arrow.id);
        game.finish(arrow.id, game.epoch);
        game.chooseCompanion(id);
        game.hideCompanion();
        final restored = GameController(levels)..restore(game.snapshot());
        expect(restored.companionId, id);
        expect(restored.companionVisible, isFalse);
        expect(restored.removed, {arrow.id});
        expect(restored.lives, 3);
        expect(restored.isUnlocked(1), isFalse);
        restored.chooseCompanion(id);
        expect(restored.companionVisible, isTrue);
        restored.reset();
        expect(restored.companionId, id);
        game.dispose();
        restored.dispose();
      }
    },
  );

  test('Legacy and malformed cosmetic settings preserve earned progress', () {
    final source = GameController(levels)
      ..completed.add(0)
      ..reset(1);
    final legacy = source.snapshot()
      ..remove('companionId')
      ..remove('companionVisible');
    final restored = GameController(levels)..restore(legacy);
    expect(restored.index, 1);
    expect(restored.companionId, 0);
    expect(restored.companionVisible, isTrue);
    restored.restore({
      ...legacy,
      'companionId': 99,
      'companionVisible': 'wrong',
    });
    expect(restored.completed, {0});
    expect(restored.companionId, 0);
    restored.chooseCompanion(-1);
    restored.chooseCompanion(4);
    expect(restored.companionId, 0);
    source.dispose();
    restored.dispose();
  });

  test(
    'Leaving during a flight invalidates old completion without losing a heart',
    () {
      final game = GameController(levels);
      final arrow = game.puzzle.available({}).first;
      game.attempt(arrow.id);
      final token = game.epoch;
      game.cancelFlight();
      expect(game.finish(arrow.id, token), isFalse);
      expect(game.removed, isEmpty);
      expect(game.busy, isFalse);
      expect(game.lives, 3);
      expect(game.attempt(arrow.id), MoveResult.moving);
      game.dispose();
    },
  );

  testWidgets(
    'Great move means multiple freed exits and praise is not repeated every tap',
    (tester) async {
      final reactions = CompanionReactions();
      reactions.moved(1);
      expect(reactions.line, 'Nice move!');
      reactions.moved(2);
      expect(companionComments[CompanionEvent.great], contains(reactions.line));
      reactions.moved(3);
      expect(companionComments[CompanionEvent.move], contains(reactions.line));
      expect(reactions.line, isNot('Nice move!'));
      await tester.pump(const Duration(seconds: 3));
      expect(reactions.mood, CompanionMood.idle);
      reactions.react(CompanionMood.thinking, 'Hint');
      await tester.pump(const Duration(seconds: 4));
      expect(reactions.mood, CompanionMood.idle);
      expect(reactions.line, isNull);
      reactions.moved(4);
      reactions.newPuzzle();
      expect(reactions.mood, CompanionMood.idle);
      reactions.dispose();
    },
  );

  testWidgets('Picker fits small phones with large accessibility text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCompanionPicker(context, 0, true),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('hide-companion')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
