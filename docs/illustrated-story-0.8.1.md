# Mira's illustrated story — 0.8.1

The supplied 20-panel sheet is packaged unchanged as assets/story/mira-panels.png. Each page displays the matching illustration directly from that shared image; captions are native text for legibility, text scaling and screen readers. The small printed captions and dividing lines are outside the displayed artwork bounds. No new art was generated.

Scene timing:

| Moment | Panels |
|---|---|
| Opening | 1–4 |
| After stage 1 | 5 |
| After stage 4 | 6 |
| After stage 5 | 7–8 |
| After stage 7 | 9 |
| After stage 9 | 10–12 |
| Boss checkpoint | 13–14 |
| After clearing the boss | 15–20 |

Scenes wait for a player's tap. Continue and Previous page stay at the bottom while the content scrolls on short screens. Skip remains available; chapter progress gates the journal. Story viewing pauses the active puzzle timer, and replaying a scene does not award coins. Gentle page dissolves respect reduced motion. All scenes are available offline.

Existing seen-scene records are retained. On an existing save, use More options → Story journal → The Last Lantern to see the illustrated opening. Already-unlocked memories can be replayed there; the three new memories unlock through matching completed stages.

Validation: Flutter analyzer, story/navigation and gameplay widget tests, plus captures of the actual rendered pages. work/flutter-previews/mira-illustration-check.png shows the 20 atlas crops together for framing review. Source update only; no APK or device installation.
