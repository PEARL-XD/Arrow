import 'dart:math' as math;
import 'dart:ui';
import 'puzzle.dart';

// Keep the full silhouette visible, but avoid a wide empty gutter around it.
const boardPadding = .9;
Offset cellPoint(Cell c) => Offset(c.x + boardPadding, c.y + boardPadding);
Size boardSize(Puzzle p) =>
    Size(p.width - 1 + 2 * boardPadding, p.height - 1 + 2 * boardPadding);
Offset pointAt(ArrowRoute arrow, double position) {
  final last = arrow.cells.length - 1;
  if (position >= last) {
    return cellPoint(arrow.head) +
        Offset(arrow.delta.x.toDouble(), arrow.delta.y.toDouble()) *
            (position - last);
  }
  if (position < 0) {
    return cellPoint(arrow.cells.first) +
        Offset(arrow.delta.x.toDouble(), arrow.delta.y.toDouble()) * position;
  }
  final i = position.floor();
  return Offset.lerp(
    cellPoint(arrow.cells[i]),
    cellPoint(arrow.cells[i + 1]),
    position - i,
  )!;
}

// Clip a constant-length interval along the route extended beyond its head.
List<Offset> movingPoints(ArrowRoute arrow, double distance) {
  final length = math.max(.45, arrow.cells.length - 1.0);
  final start = distance + (arrow.cells.length == 1 ? -.45 : 0);
  final end = start + length;
  return [
    pointAt(arrow, start),
    for (
      var i = math.max(0, start.floor() + 1);
      i <= arrow.cells.length - 1 && i < end;
      i++
    )
      cellPoint(arrow.cells[i]),
    pointAt(arrow, end),
  ];
}

double exitDistance(Puzzle p, ArrowRoute a) {
  final head = cellPoint(a.head), bounds = boardSize(p), d = a.delta;
  final edge = d.x > 0
      ? bounds.width - head.dx
      : d.x < 0
      ? head.dx
      : d.y > 0
      ? bounds.height - head.dy
      : head.dy;
  return edge + a.cells.length + 1;
}

double segmentDistance(Offset point, Offset a, Offset b) {
  final v = b - a, relative = point - a;
  if (v.distanceSquared == 0) return relative.distance;
  final t = ((relative.dx * v.dx + relative.dy * v.dy) / v.distanceSquared)
      .clamp(0.0, 1.0);
  return (point - (a + v * t)).distance;
}

ArrowRoute? hitArrow(Puzzle puzzle, Set<int> removed, Offset point) {
  ArrowRoute? best;
  var nearest = .43; // Never reach a neighboring grid line.
  for (final arrow in puzzle.arrows) {
    if (removed.contains(arrow.id)) continue;
    final points = movingPoints(arrow, 0);
    for (var i = 1; i < points.length; i++) {
      final d = segmentDistance(point, points[i - 1], points[i]);
      if (d < nearest) {
        nearest = d;
        best = arrow;
      }
    }
  }
  return best;
}
