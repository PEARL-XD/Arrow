import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'arrow_geometry.dart';
import 'board.dart';
import 'game_controller.dart';
import 'storage.dart';
import 'companions.dart';
import 'rewards.dart';
import 'level_result.dart';
import 'shop_screen.dart';
import 'story.dart';
import 'story_screen.dart';
import 'chapter_gate.dart';
import 'campaign.dart';
import 'reward_options.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
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
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController motion = AnimationController(vsync: this);
  final transform = TransformationController();
  final pageScroll = ScrollController();
  final reactions = CompanionReactions();
  bool resting = false, leaving = false;
  bool advancing = false;
  bool presentingStory = false;
  int quietThought = 0;
  Timer? feedbackTimer, idleTimer, saveTimer;
  bool foreground = true;
  int overlayDepth = 0;
  int? highlighted, blocked;
  double travel = 0, zoom = 1, boardPixels = 1;
  String message = 'Tap an arrow with a clear way out.';
  GameController get game => widget.game;
  bool get activePuzzle =>
      foreground &&
      !resting &&
      overlayDepth == 0 &&
      game.status == GameStatus.playing;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game.addListener(gameChanged);
    reactions.selectCharacter(game.companionId);
    if (game.removed.isEmpty &&
        game.status == GameStatus.playing &&
        game.companionVisible) {
      welcome();
    }
    game.resumeTiming();
    scheduleIdle();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && widget.initializeAds) {
        pauseActivity();
        await prepareGameAds(context);
        resumeActivity();
      }
      if (mounted && game.pendingScenes.isNotEmpty) {
        presentPendingStories();
        return;
      }
      if (mounted &&
          game.index < storyLevelCount &&
          game.index % chapterLength == 0 &&
          game.status == GameStatus.playing) {
        showScene(chapterScenes[game.index ~/ chapterLength].first.id);
      }
    });
    saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (activePuzzle) widget.store?.save(game);
    });
  }

  void welcome() {
    if (game.index < storyLevelCount &&
        game.companionId == game.companionForLevel(game.index)) {
      reactions.react(
        CompanionMood.idle,
        chapterWelcome(game.index),
        milliseconds: 4500,
      );
    } else {
      reactions.welcome(lives: game.maxLives);
    }
  }

  Future<void> showScene(String id, {bool replay = false}) async {
    if (!mounted || (!replay && game.seenScenes.contains(id))) return;
    final scene = allStoryScenes.firstWhere((s) => s.id == id);
    if (!game.inventory.companions.contains(scene.chapter)) return;
    if (!availableScene(id)) return;
    pauseActivity();
    reactions.reset();
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => StoryScreen(scene: scene)),
      );
      if (mounted) game.markSceneSeen(id);
    } finally {
      resumeActivity();
    }
    if (mounted && activePuzzle && game.companionVisible) welcome();
  }

  bool availableScene(String id) =>
      game.adminTesting ||
      storyAvailable(id, game.completed, game.index, game.bossPhase);

  Future<void> presentPendingStories() async {
    if (!mounted || presentingStory || overlayDepth > 0 || !foreground) return;
    presentingStory = true;
    try {
      while (mounted && game.pendingScenes.isNotEmpty) {
        final id = game.pendingScenes.first;
        await showScene(id, replay: true);
        if (game.pendingScenes.contains(id)) break;
      }
    } finally {
      presentingStory = false;
    }
  }

  Future<void> skipForTesting() async {
    if (!game.adminTesting || advancing || presentingStory) return;
    motion.stop();
    feedbackTimer?.cancel();
    highlighted = blocked = null;
    game.clearForTesting();
    await presentPendingStories();
    if (!mounted) return;
    if (game.status == GameStatus.won) await continueResult();
  }

  Future<void> journal() async {
    pauseActivity();
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Story journal',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const Text('Revisit discovered memories'),
              for (var chapter = 0; chapter < chapterScenes.length; chapter++)
                if (game.inventory.companions.contains(chapter) &&
                    (game.adminTesting ||
                        chapter == 0 ||
                        game.completed.contains(
                          chapter * chapterLength - 1,
                        ))) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 8),
                    child: Text(
                      '${storyNames[chapter]} · ${storyTitles[chapter]}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final scene in chapterScenes[chapter])
                    ListTile(
                      leading: Icon(
                        availableScene(scene.id)
                            ? Icons.auto_stories
                            : Icons.lock_outline,
                      ),
                      title: Text(
                        availableScene(scene.id)
                            ? scene.title
                            : 'An undiscovered memory',
                      ),
                      onTap: availableScene(scene.id)
                          ? () => Navigator.pop(context, scene.id)
                          : null,
                    ),
                ],
            ],
          ),
        ),
      ),
    );
    resumeActivity();
    if (id != null && mounted) await showScene(id, replay: true);
  }

  Future<void> nextChapter(int id) async {
    pauseActivity();
    final target = await showChapterGate(context, game, id);
    resumeActivity();
    if (!mounted || target == null) return;
    if (target < 0) {
      await chooseLevel();
    } else {
      game.chooseCompanion(id);
      load(target);
    }
  }

  Future<void> continueResult() async {
    if (advancing || presentingStory) return;
    advancing = true;
    try {
      if (game.status == GameStatus.lost) {
        if (game.retryCheckpoint()) {
          transform.value = Matrix4.identity();
          zoom = 1;
          highlighted = blocked = null;
          if (activePuzzle) game.resumeTiming();
          scheduleIdle();
          setState(() {});
        } else {
          load(game.index);
        }
        return;
      }
      await presentPendingStories();
      if (!mounted) return;
      if (game.chapterEnd && game.index < storyLevelCount - 1) {
        await nextChapter((game.index + 1) ~/ chapterLength);
      } else if (game.canAdvance) {
        load(game.index + 1);
      } else {
        await chooseLevel();
      }
    } finally {
      advancing = false;
    }
  }

  void gameChanged() {
    if (reactions.characterId != game.companionId) {
      reactions.selectCharacter(game.companionId);
    }
    if (!activePuzzle || !game.companionVisible) idleTimer?.cancel();
    if (game.pendingScenes.isNotEmpty && !presentingStory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) presentPendingStories();
      });
    }
  }

  void scheduleIdle({int seconds = 8}) {
    idleTimer?.cancel();
    if (!activePuzzle || !game.companionVisible) return;
    idleTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted || !activePuzzle || !game.companionVisible || game.busy) {
        return;
      }
      if (game.index < chapterLength &&
          game.companionId == 0 &&
          reactions.line == null) {
        final local = previousStageOffsets.lastIndexWhere(
          (p) => p <= game.index,
        );
        reactions.react(CompanionMood.thinking, switch (quietThought++ % 3) {
          0 => miraThoughts[local],
          1 => miraQuietThoughts[local],
          _ => reactions.nextLine(CompanionEvent.idle),
        }, milliseconds: 5000);
      } else {
        reactions.idleThought();
      }
      scheduleIdle(seconds: 24);
    });
  }

  void pauseActivity() {
    overlayDepth++;
    idleTimer?.cancel();
    game.pauseTiming();
    widget.store?.save(game);
  }

  void resumeActivity() {
    if (overlayDepth > 0) overlayDepth--;
    if (!mounted) return;
    if (activePuzzle) game.resumeTiming();
    scheduleIdle();
    if (!presentingStory && game.pendingScenes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) presentPendingStories();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      idleTimer?.cancel();
      game.pauseTiming();
      widget.store?.save(game);
    } else {
      if (activePuzzle) {
        game.resumeTiming();
        scheduleIdle();
      }
      if (game.pendingScenes.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) presentPendingStories();
        });
      }
    }
  }

  @override
  void dispose() {
    feedbackTimer?.cancel();
    idleTimer?.cancel();
    saveTimer?.cancel();
    game.removeListener(gameChanged);
    game.pauseTiming();
    WidgetsBinding.instance.removeObserver(this);
    reactions.dispose();
    motion.dispose();
    transform.dispose();
    pageScroll.dispose();
    super.dispose();
  }

  void load(int index) {
    if (!game.isUnlocked(index)) return;
    if (pageScroll.hasClients) pageScroll.jumpTo(0);
    motion.stop();
    feedbackTimer?.cancel();
    highlighted = null;
    blocked = null;
    travel = 0;
    transform.value = Matrix4.identity();
    zoom = 1;
    game.reset(index);
    quietThought = 0;
    reactions.newPuzzle();
    resting = false;
    if (activePuzzle) game.resumeTiming();
    if (game.companionVisible) welcome();
    scheduleIdle();
    setState(() => message = 'Tap an arrow with a clear way out.');
    if (index < storyLevelCount && index % chapterLength == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && game.index == index) {
          showScene(chapterScenes[index ~/ chapterLength].first.id);
        }
      });
    }
  }

  void play(int id) {
    if (!activePuzzle) return;
    final phaseBefore = game.bossPhase;
    final clearBefore = game.puzzle
        .available(game.removed)
        .map((a) => a.id)
        .toSet();
    final result = game.attempt(id);
    if (result == MoveResult.ignored) return;
    scheduleIdle();
    feedbackTimer?.cancel();
    highlighted = null;
    blocked = null;
    if (result == MoveResult.blocked) {
      if (game.companionVisible) {
        reactions.blocked(lives: game.lives);
      }
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
          if (game.bossPhase != phaseBefore) {
            motion.value = 0;
            transform.value = Matrix4.identity();
            zoom = 1;
            return;
          }
          if (game.companionVisible) {
            final newlyFreed = game.puzzle
                .available(game.removed)
                .where((a) => !clearBefore.contains(a.id))
                .length;
            reactions.moved(
              newlyFreed,
              remaining: game.remaining,
              total: game.puzzle.arrows.length,
            );
          }
          scheduleIdle();
          setState(() => message = 'Find the next clear exit.');
        })
        .catchError((Object error) {
          if (error is! TickerCanceled) throw error;
        });
  }

  void hint() {
    if (game.hints == 0) {
      hintShop();
      return;
    }
    scheduleIdle();
    final arrow = game.hint();
    if (arrow == null) return;
    if (game.companionVisible) {
      reactions.hint();
    }
    feedbackTimer?.cancel();
    transform.value = Matrix4.identity();
    zoom = 1;
    setState(() {
      highlighted = arrow.id;
      blocked = null;
      message = 'The circled arrow can escape. Tap it when you’re ready.';
    });
    feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => highlighted = null);
    });
  }

  void setZoom(double next) {
    scheduleIdle();
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

  Future<void> hintShop() => openShop();

  Future<void> adPrivacy() async {
    pauseActivity();
    try {
      final message = await rewardAds.privacyOptions();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      resumeActivity();
    }
  }

  Future<void> reviveRun({required bool ad}) async {
    pauseActivity();
    try {
      final success = ad
          ? await watchReward(context, game, RewardKind.revive)
          : game.revive();
      if (mounted && success) {
        highlighted = blocked = null;
        setState(
          () => message = 'Hearts restored. Your cleared paths are still open.',
        );
      }
    } finally {
      resumeActivity();
    }
  }

  Future<void> openShop({int tab = 0}) async {
    pauseActivity();
    try {
      await showCoinShop(context, game, tab: tab);
    } finally {
      resumeActivity();
    }
  }

  Future<void> chooseCompanion() async {
    pauseActivity();
    final selected = await showCompanionPicker(
      context,
      game.companionId,
      game.companionVisible,
      owned: game.inventory.companions,
    );
    resumeActivity();
    if (!mounted || selected == null) return;
    reactions.reset();
    if (selected == -2) {
      await openShop(tab: 1);
    } else if (selected == -1) {
      game.hideCompanion();
    } else {
      game.chooseCompanion(selected);
    }
    scheduleIdle();
  }

  Future<void> leavePuzzle() async {
    if (leaving || resting) return;
    leaving = true;
    pauseActivity();
    final goodbye = reactions.nextLine(CompanionEvent.goodbye);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take a break?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (game.companionVisible) ...[
              CompanionPortrait(
                id: game.companionId,
                mood: CompanionMood.goodbye,
                size: 104,
              ),
              const SizedBox(height: 12),
              Text(goodbye),
              const SizedBox(height: 8),
            ],
            const Text(
              'You can continue this puzzle whenever you’re ready.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave puzzle'),
          ),
        ],
      ),
    );
    leaving = false;
    resumeActivity();
    if (!mounted || leave != true) return;
    motion.stop();
    game.cancelFlight();
    feedbackTimer?.cancel();
    reactions.reset();
    highlighted = blocked = null;
    setState(() => resting = true);
    idleTimer?.cancel();
    game.pauseTiming();
    await widget.store?.save(game);
  }

  Widget restingScreen(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.turn_right_rounded,
                size: 64,
                color: Color(0xFF506BDF),
              ),
              const SizedBox(height: 16),
              Text(
                'ARROW: THE LAST LANTERN',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text('A little pause. A fresh perspective.'),
              const SizedBox(height: 24),
              if (game.companionVisible)
                CompanionPortrait(id: game.companionId, size: 104),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => setState(() {
                  resting = false;
                  if (activePuzzle) game.resumeTiming();
                  scheduleIdle();
                  message = 'Tap an arrow with a clear way out.';
                }),
                child: const Text('Continue puzzle'),
              ),
              TextButton(
                onPressed: chooseCompanion,
                child: const Text('Companions'),
              ),
              if (widget.storageUnavailable)
                const Text('Progress is kept for this session only.'),
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
  );

  Future<void> chooseLevel() async {
    pauseActivity();
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
                  'Discover one chapter at a time. Complete each stage to open the next path.',
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
                  itemCount: game.discoveredLevelCount,
                  itemBuilder: (context, i) => Material(
                    color: i == game.index
                        ? const Color(0xFFE7ECFF)
                        : game.levels[i].isBoss
                        ? const Color(0xFFFFF2DA)
                        : const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: game.isUnlocked(i)
                          ? () => Navigator.pop(context, i)
                          : (game.adminTesting || i == game.frontier) &&
                                game.companionAvailable(
                                  game.companionForLevel(i),
                                ) &&
                                !game.inventory.companions.contains(
                                  game.companionForLevel(i),
                                )
                          ? () => Navigator.pop(
                              context,
                              -game.companionForLevel(i),
                            )
                          : null,
                      child: Semantics(
                        label:
                            '${game.levels[i].isBoss ? 'Boss' : 'Level ${i + 1}'}, ${game.isUnlocked(i) ? 'unlocked' : 'locked'}',
                        child: Opacity(
                          opacity: game.isUnlocked(i) ? 1 : .5,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      game.levels[i].isBoss
                                          ? 'BOSS'
                                          : '${i + 1}'.padLeft(2, '0'),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!game.isUnlocked(i))
                                      const Icon(
                                        Icons.lock_outline_rounded,
                                        size: 18,
                                      ),
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
                                  game.isUnlocked(i)
                                      ? (game.rewards.bestTimes[i] == null
                                            ? game.levels[i].difficulty
                                            : 'Best ${formatTime(game.rewards.bestTimes[i]!)}')
                                      : 'Locked',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
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
    resumeActivity();
    if (selected != null && mounted) {
      if (selected < 0) {
        await nextChapter(-selected);
      } else {
        load(selected);
      }
    }
  }

  Future<void> showHelp() async {
    pauseActivity();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Untangle the way out'),
        scrollable: true,
        content: const Text(
          'Tap anywhere on an arrow. Its head moves straight forward and its tail follows the bends.\n\nThe entire lane ahead must be empty—even beyond a gap in the shape. A blocked tap costs one heart.\n\nYour journey begins with three hearts. Later chapters have two, then one. The Lantern Keeper has two stages; clearing the outer seal restores your hearts and saves a checkpoint.\n\nPinch to zoom and drag to inspect. Hints highlight a safe arrow. Every two clears (including replays) earn one hint. A coin revive restores hearts without resetting cleared arrows. Every starting dot belongs to exactly one arrow.\n\nStory scenes pause the timer and can be skipped. Revisit discovered scenes through More options → Story journal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Let’s play'),
          ),
        ],
      ),
    );

    resumeActivity();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: resting,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leavePuzzle();
    },
    child: ListenableBuilder(
      listenable: game,
      builder: (context, _) =>
          resting ? restingScreen(context) : puzzleScreen(context),
    ),
  );

  Widget actionIcon(
    String label,
    IconData icon,
    VoidCallback? action, {
    String? badge,
  }) => IconButton.filledTonal(
    tooltip: label,
    onPressed: action,
    style: IconButton.styleFrom(
      minimumSize: const Size(52, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    icon: badge == null
        ? Icon(icon)
        : Badge(label: Text(badge), child: Icon(icon)),
  );

  Widget puzzleScreen(BuildContext context) => Scaffold(
    backgroundColor: game.inventory.theme.background,
    bottomNavigationBar: SafeArea(
      top: false,
      child: Material(
        color: game.inventory.theme.background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (game.adminTesting)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ADMIN TEST · separate save',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9C641B),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('admin-skip'),
                      onPressed:
                          !advancing &&
                              !presentingStory &&
                              game.status == GameStatus.playing
                          ? skipForTesting
                          : null,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('Skip (test)'),
                    ),
                  ],
                ),
              Row(
                key: const Key('bottom-controls'),
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  actionIcon(
                    'Restart',
                    Icons.restart_alt_rounded,
                    () => load(game.index),
                  ),
                  actionIcon(
                    'Hint · ${game.hints}',
                    Icons.lightbulb_outline_rounded,
                    !game.busy && game.status == GameStatus.playing
                        ? hint
                        : null,
                    badge: '${game.hints}',
                  ),
                  actionIcon('Companions', Icons.face_rounded, chooseCompanion),
                  actionIcon('Shop', Icons.storefront_rounded, openShop),
                  actionIcon('Levels', Icons.grid_view_rounded, chooseLevel),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: SingleChildScrollView(
            controller: pageScroll,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.isBoss
                                ? (game.index == chapterLength - 1
                                      ? 'LANTERN KEEPER · STAGE ${game.bossPhase + 1} OF 2'
                                      : game.index < storyLevelCount
                                      ? '${storyNames[game.index ~/ chapterLength].toUpperCase()} · CHAPTER BOSS'
                                      : 'BONUS CHALLENGE')
                                : 'CHAPTER ${game.index ~/ chapterLength + 1} · STAGE ${game.index % chapterLength + 1} · ${game.puzzle.difficulty.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: .6,
                              color: Color(0xFF6B7890),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            game.puzzle.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF24334D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      label:
                          '${game.lives} of ${game.maxLives} lives remaining',
                      child: ExcludeSemantics(
                        child: Row(
                          children: List.generate(
                            game.maxLives,
                            (i) => Icon(
                              i < game.lives
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: i < game.lives
                                  ? const Color(0xFFDA737A)
                                  : const Color(0xFFBCC5D3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More options',
                      onOpened: pauseActivity,
                      onCanceled: resumeActivity,
                      onSelected: (value) {
                        resumeActivity();
                        if (value == 'help') showHelp();
                        if (value == 'haptics') game.toggleHaptics();
                        if (value == 'break') leavePuzzle();
                        if (value == 'hints') hintShop();
                        if (value == 'journal') journal();
                        if (value == 'ad-privacy') adPrivacy();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'journal',
                          child: Text('Story journal'),
                        ),
                        const PopupMenuItem(
                          value: 'hints',
                          child: Text('Coin shop'),
                        ),
                        const PopupMenuItem(
                          value: 'help',
                          child: Text('How to play'),
                        ),
                        const PopupMenuItem(
                          value: 'ad-privacy',
                          child: Text('Ad privacy options'),
                        ),
                        PopupMenuItem(
                          value: 'haptics',
                          child: Text(
                            game.haptics
                                ? 'Turn haptics off'
                                : 'Turn haptics on',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'break',
                          child: Text('Take a break'),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: openShop,
                        borderRadius: BorderRadius.circular(10),
                        child: Tooltip(
                          message: 'Open coin shop',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              game.isBoss
                                  ? 'Guard: ${game.remaining} · ${game.rewards.coins} coins'
                                  : '${game.remaining} arrows · ${game.rewards.coins} coins',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Zoom out',
                      onPressed: zoom > 1 ? () => setZoom(zoom - .5) : null,
                      icon: const Icon(Icons.remove, size: 18),
                    ),
                    Text(
                      '${zoom.toStringAsFixed(1)}×',
                      style: const TextStyle(fontSize: 11),
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
                    color: game.inventory.theme.board,
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
                                      reducedMotion:
                                          MediaQuery.disableAnimationsOf(
                                            context,
                                          ),
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

                const SizedBox(height: 10),
                LinearProgressIndicator(
                  color: game.isBoss ? const Color(0xFFB78328) : null,
                  value:
                      (game.isBoss ? game.remaining : game.removed.length) /
                      game.puzzle.arrows.length,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: const Color(0xFFE1E6F0),
                ),
                const SizedBox(height: 12),
                if (game.companionVisible)
                  ListenableBuilder(
                    listenable: reactions,
                    builder: (context, _) => CompanionStrip(
                      id: game.companionId,
                      mood: game.status == GameStatus.won
                          ? CompanionMood.victory
                          : game.status == GameStatus.lost
                          ? CompanionMood.concerned
                          : reactions.mood,
                      line: game.status == GameStatus.won
                          ? game.index == chapterLength - 1
                                ? 'The Keeper is free. Look—the village is shining!'
                                : reactions.stableLine(
                                    game.isBoss
                                        ? CompanionEvent.boss
                                        : CompanionEvent.win,
                                  )
                          : game.status == GameStatus.lost
                          ? reactions.stableLine(CompanionEvent.loss)
                          : reactions.line,
                      onChoose: chooseCompanion,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(message, textAlign: TextAlign.center),
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
  );

  Widget resultCard(BuildContext context) => LevelResult(
    key: ValueKey('result-${game.epoch}-${game.status.name}'),
    game: game,
    onContinue: continueResult,
    onReviveCoins: () => reviveRun(ad: false),
    onReviveAd: () => reviveRun(ad: true),
    onGetCoins: () => openShop(tab: 4),
  );
}
