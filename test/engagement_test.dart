import 'dart:io';
import 'dart:async';
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
import 'package:path_out/arrow_preview.dart';
import 'package:path_out/arrow_skins.dart';
import 'package:path_out/shop_catalog.dart';
import 'package:path_out/rewarded_ads.dart';
import 'fake_ads.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAdGateway ads;
  setUp(() {
    ads = FakeAdGateway();
    rewardAds = RewardedAds(
      gateway: ads,
      config: const AdConfig(platform: TargetPlatform.android),
    );
  });
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());
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

  void clear(GameController game) {
    for (final id in game.puzzle.solve(game.removed)!) {
      game.attempt(id);
      game.finish(id, game.epoch);
    }
  }

  void lose(GameController game) {
    final blocked = game.puzzle.arrows.firstWhere(
      (a) =>
          !game.removed.contains(a.id) &&
          game.puzzle.blockers(a, game.removed).isNotEmpty,
    );
    while (game.lives > 0) {
      game.attempt(blocked.id);
    }
  }

  test(
    'Later chapters and bosses allow longer speed windows with exact boundaries',
    () {
      for (final pair in [
        (0, 45000, 60000),
        (15, 90000, 120000),
        (30, 180000, 240000),
        (45, 240000, 300000),
        (59, 360000, 450000),
      ]) {
        final target = bonusTargets(pair.$1);
        expect(target, (gold: pair.$2, silver: pair.$3));
        expect(speedBonus(target.gold - 1, level: pair.$1), 10);
        expect(speedBonus(target.gold, level: pair.$1), 5);
        expect(speedBonus(target.silver - 1, level: pair.$1), 5);
        expect(speedBonus(target.silver, level: pair.$1), 0);
      }
      var now = 0;
      final rewards = RunRewards(now: () => now)..resume();
      now = 170000;
      rewards.complete(35, firstClear: true);
      expect(rewards.lastSpeed, 10);
      expect(rewards.bestTimes[35], now);
    },
  );

  test(
    'Two clears earn one hint, survives restart, checkpoint is not a clear',
    () {
      final game = GameController(levels, adminTesting: true);
      clear(game);
      expect(game.hints, 3);
      expect(game.clearsTowardHint, 1);
      final restored = GameController(levels, adminTesting: true)
        ..restore(game.snapshot());
      restored.reset(0);
      clear(restored);
      expect(restored.hints, 4);
      expect(restored.lastHintEarned, isTrue);
      expect(restored.clearsTowardHint, 0);
      restored.reset(14);
      clear(restored);
      expect(restored.bossPhase, 1);
      expect(restored.clearsTowardHint, 0);
      clear(restored);
      expect(restored.clearsTowardHint, 1);
      expect(restored.hints, 4);
      game.dispose();
      restored.dispose();
    },
  );

  test(
    'Revive charges once only on loss, preserves routes and elapsed time',
    () {
      var now = 0;
      final game = GameController(levels, now: () => now);
      game.rewards.coins = 250;
      expect(game.revive(), isFalse);
      final arrow = game.puzzle.available({}).first;
      game.attempt(arrow.id);
      game.finish(arrow.id, game.epoch);
      game.resumeTiming();
      now = 37000;
      lose(game);
      final removed = Set<int>.of(game.removed);
      final hints = game.hints;
      expect(game.revive(), isTrue);
      expect(game.rewards.coins, 50);
      expect(game.lives, game.maxLives);
      expect(game.removed, removed);
      expect(game.hints, hints);
      expect(game.rewards.elapsed, 37000);
      expect(game.revive(), isFalse);
      lose(game);
      expect(game.revive(), isFalse);
      final restored = GameController(levels)..restore(game.snapshot());
      expect(restored.status, GameStatus.lost);
      expect(restored.revive(rewarded: true), isTrue);
      expect(restored.rewards.coins, 50);
      expect(restored.removed, removed);
      expect(restored.rewards.elapsed, 37000);
      game.dispose();
      restored.dispose();
    },
  );

  test(
    'Every Raven clear queues her ending even after it was seen; queue survives save',
    () {
      final game = GameController(levels)
        ..inventory.companions.addAll([1, 2, 3])
        ..completed.addAll(List.generate(59, (i) => i))
        ..reset(59);
      final ending = ravenScenes.last.id;
      game.seenScenes.add(ending);
      for (var run = 0; run < 2; run++) {
        clear(game);
        expect(game.pendingScenes, [ending]);
        final restored = GameController(levels)..restore(game.snapshot());
        expect(restored.pendingScenes, [ending]);
        expect(restored.status, GameStatus.won);
        restored.dispose();
        game.markSceneSeen(ending);
        expect(game.pendingScenes, isEmpty);
        game.reset(59);
      }
      game.dispose();
    },
  );

  test(
    'Chapter purchase does not equip early; entering and replaying chapters switches automatically',
    () {
      final game = GameController(levels, adminTesting: true)
        ..refillTestCoins();
      expect(game.inventory.companions, {0});
      expect(game.buyCompanion(1), isFalse);
      expect(game.reset(15), isFalse);
      game.reset(14);
      game.clearForTesting();
      game.clearForTesting();
      expect(game.buyCompanion(1), isTrue);
      expect(game.companionId, 0);
      expect(game.reset(15), isTrue);
      expect(game.companionId, 1);
      game.reset(0);
      expect(game.companionId, 0);
      game.dispose();
    },
  );

  Future<void> mount(
    WidgetTester tester,
    GameController game, {
    GlobalKey? capture,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    game.seenScenes.addAll(allStoryScenes.map((s) => s.id));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: PathOutApp(game: game),
      ),
    );
    await tester.runAsync(
      () => Future.wait([
        for (var id = 1; id <= 4; id++)
          precacheImage(
            AssetImage('assets/companions/char0$id.png'),
            tester.element(find.byType(Scaffold).first),
          ),
        for (final panels in chapterPanels)
          precacheImage(
            AssetImage(panels.first.asset),
            tester.element(find.byType(Scaffold).first),
          ),
      ]),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('work/flutter-previews').createSync(recursive: true);
      File(
        'work/flutter-previews/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    if (key.startsWith('watch-') || key == 'revive-ad') {
      await tester.pump();
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> claim(WidgetTester tester) async {
    expect(ads.video.shows, 1);
    ads.video.finish(true);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Empty hint offers coins or ad, cancellation pays nothing; coin packs grant once',
    (tester) async {
      final game = GameController(levels, adminTesting: true)..hints = 0;
      final capture = GlobalKey();
      await mount(tester, game, capture: capture);
      await tester.tap(find.byTooltip('Hint · 0'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('buy-hint')), findsOneWidget);
      await tap(tester, 'buy-hint');
      expect(find.byKey(const Key('watch-coins-ad')), findsOneWidget);
      expect(game.rewards.coins, 0);
      await tap(tester, 'shop-tab-0');
      await tap(tester, 'watch-hint-ad');
      ads.video.finish(false);
      await tester.pumpAndSettle();
      expect(game.hints, 0);
      await tap(tester, 'watch-hint-ad');
      await claim(tester);
      expect(game.hints, 1);
      expect(game.rewards.coins, 0);
      expect(game.rewards.running, isFalse);
      await tap(tester, 'shop-tab-4');
      await shot(tester, capture, 'coin-options');
      await tap(tester, 'watch-coins-ad');
      await claim(tester);
      expect(game.rewards.coins, 80);
      await tap(tester, 'coin-pack-1500');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(game.rewards.coins, 80);
      await tap(tester, 'coin-pack-1500');
      await tap(tester, 'confirm-test-purchase');
      expect(game.rewards.coins, 1580);
      await tap(tester, 'coin-pack-4000');
      await tap(tester, 'confirm-test-purchase');
      expect(game.rewards.coins, 5580);
      await tester.tap(find.byTooltip('Close shop'));
      await tester.pumpAndSettle();
      expect(game.rewards.running, isTrue);
      expect(game.removed, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets(
    'Coin and ad revive both preserve progress and resume the puzzle',
    (tester) async {
      final game = GameController(levels, adminTesting: true);
      game.rewards.coins = 250;
      final arrow = game.puzzle.available({}).first;
      game.attempt(arrow.id);
      game.finish(arrow.id, game.epoch);
      lose(game);
      final capture = GlobalKey();
      await mount(tester, game, capture: capture);
      await shot(tester, capture, 'revive-options');
      await tap(tester, 'revive-coins');
      expect(game.status, GameStatus.playing);
      expect(game.rewards.coins, 50);
      expect(game.removed, {arrow.id});
      lose(game);
      await tester.pumpAndSettle();
      await tap(tester, 'revive-ad');
      ads.video.finish(false);
      await tester.pumpAndSettle();
      expect(game.status, GameStatus.lost);
      await tap(tester, 'revive-ad');
      await claim(tester);
      expect(game.status, GameStatus.playing);
      expect(game.rewards.running, isTrue);
      expect(game.rewards.coins, 50);
      expect(game.removed, {arrow.id});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets(
    'Raven test clear automatically shows ending even when already seen',
    (tester) async {
      final game = GameController(levels, adminTesting: true)
        ..inventory.companions.addAll([1, 2, 3])
        ..reset(59);
      await mount(tester, game);
      await tap(tester, 'admin-skip');
      expect(find.byType(StoryScreen), findsOneWidget);
      expect(find.text(ravenScenes.last.title), findsOneWidget);
      expect(game.rewards.running, isFalse);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(game.index, 60);
      expect(game.pendingScenes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets(
    'Non-admin player earns hint, coins and revive through ad callbacks',
    (tester) async {
      final game = GameController(levels)..hints = 0;
      await mount(tester, game);
      await tester.tap(find.byTooltip('Hint · 0'));
      await tester.pumpAndSettle();
      await tap(tester, 'watch-hint-ad');
      await claim(tester);
      expect(game.hints, 1);
      await tap(tester, 'shop-tab-4');
      await tap(tester, 'watch-coins-ad');
      await claim(tester);
      expect(game.rewards.coins, 80);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('coin-pack-1500')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Close shop'));
      await tester.pumpAndSettle();
      lose(game);
      await tester.pumpAndSettle();
      await tap(tester, 'revive-ad');
      await claim(tester);
      expect(game.lives, game.maxLives);
      expect(game.rewards.coins, 80);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets('Cancel loading prevents late ad presentation and reward', (
    tester,
  ) async {
    final game = GameController(levels)..hints = 0;
    await mount(tester, game);
    await tester.tap(find.byTooltip('Hint · 0'));
    await tester.pumpAndSettle();
    ads.pendingLoad = Completer<RewardVideo>();
    await tap(tester, 'watch-hint-ad');
    await tap(tester, 'cancel-ad-loading');
    final lateVideo = FakeRewardVideo();
    ads.pendingLoad!.complete(lateVideo);
    await tester.pumpAndSettle();
    expect(lateVideo.shows, 0);
    expect(lateVideo.disposals, 1);
    expect(game.hints, 0);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });

  testWidgets('A revive reward cannot affect a different attempt', (
    tester,
  ) async {
    final game = GameController(levels);
    lose(game);
    await mount(tester, game);
    await tap(tester, 'revive-ad');
    game.reset(0);
    lose(game);
    await claim(tester);
    expect(game.status, GameStatus.lost);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });

  testWidgets(
    'Stationary skins render distinct heads and colours on light and dark boards',
    (tester) async {
      tester.view.physicalSize = const Size(800, 980);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Column(
                children: [
                  for (final skin in arrowSkins)
                    SizedBox(
                      height: 140,
                      child: Row(
                        children: [
                          for (final theme in [
                            puzzleThemes.first,
                            puzzleThemes.last,
                          ])
                            Expanded(
                              child: Column(
                                children: [
                                  Text('${skin.name} · ${theme.name}'),
                                  Expanded(
                                    child: CustomPaint(
                                      size: const Size(400, 120),
                                      painter: ArrowPreviewPainter(
                                        skin: skin,
                                        theme: theme,
                                        progress: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await shot(tester, capture, 'stationary-skin-gallery');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
