import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_out/admin_testing.dart';
import 'package:path_out/arrow_skins.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/main.dart';
import 'package:path_out/main.dart' as app;
import 'package:path_out/puzzle.dart';
import 'package:path_out/shop_catalog.dart';
import 'package:path_out/storage.dart';
import 'package:path_out/story.dart';
import 'package:path_out/story_screen.dart';
import 'package:path_out/rewarded_ads.dart';
import 'fake_ads.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());

  test('Admin stage shortcuts still require purchased chapters', () {
    final game = GameController(levels, adminTesting: true)..refillTestCoins();
    expect(game.rewards.coins, 10000);
    expect(game.discoveredLevelCount, levels.length);
    expect(game.completed, isEmpty);
    expect(game.reset(59), isFalse);
    expect(game.inventory.companions, {0});
    expect(game.buyCompanion(1), isFalse);
    expect(game.reset(levels.length), isFalse);
    expect(game.reset(-1), isFalse);
    for (var id = 1; id < companionPrices.length; id++) {
      game.reset(id * 15 - 1);
      while (game.status != GameStatus.won) {
        game.clearForTesting();
      }
      expect(game.buyCompanion(id), isTrue);
    }
    game.reset(59);
    for (final theme in puzzleThemes.where((t) => t.price > 0)) {
      expect(game.buyTheme(theme.id), isTrue);
      expect(game.equipTheme(theme.id), isTrue);
    }
    for (final skin in arrowSkins.where((s) => s.price > 0)) {
      expect(game.buyArrowSkin(skin.id), isTrue);
      expect(game.equipArrowSkin(skin.id), isTrue);
    }
    expect(game.buyHint(), isTrue);
    expect(game.rewards.coins, lessThan(10000));
    expect(game.completed, {14, 29, 44});
    expect(game.rewards.bestTimes.keys, containsAll([14, 29, 44]));
    final restored = GameController(levels, adminTesting: true)
      ..restore(game.snapshot());
    expect(restored.index, 59);
    expect(restored.snapshot(), game.snapshot());
    restored.refillTestCoins();
    expect(restored.rewards.coins, 10000);
    game.dispose();
    restored.dispose();
  });

  test('Normal mode rejects test currency, privileges and test saves', () {
    final normal = GameController(levels);
    final original = normal.snapshot();
    normal.refillTestCoins();
    expect(normal.reset(59), isFalse);
    expect(normal.companionAvailable(1), isFalse);
    final admin = GameController(levels, adminTesting: true)
      ..refillTestCoins()
      ..reset(59);
    normal.restore(admin.snapshot());
    expect(normal.snapshot(), original);
    normal.dispose();
    admin.dispose();
  });

  test(
    'Admin shortcuts and purchases never overwrite the player save',
    () async {
      final normal = GameController(levels);
      normal.rewards.coins = 120;
      final original = jsonEncode(normal.snapshot());
      SharedPreferences.setMockInitialValues({ProgressStore.key: original});
      final preferences = await SharedPreferences.getInstance();
      final admin = GameController(levels, adminTesting: true);
      ProgressStore(preferences).restore(admin);
      expect(admin.rewards.coins, 120);
      admin.refillTestCoins();
      admin.completed.add(29);
      expect(admin.buyCompanion(2), isTrue);
      admin.reset(44);
      final adminStore = ProgressStore(
        preferences,
        saveKey: ProgressStore.adminKey,
      );
      await adminStore.save(admin);
      expect(preferences.getString(ProgressStore.key), original);
      final restored = GameController(levels, adminTesting: true);
      adminStore.restore(restored);
      expect(restored.index, 44);
      expect(restored.inventory.companions, contains(2));
      expect(restored.rewards.coins, 9300);
      final playerStore = ProgressStore(preferences);
      await playerStore.save(admin);
      expect(playerStore.saveFailed.value, isTrue);
      expect(preferences.getString(ProgressStore.key), original);
      playerStore.restore(normal);
      expect(normal.rewards.coins, 120);
      expect(normal.index, 0);
      expect(normal.completed, isEmpty);
      normal.dispose();
      admin.dispose();
      restored.dispose();
    },
  );

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets(
      'Test Skip plays stories and requires a chapter purchase at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final game = GameController(levels, adminTesting: true)
          ..refillTestCoins();
        game.seenScenes.addAll(allStoryScenes.map((s) => s.id));
        await tester.pumpWidget(PathOutApp(game: game));
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
        final skip = find.byKey(const Key('admin-skip'));
        await tester.tap(skip);
        await tester.pumpAndSettle();
        expect(find.byType(StoryScreen), findsOneWidget);
        expect(find.text(miraScenes[1].title), findsOneWidget);
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(game.index, 1);
        expect(game.completed, contains(0));
        game.reset(14);
        await tester.pumpAndSettle();
        await tester.tap(skip);
        await tester.pumpAndSettle();
        expect(find.text('The glass gives way'), findsOneWidget);
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(game.bossPhase, 1);
        await tester.tap(skip);
        await tester.pumpAndSettle();
        expect(find.text(miraScenes.last.title), findsOneWidget);
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('unlock-chapter')), findsOneWidget);
        expect(game.inventory.companions, {0});
        expect(game.reset(15), isFalse);
        final balance = game.rewards.coins;
        await tester.ensureVisible(find.byKey(const Key('unlock-chapter')));
        await tester.tap(find.byKey(const Key('unlock-chapter')));
        await tester.pumpAndSettle();
        expect(game.index, 15);
        expect(game.companionId, 1);
        expect(game.inventory.companions, {0, 1});
        expect(game.rewards.coins, balance - 600);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        game.dispose();
      },
    );
  }

  testWidgets('Normal player layout has no admin controls', (tester) async {
    final game = GameController(levels);
    game.seenScenes.addAll(allStoryScenes.map((s) => s.id));
    await tester.pumpWidget(PathOutApp(game: game));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-skip')), findsNothing);
    expect(find.text('ADMIN TEST · separate save'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });

  testWidgets('App startup respects the testing switch and player save', (
    tester,
  ) async {
    final ads = FakeAdGateway();
    rewardAds = RewardedAds(
      gateway: ads,
      config: const AdConfig(platform: TargetPlatform.android),
    );
    final player = GameController(levels);
    player.rewards.coins = 120;
    player.seenScenes.addAll(allStoryScenes.map((s) => s.id));
    final original = jsonEncode(player.snapshot());
    SharedPreferences.setMockInitialValues({ProgressStore.key: original});
    await tester.runAsync(app.main);
    await tester.pump();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(miraStoryAsset),
        tester.element(find.byType(Scaffold).first),
      ),
    );
    await tester.pumpAndSettle();
    final root = tester.widget<PathOutApp>(find.byType(PathOutApp));
    expect(root.game.adminTesting, adminTestingEnabled);
    expect(root.game.inventory.companions, {0});
    expect(ads.updates, 1);
    expect(root.game.rewards.coins, adminTestingEnabled ? 10000 : 120);
    expect(
      root.store!.saveKey,
      adminTestingEnabled ? ProgressStore.adminKey : ProgressStore.key,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(ProgressStore.key), original);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    root.game.dispose();
    player.dispose();
  });
}
