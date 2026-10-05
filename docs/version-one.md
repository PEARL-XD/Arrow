# Version 1.0 — Four illustrated stories

Source **1.0.0+11** completes the offline story build. No APK, device install,
advertising/billing setup, signing or store publication is performed.

| Story | Stages | Chapter boss |
|---|---|---|
| Mira — The Last Lantern | 1–15 | The Lantern Keeper (two-phase checkpoint) |
| Elyra — The Garden That Forgot Spring | 16–30 | The Thorn Crown |
| Lumi — The Carnival Without a Song | 31–45 | The Clockwork Maestro |
| Raven — The Shadow Beyond the Garden | 46–60 | The Shadow Weaver |

The existing Crown Keeper remains an optional bonus challenge after the story,
followed by the coming-soon message. The game header does not expose a campaign
total; level selection reveals reached chapters only.

## Story presentation

All **80 supplied panels** are included as their original image sheets. Flutter
displays individual art regions and scalable native captions without modifying
the source images. No new artwork was generated. Each chapter uses its twenty
panels once in story order. Later chapters reveal scenes on arrival and after
local stages 1, 4, 6, 8, 11, 14 and the stage-15 boss. Mira’s expanded pacing keeps
her checkpoint reveal and original narrative.

Back/Continue/Skip, reduced motion, timer pause, saved seen-scene flags and journal
replay work for all four chapters. Reading never pays coins or unlocks stages;
endings require boss completion. Companion UI names are Mira, Elyra, Lumi, Raven;
ownership retains the original numeric identities.

## Twenty extra stages

Five new boards per chapter use lantern, flower, ribbon, fountain, greenhouse
arch, ticket, rabbit, musical-note, clock and heart silhouettes. Every starting
dot is occupied by exactly one route; there are no overlaps. Heads agree with
their final segments and every board has a verified solution. Twists,
four-direction exits and blocker dependencies remain.

All forty approved campaign boards and the bonus board preserve route geometry.
Chapter ends have story-specific boss names. Mira retains two phases; the other
three bosses are single-board clears, with no new combat/moving-obstacle rules.
Hearts follow the expanded chapters: three for Mira, two for Elyra/Lumi, one
for Raven and the bonus. Economy is unchanged: first clear 70, replay 30,
unpaid performance improvements, faster-best reward, hints 80, companions
600/700/800 coins.

## Migration and maintenance

The save key stays `path_out_progress_v1` with an explicit campaign-layout
version. Old stage indexes, wins, active removed routes, checkpoint, coin balance,
hints, inventory, memories, time records and paid bonuses are remapped once.
Inserted stages below genuine old progress are grandfathered without paying
coins or inventing records; they remain replayable. Skipped selections do not
earn progress. Pre-Mira active geometry retains its existing legacy asset until
reset. Do not clear application storage to try this update.

The archived input is `assets/legacy-campaign-v08.json`; keep it unchanged.
Reproduce expansion with `node tools/expand-stories.cjs`, not the older campaign
scripts. Board report: `docs/campaign-v1-metrics.json`.

## Verification and testing

Checks cover all routes, full sixty-stage progression, chapter gates/economy,
old saves at every original index, checkpoint and record migration, illustrated
pages, navigation, endings, timers and responsive layouts. Actual Flutter
captures are in `work/flutter-previews/`.

Hot-restart Flutter on the existing emulator/debug device to load new assets.
Use Levels for unlocked stages and More options → Story journal for discovered
memories. New installs still need to earn companion unlocks.

Native Android/iOS builds were not run for this update. Real-device play-testing,
publisher identity, permanent application ID, production signing and store
requirements remain prerequisites. iOS needs Mac/Xcode; see RELEASE.md. Ads and
real-money payments remain unavailable.
