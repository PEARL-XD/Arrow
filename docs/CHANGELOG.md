# 1.1.1 — native rewarded ads, safe test defaults

- ARROW: THE LAST LANTERN display name on Android/iOS; existing identifiers and saves retained.
- Google Mobile Ads 9.1.0 and supplied Android/iOS application and rewarded-placement IDs configured.
- Native rewarded hint, 80 coins and progress-preserving revive for normal players and admins.
- Test units by default in every build mode, including Codemagic/TestFlight; explicit ARROW_TEST_ADS flag.
- UMP startup consent and in-game privacy options; loading/cancellation/no-fill handling and one reward per earned callback.
- 184 automated tests pass, analysis clean, Android debug build verified. iOS/device playback awaits Codemagic/real-device testing. No publication, installation or real billing performed.
- See [remaining setup and device checklist](monetization-setup.md).

# 1.1.0 — reliable story playback and reward testing

- Automatic, persistent story events on clears and boss endings; test Skip follows the same flow.
- Fresh Mira-only admin save; chapter purchases and automatic companion handoffs.
- Longer speed windows, a hint every two clears, 200-coin revive with preserved progress.
- Distinct resting arrow styles and colourful Prism arrows.
- Test-only rewarded-ad and coin-pack flows; live services are not connected.
- See [update notes](engagement-1.1.md) and [AdMob/billing setup](monetization-setup.md).

# 1.0.0 — four complete illustrated stories

- All 80 supplied panels, readable captions, chapter-specific scenes, endings and journal replay.
- Fifteen stages per story: 60 story stages, twenty new shaped boards, four chapter bosses and retained optional bonus.
- Companion names and chapter welcome dialogue updated; coin gates/prices retained.
- Chapter-based hearts: 3 / 2 / 2 / 1. Original routes, progress, checkpoint, records and purchases migrate without duplicate rewards.
- Source/tests only: no APK, install, ads, payments or store upload. See [version-one notes](version-one.md).

# 0.8.1 — illustrated Mira story

- Supplied 20-panel artwork replaces the generic story illustration; each panel has a scalable, accessible caption.
- Progress-matched scenes after stages 1, 4, 5, 7, 9, the boss checkpoint and chapter completion.
- Fixed page navigation, Skip, journal replay and reduced-motion transitions.
- See [illustrated story notes](illustrated-story-0.8.1.md).

# 0.8.0 — Mira’s first story chapter

- Ten story-shaped levels with a two-stage Lantern Keeper, persistent checkpoint and animated illustrated scenes.
- Journal, chapter reveal, coin-gated companion progression and permanent Lanternlight keepsake.
- First-clear 70, replay 30, speed/skill bonuses up to 30, faster replay record +5; hint cost 80; companion costs 600/700/800.
- Old active geometry, progression, owned cosmetics and previously reached chapters preserved.
- Source/tests only; no APK, device install, ads or billing activation.
- See [full notes](story-0.8.md). Later companion narratives and chapter bosses remain future work.

# 0.2.0 — progression and finale

- Level 1 is initially available. Finishing each level once unlocks the next.
- Completed levels stay replayable. Locked tiles show locks and cannot be selected.
- The old unrestricted Skip action is now a guarded Next level action.
- The original 40 boards match the previous delivered APK exactly.
- After level 40, unlock The Crown Keeper, an 80-arrow crown-shaped boss with the same rules and a diminishing guard meter.
- Boss victory shows “New levels coming soon” and allows replay without automatically returning to level 1.
- Existing recorded wins and valid in-progress games are retained. Old skipped-ahead selections return to the earliest incomplete level.
- Version/build incremented to 0.2.0+2. Install over the previous signed development APK to retain local data.
