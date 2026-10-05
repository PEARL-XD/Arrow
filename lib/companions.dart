import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'companion_dialogue.dart';
export 'companion_dialogue.dart';

enum CompanionMood { idle, cheer, thinking, concerned, goodbye, victory }

const companionNames = ['Mira', 'Elyra', 'Lumi', 'Raven'];
const companionColors = [
  Color(0xFFB95879),
  Color(0xFF7263A8),
  Color(0xFFBC518D),
  Color(0xFFA64C5B),
];

/// Reactions are cosmetic: they never change lives, moves or progression.
class CompanionReactions extends ChangeNotifier {
  CompanionReactions({Random? random}) : _random = random ?? Random();
  final Random _random;
  int characterId = 0;
  final _bags = <String, List<String>>{};
  final _lastLines = <String, String>{};
  final _stableLines = <CompanionEvent, String>{};
  Timer? _timer;
  CompanionMood mood = CompanionMood.idle;
  String? line;
  int _moves = 0, _lastPraise = -4;
  int _lastClose = -4;
  int _streak = 0;
  bool _halfway = false;

  /// Each line is used once before its category is reshuffled. The first line
  /// stays predictable for the introductory encounter; later cycles vary.
  String nextLine(CompanionEvent event) {
    final key = '$characterId:${event.name}';
    final bag = _bags.putIfAbsent(key, () => []);
    if (bag.isEmpty) {
      final choices = [...companionDialogue[characterId][event]!];
      if (!_lastLines.containsKey(key)) {
        final introduction = choices.removeAt(0);
        choices.shuffle(_random);
        choices.add(introduction);
      } else {
        choices.shuffle(_random);
        if (choices.last == _lastLines[key]) {
          final first = choices.first;
          choices[0] = choices.last;
          choices[choices.length - 1] = first;
        }
      }
      bag.addAll(choices);
    }
    final result = bag.removeLast();
    _lastLines[key] = result;
    return result;
  }

  String stableLine(CompanionEvent event) =>
      _stableLines.putIfAbsent(event, () => nextLine(event));

  void selectCharacter(int id) {
    if (id == characterId) return;
    characterId = id;
    _stableLines.clear();
    reset();
  }

  void welcome({int lives = 3}) => react(
    CompanionMood.idle,
    nextLine(lives < 3 ? CompanionEvent.challenge : CompanionEvent.welcome),
    milliseconds: 4500,
  );
  void idleThought() => react(
    CompanionMood.thinking,
    nextLine(CompanionEvent.idle),
    milliseconds: 5000,
  );

  void blocked({int? lives}) {
    _streak = 0;
    react(
      CompanionMood.concerned,
      nextLine(lives == 1 ? CompanionEvent.lastHeart : CompanionEvent.blocked),
    );
  }

  void hint() => react(CompanionMood.thinking, nextLine(CompanionEvent.hint));

  void react(CompanionMood next, String? text, {int milliseconds = 3200}) {
    _timer?.cancel();
    mood = next;
    line = text;
    notifyListeners();
    _timer = Timer(Duration(milliseconds: milliseconds), reset);
  }

  void moved(int newlyFreed, {int? remaining, int? total}) {
    _moves++;
    _streak++;
    if (newlyFreed >= 2 && _moves - _lastPraise >= 4) {
      _lastPraise = _moves;
      react(CompanionMood.cheer, nextLine(CompanionEvent.great));
    } else if (remaining != null &&
        remaining > 0 &&
        remaining <= 3 &&
        _moves - _lastClose >= 3) {
      _lastClose = _moves;
      react(CompanionMood.cheer, nextLine(CompanionEvent.close));
    } else if (!_halfway &&
        total != null &&
        remaining != null &&
        remaining > 3 &&
        remaining <= total / 2) {
      _halfway = true;
      react(CompanionMood.cheer, nextLine(CompanionEvent.halfway));
    } else if (_streak % 5 == 0) {
      react(CompanionMood.cheer, nextLine(CompanionEvent.streak));
    } else {
      react(
        CompanionMood.cheer,
        nextLine(CompanionEvent.move),
        milliseconds: 2800,
      );
    }
  }

