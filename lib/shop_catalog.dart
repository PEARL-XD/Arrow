import 'package:flutter/material.dart';
import 'arrow_skins.dart';

/// Prices are virtual coins, earned by playing or purchased through a store.
const companionPrices = [0, 600, 700, 800];

class PuzzleTheme {
  const PuzzleTheme(
    this.id,
    this.name,
    this.price,
    this.description,
    this.board,
    this.ink,
    this.dots,
    this.highlight,
    this.background,
  );
  final String id, name, description;
  final int price;
  final Color board, ink, dots, highlight, background;
}

const puzzleThemes = [
  PuzzleTheme(
    'classic',
    'Classic',
    0,
    'The original, clean and calm.',
    Color(0xFFFFFFFF),
    Color(0xFF24334D),
    Color(0xFFDDE3EB),
    Color(0xFF506BDF),
    Color(0xFFF3F5FA),
  ),
  PuzzleTheme(
    'sakura',
    'Sakura',
    150,
    'Blossom petals, rose-to-plum arrows and a pearly pink board.',
    Color(0xFFFFF4F7),
    Color(0xFF843A60),
    Color(0xFFE6C5D3),
    Color(0xFF475CC6),
    Color(0xFFF9EDF3),
  ),
  PuzzleTheme(
    'lagoon',
    'Lagoon',
    180,
    'Sea-glass gradients, rippling water and ocean-to-jade paths.',
    Color(0xFFEFFBF7),
    Color(0xFF196354),
    Color(0xFFB9DAD0),
    Color(0xFF4F57BC),
    Color(0xFFEDF5F2),
  ),
  PuzzleTheme(
    'midnight',
    'Midnight',
    220,
    'A moonlit starfield with luminous lavender-to-ice arrows.',
    Color(0xFF182337),
    Color(0xFFDFE9FF),
    Color(0xFF43516A),
    Color(0xFF91BAFF),
    Color(0xFFEDF0F7),
  ),
];

class ShopInventory {
  final Set<int> companions = {0};
  final Set<String> themes = {'classic'};
  String selectedTheme = 'classic';
  final Set<String> arrows = {'classic'};
  String selectedArrow = 'classic';
  ArrowSkin get arrow => arrowSkins.firstWhere((a) => a.id == selectedArrow);

  PuzzleTheme get theme =>
      puzzleThemes.firstWhere((t) => t.id == selectedTheme);
  Map<String, dynamic> snapshot() => {
    'companions': companions.toList(),
    'themes': themes.toList(),
    'selectedTheme': selectedTheme,
    'arrows': arrows.toList(),
    'selectedArrow': selectedArrow,
  };

  static ShopInventory decode(Object? raw) {
    final result = ShopInventory();
    // Earlier builds offered all four companions freely. Keep that entitlement.
    if (raw == null) {
      result.companions.addAll([1, 2, 3]);
      return result;
    }
    if (raw is! Map) return result;
    if (raw['companions'] is List) {
      result.companions.addAll(
        (raw['companions'] as List).whereType<int>().where(
          (id) => id >= 0 && id < companionPrices.length,
        ),
      );
    }
    if (raw['themes'] is List) {
      result.themes.addAll(
        (raw['themes'] as List).whereType<String>().where(
          (id) => puzzleThemes.any((t) => t.id == id),
        ),
      );
    }
    if (result.themes.contains(raw['selectedTheme'])) {
      result.selectedTheme = raw['selectedTheme'] as String;
    }
    if (raw['arrows'] is List) {
      result.arrows.addAll(
        (raw['arrows'] as List).whereType<String>().where(
          (id) => arrowSkins.any((a) => a.id == id),
        ),
      );
    }
    if (result.arrows.contains(raw['selectedArrow'])) {
      result.selectedArrow = raw['selectedArrow'] as String;
    }
    return result;
  }
}
