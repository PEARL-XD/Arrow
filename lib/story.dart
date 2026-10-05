import 'chapter_panels.dart';
import 'campaign.dart';
export 'story_panels.dart';
export 'chapter_panels.dart';

/// Authored stories unlock through genuine chapter progress, not reading them.
class StoryScene {
  const StoryScene(
    this.id,
    this.title,
    this.panels, {
    this.restored = false,
    this.chapter = 0,
    this.afterStage,
  });
  final String id, title;
  final List<int> panels;
  final int chapter;
  final int? afterStage;
  List<String> get lines =>
      panels.map((index) => chapterPanels[chapter][index].caption).toList();
  final bool restored;
}

const miraScenes = [
  StoryScene('arrival', 'The Last Lantern', [0, 1, 2, 3]),
  StoryScene('path', 'A little light returns', [4], afterStage: 0),
  StoryScene('garden', 'Silver wings in the garden', [5], afterStage: 4),
  StoryScene('message', 'A message in the garden', [6, 7], afterStage: 6),
  StoryScene('square', 'The silent festival', [8], afterStage: 9),
  StoryScene('gate', 'Locked from within', [9, 10, 11], afterStage: 13),
  StoryScene('keeper', 'The glass gives way', [12, 13]),
  StoryScene(
    'festival',
    'A village full of light',
    [14, 15, 16, 17, 18, 19],
    restored: true,
    afterStage: 14,
  ),
];

const elyraScenes = [
  StoryScene('elyra.arrival', 'The Garden That Forgot Spring', [
    0,
    1,
    2,
    3,
  ], chapter: 1),
  StoryScene(
    'elyra.fountain',
    'The first sleeping flower',
    [4],
    chapter: 1,
    afterStage: 0,
  ),
  StoryScene(
    'elyra.stillness',
    'A perfectly still garden',
    [5, 6, 7],
    chapter: 1,
    afterStage: 3,
  ),
  StoryScene(
    'elyra.ribbon',
    'The promise around the roots',
    [8, 9],
    chapter: 1,
    afterStage: 5,
  ),
  StoryScene(
    'elyra.greenhouse',
    'What she wanted to protect',
    [10, 11],
    chapter: 1,
    afterStage: 7,
  ),
  StoryScene(
    'elyra.crown',
    'The Thorn Crown',
    [12, 13, 14],
    chapter: 1,
    afterStage: 10,
  ),
  StoryScene(
    'elyra.hands',
    'Learning to let go',
    [15, 16],
    chapter: 1,
    afterStage: 13,
  ),
  StoryScene(
    'elyra.spring',
    'Spring returns',
    [17, 18, 19],
    chapter: 1,
    afterStage: 14,
    restored: true,
  ),
];
const lumiScenes = [
  StoryScene('lumi.arrival', 'The Carnival Without a Song', [
    0,
    1,
    2,
    3,
  ], chapter: 2),
  StoryScene(
    'lumi.lights',
    'A cheer for an empty carnival',
    [4],
    chapter: 2,
    afterStage: 0,
  ),
  StoryScene(
    'lumi.invitation',
    'Invitations nobody collected',
    [5, 6, 7],
    chapter: 2,
    afterStage: 3,
  ),
  StoryScene(
    'lumi.workshop',
    'One more surprise',
    [8, 9],
    chapter: 2,
    afterStage: 5,
  ),
  StoryScene(
    'lumi.clock',
    'One minute before midnight',
    [10, 11],
    chapter: 2,
    afterStage: 7,
  ),
  StoryScene(
    'lumi.steps',
    'You do not have to smile',
    [12, 13],
    chapter: 2,
    afterStage: 10,
  ),
  StoryScene(
    'lumi.maestro',
    'The Clockwork Maestro',
    [14, 15, 16],
    chapter: 2,
    afterStage: 13,
  ),
  StoryScene(
    'lumi.midnight',
    'An honest song',
    [17, 18, 19],
    chapter: 2,
    afterStage: 14,
    restored: true,
  ),
];
const ravenScenes = [
  StoryScene('raven.arrival', 'The Shadow Beyond the Garden', [
    0,
    1,
    2,
    3,
  ], chapter: 3),
  StoryScene(
    'raven.footprints',
    'Footprints carrying something home',
    [4],
    chapter: 3,
    afterStage: 0,
  ),
  StoryScene(
    'raven.rescue',
    'What Raven rescued',
    [5, 6, 7],
    chapter: 3,
    afterStage: 3,
  ),
  StoryScene(
    'raven.promise',
    'The way she never took',
    [8, 9],
    chapter: 3,
    afterStage: 5,
  ),
  StoryScene(
    'raven.weaver',
    'The Shadow Weaver',
    [10, 11],
    chapter: 3,
    afterStage: 7,
  ),
  StoryScene(
    'raven.reflection',
    'A face inside the shadows',
    [12, 13, 14],
    chapter: 3,
    afterStage: 10,
  ),
  StoryScene(
    'raven.together',
    'Never part of the promise',
    [15, 16],
    chapter: 3,
    afterStage: 13,
  ),
  StoryScene(
    'raven.home',
    'A place at the table',
    [17, 18, 19],
    chapter: 3,
    afterStage: 14,
    restored: true,
  ),
];
const chapterScenes = [miraScenes, elyraScenes, lumiScenes, ravenScenes];
final allStoryScenes = chapterScenes.expand((s) => s).toList(growable: false);

