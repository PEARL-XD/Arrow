import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_out/game_audio.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/puzzle.dart';
import 'package:path_out/main.dart';
import 'package:path_out/story.dart';
import 'package:path_out/arrow_geometry.dart';
import 'package:path_out/companions.dart';

class RecordingSoundOutput implements SoundOutput {
  final played = <GameSound>[];
  int stops = 0, disposals = 0;
  Completer<void>? loading;
  bool fail = false;
  @override
  Future<void> preload() async {
    if (loading != null) await loading!.future;
    if (fail) throw StateError('No audio device');
  }

  @override
  Future<void> play(GameSound sound) async {
    if (fail) throw StateError('Interrupted');
    played.add(sound);
  }

  @override
  Future<void> stopAll() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

void main() {
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());

  test('Old voice preferences are ignored without losing player state', () {
    final game = GameController(levels);
    game.hints = 7;
    game.toggleSounds();
    final oldSave = game.snapshot()..['companionVoice'] = true;
    final restored = GameController(levels)..restore(oldSave);
    expect(restored.hints, 7);
    expect(restored.sounds, false);
    expect(restored.haptics, game.haptics);
    expect(restored.companionId, game.companionId);
    expect(restored.companionVisible, game.companionVisible);
    expect(restored.completed, game.completed);
    expect(restored.snapshot().containsKey('companionVoice'), false);
    game.dispose();
    restored.dispose();
  });

