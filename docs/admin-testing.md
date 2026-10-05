# Temporary admin testing

Debug launches currently enable local testing mode. Hot restart the app (not just hot reload) to activate it.

- A clearly marked **Skip (test)** button above the bottom controls clears the current stage, shows its story, and then continues. It records test rewards and completion in the admin save. A two-phase boss takes two skips; the bonus returns to level selection when cleared.
- The balance is topped up to **10,000 coins** on each launch if below that amount. Purchases still charge the normal price so the purchase flow can be tested.
- Stages within owned chapters are selectable. Only Mira starts unlocked. Beat (or test-clear) a chapter boss, then buy the next companion with coins. The companion switches automatically when entering her chapter. Purchased companions stay unlocked between launches.
- Lanternlight is still a boss reward, not a purchase: select Mira's boss and complete both phases to test earning it.
- Testing uses `path_out_admin_testing_v2`, separate from `path_out_progress_v1`. This new test save starts fresh to test companion locks; previous test and player saves remain stored under their old keys. Subsequent test activity never changes the player save. Normal controllers also reject admin snapshots.

Rewarded-ad and coin-pack demos are available in admin mode only. They are labelled simulations, and never show real ads or charge money. See [live integration steps](monetization-setup.md).

To return to normal player mode, run:

```text
flutter run --dart-define=PATH_OUT_ADMIN=false
```

Or change `defaultValue: true` to `defaultValue: false` in `lib/admin_testing.dart` and restart. Release and profile builds always disable this mode, regardless of the flag. This is a local development convenience, not a production admin authentication system.

Run the native progression integration smoke test with `--dart-define=PATH_OUT_ADMIN=false` so it checks normal player saves and locks.
