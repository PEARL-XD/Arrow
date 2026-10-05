# Independent arrow skins — 0.7.0+8

Open Shop → Arrows (swipe the tab row on narrow phones). Skins are bought with earned coins, previewed without spending, and equipped independently of the board theme:

| Skin | Coins | Escape effect |
| --- | ---: | --- |
| Classic | Free | Existing board palette, no extra particles |
| Neon | 180 | Violet/cyan gradient, glow and light particles |
| Fire | 220 | Ember/orange gradient and sparks |
| Ice | 220 | Blue/teal gradient and crystal fragments |
| Sakura | 200 | Berry/rose gradient and petal drift |

All movement uses the original snake route and straight-head escape. Cosmetic effects do not alter speed, collision rules, hit targets, lives or rewards. Stationary routes stay still. Only the one escaping route emits particles (at most 12); reduced motion suppresses particles/glow and shortens previews. Colours adapt to light/dark boards. Hints also outline the head with a ring, so a blue cosmetic skin does not remove the hint cue.

Preview escape plays once on tap, then resets. Gameplay and previews share the same renderer. Arrow ownership and selection join the existing local save; old saves start on Classic and retain everything previously bought. Paid/equipped themes and arrows do not overwrite each other. Duplicate/invalid purchases and insufficient funds are rejected by the controller.

105 unit/widget tests cover preview playback across all skin/theme combinations, reduced motion, contrast, purchase/cancel/equip flows, save migration, and actual skin-equipped arrow escapes. Static analysis is clean. Phone renders were inspected. No APK, live advertising, real-money checkout, analytics or external account integration was added.
