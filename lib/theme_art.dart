import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'shop_catalog.dart';

/// Shared by the real playfield and shop previews. Quiet decoration stays
/// beneath the puzzle, never changing routes, head shapes or hit targets.
void paintThemeSurface(Canvas canvas, Size size, PuzzleTheme theme) {
  final rect = Offset.zero & size;
  canvas.save();
  canvas.clipRect(rect);
  final colors = switch (theme.id) {
    'sakura' => const [Color(0xFFFFE4ED), Color(0xFFFFFAFC), Color(0xFFF6DDEA)],
    'lagoon' => const [Color(0xFFD3F1E8), Color(0xFFF4FFFC), Color(0xFFCDEDEB)],
    'midnight' => const [
      Color(0xFF302B54),
      Color(0xFF16253C),
      Color(0xFF123440),
    ],
    _ => [theme.board, theme.board, theme.board],
  };
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(rect),
  );
  final unit = size.shortestSide;
  if (theme.id == 'sakura') {
    // Petal clusters at the corners, not high-contrast marks inside exit lanes.
    for (final corner in [
      Offset(unit * .09, unit * .1),
      Offset(size.width - unit * .08, size.height - unit * .08),
    ]) {
      for (var flower = 0; flower < 3; flower++) {
        canvas.save();
        canvas.translate(
          corner.dx + flower * unit * .055,
          corner.dy + (flower == 1 ? .075 : -.045) * unit,
        );
        for (var petal = 0; petal < 5; petal++) {
          canvas.rotate(math.pi * 2 / 5);
          canvas.drawOval(
            Rect.fromLTWH(-unit * .014, -unit * .051, unit * .028, unit * .052),
            Paint()..color = const Color(0xFFD97A9F).withValues(alpha: .17),
          );
        }
        canvas.drawCircle(
          Offset.zero,
          unit * .008,
          Paint()..color = const Color(0xFFCC9760).withValues(alpha: .35),
        );
        canvas.restore();
      }
    }
    for (var i = 0; i < 8; i++) {
      final x = size.width * (i + .5) / 8;
      final y = i.isEven ? unit * .028 : size.height - unit * .032;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: unit * .026,
          height: unit * .01,
        ),
        Paint()..color = const Color(0xFFC66592).withValues(alpha: .2),
      );
    }
  } else if (theme.id == 'lagoon') {
    for (var i = 0; i < 4; i++) {
      final y = size.height - unit * (.018 + i * .025);
      final wave = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 3) {
        wave.lineTo(x, y + math.sin(x / unit * 9 + i * .7) * unit * .014);
      }
      canvas.drawPath(
        wave,
        Paint()
          ..color = const Color(0xFF2B9F92).withValues(alpha: .16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(size.width - unit * .08, unit * .07),
        unit * (.035 + i * .027),
        Paint()
          ..color = const Color(0xFF259483).withValues(alpha: .13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  } else if (theme.id == 'midnight') {
    // Border constellations remain visually distinct from the grid's dots.
    for (var i = 0; i < 18; i++) {
      final x = size.width * (i + .5) / 18;
      final y = i.isEven
          ? unit * (.024 + i % 3 * .012)
          : size.height - unit * (.025 + i % 3 * .009);
      final r = unit * (i % 4 == 0 ? .006 : .003);
      final pen = Paint()
        ..color = const Color(0xFFAFCCF6).withValues(alpha: .5);
      canvas.drawCircle(Offset(x, y), r * .45, pen);
      if (i % 4 == 0) {
        pen
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7;
        canvas.drawLine(Offset(x - r, y), Offset(x + r, y), pen);
        canvas.drawLine(Offset(x, y - r), Offset(x, y + r), pen);
      }
    }
    final moon = Offset(size.width - unit * .09, unit * .09);
    canvas.drawCircle(
      moon,
      unit * .024,
      Paint()..color = const Color(0xFFDCE7FF).withValues(alpha: .23),
    );
  }
  canvas.restore();
}

Shader? themeArrowShader(PuzzleTheme theme, Rect bounds) {
  final colors = switch (theme.id) {
    'sakura' => const [Color(0xFF6F355D), Color(0xFFAD496B)],
    'lagoon' => const [Color(0xFF155B68), Color(0xFF237B63)],
    'midnight' => const [Color(0xFFE3D7FF), Color(0xFFBDEEFF)],
    _ => null,
  };
  return colors == null
      ? null
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(bounds);
}
