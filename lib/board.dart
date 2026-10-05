import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'arrow_geometry.dart';
import 'game_controller.dart';
import 'theme_art.dart';
import 'arrow_art.dart';

class MazePainter extends CustomPainter {
  MazePainter({
    required this.game,
    required this.animation,
    required this.travel,
    required this.onArrow,
    this.highlight,
    this.blocked,
    this.reducedMotion = false,
  }) : super(repaint: animation);
  final GameController game;
  final Animation<double> animation;
  final double travel;
  final int? highlight, blocked;
  final bool reducedMotion;
  final ValueChanged<int> onArrow;
  static const ink = Color(0xFF24334D);
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = boardSize(game.puzzle);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    paintThemeSurface(canvas, size, game.inventory.theme);
    canvas.scale(size.width / bounds.width, size.height / bounds.height);
    final theme = game.inventory.theme;
    final dot = Paint()..color = theme.dots;
    for (final cell in game.puzzle.mask) {
      canvas.drawCircle(cellPoint(cell), .038, dot);
    }
    for (final arrow in game.puzzle.arrows) {
      if (game.removed.contains(arrow.id)) continue;
      final moving = game.movingId == arrow.id;
      final points = movingPoints(arrow, moving ? animation.value * travel : 0);
      paintSkinnedArrow(
        canvas,
        points: points,
        direction: Offset(arrow.delta.x.toDouble(), arrow.delta.y.toDouble()),
        skin: game.inventory.arrow,
        variant: arrow.id,
        theme: theme,
        bounds: Offset.zero & bounds,
        moving: moving,
        progress: animation.value,
        highlighted: arrow.id == highlight,
        blocked: arrow.id == blocked,
        reducedMotion: reducedMotion,
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
