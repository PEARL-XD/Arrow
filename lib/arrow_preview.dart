import 'package:flutter/material.dart';
import 'arrow_art.dart';
import 'arrow_geometry.dart';
import 'arrow_skins.dart';
import 'puzzle.dart';
import 'shop_catalog.dart';
import 'theme_art.dart';

class ArrowSkinPreview extends StatefulWidget {
  const ArrowSkinPreview({super.key, required this.skin, required this.theme});
  final ArrowSkin skin;
  final PuzzleTheme theme;
  @override
  State<ArrowSkinPreview> createState() => _ArrowSkinPreviewState();
}

class _ArrowSkinPreviewState extends State<ArrowSkinPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Semantics(
            image: true,
            label: '${widget.skin.name} arrow on ${widget.theme.name} board',
            child: SizedBox(
              height: 126,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: motion,
                builder: (context, _) => CustomPaint(
                  key: Key('arrow-preview-${widget.skin.id}'),
                  painter: ArrowPreviewPainter(
                    skin: widget.skin,
                    theme: widget.theme,
                    progress: motion.value == 1 ? 0 : motion.value,
                    reducedMotion: reduced,
                  ),
                ),
              ),
            ),
          ),
        ),
        TextButton.icon(
          key: Key('preview-${widget.skin.id}'),
          onPressed: () {
            // Keep the effect visible even if its play button was at the top
            // of the scroll viewport while the picture was offscreen.
            Scrollable.ensureVisible(context, alignment: .2);
            motion.duration = Duration(milliseconds: reduced ? 150 : 1700);
            motion.forward(from: 0);
          },
          icon: const Icon(Icons.play_circle_outline_rounded),
          label: const Text('Preview escape'),
        ),
      ],
    );
  }
}

class ArrowPreviewPainter extends CustomPainter {
  ArrowPreviewPainter({
    required this.skin,
    required this.theme,
    required this.progress,
    this.reducedMotion = false,
  });
  final ArrowSkin skin;
  final PuzzleTheme theme;
  final double progress;
  final bool reducedMotion;
  static final route = ArrowRoute(
    id: 0,
    direction: 0,
    cells: [
      (x: 0, y: 2),
      (x: 1, y: 2),
      (x: 2, y: 2),
      (x: 2, y: 1),
      (x: 2, y: 0),
      (x: 3, y: 0),
      (x: 4, y: 0),
      (x: 5, y: 0),
      (x: 5, y: 1),
      (x: 6, y: 1),
      (x: 7, y: 1),
    ],
  );
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    paintThemeSurface(canvas, size, theme);
    canvas.scale(size.width / 12, size.height / 4.8);
    paintSkinnedArrow(
      canvas,
      points: movingPoints(route, progress * 15),
      direction: const Offset(1, 0),
      skin: skin,
      theme: theme,
      bounds: const Rect.fromLTWH(0, 0, 12, 4.8),
      moving: progress > 0,
      progress: progress,
      reducedMotion: reducedMotion,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ArrowPreviewPainter oldDelegate) => true;
}
