import 'dart:ui';
import 'story_panels.dart';

const storyNames = ['Mira', 'Elyra', 'Lumi', 'Raven'];
const storyTitles = [
  'The Last Lantern',
  'The Garden That Forgot Spring',
  'The Carnival Without a Song',
  'The Shadow Beyond the Garden',
];
const chapterInvitations = [
  'One little light. That’s enough to start.',
  '“Your lantern is awake. That means my garden is next.”',
  '“Welcome, welcome! We’re only missing a little music.”',
  '“You should turn back. The lantern has already done enough.”',
];

// Native text stays legible; supplied artwork is displayed without its baked
// caption strips. Coordinates refer to each original 1536×1024 sheet.
StoryPanel _panel(
  int number,
  List<int> columns,
  int bottom,
  String asset,
  String caption,
  String description, {
  List<int> tops = const [0, 254, 511, 765],
}) {
  final row = (number - 1) ~/ 5, col = (number - 1) % 5;
  return StoryPanel(
    number,
    Rect.fromLTRB(
      columns[col] + 5.0,
      tops[row] + 5.0,
      columns[col + 1] - 5.0,
      bottom - 4.0,
    ),
    description,
    caption,
    asset: asset,
  );
}

final elyraPanels = [
  for (var i = 0; i < 20; i++)
    _panel(
      i + 1,
      [0, 319, 635, 951, 1242, 1536],
      [184, 437, 688, 931][i ~/ 5],
      'assets/story/elyra-panels.png',
      elyraCaptions[i],
      elyraDescriptions[i],
    ),
];
final lumiPanels = [
  for (var i = 0; i < 20; i++)
    _panel(
      i + 1,
      [0, 339, 635, 920, 1218, 1536],
      [191, 430, 683, 927][i ~/ 5],
      'assets/story/lumi-panels.png',
      lumiCaptions[i],
      lumiDescriptions[i],
      tops: const [0, 255, 494, 745],
    ),
];
final ravenPanels = [
  for (var i = 0; i < 20; i++)
    _panel(
      i + 1,
      [0, 316, 610, 928, 1220, 1536],
      [162, 420, 646, 895][i ~/ 5],
      'assets/story/raven-panels.png',
      ravenCaptions[i],
      ravenDescriptions[i],
      tops: const [0, 246, 495, 741],
    ),
];
final chapterPanels = [miraPanels, elyraPanels, lumiPanels, ravenPanels];

