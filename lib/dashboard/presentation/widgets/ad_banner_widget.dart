import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── Ad Model ────────────────────────────────────────────────────────────────
class AdSlide {
  final String headline;
  final String tagline;
  final String ctaLabel;
  final Color accentColor;
  final IconData icon;
  final String? imagePath;
  final bool isPortrait;

  const AdSlide({
    required this.headline,
    required this.tagline,
    required this.ctaLabel,
    required this.accentColor,
    required this.icon,
    this.imagePath,
    this.isPortrait = false,
  });
}

// ─── Ad Banner Widget ─────────────────────────────────────────────────────────
class AdBannerWidget extends StatefulWidget {
  final List<AdSlide>? slides;
  final Duration autoPlayInterval;

  const AdBannerWidget({
    Key? key,
    this.slides,
    this.autoPlayInterval = const Duration(seconds: 5),
  }) : super(key: key);

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget>
    with TickerProviderStateMixin {
  late final PageController _pageCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _phraseCtrl;
  late Animation<double> _glowAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  Timer? _autoTimer;
  int _currentPage = 0;
  final Map<int, double> _aspectRatios = {}; // index -> width/height

  static const _demoSlides = [
    AdSlide(
      headline: 'YOUR BRAND HERE',
      tagline: 'Reach thousands of cricket fans\nin real-time across every match',
      ctaLabel: 'ADVERTISE WITH US',
      accentColor: Color(0xFF00D4FF),
      icon: Icons.rocket_launch_rounded,
      imagePath: 'assets/images/ad_1.jpg',
      isPortrait: false, // landscape — cricket world cup
    ),
    AdSlide(
      headline: 'SPONSOR A TOURNAMENT',
      tagline: 'Logo placement • Live score overlays\nBroadcast mentions • Digital banners',
      ctaLabel: 'GET VISIBILITY',
      accentColor: Color(0xFFFF6B35),
      icon: Icons.emoji_events_rounded,
      imagePath: 'assets/images/ad_2.jpeg',
      isPortrait: false, // landscape — Thums Up banner
    ),
    AdSlide(
      headline: 'PLAY. SCORE. DOMINATE.',
      tagline: 'The future of local cricket\nis being scored right now',
      ctaLabel: 'JOIN CRICTRAX',
      accentColor: Color(0xFF00E676),
      icon: Icons.sports_cricket_rounded,
      imagePath: 'assets/images/ad_3.jpg',
      isPortrait: true, // portrait — IPL poster
    ),
    AdSlide(
      headline: 'GO LIVE TODAY',
      tagline: 'Set up your turf, your teams,\nyour tournament — in minutes',
      ctaLabel: 'START SCORING',
      accentColor: Color(0xFFFFD600),
      icon: Icons.bolt_rounded,
      imagePath: 'assets/images/ad_4.jpg',
      isPortrait: false, // landscape
    ),
  ];

  List<AdSlide> get _slides => widget.slides ?? _demoSlides;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _phraseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _phraseCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _phraseCtrl, curve: Curves.easeOut);

