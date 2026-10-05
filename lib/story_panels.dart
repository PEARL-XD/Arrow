import 'dart:ui';

const miraStoryAsset = 'assets/story/mira-panels.png';

class StoryPanel {
  const StoryPanel(
    this.number,
    this.art,
    this.description,
    this.caption, {
    this.asset = miraStoryAsset,
  });
  final int number;
  final Rect art;
  final String description, caption;
  final String asset;
}

/// Coordinates follow the unequal panel widths in the supplied 1536×1024 sheet.
/// Crop the illustration for display; render its caption as accessible text.
const miraPanels = [
  StoryPanel(
    1,
    Rect.fromLTRB(2, 2, 345, 200),
    'Mira enters a silent village under a blue moon.',
    'Mira returned home on the night of the Lantern Festival. But the village was completely silent and dark.',
  ),
  StoryPanel(
    2,
    Rect.fromLTRB(350, 2, 641, 200),
    'Mira holds her grandmother’s glowing lantern.',
    'Only the little lantern in Mira’s hands still glowed. Her grandmother had given it to her years ago.',
  ),
  StoryPanel(
    3,
    Rect.fromLTRB(646, 2, 892, 200),
    'Mira closes her eyes and remembers her grandmother’s words.',
    '“Keep this close,” her grandmother had said. “It will remember the way, even if you forget.”',
  ),
  StoryPanel(
    4,
    Rect.fromLTRB(898, 2, 1206, 200),
    'Mira raises the lantern toward the village entrance.',
    'Mira lifted it toward the village entrance. “One little light,” she whispered. “That’s enough to start.”',
  ),
  StoryPanel(
    5,
    Rect.fromLTRB(1212, 2, 1534, 200),
    'Golden light returns to the village arch and garden.',
    'As Mira untangled the first path, her lantern brightened. A small light appeared beneath the village arch.',
  ),
  StoryPanel(
    6,
    Rect.fromLTRB(2, 270, 363, 443),
    'A silver butterfly hovers beside Mira in a blooming garden.',
    'With every cleared passage, a little of the village returned. A silver butterfly passed through the garden, and Mira followed it.',
  ),
  StoryPanel(
    7,
    Rect.fromLTRB(368, 270, 642, 443),
    'Mira studies a torn handwritten message.',
    'She found a folded scrap of paper caught beneath the gate. “I sealed the light away to protect…” The rest had been torn off.',
  ),
  StoryPanel(
    8,
    Rect.fromLTRB(648, 270, 892, 443),
    'Mira looks toward the flickering central festival lantern.',
    'Across the empty festival grounds, the central lantern flickered. Perhaps someone there knew.',
  ),
  StoryPanel(
    9,
    Rect.fromLTRB(898, 270, 1205, 443),
    'Twisted dark branches block Mira’s passage to the square.',
    'The closer Mira came to the square, the more tightly the paths were tangled. Everything looked ready for a celebration that had never begun.',
  ),
  StoryPanel(
    10,
    Rect.fromLTRB(1212, 270, 1534, 443),
    'A key of golden light shines among the tangled paths.',
    'Finally, Mira found a key-shaped knot of light. When she freed it, the festival gates opened.',
  ),
  StoryPanel(
    11,
    Rect.fromLTRB(2, 528, 346, 688),
    'A small silhouette presses its hands against the enormous lantern.',
    'Inside the enormous central lantern, something moved. A small silhouette pressed its hand against the glass.',
  ),
  StoryPanel(
    12,
    Rect.fromLTRB(352, 528, 650, 688),
    'Mira raises her lantern with a determined expression.',
    '“This lock isn’t keeping us out,” she said. “It’s keeping someone in.” She raised her little lantern. “Someone kept that light burning all this time. We’re getting them out.”',
  ),
  StoryPanel(
    13,
    Rect.fromLTRB(656, 528, 902, 688),
    'The tiny Lantern Keeper holds a knot of golden light.',
    'Inside was a tiny Lantern Keeper. “Your grandmother asked me to keep this flame safe,” it said. “I held it so carefully. So tightly… I forgot how to let go.”',
  ),
  StoryPanel(
    14,
    Rect.fromLTRB(908, 528, 1225, 688),
    'Mira sits beside the Keeper and helps untangle the light.',
    'Mira sat beside it. “Then we’ll untangle it together.” The final paths were the hardest. Every loosened strand revealed another knot, another small piece of light waiting to escape.',
  ),
  StoryPanel(
    15,
    Rect.fromLTRB(1231, 528, 1534, 688),
    'The Keeper smiles and opens its hands beside Mira.',
    'Little by little, the Keeper opened its hands.',
  ),
  StoryPanel(
    16,
    Rect.fromLTRB(2, 785, 336, 937),
    'The village festival glows with golden lanterns and lights.',
    'The last knot came free. Golden light spilled across the square, through the garden and into every window. The festival bells began to ring. Mira’s village was bright again.',
  ),
  StoryPanel(
    17,
    Rect.fromLTRB(342, 785, 639, 920),
    'Two pieces of Grandmother’s message are joined together.',
    'The Keeper held out the missing piece of her grandmother’s message. Together, the two scraps read: “I sealed the light away to protect it from the shadow beyond the garden.”',
  ),
  StoryPanel(
    18,
    Rect.fromLTRB(645, 785, 907, 937),
    'Mira embraces the smiling Lantern Keeper.',
    '“You kept your promise,” Mira said. “Now you don’t have to keep it alone.” For the first time, the Keeper smiled.',
  ),
  StoryPanel(
    19,
    Rect.fromLTRB(914, 785, 1218, 912),
    'A silver butterfly rests on Mira’s lantern.',
    'Then a silver butterfly landed on her lantern. Between its wings, it carried a message from the guardian beyond the garden: “Your lantern is awake. That means my garden is next.”',
  ),
  StoryPanel(
    20,
    Rect.fromLTRB(1226, 785, 1534, 937),
    'Mira looks toward a dark gate under the moon.',
    'Mira looked toward the distant gate. Beyond it, the darkness remained. But now she knew a way through.',
  ),
];
