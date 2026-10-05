import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/main.dart';
import 'package:path_out/puzzle.dart';
import 'package:path_out/rewards.dart';
import 'package:path_out/story.dart';
import 'package:path_out/story_screen.dart';
import 'package:path_out/arrow_geometry.dart';

void clearPhase(GameController game) {
  for (final id in game.puzzle.solve(game.removed)!) {
    expect(game.attempt(id), MoveResult.moving);
    expect(game.finish(id, game.epoch), true);
  }
}

void clearStage(GameController game) {
  while (game.status == GameStatus.playing) {
    clearPhase(game);
    if (game.bossPhase == 1 && game.pendingScenes.contains('keeper')) {
      game.markSceneSeen('keeper');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());
  final legacy = Puzzle.decode(
    File('assets/legacy-chapter-one.json').readAsStringSync(),
  );
  setUpAll(() async {
    final file = File('.dart_tool/package_config.json');
    final packages = jsonDecode(file.readAsStringSync())['packages'] as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter');
    final sdk = Directory.fromUri(
      file.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    for (final font in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(
            File(
              '${sdk.path}/bin/cache/artifacts/material_fonts/${font.value}',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });

  test(
    'First ten shaped boards and both boss phases have full coverage and solutions',
    () {
      for (final p in levels.take(15)) {
        p.validate();
      }
      expect(levels[14].secondPhase, isNotNull);
      expect(levels[14].secondPhase!.solve(), isNotNull);
      expect(
        levels.take(15).map((p) => p.mask.toString()).toSet().length,
        greaterThanOrEqualTo(9),
      );
      expect(levels.take(5).every((p) => p.arrows.length <= 25), true);
    },
  );

  test(
    '70 first clear, 30 replay, unpaid bonus differences and separate faster best',
    () {
      var now = 0;
      final r = RunRewards(now: () => now)..resume();
      for (var i = 0; i < 10; i++) {
        r.greatMove();
      }
      now = 44000;
      r.complete(0, firstClear: true);
      expect(r.lastTotal, 100);
      expect(r.skill, 20);
      r.reset();
      r.resume();
      now += 50000;
      for (var i = 0; i < 5; i++) {
        r.greatMove();
      }
      r.complete(0, firstClear: false);
      expect(r.lastTotal, 30);
      expect(r.lastSpeed, 0);
      expect(r.lastSkill, 0);
      r.reset();
      r.resume();
      now += 43000;
      r.complete(0, firstClear: false);
      expect(r.lastTotal, 35);
      expect(r.lastRecord, 5);
      r.reset();
      r.resume();
      now += 43000;
      r.complete(0, firstClear: false);
      expect(r.lastTotal, 30);
      expect(r.lastRecord, 0);
      expect(RunRewards.decode(r.snapshot(), 41).coins, r.coins);
    },
  );

  test(
    'Slow first chapter funds 600 unlock; two hints recover with two free replays',
    () {
      var now = 0;
      final game = GameController(levels, now: () => now);
      for (var i = 0; i < 15; i++) {
        expect(game.reset(i), true);
        game.resumeTiming();
        now += 180000;
        clearStage(game);
      }
      expect(game.rewards.coins, greaterThanOrEqualTo(700));
      expect(game.isUnlocked(15), false);
      expect(game.inventory.arrows, contains('lantern'));
      game.rewards.coins = 700;
      expect(game.buyHint(), true);
      expect(game.buyHint(), true);
      expect(game.rewards.coins, 540);
      expect(game.buyCompanion(1), false);
      for (var i = 0; i < 2; i++) {
        game.reset(0);
        game.resumeTiming();
        now += 240000;
        clearStage(game);
        expect(game.rewards.lastBase, 30);
        expect(game.rewards.lastSpeed, 0);
      }
      expect(game.rewards.coins, 600);
      expect(game.buyCompanion(1), true);
      expect(game.rewards.coins, 0);
      expect(game.isUnlocked(15), true);
      expect(game.reset(15), true);
      expect(game.isUnlocked(16), false);
      expect(game.buyCompanion(1), false);
      game.dispose();
    },
  );

  test(
    'Money, story viewing and ownership alone cannot bypass boss progression',
    () {
      final game = GameController(levels)..rewards.coins = 9999;
      expect(game.buyCompanion(1), false);
      game.seenScenes.addAll(miraScenes.map((s) => s.id));
      expect(game.isUnlocked(15), false);
      game.inventory.companions.add(1);
      expect(game.reset(15), false);
      expect(game.buyArrowSkin('lantern'), false);
      expect(game.rewards.coins, 9999);
      game.dispose();
    },
  );

  test(
    'Boss checkpoint persists without paying early; retry retains elapsed time',
    () {
      var now = 0;
      final game = GameController(levels, now: () => now)
        ..completed.addAll(List.generate(14, (i) => i))
        ..reset(14);
      game.resumeTiming();
      now = 50000;
      clearPhase(game);
      expect(game.bossPhase, 1);
      expect(game.lives, 3);
      expect(game.completed, isNot(contains(14)));
      expect(game.rewards.coins, 0);
      final id = game.puzzle.available({}).first.id;
      game.attempt(id);
      game.finish(id, game.epoch);
      game.pauseTiming();
      final restored = GameController(levels, now: () => now)
        ..restore(game.snapshot());
      expect(restored.bossPhase, 1);
      expect(restored.removed, {id});
      final blocker = restored.puzzle.arrows.firstWhere(
        (a) =>
            !restored.removed.contains(a.id) &&
            restored.puzzle.blockers(a, restored.removed).isNotEmpty,
      );
      for (var i = 0; i < 3; i++) {
        restored.attempt(blocker.id);
      }
      expect(restored.status, GameStatus.lost);
      expect(restored.retryCheckpoint(), true);
      expect(restored.bossPhase, 1);
      expect(restored.removed, isEmpty);
      expect(restored.rewards.elapsed, 50000);
      restored.resumeTiming();
      now += 50000;
      clearStage(restored);
      expect(restored.completed, contains(14));
      expect(restored.rewards.lastBase, 70);
      final coins = restored.rewards.coins;
      expect(restored.retryCheckpoint(), false);
      expect(restored.rewards.coins, coins);
      expect(restored.inventory.arrows, contains('lantern'));
      game.dispose();
      restored.dispose();
    },
  );

  test(
    'Old partial geometry and reached chapter entitlements survive migration',
    () {
      final old = GameController([...legacy, ...levels.skip(15)]);
      final id = old.puzzle.available({}).first.id;
      old.attempt(id);
      old.finish(id, old.epoch);
      old.rewards.coins = 321;
      final data = old.snapshot()
        ..remove('storyVersion')
        ..remove('campaignVersion');
      final restored = GameController(levels, legacyLevels: legacy)
        ..restore(data);
      expect(restored.puzzle.mask, legacy.first.mask);
      expect(restored.removed, {id});
      expect(restored.rewards.coins, 321);
      final twice = GameController(levels, legacyLevels: legacy)
        ..restore(restored.snapshot());
      expect(twice.puzzle.mask, legacy.first.mask);
      restored.reset();
      expect(restored.puzzle.mask, levels.first.mask);
      data['index'] = 10;
      data['removed'] = <int>[];
      data['completed'] = List.generate(10, (i) => i);
      restored.restore(data);
      expect(restored.isUnlocked(15), true);
      expect(restored.inventory.companions, contains(1));
      expect(restored.inventory.companions, isNot(contains(2)));
      expect(restored.inventory.arrows, contains('lantern'));
      old.dispose();
      restored.dispose();
      twice.dispose();
    },
  );

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('work/flutter-previews').createSync(recursive: true);
      File(
        'work/flutter-previews/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      img.dispose();
    });
  }

  testWidgets(
    'Opening pauses timer; skip is saved; journal is available and total hidden',
    (tester) async {
      final game = GameController(levels);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: PathOutApp(game: game),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(miraStoryAsset),
          tester.element(find.byType(Scaffold).first),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StoryScreen), findsOneWidget);
      expect(game.rewards.running, false);
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/companions/char01.png'),
          tester.element(find.byType(StoryScreen)),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, 'mira-opening');
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(game.seenScenes, contains('arrival'));
      expect(game.rewards.running, true);
      expect(find.textContaining('/ 40'), findsNothing);
      await capture(tester, key, 'mira-lantern-board');
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Story journal'));
      await tester.pumpAndSettle();
      expect(find.text('An undiscovered memory'), findsNWidgets(7));
      expect(game.rewards.running, false);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets(
    'Boss ending grants keepsake, plays scene and purchases next chapter once',
    (tester) async {
      final game = GameController(levels)
        ..completed.addAll(List.generate(14, (i) => i))
        ..reset(14);
      clearStage(game);
      game.rewards.coins = 650;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: PathOutApp(game: game),
        ),
      );
      expect(game.inventory.arrows, contains('lantern'));
      await tester.runAsync(
        () => Future.wait([
          for (final panels in chapterPanels)
            precacheImage(
              AssetImage(panels.first.asset),
              tester.element(find.byType(Scaffold).first),
            ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StoryScreen), findsOneWidget);
      await capture(tester, key, 'mira-festival');
      for (var i = 0; i < miraScenes.last.panels.length; i++) {
        await tester.ensureVisible(find.byKey(const Key('story-next')));
        await tester.tap(find.byKey(const Key('story-next')));
        await tester.pumpAndSettle();
      }
      expect(game.seenScenes, contains('festival'));
      expect(find.text('Chapter complete!'), findsOneWidget);
      await capture(tester, key, 'mira-chapter-complete');
      await tester.tap(find.byKey(const Key('result-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Beyond the garden'), findsOneWidget);
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/companions/char02.png'),
          tester.element(find.text('Beyond the garden')),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, 'mira-next-chapter');
      await tester.ensureVisible(find.byKey(const Key('unlock-chapter')));
      await tester.tap(find.byKey(const Key('unlock-chapter')));
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/story/elyra-panels.png'),
          tester.element(find.byType(Scaffold).first),
        ),
      );
      await tester.pumpAndSettle();
      expect(game.index, 15);
      expect(game.rewards.coins, 50);
      expect(game.inventory.companions, contains(1));
      expect(find.byType(StoryScreen), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(game.seenScenes, contains('elyra.arrival'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets(
    'Final animated arrow opens checkpoint scene; loss retries inner seal',
    (tester) async {
      final game = GameController(levels)
        ..completed.addAll(List.generate(14, (i) => i))
        ..reset(14);
      final route = game.puzzle.solve()!;
      for (final id in route.take(route.length - 1)) {
        game.attempt(id);
        game.finish(id, game.epoch);
      }
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: PathOutApp(game: game),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(const Key('maze-board')));
      final point = cellPoint(
        game.puzzle.arrows.firstWhere((a) => a.id == route.last).head,
      );
      final bounds = boardSize(game.puzzle);
      await tester.tapAt(
        rect.topLeft +
            Offset(
              point.dx / bounds.width * rect.width,
              point.dy / bounds.height * rect.height,
            ),
      );
      await tester.pumpAndSettle();
      expect(game.bossPhase, 1);
      expect(game.status, GameStatus.playing);
      expect(game.rewards.coins, 0);
      expect(game.rewards.running, false);
      expect(find.text('The glass gives way'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(game.rewards.running, true);
      await capture(tester, key, 'mira-boss-inner-seal');
      final blocker = game.puzzle.arrows.firstWhere(
        (a) => game.puzzle.blockers(a, {}).isNotEmpty,
      );
      for (var i = 0; i < 3; i++) {
        game.attempt(blocker.id);
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry from checkpoint'));
      await tester.tap(find.text('Retry from checkpoint'));
      await tester.pumpAndSettle();
      expect(game.bossPhase, 1);
      expect(game.lives, 3);
      expect(game.removed, isEmpty);
      expect(game.rewards.coins, 0);
      expect(game.rewards.running, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets('Discovery pauses gameplay and advances without awarding twice', (
    tester,
  ) async {
    final game = GameController(levels)
      ..completed.addAll(List.generate(6, (i) => i))
      ..reset(6);
    clearStage(game);
    final coins = game.rewards.coins;
    await tester.pumpWidget(PathOutApp(game: game));
    await tester.pumpAndSettle();
    expect(find.text('A message in the garden'), findsOneWidget);
    expect(game.rewards.running, false);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('result-continue')));
    await tester.tap(find.byKey(const Key('result-continue')));
    await tester.pumpAndSettle();
    expect(game.index, 7);
    expect(game.seenScenes, contains('message'));
    expect(game.rewards.coins, coins);
    expect(game.rewards.running, true);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });

  testWidgets('Short balance offers offline recovery without debit', (
    tester,
  ) async {
    final game = GameController(levels)
      ..completed.addAll(List.generate(14, (i) => i))
      ..reset(14);
    clearStage(game);
    game.rewards.coins = 540;
    game.seenScenes.add('festival');
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PathOutApp(game: game));
    await tester.pumpAndSettle();
    expect(find.text(miraScenes.last.title), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue journey'));
    await tester.tap(find.text('Continue journey'));
    await tester.pumpAndSettle();
    expect(find.textContaining('60 more needed'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('unlock-chapter')))
          .onPressed,
      isNull,
    );
    final replay = find.text('Replay levels · earn 30 coins per clear');
    await tester.ensureVisible(replay);
    await tester.pumpAndSettle();
    await tester.tap(replay);
    await tester.pumpAndSettle();
    expect(find.text('Your journey'), findsOneWidget);
    await tester.tap(find.text('01'));
    await tester.pumpAndSettle();
    expect(game.index, 0);
    expect(game.rewards.coins, 540);
    expect(game.isUnlocked(15), false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });

  test(
    'Illustrations follow the full story and unlock with matching progress',
    () {
      expect(
        miraScenes.expand((scene) => scene.panels),
        List.generate(20, (i) => i),
      );
      expect(storyAvailable('path', {}, 0, 0), false);
      expect(storyAvailable('path', {0}, 1, 0), true);
      expect(storyAvailable('garden', {0}, 1, 0), false);
      expect(storyAvailable('garden', {4}, 5, 0), true);
      expect(storyAvailable('square', {4}, 5, 0), false);
      expect(storyAvailable('square', {9}, 10, 0), true);
      expect(storyAvailable('festival', {}, 14, 1), false);
      expect(storyAvailable('festival', {14}, 14, 1), true);
    },
  );

  testWidgets(
    'All supplied illustrations render from the atlas without changing captions',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF121A2C),
              body: GridView.count(
                crossAxisCount: 5,
                childAspectRatio: 240 / 180,
                children: [
                  for (final panel in miraPanels)
                    Column(
                      children: [
                        Expanded(child: StoryIllustration(panel: panel)),
                        Text(
                          '${panel.number}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(miraStoryAsset),
          tester.element(find.byType(Scaffold)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StoryIllustration), findsNWidgets(20));
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'mira-illustration-check');
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('Story readable and skippable on $size with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.4),
              disableAnimations: true,
            ),
            child: StoryScreen(scene: miraScenes.last),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('story-next')), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('story-next')));
      await tester.pumpAndSettle();
      expect(find.textContaining('The last knot came free'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