    _phraseCtrl.forward();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      final next = (_currentPage + 1) % _slides.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
  }

  void _resolveAspectRatio(int index, String path) {
    if (_aspectRatios.containsKey(index)) return;
    final stream = AssetImage(path).resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final ratio = info.image.width / info.image.height;
      if (mounted) {
        setState(() => _aspectRatios[index] = ratio);
      }
      stream.removeListener(listener);
    }, onError: (_, __) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _phraseCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageCtrl.dispose();
    _glowCtrl.dispose();
    _phraseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSlide = _slides[_currentPage];
    if (currentSlide.imagePath != null) {
      _resolveAspectRatio(_currentPage, currentSlide.imagePath!);
    }
    final ratio = _aspectRatios[_currentPage];
    // Fallback heights while the real aspect ratio is still loading
    final fallbackHeight = currentSlide.isPortrait ? 420.0 : 260.0;
    final bannerHeight = ratio != null
        ? MediaQuery.of(context).size.width / ratio
        : fallbackHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          height: bannerHeight.clamp(180.0, 600.0), // keep banner sane on extreme ratios
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: _onPageChanged,
            itemCount: _slides.length,
            itemBuilder: (_, i) => _AdSlideCard(
              key: ValueKey(i),
              slide: _slides[i],
              glowAnim: _glowAnim,
              slideAnim: _slideAnim,
              fadeAnim: _fadeAnim,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildDotIndicators(),
      ],
    );
  }

  Widget _buildDotIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (i) {
        final active = i == _currentPage;
        final color = _slides[i].accentColor;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? color : color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ─── Single Slide Card ────────────────────────────────────────────────────────
// Layout: image docked flush to the LEFT edge of the card (no padding, no
// rounded corners on the image itself — it bleeds into the card boundary),
// text + CTA left-aligned and top-anchored in the RIGHT panel. A soft
// gradient at the image's right edge fades it into the dark background so
// the seam between image and text panel feels intentional, not abrupt.
// Same structure for both landscape and portrait slides.
class _AdSlideCard extends StatelessWidget {
  final AdSlide slide;
  final Animation<double> glowAnim;
  final Animation<Offset> slideAnim;
  final Animation<double> fadeAnim;

  const _AdSlideCard({
    super.key,
    required this.slide,
    required this.glowAnim,
    required this.slideAnim,
    required this.fadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = slide.imagePath != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF080E1A),
            const Color(0xFF0A1628),
            slide.accentColor.withOpacity(0.08),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
          color: slide.accentColor.withOpacity(0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: slide.accentColor.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        // Card-level rounding only. The image itself stays square so it
        // sits flush against the left/top/bottom edges, matching the
        // reference layout's edge-to-edge image panel.
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Dot grid (full card background texture) ──────────────────
            Positioned.fill(
              child: CustomPaint(painter: _DotGridPainter(slide.accentColor)),
            ),

            // ── Main row: image panel (left, flush) + text panel (right) ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT: image panel — flush to the card edge, no padding,
                // no independent rounding. ~43% of width (flex 43:57).
                if (hasImage)
                  Expanded(
                    flex: 43,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          slide.imagePath!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF080E1A),
                                  slide.accentColor.withOpacity(0.12),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Soft fade at the right edge of the image so it
                        // dissolves into the text panel's background
                        // instead of cutting off abruptly.
                        Positioned(
                          right: 0, top: 0, bottom: 0,
                          width: 90,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  const Color(0xFF080E1A).withOpacity(0.0),
                                  const Color(0xFF080E1A).withOpacity(0.85),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // RIGHT: text panel — left-aligned, top-anchored.
                // ~57% of width (flex 57:43), or full width if no image.
                Expanded(
                  flex: hasImage ? 57 : 100,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        _buildTextBlock(withCta: false),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _buildCtaColumn(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Left accent stripe (drawn last so it sits on top) ─────────
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: AnimatedBuilder(
                animation: glowAnim,
                builder: (_, __) => Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        slide.accentColor.withOpacity(glowAnim.value),
                        slide.accentColor.withOpacity(0.3),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: slide.accentColor
                            .withOpacity(glowAnim.value * 0.7),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Text block (headline + tagline + optional inline CTA) ───────────────
  Widget _buildTextBlock({required bool withCta}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // SPONSORED label
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: glowAnim,
              builder: (_, __) => Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: slide.accentColor.withOpacity(glowAnim.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: slide.accentColor.withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'SPONSORED',
              style: TextStyle(
                color: slide.accentColor.withOpacity(0.9),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Headline
        FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: slideAnim,
            child: Text(
              slide.headline,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                height: 1.15,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Tagline
        FadeTransition(
          opacity: fadeAnim,
          child: Text(
            slide.tagline,
            textAlign: TextAlign.left,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 13,
              height: 1.6,
              letterSpacing: 0.2,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ),

        // Optional inline CTA (kept for backwards-compat; main layout above
        // always passes withCta: false and places the CTA separately).
        if (withCta) ...[
          const SizedBox(height: 20),
          _buildCtaColumn(),
        ],
      ],
    );
  }

  // ── Icon orb + CTA button ────────────────────────────────────────────────
  Widget _buildCtaColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon orb
        AnimatedBuilder(
          animation: glowAnim,
          builder: (_, __) => Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.4),
              border: Border.all(
                color: slide.accentColor.withOpacity(glowAnim.value * 0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.accentColor.withOpacity(glowAnim.value * 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(slide.icon, color: slide.accentColor, size: 32),
          ),
        ),
        const SizedBox(height: 12),

        // CTA button
        GestureDetector(
          onTap: () {},
          child: AnimatedBuilder(
            animation: glowAnim,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: slide.accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: slide.accentColor
                      .withOpacity(0.3 + glowAnim.value * 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: slide.accentColor.withOpacity(glowAnim.value * 0.2),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(
                slide.ctaLabel,
                style: TextStyle(
                  color: slide.accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Dot Grid Painter ─────────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  final Color color;
  const _DotGridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.03);
    const spacing = 20.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}