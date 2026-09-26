import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_controller.dart';
import 'game_screen.dart';
import 'puzzle.dart';
import 'storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final levels = Puzzle.decode(
      await rootBundle.loadString('assets/levels.json'),
    );
    final game = GameController(levels);
    ProgressStore? store;
    try {
      store = ProgressStore(await SharedPreferences.getInstance());
      store.restore(game);
      final progress = store;
      game.addListener(() {
        progress.save(game);
      });
    } catch (_) {
      /* Gameplay stays available if device storage is unavailable. */
    }
    runApp(
      PathOutApp(game: game, store: store, storageUnavailable: store == null),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'The puzzle pack could not be loaded. Please close and reopen Path Out.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PathOutApp extends StatelessWidget {
  const PathOutApp({
    super.key,
    required this.game,
    this.store,
    this.storageUnavailable = false,
  });
  final GameController game;
  final ProgressStore? store;
  final bool storageUnavailable;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Path Out',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF3F5FA),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF506BDF),
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF24334D),
          letterSpacing: -1,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF24334D),
        ),
        bodyMedium: TextStyle(color: Color(0xFF617087), height: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    home: GameScreen(
      game: game,
      store: store,
      storageUnavailable: storageUnavailable,
    ),
  );
}
