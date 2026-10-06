import 'package:flutter/foundation.dart';
import 'puzzle.dart';
import 'rewards.dart';
import 'shop_catalog.dart';
import 'arrow_skins.dart';
import 'campaign.dart';
import 'admin_testing.dart';
import 'story.dart';
import 'paid_wallet.dart';
import 'package:uuid/uuid.dart';

enum GameStatus { playing, won, lost }

enum MoveResult { ignored, blocked, moving }

class GameController extends ChangeNotifier {
  GameController(
    this.levels, {
    int Function()? now,
    this.legacyLevels = const [],
    bool adminTesting = false,
  }) : _now = now,
       _adminTesting = kDebugMode && adminTesting,
       rewards = RunRewards(now: now);
  final bool _adminTesting;
  bool get adminTesting => _adminTesting;
  void refillTestCoins() {
    if (!adminTesting || rewards.coins >= adminTestCoins) return;
    rewards.coins = adminTestCoins;
    notifyListeners();
  }

  final int Function()? _now;
  RunRewards rewards;
  PaidWallet? paidWallet;
  Future<bool> Function()? persistWallet;
  bool walletBusy = false;
  String? walletError;
  int get coins => rewards.coins + (paidWallet?.balance ?? 0);
  final Set<String> walletDeliveries = {};
  Map<String, dynamic>? pendingWalletSpend;
  int reviveCredits = 0;
  void walletChanged() => notifyListeners();

  int? coinPrice(String sku) {
    if (sku == 'hint') return 80;
    if (sku == 'revive') return revivePrice;
    final parts = sku.split(':');
    if (parts.length != 2) return null;
    if (parts[0] == 'companion') {
      final id = int.tryParse(parts[1]);
      return id != null && id > 0 && id < 4 ? companionPrices[id] : null;
    }
    if (parts[0] == 'theme') {
      return puzzleThemes
          .where((x) => x.id == parts[1] && x.price > 0)
          .firstOrNull
          ?.price;
    }
    if (parts[0] == 'arrow') {
      return arrowSkins
          .where((x) => x.id == parts[1] && x.price > 0)
          .firstOrNull
          ?.price;
    }
    return null;
  }

  bool _canBuySku(String sku) {
    if (sku == 'hint') return hints < 999;
    if (sku == 'revive') return status == GameStatus.lost;
    final p = sku.split(':');
    if (p.length != 2 || coinPrice(sku) == null) return false;
    if (p[0] == 'companion') {
      final id = int.parse(p[1]);
      return companionAvailable(id) && !inventory.companions.contains(id);
    }
    return p[0] == 'theme'
        ? !inventory.themes.contains(p[1])
        : !inventory.arrows.contains(p[1]);
  }

  bool _buyEarned(String sku) {
    if (sku == 'hint') return buyHint();
    if (sku == 'revive') return revive();
    final p = sku.split(':');
    return switch (p[0]) {
      'companion' => buyCompanion(int.parse(p[1])),
      'theme' => buyTheme(p[1]),
      'arrow' => buyArrowSkin(p[1]),
      _ => false,
    };
  }

  /// Reserve the offline contribution durably before contacting the server.
  /// A retry always uses the same request ID, including after an app restart.
  Future<bool> spendCoins(String sku) async {
    if (walletBusy) return false;
    walletError = null;
    if (sku == 'revive' && reviveCredits > 0 && status == GameStatus.lost) {
      reviveCredits--;
      return revive(rewarded: true);
    }
    if (pendingWalletSpend != null) {
      walletError =
          'A previous wallet purchase needs syncing. Open Coins and tap Retry / sync.';
      notifyListeners();
      return false;
    }
    if (!_canBuySku(sku)) return false;
    final price = coinPrice(sku)!;
    if (rewards.coins >= price) return _buyEarned(sku);
    if (paidWallet == null || persistWallet == null || coins < price) {
      return false;
    }
    walletBusy = true;
    final attempt = epoch;
    notifyListeners();
    final contribution = rewards.coins;
    final id = const Uuid().v4();
    pendingWalletSpend = {
      'id': id,
      'sku': sku,
      'amount': price - contribution,
      'earned': contribution,
    };
    rewards.coins -= contribution;
    try {
      if (!await persistWallet!()) {
        rewards.coins += contribution;
        pendingWalletSpend = null;
        walletError =
            'Device storage is unavailable. Nothing was sent to the wallet.';
        return false;
      }
      await retryWalletSpend();
      final delivered = walletDeliveries.contains(id);
      if (delivered &&
          sku == 'revive' &&
          epoch == attempt &&
          status == GameStatus.lost &&
          reviveCredits > 0) {
        reviveCredits--;
        revive(rewarded: true);
        await persistWallet!();
      }
      return delivered;
    } catch (_) {
      walletError =
          'Purchase saved for retry. Open Coins and sync when you are online.';
      return false;
    } finally {
      walletBusy = false;
      notifyListeners();
    }
  }