  void reset() {
    _timer?.cancel();
    mood = CompanionMood.idle;
    line = null;
    notifyListeners();
  }

  void newPuzzle() {
    _moves = 0;
    _lastPraise = -4;
    _lastClose = -4;
    _streak = 0;
    _halfway = false;
    _stableLines.clear();
    reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// The atlas stays intact on disk. Only one equal-sized cell is displayed.
class CompanionPortrait extends StatelessWidget {
  const CompanionPortrait({
    super.key,
    required this.id,
    this.mood = CompanionMood.idle,
    this.size = 76,
  });
  final int id;
  final CompanionMood mood;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '${companionNames[id]} companion, ${mood.name}',
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: size * 3,
            maxWidth: size * 3,
            minHeight: size * 2,
            maxHeight: size * 2,
            child: Transform.translate(
              offset: Offset(
                -(mood.index % 3) * size,
                -(mood.index ~/ 3) * size,
              ),
              child: Image.asset(
                'assets/companions/char0${id + 1}.png',
                width: size * 3,
                height: size * 2,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                errorBuilder: (_, error, stack) => ColoredBox(
                  color: companionColors[id].withValues(alpha: .12),
                  child: const Center(child: Icon(Icons.face_rounded)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CompanionStrip extends StatelessWidget {
  const CompanionStrip({
    super.key,
    required this.id,
    required this.mood,
    this.line,
    required this.onChoose,
  });
  final int id;
  final CompanionMood mood;
  final String? line;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final portraitSize = (constraints.maxWidth * .52).clamp(128.0, 220.0);
      final thinking = mood == CompanionMood.thinking || line == null;
      return Row(
        key: const Key('companion-strip'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Tooltip(
            message: 'Choose companion',
            child: InkWell(
              onTap: onChoose,
              borderRadius: BorderRadius.circular(18),
              child: AnimatedSwitcher(
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .96, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                duration: Duration(
                  milliseconds: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : 180,
                ),
                child: CompanionPortrait(
                  key: ValueKey('$id-${mood.name}-${line ?? 'quiet'}'),
                  id: id,
                  mood: mood,
                  size: portraitSize,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: Key(thinking ? 'thought-bubble' : 'speech-bubble'),
                    constraints: const BoxConstraints(minHeight: 66),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(thinking ? 30 : 18),
                      border: Border.all(
                        color: companionColors[id].withValues(alpha: .16),
                      ),
                    ),
                    child: Semantics(
                      liveRegion: line != null,
                      label: line == null ? 'Companion quietly waiting' : null,
                      child: Text(
                        line ?? '…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: line == null ? 24 : 13,
                          height: 1.35,
                          color: const Color(0xFF536079),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14, top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: thinking ? 6 : 10,
                            height: thinking ? 6 : 10,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (thinking)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

Future<int?> showCompanionPicker(
  BuildContext context,
  int selected,
  bool visible, {
  Set<int> owned = const {0, 1, 2, 3},
}) => showModalBottomSheet<int>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose your companion',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'A little encouragement, never in the way.\nExpressions and text only. No voice or sound.',
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < companionNames.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: visible && selected == i
                      ? companionColors[i].withValues(alpha: .09)
                      : const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    key: Key('choose-companion-$i'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    leading: CompanionPortrait(id: i, size: 52),
                    title: Text(companionNames[i]),
                    subtitle: owned.contains(i)
                        ? null
                        : const Text('Unlock in the coin shop'),
                    trailing: !owned.contains(i)
                        ? const Icon(Icons.lock_outline_rounded)
                        : visible && selected == i
                        ? const Icon(Icons.check_circle_rounded)
                        : const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.pop(context, owned.contains(i) ? i : -2),
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, -2),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Visit companion shop'),
            ),
            ListTile(
              key: const Key('hide-companion'),
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('No companion'),
              subtitle: const Text('Keep the puzzle distraction-free'),
              trailing: !visible
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
              onTap: () => Navigator.pop(context, -1),
            ),
          ],
        ),
      ),
    ),
  ),
);
