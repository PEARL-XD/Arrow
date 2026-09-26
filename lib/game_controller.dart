import 'package:flutter/foundation.dart';
import 'puzzle.dart';

enum GameStatus { playing, won, lost }

enum MoveResult { ignored, blocked, moving }

class GameController extends ChangeNotifier {
  GameController(this.levels);
  final List<Puzzle> levels;
  int index = 0, lives = 3, hints = 3, epoch = 0;
  Set<int> removed = {}, completed = {};
  int? movingId;
  bool haptics = true;
  GameStatus get status => removed.length == puzzle.arrows.length
      ? GameStatus.won
      : lives == 0
      ? GameStatus.lost
      : GameStatus.playing;
  Puzzle get puzzle => levels[index];
  bool get busy => movingId != null;
  int get remaining => puzzle.arrows.length - removed.length;
  void reset([int? level]) {
    index = (level ?? index).clamp(0, levels.length - 1);
    removed = {};
    lives = 3;
    hints = 3;
    movingId = null;
    epoch++;
    notifyListeners();
  }

  void skip() => reset((index + 1) % levels.length);
  void toggleHaptics() {
    haptics = !haptics;
    notifyListeners();
  }

  ArrowRoute? hint() {
    if (busy || status != GameStatus.playing || hints == 0) return null;
    final choices = puzzle.available(removed);
    if (choices.isEmpty) return null;
    hints--;
    notifyListeners();
    return choices.first;
  }

  MoveResult attempt(int id) {
    if (busy || status != GameStatus.playing || removed.contains(id)) {
      return MoveResult.ignored;
    }
    final candidates = puzzle.arrows.where((a) => a.id == id);
    if (candidates.isEmpty) return MoveResult.ignored;
    if (puzzle.blockers(candidates.first, removed).isNotEmpty) {
      lives--;
      notifyListeners();
      return MoveResult.blocked;
    }
    movingId = id;
    notifyListeners();
    return MoveResult.moving;
  }

  bool finish(int id, int token) {
    if (token != epoch || movingId != id) return false;
    removed.add(id);
    movingId = null;
    if (status == GameStatus.won) completed.add(index);
    notifyListeners();
    return true;
  }

  Map<String, dynamic> snapshot() => {
    'version': 1,
    'index': index,
    'lives': lives,
    'hints': hints,
    'removed': removed.toList(),
    'completed': completed.toList(),
    'haptics': haptics,
  };
  void restore(Map<String, dynamic> data) {
    // A mid-flight arrow stays present in the save until its animation ends.
    if (data['version'] != 1) return;
    try {
      final newIndex = data['index'] as int;
      final newLives = data['lives'] as int, newHints = data['hints'] as int;
      final newHaptics = data['haptics'] as bool? ?? true;
      if (newIndex < 0 ||
          newIndex >= levels.length ||
          newLives < 0 ||
          newLives > 3 ||
          newHints < 0 ||
          newHints > 3) {
        return;
      }
      final newRemoved = (data['removed'] as List).cast<int>().toSet();
      final newCompleted = (data['completed'] as List).cast<int>().toSet();
      final ids = levels[newIndex].arrows.map((a) => a.id).toSet();
      if (!ids.containsAll(newRemoved) ||
          newCompleted.any((i) => i < 0 || i >= levels.length)) {
        return;
      }
      index = newIndex;
      lives = newLives;
      hints = newHints;
      removed = newRemoved;
      completed = newCompleted;
      haptics = newHaptics;
      movingId = null;
      epoch++;
      notifyListeners();
    } catch (_) {
      /* Old/corrupted saves leave the current puzzle untouched. */
    }
  }
}