  Future<void> retryWalletSpend() async {
    final pending = pendingWalletSpend;
    if (pending == null || paidWallet == null) return;
    final response = await paidWallet!.spend(pending);
    await applyWallet(response);
  }

  /// Acknowledge only after entitlements and delivery IDs are saved together.
  Future<void> applyWallet(Map<String, dynamic> data) async {
    for (final sku
        in (data['entitlements'] as List? ?? []).whereType<String>()) {
      _applyPermanent(sku);
    }
    final ack = <String>[];
    for (final raw in data['deliveries'] as List? ?? []) {
      final delivery = Map<String, dynamic>.from(raw as Map);
      final id = delivery['id'] as String;
      final sku = delivery['sku'] as String;
      if (!walletDeliveries.contains(id)) {
        if (sku == 'hint') {
          if (hints >= 999) {
            continue; // Keep it undelivered until room is available.
          }
          hints++;
        } else if (sku == 'revive') {
          reviveCredits++;
        } else {
          _applyPermanent(sku);
        }
        walletDeliveries.add(id);
      }
      if (pendingWalletSpend?['id'] == id) pendingWalletSpend = null;
      ack.add(id);
    }
    notifyListeners();
    if (persistWallet != null && await persistWallet!()) {
      for (final id in ack) {
        await paidWallet?.acknowledge(id);
      }
    } else if (ack.isNotEmpty) {
      throw StateError('Wallet delivery could not be saved');
    }
  }

  void _applyPermanent(String sku) {
    if (coinPrice(sku) == null) return;
    final p = sku.split(':');
    if (p.length != 2) return;
    switch (p[0]) {
      case 'companion':
        inventory.companions.add(int.parse(p[1]));
      case 'theme':
        inventory.themes.add(p[1]);
      case 'arrow':
        inventory.arrows.add(p[1]);
    }
  }

  ShopInventory inventory = ShopInventory();
  final List<Puzzle> levels;
  final List<Puzzle> legacyLevels;
  Puzzle? _legacyPuzzle;
  int? _legacyLevelIndex;
  int bossPhase = 0, checkpointSkill = 0;
  final Set<String> seenScenes = {};
  final List<String> pendingScenes = [];
  int clearsTowardHint = 0;
  bool lastHintEarned = false;
  static const revivePrice = 200;
  void markSceneSeen(String id) {
    seenScenes.add(id);
    pendingScenes.remove(id);
    notifyListeners();
  }

  int index = 0, lives = 3, hints = 3, epoch = 0;
  Set<int> removed = {}, completed = {};
  int? movingId;
  bool haptics = true;
  bool sounds = true;
  int companionId = 0;
  bool companionVisible = true;
  GameStatus get status => removed.length == puzzle.arrows.length
      ? GameStatus.won
      : lives == 0
      ? GameStatus.lost
      : GameStatus.playing;
  Puzzle get puzzle =>
      _legacyPuzzle ??
      (bossPhase == 1 ? levels[index].secondPhase! : levels[index]);
  bool get busy => movingId != null;
  int get remaining => puzzle.arrows.length - removed.length;
  int get regularLevelCount =>
      levels.length > storyLevelCount ? storyLevelCount : levels.length;
  int get regularCompleted =>
      completed.where((i) => i < regularLevelCount).length;
  int companionForLevel(int level) => (level ~/ chapterLength).clamp(0, 3);
  bool get chapterEnd =>
      index < storyLevelCount && (index + 1) % chapterLength == 0;
  bool companionAvailable(int id) =>
      id >= 0 &&
      id < companionPrices.length &&
      (id == 0 || completed.contains(id * chapterLength - 1));
  int get discoveredLevelCount => adminTesting || frontier >= storyLevelCount
      ? levels.length
      : ((frontier ~/ chapterLength + 1) * chapterLength).clamp(
          0,
          levels.length,
        );
  bool get isBoss => puzzle.isBoss;
  static int lifeLimitFor(int levelIndex) => levelIndex < chapterLength
      ? 3
      : levelIndex < chapterLength * 3
      ? 2
      : 1;
  int get maxLives => lifeLimitFor(index);
  int get frontier {
    var next = 0;
    while (next < levels.length - 1 && completed.contains(next)) {
      next++;
    }
    return next;
  }

