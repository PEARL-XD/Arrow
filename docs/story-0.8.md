# 0.8.0 — Mira: The Last Lantern

## Included

- Mira's opening, midpoint discovery, gate reveal, boss checkpoint scene and full chapter ending. Skippable scenes use existing companion artwork and pause active-time measurement. More options → Story journal replays discovered memories without rewards or progress changes.
- Ten replacement chapter-one boards: lantern, arch, leaf, butterfly, envelope, kite, flower, key, gate and boss lantern. Each is an actual cell silhouette with complete, non-overlapping arrow coverage. First five have 10–22 arrows. Difficulty estimates still need real-player testing.
- Stage 10 has two fixed, solvable boards. The outer seal pays nothing by itself; breaking it restores three hearts and saves a checkpoint. Losing the inner seal offers Retry from checkpoint, keeping cumulative elapsed time, banked coins and consumed hints. Restart in the dock intentionally restarts both stages. Completing both awards one stage-clear reward.
- Chapter victory grants permanent Lanternlight arrows with golden escape motes. Not purchasable or convertible to coins. Equip through Shop → Arrows. Older users who already completed stage 10 receive the keepsake on migration.
- The next-companion screen shows exact balance/cost, unlocks once and selects that companion. If short, replay completed stages for coins. Ads and coin packs are explicitly unavailable, not fake working buttons.
- Chapters 2–4 retain existing puzzles and companion dialogue. Their full narratives and distinctive chapter bosses are later work; this update does not claim those stories are finished. Crown Keeper remains a bonus finale.
- Header uses chapter/stage instead of campaign total; picker reveals chapters as reached. No released content is described as infinite.

## Economy

| Action | Coins |
|---|---:|
| First stage clear | 70 |
| Completed replay | 30 |
| Under 45 seconds | 10 |
| 45 seconds to under 60 seconds | 5 |
| Great move (frees at least two previously blocked arrows) | 4, capped at 20 per attempt |
| Strictly faster recorded personal best on replay | 5 |
| One hint | costs 80 |
| Companion 2 / 3 / 4 | costs 600 / 700 / 800 |

Speed + skill cap at 30. Each stage stores already-paid bonus tiers; replay pays only their positive difference. Faster personal best is a separate 5 coins; equal/slower records get none. Unknown legacy elapsed times cannot earn speed or personal-best rewards. Rewards bank only at stage completion, not during moves or story navigation.

Ten first clears guarantee 700 before bonuses. Two hints leave 540; two ordinary replays recover the missing 60 for companion 2. No ads, purchase or improved record is needed. First companion is free: three paid unlocks, not four. No fifth companion or 1,000-coin unlock is implemented.

Cosmetics retain experimental prices: Sakura/Lagoon/Midnight themes 150/180/220; Neon/Fire/Ice/Sakura arrows 180/220/220/200. Confirmations mention the next unowned companion cost and post-purchase balance. Currency/ownership remain local: this is not a secure real-money economy.

## Preservation and trying the update

Existing completion records, balances, hints, best times and purchases are retained. Pre-story saves already past a chapter boundary receive that companion entitlement instead of losing access. Old active chapter-one layouts load from assets/legacy-chapter-one.json until restarted or another stage is selected. Old removed-arrow IDs are not silently applied to a different layout.

Hot-restart Flutter on the existing emulator/debug device. No APK was generated or installed. An old save can resume its original board: select stage 1 through Levels (or restart it) for the new lantern. More options → Story journal → The Last Lantern opens the story without erasing progress. Previously completed stages pay replay rewards, not another first-clear payout.

Authoring: node tools/build-mira.cjs replaces only entries 1–10 and records docs/mira-metrics.json. It preserves the original ten boards once; retain the legacy asset. Later campaign geometry and bonus finale are untouched. docs/level-metrics.json is the pre-story calibration record, not a claim of strict monotonic difficulty in this chapter.

## Verification

Analyzer and complete unit/widget suite cover geometry, reward boundaries, replay bonuses, affordability, ownership locks, boss checkpoint persistence, migration, scene timing, ending/unlock flow, reduced motion and small/landscape layouts. Flutter screen captures: work/flutter-previews/mira-*.png. Native Android/iOS deployment and real ads/billing were not exercised.
