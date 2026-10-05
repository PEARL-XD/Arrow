import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_out/main.dart' as app;
import 'package:path_out/game_controller.dart';
import 'package:path_out/storage.dart';
import 'package:path_out/arrow_geometry.dart';
import 'package:path_out/admin_testing.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android native launch, touch, zoom, saves and level controls', (
    tester,
  ) async {
    expect(
      adminTestingEnabled,
      isFalse,
      reason:
          'Run this normal-player smoke test with --dart-define=PATH_OUT_ADMIN=false',
    );
    final preferences = await SharedPreferences.getInstance();
    // This key belongs only to the development app running this test.
    await preferences.remove(ProgressStore.key);
    await app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('A Little Light'), findsOneWidget);
    final root = tester.widget<app.PathOutApp>(find.byType(app.PathOutApp));
    final game = root.game;
    expect(game.levels.length, 61);
    expect(root.store, isNotNull);

    final board = find.byKey(const Key('maze-board'));
    final bounds = boardSize(game.puzzle);
    final rect = tester.getRect(board);
    final arrow = game.puzzle.available({}).first;
    final point = cellPoint(arrow.head);
    await tester.tapAt(
      rect.topLeft +
          Offset(
            point.dx / bounds.width * rect.width,
            point.dy / bounds.height * rect.height,
          ),
    );
    await tester.pumpAndSettle();
    expect(game.removed, contains(arrow.id));
    await root.store!.save(game);
    await preferences.reload();
    final restored = GameController(game.levels);
    ProgressStore(preferences).restore(restored);
    expect(restored.removed, game.removed);
    expect(restored.lives, game.lives);
    restored.dispose();

    await tester.ensureVisible(find.byTooltip('Hint · 3'));
    await tester.tap(find.byTooltip('Hint · 3'));
    await tester.pumpAndSettle();
    expect(game.hints, 2);
    await tester.tap(find.byTooltip('Restart'));
    await tester.pumpAndSettle();
    expect(game.removed, isEmpty);
    expect(find.text('Next level'), findsNothing);
    for (final id in game.puzzle.solve()!) {
      game.attempt(id);
      game.finish(id, game.epoch);
    }
    await tester.pumpAndSettle();
    expect(find.text('A little light returns'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    final next = find.byKey(const Key('result-continue'));
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(game.index, 1);

    await tester.ensureVisible(find.byTooltip('Zoom in'));
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(find.text('1.5×'), findsOneWidget);
    await tester.tap(find.byTooltip('Fit board'));
    await tester.pumpAndSettle();
    expect(find.text('1.0×'), findsOneWidget);
    game.completed.add(14);
    game.rewards.coins = 600;
    game.buyCompanion(1);
    await tester.ensureVisible(find.byTooltip('Companions'));
    await tester.tap(find.byTooltip('Companions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-companion-1')));
    await tester.pumpAndSettle();
    expect(game.companionId, 1);
    await root.store!.save(game);
    await preferences.reload();
    final companionSave = GameController(game.levels);
    ProgressStore(preferences).restore(companionSave);
    expect(companionSave.companionId, 1);
    expect(companionSave.index, 1);
    expect(companionSave.completed, contains(0));
    companionSave.dispose();
    await tester.ensureVisible(find.byTooltip('More options'));
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a break'));
    await tester.pumpAndSettle();
    expect(find.text('Until next time.'), findsOneWidget);
    await tester.tap(find.text('Leave puzzle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue puzzle'));
    await tester.pumpAndSettle();
    expect(game.index, 1);
    expect(tester.takeException(), isNull);
    await root.store!.save(game);
  });
}
