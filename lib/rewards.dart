import 'dart:math' as math;
import 'campaign.dart';

({int gold, int silver}) bonusTargets(int level) {
  final chapter = (level ~/ chapterLength).clamp(0, 3);
  final gold = [45, 90, 180, 240][chapter];
  final silver = [60, 120, 240, 300][chapter];
  final boss = (level + 1) % chapterLength == 0 || level >= storyLevelCount;
  return (
    gold: gold * (boss ? 1500 : 1000),
    silver: silver * (boss ? 1500 : 1000),
  );
}

int speedBonus(int milliseconds, {int level = 0}) =>
    milliseconds < bonusTargets(level).gold
    ? 10
    : milliseconds < bonusTargets(level).silver
    ? 5
    : 0;

String formatTime(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}.${(milliseconds % 1000 ~/ 100)}';
}

/// Replays always pay a base; performance tiers only pay their unpaid difference.
class RunRewards {
  RunRewards({int Function()? now}) : _nowOverride = now;
  final int Function()? _nowOverride;
  final Stopwatch _clock = Stopwatch()..start();
  int get _now => _nowOverride?.call() ?? _clock.elapsedMilliseconds;
  int _elapsed = 0;
  int? _started;
  int coins = 0, skill = 0, lastBase = 0, lastSpeed = 0, lastSkill = 0;
  int lastRecord = 0;
  bool eligible = true;
  final bestTimes = <int, int>{};
  final lastTimes = <int, int>{};
  final paidSpeed = <int, int>{};
  final paidSkill = <int, int>{};
  int get elapsed =>
      _elapsed + (_started == null ? 0 : math.max(0, _now - _started!));
  int get lastTotal => lastBase + lastSpeed + lastSkill + lastRecord;
  bool get running => _started != null;
  void resume() => _started ??= _now;
  void pause() {
    _elapsed = elapsed;
    _started = null;
  }

  void reset() {
    _elapsed = 0;
    _started = null;
    skill = 0;
    lastBase = lastSpeed = lastSkill = 0;
    lastRecord = 0;
    eligible = true;
  }

  void greatMove() {
    skill = math.min(20, skill + 4);
  }

  void complete(int level, {required bool firstClear}) {
    pause();
    lastBase = firstClear ? 70 : 30;
    final previous = bestTimes[level];
    lastRecord =
        !firstClear && eligible && previous != null && elapsed < previous
        ? 5
        : 0;
    final bonus = eligible ? speedBonus(elapsed, level: level) : 0;
    lastSpeed = math.max(0, bonus - (paidSpeed[level] ?? 0));
    lastSkill = math.max(0, skill - (paidSkill[level] ?? 0));
    paidSpeed[level] = math.max(bonus, paidSpeed[level] ?? 0);
    paidSkill[level] = math.max(skill, paidSkill[level] ?? 0);
    coins += lastTotal;
    if (eligible) {
      lastTimes[level] = elapsed;
      bestTimes[level] = math.min(elapsed, bestTimes[level] ?? elapsed);
    }
  }

  Map<String, Object> snapshot() => {
    'coins': coins,
    'elapsed': elapsed,
    'eligible': eligible,
    'skill': skill,
    'lastBase': lastBase,
    'lastSpeed': lastSpeed,
    'lastSkill': lastSkill,
    'lastRecord': lastRecord,
    'best': bestTimes.map((k, v) => MapEntry('$k', v)),
    'times': lastTimes.map((k, v) => MapEntry('$k', v)),
    'speed': paidSpeed.map((k, v) => MapEntry('$k', v)),
    'skills': paidSkill.map((k, v) => MapEntry('$k', v)),
  };
  static RunRewards decode(Object? raw, int levelCount, {int Function()? now}) {
    final result = RunRewards(now: now);
    if (raw == null) return result;
    final data = raw as Map;
    int number(String key, int max) {
      final value = data[key];
      if (value is! int || value < 0 || value > max) {
        throw const FormatException('Invalid economy');
      }
      return value;
    }

    result.coins = number('coins', 100000000);
    result._elapsed = number('elapsed', 31536000000);
    result.skill = number('skill', 20);
    result.lastBase = number('lastBase', 70);
    result.lastSpeed = number('lastSpeed', 10);
    result.lastSkill = number('lastSkill', 20);
    result.lastRecord = data.containsKey('lastRecord')
        ? number('lastRecord', 5)
        : 0;
    result.eligible = data['eligible'] as bool;
    void readMap(String key, Map<int, int> target, int max) {
      for (final entry in (data[key] as Map).entries) {
        final id = int.parse(entry.key as String);
        final value = entry.value;
        if (id < 0 ||
            id >= levelCount ||
            value is! int ||
            value < 0 ||
            value > max) {
          throw const FormatException('Invalid record');
        }
        target[id] = value;
      }
    }

    readMap('best', result.bestTimes, 31536000000);
    readMap('times', result.lastTimes, 31536000000);
    readMap('speed', result.paidSpeed, 10);
    readMap('skills', result.paidSkill, 20);
    return result;
  }
}