  bool isUnlocked(int level) =>
      level >= 0 &&
      level < levels.length &&
      (adminTesting || level <= frontier) &&
      inventory.companions.contains(companionForLevel(level));
  bool get canAdvance => completed.contains(index) && isUnlocked(index + 1);
  bool reset([int? level]) {
    final target = level ?? index;
    // Enforce progression here, not just in the level-picker presentation.
    if (!isUnlocked(target)) return false;
    final changingChapter =
        companionForLevel(index) != companionForLevel(target);
    index = target;
    if (changingChapter) companionId = companionForLevel(index);
    _legacyPuzzle = null;
    _legacyLevelIndex = null;
    bossPhase = checkpointSkill = 0;
    removed = {};
    lives = maxLives;
    rewards.reset();
    lastHintEarned = false;
    pendingScenes.clear();
    movingId = null;
    epoch++;
    notifyListeners();
    return true;
  }

  bool skip() => canAdvance ? reset(index + 1) : false;

  /// Debug clear follows the same rewards, checkpoint and story events as play.
  bool clearForTesting() {
    if (!adminTesting || status == GameStatus.won) return false;
    movingId = null;
    epoch++;
    lives = maxLives;
    removed = puzzle.arrows.map((a) => a.id).toSet();
    _completeBoard();
    notifyListeners();
    return true;
  }

  bool revive({bool rewarded = false}) {
    if (status != GameStatus.lost ||
        (!rewarded && rewards.coins < revivePrice)) {
      return false;
    }
    if (!rewarded) rewards.coins -= revivePrice;
    lives = maxLives;
    movingId = null;
    epoch++;
    notifyListeners();
    return true;
  }

  void grantAdCoins() {
    rewards.coins += 80;
    notifyListeners();
  }

  bool grantAdHint() {
    if (hints >= 999) return false;
    hints++;
    notifyListeners();
    return true;
  }

  bool grantTestCoinPack(int amount) {
    if (!adminTesting || (amount != 1500 && amount != 4000)) return false;
    rewards.coins += amount;
    notifyListeners();
    return true;
  }

  bool retryCheckpoint() {
    if (bossPhase != 1 || status != GameStatus.lost) return false;
    removed = {};
    lives = maxLives;
    movingId = null;
    rewards.skill = checkpointSkill;
    epoch++;
    notifyListeners();
    return true;
  }

  void resumeTiming() {
    if (status == GameStatus.playing) rewards.resume();
  }

  void pauseTiming() => rewards.pause();
  bool buyHint() {
    if (rewards.coins < 80 || hints >= 999) return false;
    rewards.coins -= 80;
    hints++;
    notifyListeners();
    return true;
  }

  void chooseCompanion(int id) {
    if (!inventory.companions.contains(id)) return;
    companionId = id;
    companionVisible = true;
    notifyListeners();
  }

  bool buyCompanion(int id) {
    if (id < 0 ||
        id >= companionPrices.length ||
        !companionAvailable(id) ||
        inventory.companions.contains(id) ||
        rewards.coins < companionPrices[id]) {
      return false;
    }
    rewards.coins -= companionPrices[id];
    inventory.companions.add(id);
    notifyListeners();
    return true;
  }

  bool buyTheme(String id) {
    final matches = puzzleThemes.where((theme) => theme.id == id);
    if (matches.isEmpty ||
        inventory.themes.contains(id) ||
        rewards.coins < matches.first.price) {
      return false;
    }
    rewards.coins -= matches.first.price;
    inventory.themes.add(id);
    notifyListeners();
    return true;
  }

  bool equipTheme(String id) {
    if (!inventory.themes.contains(id)) return false;
    inventory.selectedTheme = id;
    notifyListeners();
    return true;
  }

  bool buyArrowSkin(String id) {
    final matches = arrowSkins.where((skin) => skin.id == id);
    if (matches.isEmpty ||
        id == 'lantern' ||
        inventory.arrows.contains(id) ||
        rewards.coins < matches.first.price) {
      return false;
    }
    rewards.coins -= matches.first.price;
    inventory.arrows.add(id);
    notifyListeners();
    return true;
  }