  test('Audio assets contain only the ten sound effects, not speech', () {
    final waveFiles = Directory('assets/audio')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.wav'))
        .map((file) => file.uri.pathSegments.last)
        .toSet();
    expect(
      waveFiles,
      GameSound.values.map((sound) => '${sound.name}.wav').toSet(),
    );
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('assets/audio/companions')),
    );
  });

  test(
    'Mute, overlays, background and disposal gate cues independently',
    () async {
      final output = RecordingSoundOutput();
      final audio = GameAudio(output: output);
      await audio.initialize();
      await audio.play(GameSound.glide);
      audio.configure(enabled: true, foreground: true, paused: true);
      await audio.play(GameSound.good);
      await audio.play(GameSound.pause, whilePaused: true);
      expect(output.played, [GameSound.glide, GameSound.pause]);
      audio.configure(enabled: false, foreground: true, paused: false);
      await audio.play(GameSound.resume, whilePaused: true);
      expect(output.stops, 1);
      audio.configure(enabled: true, foreground: false, paused: false);
      await audio.play(GameSound.victory, whilePaused: true);
      expect(output.stops, 2);
      audio.configure(enabled: true, foreground: true, paused: false);
      await audio.play(GameSound.nice);
      await audio.dispose();
      await audio.play(GameSound.hint);
      await audio.dispose();
      expect(output.played.last, GameSound.nice);
      expect(output.disposals, 1);
    },
  );

  test(
    'Startup never replays delayed taps; audio failures stay optional',
    () async {
      final output = RecordingSoundOutput()..loading = Completer<void>();
      final audio = GameAudio(output: output);
      final ready = audio.initialize();
      await audio.play(GameSound.glide);
      output.loading!.complete();
      await ready;
      expect(output.played, isEmpty);
      output.fail = true;
      await audio.play(GameSound.good);
      await audio.dispose();
      final unavailable = GameAudio(
        output: RecordingSoundOutput()..fail = true,
      );
      await unavailable.initialize();
      await unavailable.play(GameSound.hint);
      await unavailable.dispose();
    },
  );

  test(
    'Sound setting survives saves without changing haptics or progression',
    () {
      final game = GameController(levels)..toggleSounds();
      final restored = GameController(levels)..restore(game.snapshot());
      expect(restored.sounds, false);
      expect(restored.haptics, true);
      final old = game.snapshot()..remove('sounds');
      restored.restore(old);
      expect(restored.sounds, true);
      old['sounds'] = 'damaged preference';
      restored.restore(old);
      expect(restored.index, game.index);
      expect(restored.sounds, true);
      game.dispose();
      restored.dispose();
    },
  );

  test(
    'Every cue is bundled PCM audio with a safe peak and no silence-only file',
    () {
      for (final cue in GameSound.values) {
        final bytes = File('assets/audio/${cue.name}.wav').readAsBytesSync();
        final data = ByteData.sublistView(bytes);
        expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
        expect(data.getUint16(22, Endian.little), 1);
        expect(data.getUint32(24, Endian.little), 48000);
        expect(data.getUint16(34, Endian.little), 16);
        var peak = 0;
        for (var i = 44; i < bytes.length; i += 2) {
          final sample = data.getInt16(i, Endian.little).abs();
          if (sample > peak) peak = sample;
        }
        expect(peak, inInclusiveRange(1000, 26000));
        expect((bytes.length - 44) / 96000, inInclusiveRange(.1, 1.2));
      }
    },
  );

  testWidgets(
    'Actual taps produce glide, blocked, completion and hint cues; mute persists',
    (tester) async {
      final game = GameController(levels);
      game.seenScenes.addAll(allStoryScenes.map((s) => s.id));
      final output = RecordingSoundOutput();
      final audio = GameAudio(output: output);
      await audio.initialize();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(PathOutApp(game: game, audio: audio));
      await tester.pumpAndSettle();
      expect(find.byType(CompanionStrip), findsOneWidget);
      Future<void> tapArrow(int id) async {
        final board = find.byKey(const Key('maze-board'));
        final rect = tester.getRect(board), bounds = boardSize(game.puzzle);
        final head = cellPoint(
          game.puzzle.arrows.firstWhere((a) => a.id == id).head,
        );
        await tester.tapAt(
          rect.topLeft +
              Offset(
                head.dx / bounds.width * rect.width,
                head.dy / bounds.height * rect.height,
              ),
        );
        await tester.pump();
      }

      final blocked = game.puzzle.arrows.firstWhere(
        (a) => game.puzzle.blockers(a, game.removed).isNotEmpty,
      );
      await tapArrow(blocked.id);
      expect(output.played, [GameSound.blocked]);
      await tester.pumpAndSettle();
      final safe = game.puzzle.available(game.removed).first;
      final before = game.puzzle
          .available(game.removed)
          .map((a) => a.id)
          .toSet();
      await tapArrow(safe.id);
      expect(output.played.last, GameSound.glide);
      // Tapping while the current arrow flies must not add another cue.
      await tapArrow(safe.id);
      expect(output.played.where((s) => s == GameSound.glide).length, 1);
      await tester.pumpAndSettle();
      final freed = game.puzzle
          .available(game.removed)
          .where((a) => !before.contains(a.id))
          .length;
      expect(output.played.last, GameAudio.successfulMove(freed));
      await tester.tap(find.byTooltip('Hint · ${game.hints}'));
      await tester.pump();
      expect(output.played.last, GameSound.hint);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.textContaining('companion voice'), findsNothing);
      await tester.tap(find.text('Turn sounds off'));
      await tester.pumpAndSettle();
      expect(game.sounds, false);
      final count = output.played.length;
      await tapArrow(game.puzzle.available(game.removed).first.id);
      await tester.pumpAndSettle();
      expect(output.played.length, count);
      expect(game.haptics, true);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn sounds on'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a break'));
      await tester.pumpAndSettle();
      expect(output.played.last, GameSound.pause);
      await tester.tap(find.text('Keep playing'));
      await tester.pumpAndSettle();
      expect(output.played.last, GameSound.resume);
      while (game.status == GameStatus.playing) {
        await tapArrow(game.puzzle.available(game.removed).first.id);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }
      expect(output.played.last, GameSound.victory);
      await tester.pumpWidget(const SizedBox());
      expect(output.disposals, 1);
      game.dispose();
    },
  );
}
