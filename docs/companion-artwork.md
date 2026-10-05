# Companion artwork and behavior

Prepared with the built-in image-generation tool (not the CLI/API fallback) from the four character sheets supplied by the user. Original sheets remain untouched.

## Saved project assets

- C:\CODE\Arrow\assets\companions\char01.png — Cheerful
- C:\CODE\Arrow\assets\companions\char02.png — Elegant
- C:\CODE\Arrow\assets\companions\char03.png — Playful
- C:\CODE\Arrow\assets\companions\char04.png — Cool

Each PNG is an RGBA 3×2 sprite atlas. Order: idle, cheer, thinking, concerned, goodbye, victory. Flutter displays one cell directly; atlas files are not destructively cropped. Transparency is preserved. Reactions are cosmetic and never change puzzle state.

## Behavior

Choose a character using Companions; choose No companion to hide. Both settings persist with the existing version-1 save, and legacy saves default to the first companion. Ordinary successful moves show a brief happy expression without speech. Great-move dialogue requires at least two previously blocked arrows to become available; praise is limited to once in four successful moves. Hints, blocked taps, loss, victory, and the leave confirmation have distinct responses. All reactions are silent. Reduced-motion preferences disable portrait transitions.

Take a break opens a cancelable confirmation; Leave puzzle returns to a resting screen. Continue puzzle restores the same in-session board. An unfinished flight is rolled back safely, while finished arrows remain removed. Android Back from the resting screen may exit normally. No attempt is made to intercept OS force-close or to terminate an iOS application programmatically.

## Final prompt set

### Character 1

Use case: background-extraction. Input image is the edit target, a character reference sheet. Prepare ONE production game sprite atlas of the SAME character's chibi bust reaction portraits, preserving her recognizable identity, colors and accessories: brown hair, pink bow and small bunny clip, pink and white outfit. Use the chibi portraits in the bottom area as the style reference. Exactly SIX separate head-and-shoulders portraits in a perfectly regular 3 column by 2 row grid, landscape 1536x1024 canvas, six equal 512x512 cells. Each portrait centered within its cell with generous transparent padding; identical scale. Reading order: top-left calm idle soft smile; top-middle delighted cheering eyes closed hands up; top-right thoughtful finger near chin; bottom-left concerned but kind after a mistake; bottom-middle slightly sad gentle goodbye waving; bottom-right joyful victory sparkling eyes. Clean detailed anime chibi illustration, fully clothed shoulders and head only. Remove ALL original panels, text, borders, scenic backgrounds, labels, full bodies. Genuine transparent background around all six portraits, NO drawn checkerboard, no floor, no cast shadows, no frames, no text. Nothing crosses cell boundaries. Keep hair and accessories fully inside each cell.

### Character 2

Use case: background-extraction. Input image is the edit target, a character reference sheet. Prepare ONE production game sprite atlas of the SAME character's chibi bust reaction portraits, preserving her recognizable identity, colors and accessories: silver lavender hair, purple eyes, blue and gold hair ornament, elegant dark outfit. Use the chibi portraits in the bottom area as the style reference. Exactly SIX separate head-and-shoulders portraits in a perfectly regular 3 column by 2 row grid, landscape 1536x1024 canvas, six equal 512x512 cells. Each portrait centered within its cell with generous transparent padding; identical scale. Reading order: top-left calm idle soft smile; top-middle delighted cheering eyes closed hands up; top-right thoughtful finger near chin; bottom-left concerned but kind after a mistake; bottom-middle slightly sad gentle goodbye waving; bottom-right joyful victory sparkling eyes. Clean detailed anime chibi illustration, fully clothed shoulders and head only. Remove ALL original panels, text, borders, scenic backgrounds, labels, full bodies. Genuine transparent background around all six portraits, NO drawn checkerboard, no floor, no cast shadows, no frames, no text. Nothing crosses cell boundaries. Keep hair and accessories fully inside each cell.

### Character 3

Use case: background-extraction. Input image is the edit target, a character reference sheet. Prepare ONE production game sprite atlas of the SAME character's chibi bust reaction portraits, preserving her recognizable identity, colors and accessories: pink hair, pink cat-ear headphones, playful pink outfit. Use the chibi portraits in the bottom area as the style reference. Exactly SIX separate head-and-shoulders portraits in a perfectly regular 3 column by 2 row grid, landscape 1536x1024 canvas, six equal 512x512 cells. Each portrait centered within its cell with generous transparent padding; identical scale. Reading order: top-left calm idle soft smile; top-middle delighted cheering eyes closed hands up; top-right thoughtful finger near chin; bottom-left concerned but kind after a mistake; bottom-middle slightly sad gentle goodbye waving; bottom-right joyful victory sparkling eyes. Clean detailed anime chibi illustration, fully clothed shoulders and head only. Remove ALL original panels, text, borders, scenic backgrounds, labels, full bodies. Genuine transparent background around all six portraits, NO drawn checkerboard, no floor, no cast shadows, no frames, no text. Nothing crosses cell boundaries. Keep hair and accessories fully inside each cell.

### Character 4

Use case: background-extraction. Input image is the edit target, a character reference sheet. Prepare ONE production game sprite atlas of the SAME character's chibi bust reaction portraits, preserving her recognizable identity, colors and accessories: dark brown hair, red roses and black ribbons, red and black outfit. Use the chibi portraits in the bottom area as the style reference. Exactly SIX separate head-and-shoulders portraits in a perfectly regular 3 column by 2 row grid, landscape 1536x1024 canvas, six equal 512x512 cells. Each portrait centered within its cell with generous transparent padding; identical scale. Reading order: top-left calm idle soft smile; top-middle delighted cheering eyes closed hands up; top-right thoughtful finger near chin; bottom-left concerned but kind after a mistake; bottom-middle slightly sad gentle goodbye waving; bottom-right joyful victory sparkling eyes. Clean detailed anime chibi illustration, fully clothed shoulders and head only. Remove ALL original panels, text, borders, scenic backgrounds, labels, full bodies. Genuine transparent background around all six portraits, NO drawn checkerboard, no floor, no cast shadows, no frames, no text. Nothing crosses cell boundaries. Keep hair and accessories fully inside each cell.
