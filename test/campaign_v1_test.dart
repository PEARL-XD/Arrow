import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_out/campaign.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/main.dart';
import 'package:path_out/puzzle.dart';
import 'package:path_out/story.dart';
import 'package:path_out/story_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());
  final previous = Puzzle.decode(
    File('assets/legacy-campaign-v08.json').readAsStringSync(),
  );

  test(
    'Four fifteen-stage chapters retain all approved routes and add twenty unique boards',
    () {
      expect(levels.length, 61);
      for (var old = 0; old < previous.length; old++) {
        final current = levels[expandedStage(old)];
        expect(current.mask, previous[old].mask);
        expect(current.arrows.length, previous[old].arrows.length);
        for (var arrow = 0; arrow < current.arrows.length; arrow++) {
          expect(
            current.arrows[arrow].cells,
            previous[old].arrows[arrow].cells,
          );
          expect(
            current.arrows[arrow].direction,
            previous[old].arrows[arrow].direction,
          );
        }
      }
      final additions = [
        for (var i = 0; i < 60; i++)
          if (!List.generate(41, expandedStage).contains(i)) levels[i],
      ];
      expect(additions.length, 20);
      expect(
        additions
            .map(
              (p) => jsonEncode(
                p.arrows
                    .map((a) => a.cells.map((c) => [c.x, c.y]).toList())
                    .toList(),
              ),
            )
            .toSet()
            .length,
        20,
      );
      for (final p in additions) {
        p.validate();
      }
      for (final index in [14, 29, 44, 59]) {
        expect(levels[index].isBoss, true);
      }
      expect(levels[14].secondPhase, isNotNull);
    },
  );

  test(
    'Every chapter uses all twenty panels once, without early endings or duplicate scene ids',
    () {
      expect(
        allStoryScenes.map((s) => s.id).toSet().length,
        allStoryScenes.length,
      );
      for (var c = 0; c < 4; c++) {
        expect(
          chapterScenes[c].expand((s) => s.panels),
          List.generate(20, (i) => i),
        );
        for (final scene in chapterScenes[c]) {
          expect(scene.lines.length, scene.panels.length);
          if (scene.afterStage != null) {
            final required = c * 15 + scene.afterStage!;
            expect(storyAvailable(scene.id, {}, required, 0), false);
            expect(storyAvailable(scene.id, {required}, required, 0), true);
          }
        }
        expect(chapterScenes[c].last.afterStage, 14);
        expect(chapterScenes[c].last.restored, true);
      }
      expect(storyAvailable('keeper', {}, 14, 0), false);
      expect(storyAvailable('keeper', {}, 14, 1), true);
      expect(storyAvailable('festival', {}, 14, 1), false);
    },
  );

  test(
    'Old progress, purchases, checkpoint and records migrate exactly once',
    () {
      final old = GameController(previous)
        ..inventory.companions.addAll([1, 2, 3])
        ..completed.addAll(List.generate(9, (i) => i))
        ..reset(9);
      for (final id in old.puzzle.solve()!) {
        old.attempt(id);
        old.finish(id, old.epoch);
      }
      expect(old.bossPhase, 1);
      final safe = old.puzzle.available({}).first.id;
      old.attempt(safe);
      old.finish(safe, old.epoch);
      old.rewards.coins = 941;
      old.rewards.bestTimes[8] = 56000;
      old.rewards.paidSpeed[8] = 5;
      old.rewards.paidSkill[8] = 12;
      old.seenScenes.add('gate');
      final data = old.snapshot()..remove('campaignVersion');
      final game = GameController(levels)..restore(data);
      expect(game.index, 14);
      expect(game.bossPhase, 1);
      expect(game.removed, {safe});
      expect(game.completed, List.generate(14, (i) => i).toSet());
      expect(game.rewards.coins, 941);
      expect(game.rewards.bestTimes, {13: 56000});
      expect(game.rewards.paidSpeed, {13: 5});
      expect(game.rewards.paidSkill, {13: 12});
      expect(game.seenScenes, contains('gate'));
      expect(game.isUnlocked(15), false);
      final twice = GameController(levels)..restore(game.snapshot());
      expect(twice.snapshot(), game.snapshot());
      game.dispose();
      twice.dispose();
      old.dispose();
    },
  );

  test(
    'Old active boards at every index keep their removed routes and progress',
    () {
      for (var index = 0; index < 41; index++) {
        final old = GameController(previous)
          ..inventory.companions.addAll([1, 2, 3])
          ..completed.addAll(List.generate(index, (i) => i))
          ..reset(index);
        final safe = old.puzzle.available({}).first.id;
        old.attempt(safe);
        old.finish(safe, old.epoch);
        final data = old.snapshot()..remove('campaignVersion');
        final game = GameController(levels)..restore(data);
        expect(
          game.index,
          expandedStage(index),
          reason: 'old stage ${index + 1}',
        );
        expect(game.removed, {safe});
        expect(game.puzzle.mask, old.puzzle.mask);
        expect(game.rewards.coins, old.rewards.coins);
        expect(game.inventory.companions, old.inventory.companions);
        game.dispose();
        old.dispose();
      }
    },
  );

  Future<void> cache(WidgetTester tester) async {
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
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
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

  for (var c = 1; c < 4; c++) {
    testWidgets(
      '${storyNames[c]} supplied twenty-panel artwork renders and paginates',
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
                  childAspectRatio: 1.67,
                  children: [
                    for (final panel in chapterPanels[c])
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
        await cache(tester);
        expect(find.byType(StoryIllustration), findsNWidgets(20));
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          key,
          '${storyNames[c].toLowerCase()}-illustration-check',
        );
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: StoryScreen(scene: chapterScenes[c].last),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(tester, key, '${storyNames[c].toLowerCase()}-ending');
        expect(find.text(chapterScenes[c].last.lines.first), findsOneWidget);
        await tester.tap(find.byKey(const Key('story-next')));
        await tester.pumpAndSettle();
        expect(find.text(chapterScenes[c].last.lines[1]), findsOneWidget);
        await tester.tap(find.byTooltip('Previous page'));
        await tester.pumpAndSettle();
        expect(find.text(chapterScenes[c].last.lines.first), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '${storyNames[c]} ending pauses the clock and leads to the next gate or bonus',
      (tester) async {
        final ending = c * 15 + 14;
        final game = GameController(levels)
          ..inventory.companions.addAll(List.generate(c + 1, (i) => i))
          ..completed.addAll(List.generate(ending, (i) => i))
          ..reset(ending);
        game.chooseCompanion(c);
        while (game.status == GameStatus.playing) {
          for (final id in game.puzzle.solve()!) {
            game.attempt(id);
            game.finish(id, game.epoch);
          }
        }
        final balance = game.rewards.coins;
        await tester.pumpWidget(PathOutApp(game: game));
        await cache(tester);
        expect(find.byType(StoryScreen), findsOneWidget);
        expect(find.text(chapterScenes[c].last.title), findsOneWidget);
        expect(game.rewards.running, false);
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(game.seenScenes, contains(chapterScenes[c].last.id));
        await tester.ensureVisible(find.byKey(const Key('result-continue')));
        await tester.tap(find.byKey(const Key('result-continue')));
        await tester.pumpAndSettle();
        expect(game.rewards.coins, balance);
        if (c < 3) {
          expect(find.byKey(const Key('unlock-chapter')), findsOneWidget);
          expect(game.index, ending);
          expect(game.isUnlocked(ending + 1), false);
        } else {
          expect(game.index, 60);
          expect(game.puzzle.name, 'The Crown Keeper');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        game.dispose();
      },
    );
  }
}
