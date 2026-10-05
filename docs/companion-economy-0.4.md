# Bottom bar, companion voices and timed rewards — 0.4.0+5

## Interface and reactions

Four fixed bottom actions: Restart, Hint (with saved count), Companions and Levels. Controls stay available when the body scrolls on small screens. The companion portrait is larger, with a speech/thought bubble beside it; the visible selected-character name remains absent. Shapes, puzzle data, animation and progression rules are unchanged.

Each companion has individually written lines for eleven events, not a prefix added to shared text. Cheerful is warm, Elegant composed, Playful energetic and Cool understated. Every character/event combination has its own shuffled bag, avoiding immediate repeats and exhausting a set before reuse. History lasts for the screen session, across level and character changes.

Welcome is a separate event. It appears only for a fresh puzzle and fades after 4.5 seconds. There is no fallback welcome line between moves. After eight seconds without puzzle activity, the companion shows a thinking expression and an actual resting/thinking line for five seconds. Further idle thoughts wait 24 seconds; menus, resting, hidden companions, inactive apps and finished puzzles suppress idle messages. Idle thinking does not pause the completion timer.

## Prototype economy

- First clear: 40 coins, once per level.
- Great move: frees at least two previously unavailable arrows; +1 coin, capped at five per attempt, banked only on completion.
- Speed bonus uses strict millisecond boundaries: under 45,000ms = 10; 45,000–59,999ms = 5; 60,000ms or more = 0.
- Replay rewards are only improvements over the previously paid speed/skill tiers. No repeated first-clear payout or repeat farming of the same bonus.
- Last and best completed times are saved per level, even when over a minute. The ending shows elapsed time and payout; level selection shows personal bests.
- Three starter hints become a persistent inventory. Restarting or changing level never refills them.
- Buy one hint for 60 coins through More options → Hints & coins, or tap Hint when empty. Buying does not consume the hint immediately. Transactions cannot overdraw coins.
- Currency is offline/local only; no real-money purchases or network service. Previously selectable companions remain available. No cosmetic shop or rewarded-ad SDK is connected in this pass.

## Timing and saves

Timing begins when a playable puzzle screen is shown. It uses a monotonic clock, includes thinking and arrow travel, pauses for menus/dialogs, in-game resting and app lifecycle interruptions, and stops on completion/loss. Progress is saved on game events, pauses/backgrounding and every five seconds while active. Abrupt OS termination can lose up to the latest checkpoint interval.

Version-1 saves remain readable. New rewards/time data is nested alongside the existing fields. A legacy in-progress attempt without timing history cannot receive a fabricated zero-second speed bonus or time record; the next fresh attempt is timed normally. Existing completed levels are not retroactively paid a first-clear reward.

## Verification

Static analysis and unit/widget tests cover exact boundaries, timer pause/resume, saved time/currency, legacy timing, hint purchases and persistence, replay payout limits, canceled flights, per-character dialogue, idle scheduling, mobile layout and existing puzzle invariants. Flutter-rendered screenshots are in work/flutter-previews. Native emulator integration selectors were updated but that suite was not run for this source-only revision. No APK was built or distributed for this revision.
