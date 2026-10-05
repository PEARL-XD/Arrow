# Story and reward update — October 3, 2026

- Clear events now persist a queue of story scenes. Milestone scenes and chapter endings open automatically, including on replay after a scene has been seen. The queue is acknowledged when the player finishes/skips the scene. Pending scenes resume after an app restart.
- The original test Skip jumped directly to another board and never emitted a clear event. It now clears the current stage through the same progression/reward/story code as gameplay. Mira's two-phase boss needs two test skips, with its checkpoint scene between them. The final Raven scene precedes the optional bonus.
- Fresh admin testing uses save key `path_out_admin_testing_v2`, starts with only Mira, and still tops up to 10,000 coins. Earlier admin/player saves are preserved. Chapter purchases require their preceding boss even in test mode. Tests may jump among stages of an owned chapter. Entering a different chapter automatically switches its companion; the shop no longer requires an equip step.
- One hint is awarded after every two full level clears, including replays. Boss checkpoints do not count as separate levels. The counter and award result persist.
- Revive costs 200 coins and restores that chapter's full heart allowance, keeping removed arrows, hints, checkpoint and elapsed time. Insufficient funds and duplicate revive calls do not charge. A simulated rewarded-ad alternative is available in admin testing.
- Classic, Neon, Fire, Ice, Sakura and Lanternlight have visibly distinct resting styles; Prism adds colourful routes for 260 coins. Preview and gameplay share the same renderer. Movement, collision and hit geometry are unchanged.
- Ad/purchase offers: one hint or revive per corresponding ad; 80 coins per coin ad; planned packs 1,500/₹49 and 4,000/₹99. These are explicitly labelled offline simulations in admin testing. Live ads and billing are not connected. See [setup guide](monetization-setup.md).

| Chapter | Under this time: +10 | Under this time: +5 |
| --- | --- | --- |
| Mira | 45 seconds | 1 minute |
| Elyra | 1 minute 30 seconds | 2 minutes |
| Lumi | 3 minutes | 4 minutes |
| Raven | 4 minutes | 5 minutes |

Bosses receive 50% more time, including Mira's combined phases and the optional bonus. Thresholds are strict: exactly at the first target pays +5, and exactly at the second pays no speed bonus. The normal first-clear/replay coins, unpaid bonus differences, personal-best tracking and absence of a time penalty remain in place. These are starting tuning values for play-testing, not measured completion-time percentiles.

Verified with 166 automated Flutter tests, a clean analyzer, and rendered UI review of the coin offers, revive popup and every stationary arrow skin on light/dark boards. Native smoke-test expectations were updated for automatic stories, but no device test, APK build, installation or live ad/payment transaction was performed for this update.
