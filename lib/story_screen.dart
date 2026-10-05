import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'story.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key, required this.scene});
  final StoryScene scene;
  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  int page = 0;
  bool closing = false;
  final scroll = ScrollController();
  void leave() {
    if (closing) return;
    closing = true;
    Navigator.pop(context);
  }

  void turn(int next) {
    if (closing) return;
    if (scroll.hasClients) scroll.jumpTo(0);
    setState(() => page = next);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final panel = chapterPanels[scene.chapter][scene.panels[page]];
    final last = page == scene.panels.length - 1;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return Scaffold(
      backgroundColor: const Color(0xFF121A2C),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${storyNames[scene.chapter].toUpperCase()} · ${storyTitles[scene.chapter].toUpperCase()}',
                          style: const TextStyle(
                            color: Color(0xFFE8C682),
                            letterSpacing: 1.5,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: leave,
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      children: [
                        Text(
                          scene.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedSwitcher(
                          duration: duration,
                          child: Container(
                            key: ValueKey(panel.number),
                            decoration: BoxDecoration(
                              color: const Color(0xFF202A40),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFF46516B),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .25),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(21),
                              child: Column(
                                children: [
                                  StoryIllustration(panel: panel),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      22,
                                      22,
                                      24,
                                    ),
                                    child: Text(
                                      panel.caption,
                                      key: const Key('story-caption'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        height: 1.6,
                                        color: Color(0xFFFFF2D5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (scene.id == 'keeper') ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Checkpoint reached · hearts restored\nYou can retry the inner seal from here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFE8C682),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Column(
                    children: [
                      Text(
                        '${page + 1} / ${scene.panels.length}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Previous page',
                            onPressed: page > 0 ? () => turn(page - 1) : null,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              key: const Key('story-next'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFEBC77E),
                                foregroundColor: const Color(0xFF202A40),
                              ),
                              onPressed: () => last ? leave() : turn(page + 1),
                              child: Text(
                                last
                                    ? (scene.restored
                                          ? 'Keep this memory'
                                          : 'Continue journey')
                                    : 'Continue',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays one supplied illustration directly from the shared atlas.
/// The file stays unchanged; native captions scale with phone text size.
class StoryIllustration extends StatefulWidget {
  const StoryIllustration({super.key, required this.panel});
  final StoryPanel panel;
  @override
  State<StoryIllustration> createState() => _StoryIllustrationState();
}

class _StoryIllustrationState extends State<StoryIllustration> {
  ImageStream? stream;
  ImageInfo? frame;
  bool failed = false;
  late final listener = ImageStreamListener(
    (info, synchronous) {
      if (!mounted) {
        info.dispose();
        return;
      }
      final previous = frame;
      setState(() {
        frame = info;
        failed = false;
      });
      previous?.dispose();
    },
    onError: (Object error, StackTrace? trace) {
      if (mounted) setState(() => failed = true);
    },
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    resolveImage();
  }

  @override
  void didUpdateWidget(StoryIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.panel.asset != widget.panel.asset) resolveImage();
  }

  void resolveImage() {
    final next = AssetImage(
      widget.panel.asset,
    ).resolve(createLocalImageConfiguration(context));
    if (stream?.key == next.key) return;
    stream?.removeListener(listener);
    frame?.dispose();
    frame = null;
    failed = false;
    stream = next..addListener(listener);
  }

  @override
  void dispose() {
    stream?.removeListener(listener);
    frame?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: widget.panel.description,
    child: AspectRatio(
      aspectRatio: widget.panel.art.width / widget.panel.art.height,
      child: frame != null
          ? CustomPaint(painter: _PanelPainter(frame!.image, widget.panel.art))
          : Center(
              child: failed
                  ? const Icon(Icons.image_outlined, color: Colors.white54)
                  : const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFEBC77E),
                      ),
                    ),
            ),
    ),
  );
}

class _PanelPainter extends CustomPainter {
  _PanelPainter(this.image, this.art);
  final ui.Image image;
  final Rect art;
  @override
  void paint(Canvas canvas, Size size) {
    final source = Rect.fromLTRB(
      art.left * image.width / 1536,
      art.top * image.height / 1024,
      art.right * image.width / 1536,
      art.bottom * image.height / 1024,
    );
    canvas.drawImageRect(
      image,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_PanelPainter old) => image != old.image || art != old.art;
}