bool storyAvailable(String id, Set<int> completed, int index, int phase) {
  final found = allStoryScenes.where((s) => s.id == id);
  if (found.isEmpty) return false;
  final scene = found.first;
  if (id == 'keeper') {
    return completed.contains(14) || index == 14 && phase == 1;
  }
  if (scene.afterStage == null) {
    return scene.chapter == 0 ||
        completed.contains(scene.chapter * chapterLength - 1);
  }
  return completed.contains(scene.chapter * chapterLength + scene.afterStage!);
}

/// Use story-specific thoughts only for the companion whose chapter is active.
String chapterWelcome(int index) {
  final chapter = (index ~/ chapterLength).clamp(0, 3);
  final local = index % chapterLength;
  if (chapter == 0) {
    final previous = previousStageOffsets.lastIndexWhere((p) => p <= local);
    return miraWelcome[previous];
  }
  return chapterWelcomeLines[chapter - 1][local];
}

const chapterWelcomeLines = [
  [
    'Welcome to my garden. Please mind the sleeping flowers.',
    'The fountain used to sing beside this path.',
    'I remember the sound of water here.',
    'That butterfly never learned to stay still.',
    'Everything is exactly where I left it.',
    'A silver petal. Still trying to move.',
    'There’s an old ribbon around these roots.',
    'I thought I was keeping a promise.',
    'The ribbon reaches further than I remembered.',
    'We’re getting close to the greenhouse.',
    'I planted that Moonflower myself.',
    'Perhaps it has waited long enough.',
    'A little wind wouldn’t hurt this garden.',
    'I can loosen this knot. Slowly.',
    'Let’s give the Moonflower room to open.',
  ],
  [
    'Welcome! I saved you the very best ticket.',
    'Watch your step. The carousel is taking a nap.',
    'One ticket for a midnight that hasn’t arrived.',
    'A few bulbs are better than none, right?',
    'I wrote these invitations myself.',
    'That rabbit’s ear is supposed to look like that. Mostly.',
    'I kept thinking of one more surprise.',
    'Listen. The same three notes again.',
    'Perhaps the missing note is somewhere along this path.',
    'The Maestro never liked mistakes.',
    'Can we sit here a little while first?',
    'Thanks for not making me tell another joke.',
    'I used to sing while building these toys.',
    'My voice might shake. I’ll try anyway.',
    'One honest song. Let’s finish it together.',
  ],
  [
    'Stay close. The roses remember this road.',
    'The gate still has the same scratches.',
    'Someone carried a lantern along this path.',
    'I brought what I could back here.',
    'That ribbon belongs to the old festival.',
    'There are names in these whispers.',
    'Your grandmother knew this place.',
    'I meant to return. I really did.',
    'Some promises are heavier than they look.',
    'The Weaver guards the courtyard’s centre.',
    'Don’t let its size frighten you.',
    'It knows my face. I should have known why.',
    'Maybe I don’t have to face it alone.',
    'Keep the lantern steady. I’m staying beside you.',
    'One last knot. Then we go home together.',
  ],
];

const miraWelcome = [
  'One little light. That’s enough to start.',
  'The village entrance… I know this arch.',
  'Grandmother used to plant flowers here.',
  'Did you see that silver butterfly?',
  'There’s something caught beneath those paths.',
  'The festival used to be so noisy here.',
  'Even in the dark, the flowers kept growing.',
  'A key made of light. It must open something.',
  'Someone is waiting beyond that gate.',
  'Hold on, little Keeper. We’re here.',
];
const miraThoughts = [
  'The flame leans toward the clear paths…',
  'I can almost hear footsteps under this arch.',
  'These flowers still smell like home.',
  'That butterfly seems to be waiting for us.',
  'I wonder what the missing words could be.',
  'I remember lanterns hanging from every stall.',
  'Grandmother always said roots remember.',
  'The key feels warmer near the lantern.',
  'There’s a shadow moving behind the glass.',
  'That tiny flame has waited long enough.',
];

const miraQuietThoughts = [
  'Grandmother’s lantern is still warm in my hands.',
  'The old sign is pointing toward the square.',
  'There might be something beneath those leaves.',
  'Silver wings, even without the moon…',
  'She must have left this for someone to find.',
  'The empty stalls look like they’re holding their breath.',
  'A little colour is returning to the petals.',
  'I wonder who turned this key for the last time.',
  'The glass is glowing on the other side.',
  'We can take our time. I’ll keep the light steady.',
];