  bool equipArrowSkin(String id) {
    if (!inventory.arrows.contains(id)) return false;
    inventory.selectedArrow = id;
    notifyListeners();
    return true;
  }

  void hideCompanion() {
    companionVisible = false;
    notifyListeners();
  }

  void cancelFlight() {
    movingId = null;
    epoch++;
    notifyListeners();
  }

  void toggleHaptics() {
    haptics = !haptics;
    notifyListeners();
  }

  void toggleSounds() {
    sounds = !sounds;
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
      if (lives == 0) rewards.pause();
      notifyListeners();
      return MoveResult.blocked;
    }
    movingId = id;
    notifyListeners();
    return MoveResult.moving;
  }

  bool finish(int id, int token) {
    if (token != epoch || movingId != id) return false;
    final before = puzzle.available(removed).map((a) => a.id).toSet();
    removed.add(id);
    if (puzzle.available(removed).where((a) => !before.contains(a.id)).length >=
        2) {
      rewards.greatMove();
    }
    movingId = null;
    if (status == GameStatus.won) _completeBoard();
    notifyListeners();
    return true;
  }

  void _completeBoard() {
    if (bossPhase == 0 &&
        _legacyPuzzle == null &&
        levels[index].secondPhase != null) {
      bossPhase = 1;
      checkpointSkill = rewards.skill;
      removed = {};
      lives = maxLives;
      epoch++;
      if (!pendingScenes.contains('keeper')) pendingScenes.add('keeper');
      return;
    }
    rewards.complete(index, firstClear: !completed.contains(index));
    completed.add(index);
    clearsTowardHint++;
    lastHintEarned = clearsTowardHint >= 2 && hints < 999;
    if (clearsTowardHint >= 2) {
      clearsTowardHint = 0;
      if (lastHintEarned) hints++;
    }
    if (index < storyLevelCount) {
      for (final scene in chapterScenes[index ~/ chapterLength]) {
        if (scene.afterStage == index % chapterLength &&
            !pendingScenes.contains(scene.id)) {
          pendingScenes.add(scene.id);
        }
      }
    }
    if (index == chapterLength - 1) inventory.arrows.add('lantern');
  }

  Map<String, dynamic> snapshot() => {
    'version': 1,
    'adminTesting': adminTesting,
    'storyVersion': 1,
    'campaignVersion': campaignVersion,
    'legacyAttempt': _legacyPuzzle != null,
    'legacyLevelIndex': _legacyLevelIndex,
    'bossPhase': bossPhase,
    'checkpointSkill': checkpointSkill,
    'seenScenes': seenScenes.toList(),
    'pendingScenes': pendingScenes.toList(),
    'clearsTowardHint': clearsTowardHint,
    'lastHintEarned': lastHintEarned,
    'index': index,
    'lives': lives,
    'hints': hints,
    'removed': removed.toList(),
    'completed': completed.toList(),
    'haptics': haptics,
    'sounds': sounds,
    'companionId': companionId,
    'companionVisible': companionVisible,
    'rewards': rewards.snapshot(),
    'shop': inventory.snapshot(),
    'walletDeliveries': walletDeliveries.toList(),
    'pendingWalletSpend': pendingWalletSpend,
    'reviveCredits': reviveCredits,
  };
  void restore(Map<String, dynamic> data) {
    // A mid-flight arrow stays present in the save until its animation ends.
    if (data['version'] != 1) return;
    if (data['adminTesting'] == true && !adminTesting) return;
    try {
      if (levels.length > storyLevelCount) data = migrateCampaign(data);
      final newIndex = data['index'] as int;
      final newLives = data['lives'] as int, newHints = data['hints'] as int;
      final newHaptics = data['haptics'] as bool? ?? true;
      // Invalid cosmetic preferences must never discard earned progress.
      final newCompanionVisible = data['companionVisible'] is bool
          ? data['companionVisible'] as bool
          : true;
      if (newIndex < 0 ||
          newIndex >= levels.length ||
          newLives < 0 ||
          newLives > 3 ||
          newHints < 0 ||
          newHints > 999) {
        return;
      }
      final newRemoved = (data['removed'] as List).cast<int>().toSet();
      final newCompleted = (data['completed'] as List).cast<int>().toSet();
      final oldStory = data['storyVersion'] == null;
      final legacyIndex = data['legacyLevelIndex'] is int
          ? data['legacyLevelIndex'] as int
          : newIndex;
      final useLegacy =
          (oldStory || data['legacyAttempt'] == true) &&
          legacyIndex >= 0 &&
          legacyIndex < legacyLevels.length;
      final newPhase =
          data['bossPhase'] == 1 &&
              levels[newIndex].secondPhase != null &&
              !useLegacy
          ? 1
          : 0;
      final newPuzzle = useLegacy
          ? legacyLevels[legacyIndex]
          : newPhase == 1
          ? levels[newIndex].secondPhase!
          : levels[newIndex];
      final ids = newPuzzle.arrows.map((a) => a.id).toSet();
      final newRewards = RunRewards.decode(
        data['rewards'],
        levels.length,
        now: _now,
      );
      final newInventory = ShopInventory.decode(data['shop']);
      if (data['rewards'] == null && newRemoved.isNotEmpty) {
        newRewards.eligible = false;
      }
      if (!ids.containsAll(newRemoved) ||
          newCompleted.any((i) => i < 0 || i >= levels.length)) {
        return;
      }
      index = newIndex;
      bossPhase = newPhase;
      _legacyPuzzle = useLegacy ? newPuzzle : null;
      _legacyLevelIndex = useLegacy ? legacyIndex : null;
      checkpointSkill =
          (data['checkpointSkill'] is int ? data['checkpointSkill'] as int : 0)
              .clamp(0, 20);
      seenScenes.clear();
      if (data['seenScenes'] is List) {
        seenScenes.addAll((data['seenScenes'] as List).whereType<String>());
      }
      // Older saves may have three hearts on a now harder level. Cap them,
      // but never refill spent hearts or revive an already lost attempt.
      lives = newLives.clamp(0, maxLives);
      hints = newHints;
      removed = newRemoved;
      completed = newCompleted;
      rewards = newRewards;
      inventory = newInventory;
      walletDeliveries.clear();
      if (data['walletDeliveries'] is List) {
        walletDeliveries.addAll(
          (data['walletDeliveries'] as List).whereType<String>(),
        );
      }
      final pending = data['pendingWalletSpend'];
      pendingWalletSpend =
          pending is Map &&
              pending['id'] is String &&
              pending['sku'] is String &&
              pending['amount'] is int &&
              pending['earned'] is int
          ? Map<String, dynamic>.from(pending)
          : null;
      reviveCredits = data['reviveCredits'] is int
          ? (data['reviveCredits'] as int).clamp(0, 100000)
          : 0;
      clearsTowardHint = data['clearsTowardHint'] == 1 ? 1 : 0;
      lastHintEarned = data['lastHintEarned'] == true;
      pendingScenes.clear();
      if (data['pendingScenes'] is List) {
        pendingScenes.addAll(
          (data['pendingScenes'] as List).whereType<String>().toSet().where(
            (id) =>
                allStoryScenes.any(
                  (s) => s.id == id && inventory.companions.contains(s.chapter),
                ) &&
                storyAvailable(id, completed, index, bossPhase),
          ),
        );
      }
      // Preserve genuine wins from the old unrestricted test build, but an old
      // selected/skipped level must not bypass the new completion requirements.
      if (removed.length == puzzle.arrows.length &&
          (useLegacy || levels[index].secondPhase == null || bossPhase == 1)) {
        completed.add(index);
      }
      // Grandfather already-reached chapters, not unearned future chapters.
      if (oldStory) {
        for (var id = 1; id < 4; id++) {
          if (frontier >= id * chapterLength) inventory.companions.add(id);
        }
      }
      if (completed.contains(chapterLength - 1)) {
        inventory.arrows.add('lantern');
      }
      if (!isUnlocked(index)) {
        index = frontier;
        while (index > 0 && !isUnlocked(index)) {
          index--;
        }
        bossPhase = checkpointSkill = 0;
        _legacyPuzzle = null;
        _legacyLevelIndex = null;
        removed = {};
        lives = maxLives;
        rewards.reset();
        pendingScenes.clear();
      }
      haptics = newHaptics;
      sounds = data['sounds'] is bool ? data['sounds'] as bool : true;
      final savedCompanion = data['companionId'];
      companionId =
          savedCompanion is int && inventory.companions.contains(savedCompanion)
          ? savedCompanion
          : companionForLevel(index);
      companionVisible = newCompanionVisible;
      movingId = null;
      epoch++;
      notifyListeners();
    } catch (_) {
      /* Old/corrupted saves leave the current puzzle untouched. */
    }
  }
}
