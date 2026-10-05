import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_controller.dart';

class ProgressStore {
  ProgressStore(this.preferences, {this.saveKey = key});
  final SharedPreferences preferences;
  static const key = 'path_out_progress_v1';
  static const adminKey = 'path_out_admin_testing_v2';
  final String saveKey;
  final saveFailed = ValueNotifier(false);
  Future<void> _pending = Future.value();
  void restore(GameController game) {
    try {
      final data = preferences.getString(saveKey);
      if (data != null) game.restore(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      /* A damaged save must never prevent starting the app. */
    }
  }

  Future<void> save(GameController game) {
    if (game.adminTesting && saveKey == key) {
      saveFailed.value = true;
      return Future.value();
    }
    final data = jsonEncode(game.snapshot());
    // Serialize writes so a slow older write cannot overwrite newer progress.
    _pending = _pending.then((_) async {
      try {
        saveFailed.value = !await preferences.setString(saveKey, data);
      } catch (_) {
        saveFailed.value = true;
      }
    });
    return _pending;
  }
}