const elyraCaptions = [
  'The silver butterfly led Mira beyond the village gate. There, beneath a pale moon, stood a garden where every flower was closed.',
  'A silver-haired woman waited beside the fountain. “You brought the lantern,” she said. “I’m Elyra. I used to keep this garden.”',
  'Mira looked at the tangled paths. “Used to?” Elyra glanced away. “A garden needs more than someone who knows where everything belongs.”',
  'She carried a small glass flower. Inside it, one silver petal trembled. It was the only thing in the garden that still moved.',
  'As the first passage opened, water returned to the fountain. A sleeping flower lifted its head—but Elyra stepped forward and gently pressed it closed.',
  '“Not yet,” she whispered. “The night air might hurt it.” The butterfly settled on her hand, then flew away again.',
  'Every cleared path revealed something carefully preserved: a bench without a fallen leaf, a rose without a broken petal, a pond perfectly still.',
  'But nothing grew. Nothing sang. Even the wind seemed to hesitate before entering.',
  'Beneath the old greenhouse, Elyra found a ribbon she recognised. She had tied it around a sapling years ago, promising never to let anything happen to it.',
  'The ribbon had become a knot. The knot had become a vine. And the vine now wound through the entire garden.',
  '“I only wanted to keep it safe,” Elyra said. “After the darkness reached the village, I couldn’t bear to lose one more thing.”',
  'Ahead, the greenhouse rose beneath a crown of enormous thorns. Behind its glass stood the Moonflower—the first flower Elyra had ever planted.',
  'Its petals were folded around a tiny glow. Each time it tried to open, the thorns tightened.',
  'The Thorn Crown stirred. Branches bent across every passage, protecting the flower from rain, wind, sunlight—and anyone who might help it.',
  'Elyra touched the glass. “I thought the garden had stopped trusting me.” Mira raised her lantern. “Perhaps it’s waiting for you to trust it.”',
  'Together, they loosened the crown. With each freed path, one thorn fell away. Elyra’s glass flower began to crack.',
  'She almost closed her hands around it. Then she took a breath and let them open.',
  'The glass broke into harmless silver light. The Moonflower unfolded, and a breeze carried its seeds through the greenhouse. Outside, imperfect, beautiful flowers began to bloom.',
  'Elyra laughed softly when a petal landed in her hair. Beyond the garden, a distant music box played three notes—then stopped. The butterfly turned toward the sound.',
  '“That melody belongs to the carnival,” Elyra said, opening the gate herself. “Someone there has been waiting a very long time.” This time, she let the butterfly go first.',
];
const elyraDescriptions = [
  'Mira follows a silver butterfly into a moonlit garden.',
  'Elyra meets Mira beside the fountain.',
  'Mira and Elyra discuss the silent garden.',
  'Elyra holds a glass flower with a silver petal.',
  'Water flows again in the garden fountain.',
  'A butterfly rests on Elyra’s hand.',
  'The companions explore a perfectly preserved garden.',
  'A still pond lies beneath the moon.',
  'A hand touches a ribbon tied around a sapling.',
  'Thick vines spread from the ribbon’s knot.',
  'Elyra admits why she sealed the garden.',
  'A thorn-covered greenhouse glows in the darkness.',
  'The Moonflower struggles to open inside the thorns.',
  'The Thorn Crown blocks the greenhouse passages.',
  'Mira encourages Elyra beside the greenhouse glass.',
  'The companions begin to loosen the crown.',
  'Elyra opens her hands around the cracking glass flower.',
  'The Moonflower blooms and seeds float through the garden.',
  'Elyra and Mira smile beside the restored garden.',
  'An open gate leads toward a distant carnival.',
];
const lumiCaptions = [
  'Beyond Elyra’s garden stood a carnival beneath hundreds of unlit stars. The rides were still. The stalls were empty. Yet someone was calling, “Welcome, welcome!”',
  'A pink-haired girl sprang from behind the ticket booth. “I’m Lumi! Best guide, best jokes, absolutely terrible at standing still.”',
  'She bowed so dramatically that her hat slipped over her eyes. Mira laughed. For a moment, the little lantern glowed brighter.',
  'Lumi quickly straightened it. “See? Still a wonderful place.” Behind her, a carousel horse hung motionless halfway through a jump.',
  'When the first path cleared, a row of bulbs flickered on. Lumi cheered loudly enough for a whole crowd.',
  'But when the lights settled, the silence returned. Lumi filled it immediately with another joke.',
  'They found abandoned invitations beneath a stall. Every one promised a celebration at midnight. None had ever been collected.',
  '“We were going to make everyone smile,” Lumi said. “After what happened in the village, I thought they needed something happy.”',
  'In a little workshop, unfinished toys crowded the shelves. Lumi had made them all: wind-up birds, dancing stars, a wooden rabbit with one crooked ear.',
  'She picked up the rabbit. “I kept making more. If the next surprise was good enough, perhaps someone would come.”',
  'Above the carnival stood a clock tower. Its hands pointed to one minute before midnight. From inside came the same three notes, over and over.',
  '“The Clockwork Maestro runs everything,” Lumi explained. “He won’t start the festival until the song is perfect.”',
  'At the tower door, Lumi smiled again. “Don’t worry. I’m excellent at making things fun.” Her voice caught on the last word.',
  'Mira sat beside her on the steps. “You don’t have to make this fun for us.” Lumi looked down at the wooden rabbit. “Good. Because I’m tired.”',
  'Inside, the Maestro turned beneath a tangled crown of gears. Every unfinished melody fed another loop into the machine.',
  'Lumi recognised the tune: a song she used to hum while working. She had stopped singing it because her voice sometimes shook.',
  'As the final paths opened, the Maestro waited for the missing notes. Lumi tried once, stumbled, and nearly laughed it away.',
  'Then she sang again. Quietly. Unevenly. Honestly. The Maestro lowered its baton and followed her—not correcting a single note.',
  'Midnight finally arrived. The carousel moved, lanterns rose, and footsteps approached from the restored village. Lumi placed the crooked-eared rabbit on the first prize shelf.',
  'Beneath the tower, a hidden door opened onto a road of red roses. A dark feather lay on its threshold. Lumi held it up. “Well… whoever lives down there could probably use some company.”',
];
const lumiDescriptions = [
  'Mira and Lumi approach a silent star-lit carnival.',
  'Lumi welcomes Mira from the ticket booth.',
  'Lumi’s hat slips over her eyes as Mira laughs.',
  'A carousel horse hangs motionless behind Lumi.',
  'Lumi cheers as the first carnival bulbs glow.',
  'Lumi hides her unease behind another joke.',
  'Abandoned midnight invitations lie beneath a stall.',
  'Lumi recalls her plans for the carnival.',
  'Unfinished toys fill Lumi’s workshop shelves.',
  'Lumi holds a crooked-eared wooden rabbit.',
  'A clock tower is frozen one minute before midnight.',
  'Lumi points toward the clockwork tower.',
  'Lumi tries to smile at the tower door.',
  'Mira comforts Lumi on the tower steps.',
  'The Clockwork Maestro stands amid tangled gears.',
  'Lumi remembers a melody she once sang.',
  'Lumi begins to sing despite her uncertainty.',
  'Lumi sings while the Maestro follows her melody.',
  'The carnival lights up and visitors return.',
  'Lumi holds a feather beside a road of red roses.',
];
const ravenCaptions = [
  'The road beneath the clock tower led to a quiet courtyard. Red roses climbed its walls, their petals bright against the darkness.',
  'A woman with dark hair waited at the far gate. “You should turn back,” she said. “The lantern has already done enough.”',
  '“Raven?” Elyra asked. The woman’s expression changed. “You remember me.”',
  'Raven had once watched the paths beyond the garden. When the darkness came, she disappeared. Everyone believed it had taken her.',
  'As the first passage cleared, Mira’s lantern revealed old footprints. They led away from the village—and returned carrying something heavy.',
  'Beneath a broken arch, they found lantern frames, torn festival ribbons, and toys from the carnival. Raven had rescued them before the gates closed.',
  '“I saved what I could,” she said. “Then I brought the shadows here so they wouldn’t follow anyone home.”',
  'Lumi reached for a ribbon. Its shadow shivered like a frightened animal. Raven caught her hand. “They remember everything that hurt.”',
  'The deeper passages were filled with whispers: promises broken, goodbyes unfinished, fears nobody had spoken aloud.',
  'Mira heard her grandmother’s words among them. Raven lowered her eyes. “She helped me seal the road. Your little lantern was meant to guide me back.”',
  '“Then why didn’t you return?” Mira asked. Raven touched a rose whose shadow stretched far beyond its stem. “Because I thought bringing myself home meant bringing this with me.”',
  'At the courtyard’s centre stood the Shadow Weaver. A towering figure of tangled ribbons, it wore a crown shaped like the village gates.',
  'Whenever a path opened, it pulled another closed. It was not chasing them. It was trying desperately to keep the courtyard sealed.',
  'Raven stepped forward alone. “Stay behind me.” The Weaver lifted its head, and its face became hers.',
  'She stopped. All these years, the thing she had guarded against had been built from her own fear of failing again.',
  '“You kept them safe,” Mira said. Elyra stood beside Raven. “But keeping yourself here was never part of the promise.”',
  'Together, they cleared the final paths. Lumi held the loose ribbons. Elyra steadied the roses. Mira brought the lantern close enough to reveal what lay beneath the crown.',
  'Not a monster. A small, trembling shadow with nowhere to rest. Raven knelt and held out her hand. “You can come with us. But you don’t get to choose every road anymore.”',
  'The Weaver unravelled into the ordinary shadows of flowers, trees, and four friends beneath the moon. For the first time, Raven’s own shadow followed her instead of blocking the way.',
  'They returned to the Lantern Festival together. Raven paused at the village entrance until Mira held the gate open. Behind them, the garden swayed and the carnival sang. Ahead, there was a place at the table for everyone.',
];
const ravenDescriptions = [
  'Four companions approach a dark courtyard lined with roses.',
  'Raven waits beside the courtyard gate.',
  'Elyra recognises Raven in the lantern light.',
  'Raven watches the distant village from the shadows.',
  'Golden light reveals footprints along the rose road.',
  'Rescued lantern frames, toys and ribbons lie beneath an arch.',
  'Raven explains why she brought the shadows here.',
  'Raven warns Lumi about a trembling ribbon shadow.',
  'Whispering shadows fill the deep courtyard.',
  'Mira remembers her grandmother’s voice.',
  'Raven explains why she never came home.',
  'The Shadow Weaver rises over the courtyard.',
  'Dark ribbons tighten across the courtyard paths.',
  'Raven steps alone toward the Weaver.',
  'Raven sees her own face within the Weaver.',
  'Mira, Elyra and Lumi stand beside Raven.',
  'All four companions untangle the ribbons together.',
  'Raven offers her hand to a small trembling shadow.',
  'Four friends stand beneath the moon after the Weaver unravels.',
  'The companions return to the bright Lantern Festival.',
];
