import 'dart:convert';

typedef Cell = ({int x, int y});
const directions = <Cell>[
  (x: 1, y: 0),
  (x: 0, y: 1),
  (x: -1, y: 0),
  (x: 0, y: -1),
];

class ArrowRoute {
  ArrowRoute({
    required this.id,
    required List<Cell> cells,
    required this.direction,
  }) : cells = List.unmodifiable(cells);
  final int id;
  final List<Cell> cells;
  final int direction;
  Cell get head => cells.last;
  Cell get delta => directions[direction];
  factory ArrowRoute.fromJson(Map<String, dynamic> data) => ArrowRoute(
    id: data['id'] as int,
    cells: (data['cells'] as List)
        .map((p) => (x: p[0] as int, y: p[1] as int))
        .toList(),
    direction: data['direction'] as int,
  );
}

class Puzzle {
  Puzzle({
    required this.name,
    required this.difficulty,
    required this.width,
    required this.height,
    required List<Cell> mask,
    required List<ArrowRoute> arrows,
    this.isBoss = false,
    this.secondPhase,
  }) : mask = List.unmodifiable(mask),
       arrows = List.unmodifiable(arrows);
  final String name, difficulty;
  final bool isBoss;
  final Puzzle? secondPhase;
  final int width, height;
  final List<Cell> mask;
  final List<ArrowRoute> arrows;
  factory Puzzle.fromJson(Map<String, dynamic> data) => Puzzle(
    name: data['name'] as String,
    difficulty: data['difficulty'] as String,
    isBoss: data['isBoss'] as bool? ?? false,
    secondPhase: data['secondPhase'] == null
        ? null
        : Puzzle.fromJson(data['secondPhase'] as Map<String, dynamic>),
    width: data['width'] as int,
    height: data['height'] as int,
    mask: (data['mask'] as List)
        .map((p) => (x: p[0] as int, y: p[1] as int))
        .toList(),
    arrows: (data['paths'] as List)
        .map((p) => ArrowRoute.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
  static List<Puzzle> decode(String json) => (jsonDecode(json) as List)
      .map((p) => Puzzle.fromJson(p as Map<String, dynamic>))
      .toList();
  Map<Cell, int> occupancy(Set<int> removed) => {
    for (final arrow in arrows)
      if (!removed.contains(arrow.id))
        for (final cell in arrow.cells) cell: arrow.id,
  };
  // Trace across empty parts of a silhouette: a distant arm can still block.
  Iterable<Cell> escapeRay(ArrowRoute arrow) sync* {
    final d = arrow.delta;
    for (
      var x = arrow.head.x + d.x, y = arrow.head.y + d.y;
      x >= 0 && y >= 0 && x < width && y < height;
      x += d.x, y += d.y
    ) {
      yield (x: x, y: y);
    }
  }

  Set<int> blockers(ArrowRoute arrow, Set<int> removed) {
    final occupied = occupancy(removed);
    return {
      for (final c in escapeRay(arrow))
        if (occupied.containsKey(c)) occupied[c]!,
    };
  }

  List<ArrowRoute> available(Set<int> removed) {
    final occupied = occupancy(removed);
    return arrows
        .where(
          (a) =>
              !removed.contains(a.id) &&
              !escapeRay(a).any(occupied.containsKey),
        )
        .toList();
  }

  List<int>? solve([Set<int> removed = const {}]) {
    final cleared = {...removed}, order = <int>[];
    while (cleared.length < arrows.length) {
      final moves = available(cleared);
      if (moves.isEmpty) return null;
      // Removal cannot create blockers. Every available choice is safe.
      cleared.add(moves.first.id);
      order.add(moves.first.id);
    }
    return order;
  }

  void validate() {
    secondPhase?.validate();
    final allowed = mask.toSet(), occupied = <Cell>{}, ids = <int>{};
    if (width < 1 ||
        height < 1 ||
        mask.isEmpty ||
        allowed.length != mask.length) {
      throw FormatException('Invalid board mask: $name');
    }
    for (final c in mask) {
      if (c.x < 0 || c.y < 0 || c.x >= width || c.y >= height) {
        throw FormatException('Cell outside board: $name');
      }
    }
    for (final arrow in arrows) {
      if (!ids.add(arrow.id) ||
          arrow.cells.isEmpty ||
          arrow.direction < 0 ||
          arrow.direction > 3) {
        throw FormatException('Invalid arrow: $name');
      }
      for (var i = 0; i < arrow.cells.length; i++) {
        final c = arrow.cells[i];
        if (!allowed.contains(c) || !occupied.add(c)) {
          throw FormatException('Overlapping or out-of-mask arrow: $name');
        }
        if (i > 0) {
          final before = arrow.cells[i - 1];
          if ((c.x - before.x).abs() + (c.y - before.y).abs() != 1) {
            throw FormatException('Disconnected arrow: $name');
          }
        }
      }
      if (arrow.cells.length > 1) {
        final before = arrow.cells[arrow.cells.length - 2];
        if (arrow.head.x - before.x != arrow.delta.x ||
            arrow.head.y - before.y != arrow.delta.y) {
          throw FormatException('Incorrect arrowhead: $name');
        }
      }
    }
    if (occupied.length != allowed.length || solve() == null) {
      throw FormatException('Incomplete or unsolvable board: $name');
    }
  }
}
