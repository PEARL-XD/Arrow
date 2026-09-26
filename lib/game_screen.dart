import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'arrow_geometry.dart';
import 'board.dart';
import 'game_controller.dart';
import 'storage.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.game,
    this.store,
    this.storageUnavailable = false,
  });
  final GameController game;
  final ProgressStore? store;
  final bool storageUnavailable;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(vsync: this);
  final transform = TransformationController();
  Timer? feedbackTimer;
  int? highlighted, blocked;
  double travel = 0, zoom = 1, boardPixels = 1;
  String message = 'Tap an arrow with a clear way out.';
  GameController get game => widget.game;
  @override
  void dispose() {
    feedbackTimer?.cancel();
    motion.dispose();
    transform.dispose();
    super.dispose();
  }

  void load(int index) {
    motion.stop();
    feedbackTimer?.cancel();
    highlighted = null;
    blocked = null;
    travel = 0;
    transform.value = Matrix4.identity();
    zoom = 1;
    game.reset(index);
    setState(() => message = 'Tap an arrow with a clear way out.');
  }

  void play(int id) {
    final result = game.attempt(id);
    if (result == MoveResult.ignored) return;
    feedbackTimer?.cancel();
    highlighted = null;
    blocked = null;
    if (result == MoveResult.blocked) {
      if (game.haptics) HapticFeedback.mediumImpact();
      setState(() {
        blocked = id;
        message = 'Blocked ahead. Follow the arrowhead’s exit lane.';
      });
      feedbackTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => blocked = null);
      });
      return;
    }
    if (game.haptics) HapticFeedback.selectionClick();
    final arrow = game.puzzle.arrows.firstWhere((a) => a.id == id);
    final token = game.epoch;
    travel = exitDistance(game.puzzle, arrow);
    motion.duration = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context)
          ? 150
          : (travel * 23).round().clamp(450, 1800),
    );
    setState(() => message = 'Clear path. Watch the tail follow.');
    motion
        .forward(from: 0)
        .orCancel
        .then((_) {
          if (!mounted || !game.finish(id, token)) return;
          setState(() => message = 'Find the next clear exit.');
        })
        .catchError((Object error) {
          if (error is! TickerCanceled) throw error;
        });
  }

  void hint() {
    final arrow = game.hint();
    if (arrow == null) return;
    feedbackTimer?.cancel();
    transform.value = Matrix4.identity();
    zoom = 1;
    setState(() {
      highlighted = arrow.id;
      blocked = null;
      message = 'The blue arrow can escape. Tap it when you’re ready.';
    });
    feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => highlighted = null);
    });
  }

  void setZoom(double next) {
    final value = next.clamp(1.0, 4.0);
    final center = Offset(boardPixels / 2, boardPixels / 2);
    final scene = transform.toScene(center);
    transform.value = Matrix4.identity()
      ..setEntry(0, 0, value)
      ..setEntry(1, 1, value)
      ..setEntry(0, 3, center.dx - scene.dx * value)
      ..setEntry(1, 3, center.dy - scene.dy * value);
    if (value == 1) transform.value = Matrix4.identity();
    setState(() => zoom = value);
  }

  Future<void> chooseLevel() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              Text(
                'Your journey',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  '${game.completed.length} of ${game.levels.length} cleared · All levels open for testing',
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisExtent: 112,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: game.levels.length,
                  itemBuilder: (context, i) => Material(
                    color: i == game.index
                        ? const Color(0xFFE7ECFF)
                        : const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(context, i),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${i + 1}'.padLeft(2, '0'),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                if (game.completed.contains(i))
                                  const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Color(0xFF438575),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              game.levels[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              game.levels[i].difficulty,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) load(selected);
  }

  void showHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Untangle the way out'),
      content: const Text(
        'Tap anywhere on an arrow. Its head moves straight forward and its tail follows the bends.\n\nThe entire lane ahead must be empty—even beyond a gap in the shape. A blocked tap costs one heart.\n\nPinch to zoom and drag to inspect. Hints highlight a safe arrow. Every starting dot belongs to exactly one arrow.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Let’s play'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: game,
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF506BDF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.turn_right_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Path Out',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: game.haptics
                            ? 'Turn haptics off'
                            : 'Turn haptics on',
                        onPressed: game.toggleHaptics,
                        icon: Icon(
                          game.haptics ? Icons.vibration : Icons.mobile_off,
                        ),
                      ),
                      IconButton(
                        tooltip: 'How to play',
                        onPressed: showHelp,
                        icon: const Icon(Icons.help_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEVEL ${'${game.index + 1}'.padLeft(2, '0')} / ${game.levels.length}  ·  ${game.puzzle.difficulty.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: Color(0xFF6B7890),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              game.puzzle.name,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: '${game.lives} lives remaining',
                        child: ExcludeSemantics(
                          child: Row(
                            children: List.generate(
                              3,
                              (i) => Icon(
                                i < game.lives
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 21,
                                color: i < game.lives
                                    ? const Color(0xFFDA737A)
                                    : const Color(0xFFBCC5D3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${game.remaining} arrows remaining',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Zoom out',
                        onPressed: zoom > 1 ? () => setZoom(zoom - .5) : null,
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      Text(
                        '${zoom.toStringAsFixed(1)}×',
                        style: const TextStyle(fontSize: 12),
                      ),
                      IconButton(
                        tooltip: 'Zoom in',
                        onPressed: zoom < 4 ? () => setZoom(zoom + .5) : null,
                        icon: const Icon(Icons.add, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Fit board',
                        onPressed: () => setZoom(1),
                        icon: const Icon(Icons.fit_screen, size: 20),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E7F0)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(23),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            boardPixels = constraints.maxWidth;
                            return Stack(
                              children: [
                                InteractiveViewer(
                                  transformationController: transform,
                                  minScale: 1,
                                  maxScale: 4,
                                  onInteractionEnd: (_) => setState(
                                    () => zoom = transform.value
                                        .getMaxScaleOnAxis(),
                                  ),
                                  child: GestureDetector(
                                    key: const Key('maze-board'),
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (details) {
                                      final bounds = boardSize(game.puzzle);
                                      final point = Offset(
                                        details.localPosition.dx /
                                            boardPixels *
                                            bounds.width,
                                        details.localPosition.dy /
                                            boardPixels *
                                            bounds.height,
                                      );
                                      final arrow = hitArrow(
                                        game.puzzle,
                                        game.removed,
                                        point,
                                      );
                                      if (arrow != null) play(arrow.id);
                                    },
                                    child: CustomPaint(
                                      size: Size.square(boardPixels),
                                      painter: MazePainter(
                                        game: game,
                                        animation: motion,
                                        travel: travel,
                                        onArrow: play,
                                        highlight: highlighted,
                                        blocked: blocked,
                                      ),
                                    ),
                                  ),
                                ),
                                if (game.status != GameStatus.playing)
                                  Positioned.fill(child: resultCard(context)),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: game.removed.length / game.puzzle.arrows.length,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFE1E6F0),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => load(game.index),
                          child: const Text('Restart'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              load((game.index + 1) % game.levels.length),
                          child: const Text('Skip level'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              game.hints > 0 &&
                                  !game.busy &&
                                  game.status == GameStatus.playing
                              ? hint
                              : null,
                          child: Text('Hint · ${game.hints}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: chooseLevel,
                    icon: const Icon(Icons.grid_view_rounded, size: 17),
                    label: Text(
                      'Levels  ·  ${game.completed.length}/${game.levels.length} cleared',
                    ),
                  ),
                  Text(
                    game.index < 8
                        ? 'LEARN THE FLOW  ·  First 20%'
                        : 'ONE CLEAR PATH AT A TIME',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      color: Color(0xFF8994A7),
                    ),
                  ),
                  if (widget.storageUnavailable)
                    const Text(
                      'Storage unavailable. Progress will last for this session only.',
                    ),
                  if (widget.store != null)
                    ValueListenableBuilder(
                      valueListenable: widget.store!.saveFailed,
                      builder: (_, failed, _) => failed
                          ? const Text(
                              'Progress could not be saved on this device.',
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget resultCard(BuildContext context) {
    final won = game.status == GameStatus.won;
    final all = game.completed.length == game.levels.length;
    return ColoredBox(
      color: Colors.white.withValues(alpha: .96),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won
                    ? Icons.check_circle_outline_rounded
                    : Icons.refresh_rounded,
                size: 54,
                color: won ? const Color(0xFF438575) : const Color(0xFF506BDF),
              ),
              const SizedBox(height: 14),
              Text(
                won
                    ? (all ? 'Every path cleared.' : 'Beautifully untangled.')
                    : 'A fresh look?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                won
                    ? '${game.completed.length} of ${game.levels.length} puzzles complete.'
                    : 'Three blocked taps. Restart and trace the exit lanes.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => load(
                  won ? (game.index + 1) % game.levels.length : game.index,
                ),
                child: Text(
                  won ? (all ? 'Play again' : 'Next level') : 'Try again',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
