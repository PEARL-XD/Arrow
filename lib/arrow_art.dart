import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'arrow_skins.dart';
import 'shop_catalog.dart';
import 'theme_art.dart';

/// A shared renderer for preview and gameplay; all distances use grid units.
/// Effects never influence the route, exit checks or tap geometry.
void paintSkinnedArrow(
  Canvas canvas, {
  required List<Offset> points,
  required Offset direction,
  required ArrowSkin skin,
  required PuzzleTheme theme,
  required Rect bounds,
  int variant = 0,
  bool moving = false,
  double progress = 0,
  bool highlighted = false,
  bool blocked = false,
  bool reducedMotion = false,
}) {
  final palette = skin.colorsFor(theme.board.computeLuminance() < .3);
  final colors = List<Color>.generate(
    palette.length,
    (i) => palette[(i + variant) % palette.length],
  );
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    final point = i == points.length - 1 && skin.id != 'classic'
        ? points[i] - direction * .18
        : points[i];
    path.lineTo(point.dx, point.dy);
  }
  final head = points.last;
  final a =
      head -
      Offset(
        direction.dx * .32 + direction.dy * .19,
        direction.dy * .32 - direction.dx * .19,
      );
  final b =
      head -
      Offset(
        direction.dx * .32 - direction.dy * .19,
        direction.dy * .32 + direction.dx * .19,
      );
  final arrowHead = Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(head.dx, head.dy)
    ..lineTo(b.dx, b.dy);
  final pen = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = .14
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  if (blocked) {
    pen.color = const Color(0xFFDC5960);
  } else if (highlighted || (moving && skin.id == 'classic')) {
    pen.color = theme.highlight;
  } else if (skin.id == 'classic') {
    pen
      ..color = theme.ink
      ..shader = themeArrowShader(theme, bounds);
  } else {
    pen.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    ).createShader(path.getBounds().inflate(.5));
  }
  if (moving && !reducedMotion && !blocked && skin.id != 'classic') {
    if (skin.id == 'neon') {
      final halo = Paint()
        ..color = colors.last.withValues(alpha: .4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .25
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .09);
      canvas.drawPath(path, halo);
      canvas.drawPath(arrowHead, halo);
    }
    final metrics = path.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      // Bounded particle count: only the moving route emits, never the grid.
      for (var i = 0; i < 12; i++) {
        final phase = (i * .173 + progress * 2) % 1;
        final fraction = (i + .5) / 12;
        final tangent = metric.getTangentForOffset(metric.length * fraction);
        if (tangent == null) continue;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        final spread = skin.id == 'sakura' ? .34 : .22;
        final center =
            tangent.position +
            normal * ((i.isEven ? 1 : -1) * phase * spread) -
            tangent.vector * phase * .32;
        final paint = Paint()
          ..color = colors[i % 2].withValues(alpha: (1 - phase) * .8);
        final radius = .025 + (1 - phase) * .045;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(phase * math.pi + i);
        switch (skin.id) {
          case 'fire':
            canvas.drawPath(
              Path()
                ..moveTo(0, -radius * 2)
                ..lineTo(radius, radius)
                ..lineTo(-radius, radius)
                ..close(),
              paint,
            );
          case 'ice':
            canvas.drawPath(
              Path()
                ..moveTo(0, -radius * 1.6)
                ..lineTo(radius, 0)
                ..lineTo(0, radius * 1.6)
                ..lineTo(-radius, 0)
                ..close(),
              paint,
            );
          case 'sakura':
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset.zero,
                width: radius * 3,
                height: radius * 1.5,
              ),
              paint,
            );
          default:
            canvas.drawCircle(Offset.zero, radius, paint);
        }
        canvas.restore();
      }
    }
  }
  if (skin.id != 'classic' && !blocked && !highlighted) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = skin.id == 'neon' || skin.id == 'lantern' ? .23 : .18
      ..strokeCap = skin.id == 'ice' ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = skin.id == 'ice' ? StrokeJoin.bevel : StrokeJoin.round
      ..color = colors.first;
    canvas.drawPath(path, outline);
    pen.strokeWidth = skin.id == 'neon' || skin.id == 'lantern' ? .09 : .13;
    if (skin.id == 'neon' || skin.id == 'lantern') {
      pen.shader = null;
      pen.color = skin.id == 'lantern'
          ? const Color(0xFFFFDF8B)
          : const Color(0xFFC8F8FF);
    }
    if (skin.id == 'ice') {
      pen.strokeCap = StrokeCap.square;
      pen.strokeJoin = StrokeJoin.bevel;
    }
  }
  canvas.drawPath(path, pen);
  if (skin.id == 'classic' || skin.id == 'neon' || blocked || highlighted) {
    canvas.drawPath(
      arrowHead,
      Paint()
        ..color = blocked
            ? const Color(0xFFDC5960)
            : highlighted
            ? theme.highlight
            : skin.id == 'classic'
            ? pen.color
            : colors.first
        ..shader = skin.id == 'classic' ? pen.shader : null
        ..style = PaintingStyle.stroke
        ..strokeWidth = .14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (skin.id == 'neon' && !blocked && !highlighted) {
      canvas.drawPath(
        arrowHead.shift(-direction * .20),
        Paint()
          ..color = colors.last
          ..style = PaintingStyle.stroke
          ..strokeWidth = .065,
      );
    }
  } else {
    final normal = Offset(-direction.dy, direction.dx);
    final tip = Path()..moveTo(head.dx, head.dy);
    if (skin.id == 'sakura') {
      final left = head - direction * .38 + normal * .50;
      final back = head - direction * .42;
      final right = head - direction * .38 - normal * .50;
      tip.quadraticBezierTo(left.dx, left.dy, back.dx, back.dy);
      tip.quadraticBezierTo(right.dx, right.dy, head.dx, head.dy);
    } else {
      final left = head - direction * .46 + normal * .28;
      final right = head - direction * .46 - normal * .28;
      tip.lineTo(left.dx, left.dy);
      if (skin.id == 'ice' || skin.id == 'fire') {
        final notch = head - direction * .24;
        tip.lineTo(notch.dx, notch.dy);
      }
      tip.lineTo(right.dx, right.dy);
      tip.close();
    }
    canvas.drawPath(tip, Paint()..color = colors.first);
    if (skin.id == 'ice' || skin.id == 'prism') {
      canvas.drawLine(
        head - direction * .08,
        head - direction * .29,
        Paint()
          ..color = const Color(0xFFE8FAFF)
          ..strokeWidth = .045,
      );
    }
    if (skin.id == 'sakura' || skin.id == 'lantern') {
      final tail = points.first;
      if (skin.id == 'lantern') {
        canvas.drawPath(
          Path()
            ..moveTo(tail.dx, tail.dy - .13)
            ..lineTo(tail.dx + .10, tail.dy)
            ..lineTo(tail.dx, tail.dy + .13)
            ..lineTo(tail.dx - .10, tail.dy)
            ..close(),
          Paint()..color = colors.first,
        );
        canvas.drawCircle(tail, .035, Paint()..color = const Color(0xFFFFDF8B));
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: tail, width: .15, height: .24),
          Paint()..color = colors.last,
        );
      }
    }
  }
  if (highlighted) {
    // Colour alone is not the only hint cue when players mix blue skins.
    canvas.drawCircle(
      head,
      .43,
      Paint()
        ..color = theme.highlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = .055,
    );
  }
}
