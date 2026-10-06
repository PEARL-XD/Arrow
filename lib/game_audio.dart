import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum GameSound {
  glide,
  good,
  nice,
  great,
  blocked,
  pause,
  resume,
  hint,
  victory,
  loss,
}

abstract interface class SoundOutput {
  Future<void> preload();
  Future<void> play(GameSound sound);
  Future<void> stopAll();
  Future<void> dispose();
}

/// Isolates native audio from puzzle rules and allows headless UI tests.
class SilentSoundOutput implements SoundOutput {
  @override
  Future<void> preload() async {}
  @override
  Future<void> play(GameSound sound) async {}
  @override
  Future<void> stopAll() async {}
  @override
  Future<void> dispose() async {}
}

class NativeSoundOutput implements SoundOutput {
  final _players = <GameSound, AudioPlayer>{};
  Future<void> _tail = Future.value();

  // Ordering prevents a late native resume from undoing mute/background stop.
  Future<void> _ordered(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> preload() => _ordered(() async {
    final context = AudioContext(
      android: const AudioContextAndroid(
        usageType: AndroidUsageType.game,
        contentType: AndroidContentType.sonification,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    );
    for (final sound in GameSound.values) {
      final player = AudioPlayer();
      // Short cues need no progress stream. Low-latency playback has no
      // completion event, so frame polling would otherwise run indefinitely.
      player.positionUpdater = null;
      _players[sound] = player;
      await player.setAudioContext(context);
      await player.setReleaseMode(ReleaseMode.stop);
      if (defaultTargetPlatform == TargetPlatform.android) {
        await player.setPlayerMode(PlayerMode.lowLatency);
      }
      await player.setVolume(.55);
      await player.setSource(AssetSource('audio/${sound.name}.wav'));
    }
  });

  @override
  Future<void> play(GameSound sound) => _ordered(() async {
    final player = _players[sound];
    if (player == null) return;
    await player.stop();
    await player.resume();
  });

  @override
  Future<void> stopAll() => _ordered(() async {
    for (final player in _players.values) {
      await player.stop();
    }
  });

  @override
  Future<void> dispose() => _ordered(() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  });
}

class GameAudio {
  GameAudio({required this.output});
  final SoundOutput output;
  bool _enabled = true, _foreground = true, _paused = false;
  bool _ready = false, _disposed = false;
  Future<void>? _initializing;

  Future<void> initialize() => _initializing ??= _safely(() async {
    await output.preload();
    if (!_disposed) _ready = true;
  });

  void configure({
    required bool enabled,
    required bool foreground,
    required bool paused,
  }) {
    final shouldStop = (_enabled && !enabled) || (_foreground && !foreground);
    _enabled = enabled;
    _foreground = foreground;
    _paused = paused;
    if (!_disposed && shouldStop) unawaited(_safely(output.stopAll));
  }

  Future<void> play(GameSound sound, {bool whilePaused = false}) async {
    // Drop cues during startup instead of playing an old tap after loading.
    if (!_ready ||
        _disposed ||
        !_enabled ||
        !_foreground ||
        (_paused && !whilePaused)) {
      return;
    }
    await _safely(() => output.play(sound));
  }

  static GameSound successfulMove(int newlyFreed) => newlyFreed >= 2
      ? GameSound.great
      : newlyFreed == 1
      ? GameSound.nice
      : GameSound.good;

  Future<void> stop() => _safely(output.stopAll);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _ready = false;
    await _safely(output.dispose);
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      // Audio is optional: interruptions or missing devices cannot stop play.
      debugPrint('Game audio unavailable: $error');
    }
  }
}
