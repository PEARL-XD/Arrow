# Shop access, themed boards, reactions and lives — 0.6.0+7

The fixed bottom bar now contains Restart, Hint, Companions, **Shop**, and Levels. The storefront icon opens the existing coin shop directly. All five controls retain at least 48px touch targets on a 320px-wide phone. The balance and menu shop entry remain available.

Existing purchased themes receive their improved art at no extra cost:

- Sakura: soft pearlescent background, corner blossoms and rose/plum arrow gradient.
- Lagoon: sea-glass background, subtle ripples/waves and ocean/jade arrow gradient.
- Midnight: a deep twilight gradient, border stars, a moon and lavender/ice arrows.

Shop previews and actual boards use the same drawing helpers. Decoration is subdued behind the routes; geometry, arrowheads, collisions, tap targets and level data are unchanged. Classic retains its clean original appearance. These are code-drawn designs, not additional image downloads or assets.

Companion dialogue has 112 additional lines across the four personalities. Four new events respond to harder-level starts, the last remaining heart, halfway progress and five-successful-move streaks. Blocks reset the clean streak; halfway is announced at most once per attempt. Welcome and idle dialogue stay separate. Reactions use a brief fade/scale transition, honoring reduced-motion settings, with the existing six expression poses per character. No new portrait artwork or recorded voices were added.

## Hearts

| Levels | Starting hearts |
| --- | ---: |
| 1–10 | 3 |
| 11–30 | 2 |
| 31–40 and the boss | 1 |

Restart, Next, replay and restore use the same level-based limit. Previous saves retain their removed arrows, records and inventory; excess saved hearts are capped at the new limit. Spent hearts are never refilled on restore, and a lost attempt stays lost. Replaying an early level restores that early level's own allowance. Loss text and help no longer assume three mistakes for every board.

## Verification

100 unit/widget tests pass. Coverage includes all threshold boundaries (10/11 and 30/31), boss hearts, save migration, spent-heart preservation, loss/restart, visible heart counts, shop icon interaction, reaction triggers, and unchanged 41-board validation. Actual Flutter renders of all three themes were inspected at phone size. Static analysis is clean. No APK was built or installed and native-device integration was not rerun.
