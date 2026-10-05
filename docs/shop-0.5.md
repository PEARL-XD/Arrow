# Celebrations and coin shop — 0.5.0+6

## Level-clear popup

The completed board now presents a rounded trophy card with a short fade/scale entrance and confetti burst. It shows the recorded time and coins actually banked, split into clear, speed and skill. Animation is cosmetic and cannot issue rewards twice. Reduced-motion settings disable the celebration animation.

**Next** opens the next unlocked puzzle immediately and resets the page scroll. Level 40 offers **Face the boss**. Boss completion retains **New levels coming soon** and **Replay a level**. Losses offer **Try again**. The permanent Levels navigation button still provides manual replay.

## Coin shop

Open by tapping the coin balance, choosing More options → Coin shop, using Hint when empty, or selecting a locked companion. Three tabs offer previews and confirmation before spending. The game timer pauses while shopping. Purchases do not use real money; rewarded ads remain unconnected.

| Item | Coins |
| --- | ---: |
| One persistent hint | 60 |
| Cheerful companion | Free |
| Elegant companion | 200 |
| Playful companion | 200 |
| Cool companion | 250 |
| Classic theme | Free |
| Sakura theme | 150 |
| Lagoon theme | 180 |
| Midnight theme | 220 |

Themes coordinate arrow ink, dots, board surface and page background without changing geometry or rules. The four existing companion atlases and their individual dialogue are reused. Owned items can be equipped freely; duplicate purchases and spending without enough coins are rejected in the controller, not only disabled in the UI. Hints remain consumable and can be bought repeatedly up to the existing storage limit.

New installations start with Cheerful and Classic. Saves made before this shop retain all four formerly free companions. Existing progress, coins, hints and timed records are preserved. Inventory and equipped choices join the existing local save; they survive restart but are not a cloud account or reinstall guarantee. Corrupt cosmetic fields fall back to valid defaults without discarding puzzle progress.

Economy unchanged: first clear +40; below 45 seconds +10, 45–59.999 seconds +5, 60 seconds or more no speed bonus. Skill rewards are capped at five and replays pay only improvements over previous bonuses.

## Verification

Unit and widget checks cover purchases, duplicate/invalid requests, insufficient funds, cancellation, equipment locks, save round trips, legacy migration, contrast, direct Next progression, boss completion, reduced motion, small portrait/landscape layouts, and unchanged puzzle validation. Actual Flutter renders are generated in `work/flutter-previews/` for celebration, shop tabs and all new themes. No APK was built or installed, and native-device integration was not rerun for this revision.
