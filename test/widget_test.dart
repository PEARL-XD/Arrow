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
    await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
      expect(game.removed, contains(available.id));
      await tester.ensureVisible(find.text('Restart'));
      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      expect(game.removed, isEmpty);
      expect(game.lives, 3);
      await tester.ensureVisible(find.text('Hint · 3'));
      await tester.tap(find.text('Hint · 3'));
      await tester.pump();
      expect(game.hints, 2);
      await tester.tap(find.text('Skip level'));
      await tester.pumpAndSettle();
      expect(game.index, 1);
      expect(game.hints, 3);
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
      await tester.pumpAndSettle();
      expect(find.text('1.5×'), findsOneWidget);
      await tester.tap(find.byTooltip('Fit board'));
      await tester.pumpAndSettle();
      expect(find.text('1.0×'), findsOneWidget);
      await tester.tap(find.byTooltip('How to play'));
      await tester.pumpAndSettle();
      expect(find.text('Untangle the way out'), findsOneWidget);
      await tester.tap(find.text('Let’s play'));
      await tester.pumpAndSettle();
      final picker = find.text('Levels  ·  0/40 cleared');
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(find.text('Your journey'), findsOneWidget);
      await tester.tap(find.text('03'));
      await tester.pumpAndSettle();
      expect(game.index, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );
  testWidgets('Changing levels cancels a flight before its old completion', (
    tester,
  ) async {
    final game = GameController(levels);
    await mount(tester, game);
    await tapArrow(tester, game, game.puzzle.available({}).first.id);
    await tester.ensureVisible(find.text('Skip level'));
    await tester.tap(find.text('Skip level'));
    await tester.pumpAndSettle();
    expect(game.index, 1);
    expect(game.removed, isEmpty);
    expect(game.busy, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(768, 1024),
  ]) {
    testWidgets('No layout overflow at $size', (tester) async {
      final game = GameController(levels)..reset(39);
      await mount(tester, game, size: size);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    });
  }
  testWidgets('Render actual Flutter phone screens for visual inspection', (
    tester,
  ) async {
    final game = GameController(levels);
    for (final index in [0, 7, 19, 31, 39]) {
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
}
