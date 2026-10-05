import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_out/arrow_skins.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/puzzle.dart';
import 'package:path_out/shop_catalog.dart';
import 'package:flutter/material.dart';
import 'package:path_out/arrow_preview.dart';

void main() {
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());
  test(
    'Skins charge once, reject invalid/locked choices, and stay independent of themes',
    () {
      final game = GameController(levels);
      expect(game.inventory.arrows, {'classic'});
      expect(game.equipArrowSkin('fire'), false);
      expect(game.buyArrowSkin('fire'), false);
      game.rewards.coins = 400;
      expect(game.buyArrowSkin('neon'), true);
      expect(game.rewards.coins, 220);
      expect(game.buyArrowSkin('neon'), false);
      expect(game.buyArrowSkin('fake'), false);
      expect(game.buyArrowSkin('classic'), false);
      expect(game.equipArrowSkin('neon'), true);
      expect(game.buyTheme('midnight'), true);
      game.equipTheme('midnight');
      expect(game.inventory.selectedArrow, 'neon');
      expect(game.rewards.coins, 0);
      final available = game.puzzle.available({}).map((a) => a.id).toList();
      game.equipArrowSkin('classic');
      expect(game.puzzle.available({}).map((a) => a.id).toList(), available);
      expect(game.inventory.selectedTheme, 'midnight');
      game.equipArrowSkin('neon');
      game.reset();
      final restored = GameController(levels)..restore(game.snapshot());
      expect(restored.inventory.selectedArrow, 'neon');
      expect(restored.inventory.arrows, {'classic', 'neon'});
      expect(restored.inventory.selectedTheme, 'midnight');
      expect(restored.rewards.coins, 0);
      game.dispose();
      restored.dispose();
    },
  );
  test('Legacy and malformed skins preserve purchased themes and progress', () {
    final game = GameController(levels)
      ..completed.add(0)
      ..reset(1);
    game.rewards.coins = 400;
    game.buyTheme('sakura');
    game.equipTheme('sakura');
    final save = game.snapshot();
    (save['shop'] as Map)
      ..remove('arrows')
      ..remove('selectedArrow');
    final restored = GameController(levels)..restore(save);
    expect(restored.inventory.selectedArrow, 'classic');
    expect(restored.inventory.selectedTheme, 'sakura');
    expect(restored.index, 1);
    expect(restored.rewards.coins, 250);
    (save['shop'] as Map)
      ..['arrows'] = ['fake', 2, 'ice']
      ..['selectedArrow'] = 'fire';
    restored.restore(save);
    expect(restored.inventory.arrows, {'classic', 'ice'});
    expect(restored.inventory.selectedArrow, 'classic');
    game.dispose();
    restored.dispose();
  });
  test(
    'Every paid skin maintains contrast on the lightest and darkest theme gradients',
    () {
      const lightSurfaces = [
        Color(0xFFFFE4ED),
        Color(0xFFF6DDEA),
        Color(0xFFD3F1E8),
        Color(0xFFCDEDEB),
        Colors.white,
      ];
      const darkSurfaces = [
        Color(0xFF302B54),
        Color(0xFF16253C),
        Color(0xFF123440),
      ];
      for (final skin in arrowSkins.skip(1)) {
        for (final dark in [false, true]) {
          for (final ink in skin.colorsFor(dark)) {
            for (final board in dark ? darkSurfaces : lightSurfaces) {
              final values = [ink.computeLuminance(), board.computeLuminance()]
                ..sort();
              expect(
                (values.last + .05) / (values.first + .05),
                greaterThan(3),
                reason: '${skin.id}: $dark',
              );
            }
          }
        }
      }
    },
  );
  testWidgets(
    'Every preview plays once and settles; reduced motion keeps the same skin',
    (tester) async {
      for (final reduced in [false, true]) {
        for (final theme in puzzleThemes) {
          for (final skin in arrowSkins) {
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(disableAnimations: reduced),
                  child: Scaffold(
                    body: SizedBox(
                      width: 300,
                      child: ArrowSkinPreview(
                        key: ValueKey('${skin.id}-${theme.id}-$reduced'),
                        skin: skin,
                        theme: theme,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.byKey(Key('preview-${skin.id}')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 80));
            final painter =
                tester
                        .widget<CustomPaint>(
                          find.byKey(Key('arrow-preview-${skin.id}')),
                        )
                        .painter!
                    as ArrowPreviewPainter;
            expect(painter.skin.id, skin.id);
            expect(painter.reducedMotion, reduced);
            expect(painter.progress, greaterThan(0));
            await tester.pumpAndSettle();
            final settled =
                tester
                        .widget<CustomPaint>(
                          find.byKey(Key('arrow-preview-${skin.id}')),
                        )
                        .painter!
                    as ArrowPreviewPainter;
            expect(settled.progress, 0);
            expect(tester.takeException(), isNull);
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
