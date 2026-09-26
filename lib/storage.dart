import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_controller.dart';

class ProgressStore {
  ProgressStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'path_out_progress_v1';
  final saveFailed = ValueNotifier(false);
  Future<void> _pending = Future.value();
  void restore(GameController game) {
    try {
      final data = preferences.getString(key);
      if (data != null) game.restore(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      /* A damaged save must never prevent starting the app. */
    }
  }

  Future<void> save(GameController game) {
    final data = jsonEncode(game.snapshot());
    // Serialize writes so a slow older write cannot overwrite newer progress.
    _pending = _pending.then((_) async {
      try {
        saveFailed.value = !await preferences.setString(key, data);
      } catch (_) {
        saveFailed.value = true;
      }
    });
    return _pending;
  }
}
