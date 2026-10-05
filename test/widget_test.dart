import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_out/main.dart';
import 'package:path_out/puzzle.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/arrow_geometry.dart';
import 'package:path_out/companions.dart';
import 'package:path_out/story.dart';
import 'package:path_out/story_screen.dart';

Future<void> settleGameplay(WidgetTester tester) async {
  await tester.pumpAndSettle();
  // Story playback has dedicated tests. Acknowledge automatic scenes here
  // before asserting gameplay, result cards, or shop interactions.
  while (find.byType(StoryScreen).evaluate().isNotEmpty) {
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the SDK's own fonts in rendered tests, not Flutter's blocky Ahem font.
    final configFile = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(configFile.readAsStringSync())['packages'] as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter');
    final sdk = Directory.fromUri(
      configFile.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final fontDir = '${sdk.path}/bin/cache/artifacts/material_fonts';
    for (final font in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(font.key)
        ..addFont(
          File(
            '$fontDir/${font.value}',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await loader.load();
    }
  });
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());
  Future<void> mount(
    WidgetTester tester,
    GameController game, {
    Size size = const Size(390, 844),
    GlobalKey? capture,
  }) async {
    // Gameplay-only tests bypass the opening, which has its own story tests.
    game.seenScenes.addAll(allStoryScenes.map((scene) => scene.id));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: PathOutApp(game: game),
      ),
    );
    await tester.pump();
    // Image decoding uses real async work; wait before visual captures.
    await tester.runAsync(
      () => Future.wait([
        precacheImage(
          const AssetImage(miraStoryAsset),
          tester.element(find.byType(Scaffold).first),
        ),
        for (final panels in chapterPanels.skip(1))
          precacheImage(
            AssetImage(panels.first.asset),
            tester.element(find.byType(Scaffold).first),
          ),
        for (var i = 1; i <= 4; i++)
          precacheImage(
            AssetImage('assets/companions/char0$i.png'),
            tester.element(find.byType(Scaffold).first),
          ),
      ]),
    );
    await settleGameplay(tester);
  }

  Future<void> tapArrow(
    WidgetTester tester,
    GameController game,
    int id,
  ) async {
    final finder = find.byKey(const Key('maze-board'));
    final rect = tester.getRect(finder), bounds = boardSize(game.puzzle);
    final arrow = game.puzzle.arrows.firstWhere((a) => a.id == id);
    final point = cellPoint(arrow.head);
    await tester.tapAt(
      rect.topLeft +
          Offset(
            point.dx / bounds.width * rect.width,
            point.dy / bounds.height * rect.height,
          ),
    );
    await tester.pump();
  }

  testWidgets(
    'Native touch moves snake, rejects blockers, restarts and skips',
    (tester) async {
      final game = GameController(levels);
      await mount(tester, game);
      final available = game.puzzle.available({}).first;
      final blocked = game.puzzle.arrows.firstWhere(
        (a) => game.puzzle.blockers(a, {}).isNotEmpty,
      );
      await tapArrow(tester, game, blocked.id);
      expect(game.lives, 2);
      await tester.pump(const Duration(seconds: 1));
      await tapArrow(tester, game, available.id);
      expect(game.busy, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.removed, isEmpty);
      await settleGameplay(tester);
      expect(game.removed, contains(available.id));
      await tester.ensureVisible(find.byTooltip('Restart'));
      await tester.tap(find.byTooltip('Restart'));
      await settleGameplay(tester);
      expect(game.removed, isEmpty);
      expect(game.lives, 3);
      await tester.ensureVisible(find.byTooltip('Hint · 3'));
      await tester.tap(find.byTooltip('Hint · 3'));
      await tester.pump();
      expect(game.hints, 2);
      expect(find.text('Next level'), findsNothing);
      await tester.tap(find.byTooltip('Levels'));
      await settleGameplay(tester);
      await tester.tap(find.text('02'));
      await settleGameplay(tester);
      await tester.tap(find.text('01'));
      await settleGameplay(tester);
      expect(game.index, 0);
      expect(game.hints, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );
  testWidgets(
    'Level picker, help and zoom work without corrupting game state',
    (tester) async {
      final game = GameController(levels);
      await mount(tester, game);
      await tester.tap(find.byTooltip('Zoom in'));
      await settleGameplay(tester);
      expect(find.text('1.5×'), findsOneWidget);
      await tester.tap(find.byTooltip('Fit board'));
      await settleGameplay(tester);
      expect(find.text('1.0×'), findsOneWidget);
      await tester.tap(find.byTooltip('More options'));
      await settleGameplay(tester);
      await tester.tap(find.text('How to play'));
      await settleGameplay(tester);
      expect(find.text('Untangle the way out'), findsOneWidget);
      await tester.tap(find.text('Let’s play'));
      await settleGameplay(tester);
      final picker = find.byTooltip('Levels');
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await settleGameplay(tester);
      expect(find.text('Your journey'), findsOneWidget);
      await tester.tap(find.text('03'));
      await settleGameplay(tester);
      expect(game.index, 0);
      expect(find.text('Your journey'), findsOneWidget);
      await tester.tap(find.text('01'));
      await settleGameplay(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );
  testWidgets('Restart cancels a flight before its old completion', (
    tester,
  ) async {
    final game = GameController(levels);
    game.completed.add(0);
    await mount(tester, game);
    await tapArrow(tester, game, game.puzzle.available({}).first.id);
    await tester.ensureVisible(find.byTooltip('Restart'));
    await tester.tap(find.byTooltip('Restart'));
    await settleGameplay(tester);
    expect(game.index, 0);
    expect(game.removed, isEmpty);
    expect(game.busy, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });
  testWidgets(
    'Compact layout starts at the top, enlarges maze and keeps dock clear',
    (tester) async {
      final game = GameController(levels);
      await mount(tester, game);
      final board = tester.getRect(find.byKey(const Key('maze-board')));
      final dock = tester.getRect(find.byKey(const Key('bottom-controls')));
      expect(tester.getRect(find.text('A Little Light')).top, lessThan(40));
      expect(board.top, lessThan(112));
      expect(board.width, greaterThan(365));
      expect(dock.top, greaterThan(board.bottom));
      expect(dock.bottom, lessThan(844));
      expect(find.text('Path Out'), findsNothing);
      expect(find.text('Next level'), findsNothing);
      expect(find.text('Cheerful companion'), findsNothing);
      for (final tooltip in [
        'Restart',
        'Hint · 3',
        'Companions',
        'Shop',
        'Levels',
      ]) {
        final rect = tester.getRect(find.byTooltip(tooltip));
        expect(
          rect.top,
          greaterThan(
            tester.getRect(find.byKey(const Key('companion-strip'))).bottom,
          ),
        );
        expect(rect.top, dock.top);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );
  testWidgets(
    'Welcome fades, idle thinks after eight seconds, menus and background pause timing',
    (tester) async {
      var now = 0;
      final game = GameController(levels, now: () => now);
      await mount(tester, game);
      expect(
        find.text('One little light. That’s enough to start.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.text('One little light. That’s enough to start.'),
        findsNothing,
      );
      expect(
        tester.widget<CompanionStrip>(find.byType(CompanionStrip)).line,
        isNull,
      );
      await tester.pump(const Duration(seconds: 3));
      await settleGameplay(tester);
      expect(
        find.text('The flame leans toward the clear paths…'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('thought-bubble')), findsOneWidget);
      now = 10000;
      await tester.tap(find.byTooltip('Levels'));
      await settleGameplay(tester);
      expect(game.rewards.running, isFalse);
      now = 30000;
      expect(game.rewards.elapsed, 10000);
      await tester.pump(const Duration(seconds: 30));
      expect(
        tester.widget<CompanionStrip>(find.byType(CompanionStrip)).line,
        isNull,
      );
      Navigator.of(tester.element(find.text('Your journey'))).pop();
      await settleGameplay(tester);
      expect(game.rewards.running, isTrue);
      now = 35000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = 90000;
      expect(game.rewards.elapsed, 15000);
      expect(game.rewards.running, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(game.rewards.running, isTrue);
      expect(find.text('Let’s find a way out.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets(
    'Empty hint balance opens a coin purchase without consuming or resetting the puzzle',
    (tester) async {
      final game = GameController(levels)..hints = 0;
      game.rewards.coins = 80;
      await mount(tester, game);
      await tester.tap(find.byTooltip('Hint · 0'));
      await settleGameplay(tester);
      expect(find.text('Coin shop'), findsOneWidget);
      expect(game.rewards.running, isFalse);
      await tester.tap(find.byKey(const Key('buy-hint')));
      await settleGameplay(tester);
      await tester.tap(find.text('Confirm purchase'));
      await settleGameplay(tester);
      expect(game.hints, 1);
      expect(game.rewards.coins, 0);
      expect(game.removed, isEmpty);
      await tester.tap(find.byTooltip('Close shop'));
      await settleGameplay(tester);
      await tester.tap(find.byTooltip('Restart'));
      await settleGameplay(tester);
      expect(game.hints, 1);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(768, 1024),
  ]) {
    testWidgets('No layout overflow at $size', (tester) async {
      final game = GameController(levels)
        ..inventory.companions.addAll([1, 2, 3])
        ..completed.addAll(List.generate(60, (i) => i))
        ..reset(60);
      await mount(tester, game, size: size);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    });
  }
  testWidgets('Level 60 opens the bonus boss, whose ending says coming soon', (
    tester,
  ) async {
    final game = GameController(levels)
      ..inventory.companions.addAll([1, 2, 3])
      ..completed.addAll(List.generate(59, (i) => i))
      ..reset(59);
    for (final id in game.puzzle.solve()!) {
      game.attempt(id);
      game.finish(id, game.epoch);
    }
    await mount(tester, game);
    expect(find.text('Chapter complete!'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue journey'));
    await tester.tap(find.text('Continue journey'));
    await settleGameplay(tester);
    expect(game.isBoss, isTrue);
    expect(find.text('The Crown Keeper'), findsOneWidget);
    for (final id in game.puzzle.solve()!) {
      game.attempt(id);
      game.finish(id, game.epoch);
    }
    await settleGameplay(tester);
    expect(find.text('Boss defeated!'), findsOneWidget);
    expect(find.text('New levels coming soon'), findsOneWidget);
    expect(game.index, 60);
    expect(game.canAdvance, isFalse);
    await tester.ensureVisible(find.text('Replay a level'));
    await tester.tap(find.text('Replay a level'));
    await settleGameplay(tester);
    expect(find.text('Your journey'), findsOneWidget);
    await tester.tap(find.text('01'));
    await settleGameplay(tester);
    expect(game.index, 0);
    expect(game.completed.length, 61);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });
  testWidgets('Capture locked picker and completed boss screens', (
    tester,
  ) async {
    final game = GameController(levels);
    final capture = GlobalKey();
    await mount(tester, game, capture: capture);
    Future<void> save(String name) async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'work/flutter-previews/$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final picker = find.byTooltip('Levels');
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await settleGameplay(tester);
    await save('locked-levels');
    await tester.tap(find.text('01'));
    await settleGameplay(tester);
    game.completed.addAll(List.generate(60, (i) => i));
    game.inventory.companions.addAll([1, 2, 3]);
    game.reset(60);
    for (final id in game.puzzle.solve()!) {
      game.attempt(id);
      game.finish(id, game.epoch);
    }
    await settleGameplay(tester);
    await tester.ensureVisible(find.text('Boss defeated!'));
    await settleGameplay(tester);
    await save('boss-ending');
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });
  testWidgets('Render actual Flutter phone screens for visual inspection', (
    tester,
  ) async {
    final game = GameController(levels)
      ..inventory.companions.addAll([1, 2, 3])
      ..completed.addAll(List.generate(60, (i) => i));
    for (final index in [0, 11, 29, 46, 59, 60]) {
      game.reset(index);
      final capture = GlobalKey();
      await mount(tester, game, capture: capture);
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('work/flutter-previews')
          ..createSync(recursive: true);
        File(
          '${directory.path}/level-${index + 1}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });
  testWidgets(
    'Choose, hide and restore companions; hint and goodbye keep game intact',
    (tester) async {
      final game = GameController(levels);
      game.completed.addAll([29, 44]);
      game.rewards.coins = 1500;
      game.buyCompanion(2);
      game.buyCompanion(3);
      final capture = GlobalKey();
      await mount(tester, game, capture: capture);
      Future<void> shot(String name) async {
        await settleGameplay(tester);
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            'work/flutter-previews/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final boardRect = tester.getRect(find.byKey(const Key('maze-board')));
      final stripRect = tester.getRect(
        find.byKey(const Key('companion-strip')),
      );
      expect(stripRect.top, greaterThan(boardRect.bottom));
      await tester.ensureVisible(find.byTooltip('Companions'));
      await tester.tap(find.byTooltip('Companions'));
      await settleGameplay(tester);
      await shot('companion-picker');
      await tester.tap(find.byKey(const Key('choose-companion-2')));
      await settleGameplay(tester);
      expect(game.companionId, 2);
      expect(find.text('Playful companion'), findsNothing);
      await tester.tap(find.byTooltip('Companions'));
      await settleGameplay(tester);
      await tester.ensureVisible(find.byKey(const Key('hide-companion')));
      await tester.tap(find.byKey(const Key('hide-companion')));
      await settleGameplay(tester);
      expect(find.byKey(const Key('companion-strip')), findsNothing);
      await tester.ensureVisible(find.byTooltip('Companions'));
      await tester.tap(find.byTooltip('Companions'));
      await settleGameplay(tester);
      await tester.tap(find.byKey(const Key('choose-companion-3')));
      await settleGameplay(tester);
      expect(game.companionVisible, isTrue);
      await tester.ensureVisible(find.byTooltip('Hint · 3'));
      await tester.tap(find.byTooltip('Hint · 3'));
      await settleGameplay(tester);
      expect(find.text('Blue path. Clear exit.'), findsOneWidget);
      expect(
        tester.widget<CompanionStrip>(find.byType(CompanionStrip)).mood,
        CompanionMood.thinking,
      );
      await shot('companion-hint');
      await tester.ensureVisible(find.byTooltip('More options'));
      await tester.tap(find.byTooltip('More options'));
      await settleGameplay(tester);
      await tester.tap(find.text('Take a break'));
      await settleGameplay(tester);
      expect(find.text('See you around.'), findsOneWidget);
      await shot('companion-goodbye');
      await tester.tap(find.text('Keep playing'));
      await settleGameplay(tester);
      expect(find.byKey(const Key('maze-board')), findsOneWidget);
      await tester.tap(find.byTooltip('More options'));
      await settleGameplay(tester);
      await tester.tap(find.text('Take a break'));
      await settleGameplay(tester);
      await tester.tap(find.text('Leave puzzle'));
      await settleGameplay(tester);
      expect(find.text('Continue puzzle'), findsOneWidget);
      expect(game.hints, 2);
      expect(game.lives, 3);
      await tester.tap(find.text('Continue puzzle'));
      await settleGameplay(tester);
      expect(game.hints, 2);
      expect(game.companionId, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets(
    'Blocked, winning and losing states show the appropriate companion',
    (tester) async {
      final game = GameController(levels);
      await mount(tester, game);
      final blocked = game.puzzle.arrows.firstWhere(
        (a) => game.puzzle.blockers(a, {}).isNotEmpty,
      );
      await tapArrow(tester, game, blocked.id);
      await settleGameplay(tester);
      expect(
        tester.widget<CompanionStrip>(find.byType(CompanionStrip)).mood,
        CompanionMood.concerned,
      );
      expect(
        find.text('That lane’s blocked. Try another path.'),
        findsOneWidget,
      );
      await tapArrow(tester, game, blocked.id);
      await tapArrow(tester, game, blocked.id);
      await settleGameplay(tester);
      expect(find.text('A fresh start? Take your time.'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Restart'));
      await tester.tap(find.byTooltip('Restart'));
      await settleGameplay(tester);
      for (final id in game.puzzle.solve()!) {
        game.attempt(id);
        game.finish(id, game.epoch);
      }
      await settleGameplay(tester);
      expect(
        tester.widget<CompanionStrip>(find.byType(CompanionStrip)).mood,
        CompanionMood.victory,
      );
      expect(find.text('Beautifully done!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets(
    'Animated victory banks once and Next opens the next puzzle directly',
    (tester) async {
      final game = GameController(levels);
      final capture = GlobalKey();
      await mount(tester, game, capture: capture);
      for (final id in game.puzzle.solve()!) {
        game.attempt(id);
        game.finish(id, game.epoch);
      }
      final coins = game.rewards.coins;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await settleGameplay(tester);
      expect(find.text('Level cleared!'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'work/flutter-previews/victory-shop-update.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pump(const Duration(seconds: 3));
      expect(game.rewards.coins, coins);
      await tester.ensureVisible(find.byKey(const Key('result-continue')));
      await tester.tap(find.byKey(const Key('result-continue')));
      await settleGameplay(tester);
      expect(game.index, 1);
      expect(game.status, GameStatus.playing);
      expect(find.text('Your journey'), findsNothing);
      expect(game.rewards.coins, coins);
      expect(game.rewards.running, true);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets(
    'Shop previews, cancellation, purchase, equip and persistence work end to end',
    (tester) async {
      final game = GameController(levels);
      game.completed.add(14);
      game.rewards.coins = 1000;
      final capture = GlobalKey();
      await mount(tester, game, capture: capture);
      Future<void> shot(String name) async {
        await settleGameplay(tester);
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            'work/flutter-previews/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.tap(find.byTooltip('Open coin shop'));
      await settleGameplay(tester);
      expect(game.rewards.running, false);
      await shot('shop-hints');
      await tester.tap(find.byKey(const Key('shop-tab-2')));
      await settleGameplay(tester);
      await tester.ensureVisible(find.byKey(const Key('buy-theme-sakura')));
      await tester.tap(find.byKey(const Key('buy-theme-sakura')));
      await settleGameplay(tester);
      await tester.tap(find.text('Cancel'));
      await settleGameplay(tester);
      expect(game.rewards.coins, 1000);
      expect(game.inventory.themes, {'classic'});
      await tester.tap(find.byKey(const Key('buy-theme-sakura')));
      await settleGameplay(tester);
      await tester.tap(find.text('Confirm purchase'));
      await settleGameplay(tester);
      expect(game.rewards.coins, 850);
      await tester.ensureVisible(find.byKey(const Key('use-theme-sakura')));
      await tester.tap(find.byKey(const Key('use-theme-sakura')));
      await settleGameplay(tester);
      expect(game.inventory.selectedTheme, 'sakura');
      await shot('shop-themes');
      await tester.tap(find.byKey(const Key('shop-tab-1')));
      await settleGameplay(tester);
      await tester.ensureVisible(find.byKey(const Key('buy-companion-1')));
      await tester.tap(find.byKey(const Key('buy-companion-1')));
      await settleGameplay(tester);
      await tester.tap(find.text('Confirm purchase'));
      await settleGameplay(tester);
      expect(game.rewards.coins, 250);
      expect(game.inventory.companions, contains(1));
      expect(game.companionId, 0);
      await shot('shop-companions');
      await tester.tap(find.byTooltip('Close shop'));
      await settleGameplay(tester);
      expect(game.rewards.running, true);
      expect(game.removed, isEmpty);
      final restored = GameController(levels)..restore(game.snapshot());
      expect(restored.inventory.selectedTheme, 'sakura');
      expect(restored.companionId, 0);
      expect(restored.rewards.coins, 250);
      restored.dispose();
      game.completed.addAll(List.generate(31, (i) => i));
      game.inventory.companions.addAll([1, 2, 3]);
      game.rewards.coins = 1000;
      game.reset(31);
      for (final id in ['sakura', 'lagoon', 'midnight']) {
        game.buyTheme(id);
        game.equipTheme(id);
        await shot('board-theme-$id');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('Shop and victory fit $size with reduced motion', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final game = GameController(levels);
      for (final id in game.puzzle.solve()!) {
        game.attempt(id);
        game.finish(id, game.epoch);
      }
      await mount(tester, game, size: size);
      expect(find.text('Level cleared!'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('result-continue')));
      await tester.tap(find.byKey(const Key('result-continue')));
      await settleGameplay(tester);
      expect(game.index, 1);
      await tester.tap(find.byTooltip('More options'));
      await settleGameplay(tester);
      await tester.tap(find.text('Coin shop'));
      await settleGameplay(tester);
      for (var i = 0; i < 4; i++) {
        await tester.ensureVisible(find.byKey(Key('shop-tab-$i')));
        await tester.tap(find.byKey(Key('shop-tab-$i')));
        await settleGameplay(tester);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip('Close shop'));
      await settleGameplay(tester);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    });
  }

  testWidgets(
    'Shop icon opens directly and displayed hearts match every difficulty band',
    (tester) async {
      final game = GameController(levels)
        ..inventory.companions.addAll([1, 2, 3])
        ..completed.addAll(List.generate(60, (i) => i));
      await mount(tester, game, size: const Size(320, 568));
      final shop = find.byTooltip('Shop');
      expect(tester.getSize(shop).width, greaterThanOrEqualTo(48));
      await tester.tap(shop);
      await settleGameplay(tester);
      expect(find.text('Coin shop'), findsOneWidget);
      expect(game.rewards.running, false);
      await tester.tap(find.byTooltip('Close shop'));
      await settleGameplay(tester);
      expect(game.rewards.running, true);
      for (final entry in {14: 3, 15: 2, 44: 2, 45: 1, 60: 1}.entries) {
        game.reset(entry.key);
        await settleGameplay(tester);
        expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(entry.value));
        expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
        final blocked = game.puzzle.arrows.firstWhere(
          (a) => game.puzzle.blockers(a, {}).isNotEmpty,
        );
        game.attempt(blocked.id);
        await settleGameplay(tester);
        expect(
          find.byIcon(Icons.favorite_rounded),
          findsNWidgets(entry.value - 1),
        );
        expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
        if (entry.value == 1) {
          expect(
            find.text('No hearts left. Take a breath and try again.'),
            findsOneWidget,
          );
          await tester.ensureVisible(find.byKey(const Key('result-continue')));
          await tester.tap(find.byKey(const Key('result-continue')));
          await settleGameplay(tester);
          expect(game.lives, 1);
          expect(game.status, GameStatus.playing);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets(
    'Arrow shop previews without spending, buys once, equips and animates a real escape',
    (tester) async {
      final game = GameController(levels);
      game.rewards.coins = 1000;
      final capture = GlobalKey();
      await mount(tester, game, capture: capture);
      Future<void> shot(String name) async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            'work/flutter-previews/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.tap(find.byTooltip('Shop'));
      await settleGameplay(tester);
      await tester.ensureVisible(find.byKey(const Key('shop-tab-3')));
      await tester.tap(find.byKey(const Key('shop-tab-3')));
      await settleGameplay(tester);
      await tester.ensureVisible(find.byKey(const Key('preview-neon')));
      await tester.tap(find.byKey(const Key('preview-neon')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await shot('arrow-shop-preview');
      expect(game.rewards.coins, 1000);
      expect(game.removed, isEmpty);
      expect(game.inventory.selectedArrow, 'classic');
      await settleGameplay(tester);
      await tester.ensureVisible(find.byKey(const Key('buy-arrow-neon')));
      await tester.tap(find.byKey(const Key('buy-arrow-neon')));
      await settleGameplay(tester);
      await tester.tap(find.text('Cancel'));
      await settleGameplay(tester);
      expect(game.rewards.coins, 1000);
      await tester.tap(find.byKey(const Key('buy-arrow-neon')));
      await settleGameplay(tester);
      await tester.tap(find.text('Confirm purchase'));
      await settleGameplay(tester);
      expect(game.rewards.coins, 820);
      await tester.ensureVisible(find.byKey(const Key('use-arrow-neon')));
      await tester.tap(find.byKey(const Key('use-arrow-neon')));
      await settleGameplay(tester);
      expect(game.inventory.selectedArrow, 'neon');
      await tester.tap(find.byTooltip('Close shop'));
      await settleGameplay(tester);
      for (final id in ['neon', 'fire', 'ice', 'sakura']) {
        game.buyArrowSkin(id);
        game.equipArrowSkin(id);
        await tester.tap(find.byTooltip('Restart'));
        await settleGameplay(tester);
        final arrow = game.puzzle.available({}).first;
        await tapArrow(tester, game, arrow.id);
        await tester.pump(const Duration(milliseconds: 200));
        expect(game.busy, true);
        expect(game.removed, isEmpty);
        await shot('arrow-escape-$id');
        await settleGameplay(tester);
        expect(game.removed, {arrow.id});
        expect(game.lives, 3);
        expect(game.inventory.selectedTheme, 'classic');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );
}
