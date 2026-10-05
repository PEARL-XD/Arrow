import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_controller.dart';
import 'game_screen.dart';
import 'puzzle.dart';
import 'storage.dart';
import 'admin_testing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final levels = Puzzle.decode(
      await rootBundle.loadString('assets/levels.json'),
    );
    final legacy = Puzzle.decode(
      await rootBundle.loadString('assets/legacy-chapter-one.json'),
    );
    final game = GameController(
      levels,
      legacyLevels: legacy,
      adminTesting: adminTestingEnabled,
    );
    ProgressStore? store;
    try {
      final preferences = await SharedPreferences.getInstance();
      store = ProgressStore(
        preferences,
        saveKey: game.adminTesting ? ProgressStore.adminKey : ProgressStore.key,
      );
      // New testing save begins with Mira only, so chapter purchases can be tested.
      // Earlier test and normal player saves are preserved under their own keys.
      store.restore(game);
      final progress = store;
      game.addListener(() {
        progress.save(game);
      });
    } catch (_) {
      /* Gameplay stays available if device storage is unavailable. */
    }
    game.refillTestCoins();
    runApp(
      PathOutApp(
        game: game,
        store: store,
        storageUnavailable: store == null,
        initializeAds: true,
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'The puzzle pack could not be loaded. Please close and reopen ARROW: THE LAST LANTERN.',
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
    this.initializeAds = false,
  });
  final GameController game;
  final ProgressStore? store;
  final bool storageUnavailable;
  final bool initializeAds;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ARROW: THE LAST LANTERN',
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
      initializeAds: initializeAds,
    ),
  );
}
