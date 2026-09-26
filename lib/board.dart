import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'arrow_geometry.dart';
import 'game_controller.dart';

class MazePainter extends CustomPainter {
  MazePainter({
    required this.game,
    required this.animation,
    required this.travel,
    required this.onArrow,
    this.highlight,
    this.blocked,
  }) : super(repaint: animation);
  final GameController game;
  final Animation<double> animation;
  final double travel;
  final int? highlight, blocked;
  final ValueChanged<int> onArrow;
  static const ink = Color(0xFF24334D);
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = boardSize(game.puzzle);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / bounds.width, size.height / bounds.height);
    final dot = Paint()..color = const Color(0xFFDDE3EB);
    for (final cell in game.puzzle.mask) {
      canvas.drawCircle(cellPoint(cell), .038, dot);
    }
    for (final arrow in game.puzzle.arrows) {
      if (game.removed.contains(arrow.id)) continue;
      final moving = game.movingId == arrow.id;
      final points = movingPoints(arrow, moving ? animation.value * travel : 0);
      final color = arrow.id == blocked
          ? const Color(0xFFDC5960)
          : moving || arrow.id == highlight
          ? const Color(0xFF506BDF)
          : ink;
      final pen = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = .14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, pen);
      final head = points.last, d = arrow.delta;
      final a = head - Offset(d.x * .32 + d.y * .19, d.y * .32 - d.x * .19);
      final b = head - Offset(d.x * .32 - d.y * .19, d.y * .32 + d.x * .19);
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(head.dx, head.dy)
          ..lineTo(b.dx, b.dy),
        pen,
      );
    }
    canvas.restore();
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final bounds = boardSize(game.puzzle);
    return [
      for (final a in game.puzzle.arrows)
        if (!game.removed.contains(a.id))
          CustomPainterSemantics(
            key: ValueKey('arrow-${a.id}'),
            rect: Rect.fromCenter(
              center: Offset(
                cellPoint(a.head).dx * size.width / bounds.width,
                cellPoint(a.head).dy * size.height / bounds.height,
              ),
              width: size.width / bounds.width,
              height: size.height / bounds.height,
            ),
            properties: SemanticsProperties(
              button: true,
              textDirection: TextDirection.ltr,
              label:
                  'Arrow ${a.id + 1}, points ${['right', 'down', 'left', 'up'][a.direction]}',
              onTap: game.busy || game.status != GameStatus.playing
                  ? null
                  : () => onArrow(a.id),
            ),
          ),
    ];
  };
  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) => true;
  @override
  bool shouldRebuildSemantics(covariant MazePainter oldDelegate) => true;
}
