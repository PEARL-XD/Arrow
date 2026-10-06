# Game sound effects

This version includes sound effects only. Companion spoken dialogue is deferred
to a future version; no companion voice recordings are bundled here.

These ten cues were synthesized for ARROW: THE LAST LANTERN using
`tools/audio/generate_sounds.py`. They contain no external samples or music.
They can be used commercially in this game with no third-party attribution.

All files are mono, 48 kHz, 16-bit PCM WAV. Effects play at 55% volume.

- `glide.wav`: arrow starts escaping; soft rising air sound.
- `good.wav`: ordinary successful move; single chime.
- `nice.wav`: opens one new arrow; two chimes.
- `great.wav`: opens two or more arrows; rising three-note phrase.
- `blocked.wav`: blocked arrow; muted wooden knock.
- `pause.wav` / `resume.wav`: taking a break / returning to play.
- `hint.wav`: a safe arrow is revealed.
- `victory.wav`: board clear or boss checkpoint; short resolving phrase.
- `loss.wav`: last heart lost; knock followed by a gentle falling phrase.

The sound preference is saved independently of haptics. New gameplay effects are
suppressed while a story, shop, menu, or other overlay is open. Short cues already
playing can finish, so a boss-clear chime can accompany its story reveal.
All effects stop when muted or when the app backgrounds.
There are no recurring idle sounds. iOS effects respect the silent switch.
