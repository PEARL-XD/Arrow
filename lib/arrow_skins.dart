import 'package:flutter/material.dart';

class ArrowSkin {
  const ArrowSkin(
    this.id,
    this.name,
    this.price,
    this.description,
    this.lightColors,
    this.darkColors,
  );
  final String id, name, description;
  final int price;
  final List<Color> lightColors, darkColors;
  List<Color> colorsFor(bool dark) => dark ? darkColors : lightColors;
}

const arrowSkins = [
  ArrowSkin(
    'classic',
    'Classic',
    0,
    'Your board’s original colours. A clean, effect-free escape.',
    [Color(0xFF24334D), Color(0xFF24334D)],
    [Color(0xFFDFE9FF), Color(0xFFDFE9FF)],
  ),
  ArrowSkin(
    'neon',
    'Neon',
    180,
    'Violet–cyan light tubes, double chevrons and an electric escape trail.',
    [Color(0xFF7039AF), Color(0xFF006778)],
    [Color(0xFFD5ACFF), Color(0xFF7DEAFF)],
  ),
  ArrowSkin(
    'fire',
    'Fire',
    220,
    'Red–orange ribbons, flame tips and sparks on escape.',
    [Color(0xFFAB3425), Color(0xFF925100)],
    [Color(0xFFFFAD87), Color(0xFFFFD48A)],
  ),
  ArrowSkin(
    'ice',
    'Ice',
    220,
    'Angular blue–teal paths, crystal tips and drifting ice fragments.',
    [Color(0xFF285B9D), Color(0xFF14647C)],
    [Color(0xFFA4D4FF), Color(0xFFAAFFF2)],
  ),
  ArrowSkin(
    'sakura',
    'Sakura',
    200,
    'Rose–berry ribbons, leaf-shaped tips and drifting blossom petals.',
    [Color(0xFF92366C), Color(0xFFA44260)],
    [Color(0xFFFFB3DD), Color(0xFFFFC8D5)],
  ),
  ArrowSkin(
    'prism',
    'Prism',
    260,
    'A colourful maze of violet, teal, berry and amber ribbons with faceted tips.',
    [
      Color(0xFF643CAE),
      Color(0xFF166A68),
      Color(0xFF9A365C),
      Color(0xFF89550A),
    ],
    [
      Color(0xFFD7B4FF),
      Color(0xFF87EBD8),
      Color(0xFFFFA8C9),
      Color(0xFFFFD786),
    ],
  ),
  ArrowSkin(
    'lantern',
    'Lanternlight',
    0,
    'Mira’s golden keepsake: luminous cores, lantern tails and warm motes.',
    [Color(0xFF87500B), Color(0xFF965026)],
    [Color(0xFFFFD582), Color(0xFFFFE6B4)],
  ),
];
