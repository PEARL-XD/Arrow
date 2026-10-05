# Compact layout — 0.3.1+4

- Removed the in-game Path Out logo/title and reduced the level name to 18 logical pixels.
- Anchored the screen at the top of the safe area rather than vertically centering it. Horizontal margins are now 8 pixels (originally 20). Reduced the internal maze gutter from 1.5 to 0.9 grid units, making arrows visibly larger without stretching shapes or changing level data.
- Split the bottom area: larger companion (up to 132, previously 76) and speech on the left; four 52-pixel icon buttons on the right: Restart, Hint, Companions, Levels.
- Removed the selected companion's visible name and the Next level button. Standard win screens lead to Levels; the special boss-unlock invitation remains.
- Hints retain a count badge. Buttons retain long-press tooltips and accessibility labels.
- Moved help, haptics and Take a break into the top-right More options menu.
- Added 68 comments in ten context-specific sets: idle, move, great move, blocked, hint, near-finish, win, loss, boss and goodbye. Each category exhausts its set before reshuffling, with no immediate repeat across cycles. History survives level changes within the session. Great move remains tied to opening multiple exits; near-finish lines require three or fewer remaining arrows.
- No changes to puzzle assets, rules, save format or unlock requirements.

Validation: static analysis clean, 70 unit/widget tests passed, actual Flutter-rendered phone layout inspected. Regression tests verify top alignment, larger board, icon hit targets, a non-overlapping dock and comment cycling. Native emulator integration was not rerun for this UI-only pass; its selectors were updated for the icon controls.

The user now tests from the Flutter source on their own emulator/debug device. No distribution APK was copied or supplied for this revision. Run or hot-restart the project from C:\CODE\Arrow. A prior packaging command finished before this follow-up, but that local build output predates the final top-alignment and commentary changes.
