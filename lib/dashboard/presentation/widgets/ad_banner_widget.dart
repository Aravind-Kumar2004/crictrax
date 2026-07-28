import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../dashboard_screen.dart';

// ─── Ad Model ────────────────────────────────────────────────────────────────
class AdSlide {
  final String headline;
  final String description;
  final List<String> features;
  final String ctaLabel;
  final Color accentColor;
  final IconData icon;
  final String? imagePath;
  final bool fullImage;

  const AdSlide({
    required this.headline,
    required this.description,
    required this.features,
    required this.ctaLabel,
    required this.accentColor,
    required this.icon,
    this.imagePath,
    this.fullImage = false,
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
  final FocusNode _bannerFocus = FocusNode();

  bool _hasFocus = false;

  Timer? _autoTimer;
  int _currentPage = 0;

  // ── Fixed TV banner height — never derived from image aspect ratio ────────
  static const double _bannerHeight = 200.0;

  static const _demoSlides = [
    AdSlide(
      headline: 'YOUR BRAND HERE',
      description:
      'Reach thousands of cricket fans in real-time across every live match on CRICTRAX TV.',
      features: [
        'Live Streaming',
        'Tournament Promotion',
        'Digital Advertising',
      ],
      ctaLabel: 'ADVERTISE NOW',
      accentColor: Color(0xFF00D4FF),
      icon: Icons.rocket_launch_rounded,
      imagePath: 'assets/images/ad_1.jpg',
    ),
    AdSlide(
      headline: 'SPONSOR A TOURNAMENT',
      description:
      'Get your logo in front of every viewer with broadcast-grade placements and overlays.',
      features: [
        'Logo Placement',
        'Live Score Overlays',
        'Broadcast Mentions',
      ],
      ctaLabel: 'GET VISIBILITY',
      accentColor: Color(0xFFFF6B35),
      icon: Icons.emoji_events_rounded,
      imagePath: 'assets/images/ad_2.png',
    ),
    AdSlide(
      headline: 'PLAY. SCORE. DOMINATE.',
      description:
      'The future of local cricket is being scored right now — join the movement today.',
      features: [
        'Real-Time Scoring',
        'Team Management',
        'Player Statistics',
      ],
      ctaLabel: 'JOIN CRICTRAX',
      accentColor: Color(0xFF00E676),
      icon: Icons.sports_cricket_rounded,
      imagePath: 'assets/images/ad_3.jpg',
    ),
    AdSlide(
      headline: 'GO LIVE TODAY',
      description:
      'Set up your turf, your teams, your tournament, and start broadcasting in minutes.',
      features: [
        'Quick Setup',
        'Instant Broadcast',
        'Fan Engagement',
      ],
      ctaLabel: 'START SCORING',
      accentColor: Color(0xFFFFD600),
      icon: Icons.bolt_rounded,
      imagePath: 'assets/images/ad_4.jpg',
    ),

    AdSlide(
      headline: 'Decathlon',
      description: 'the ultimate track and field test of speed, strength, and endurance',
      features: [
        'Hiking',
        'Sports',
        'Fitness'
      ],

      ctaLabel: 'Grab Yours',
      accentColor: Color(0xFF002D91),
      icon: Icons.shop_2_rounded,
      imagePath: 'assets/images/ad_1.png',
    ),

    AdSlide(
      headline: 'Revolt Energy',
      description: 'Fuel your game with instant energy, focus, and endurance for every match.',
      features: [
        'Instant Energy',
        'Electrolytes',
        'Zero Crash',
      ],
      ctaLabel: 'Power Up',
      accentColor: const Color(0xFFAEFF34),
      icon: Icons.bolt_rounded,
      imagePath: 'assets/images/ad2.png',
    ),

    AdSlide(
      headline: 'Nexo Physio',
      description: 'Professional sports physiotherapy and rehabilitation to keep athletes match-ready.',
      features: [
        'Sports Injury',
        'Rehabilitation',
        'Recovery',
      ],
      ctaLabel: 'Book Now',
      accentColor: const Color(0xFF888888),
      icon: Icons.medical_services_rounded,
      imagePath: 'assets/images/ad3.png',
    ),

    AdSlide(
      headline: 'Zepto',
      description: 'Groceries, snacks, drinks, and essentials delivered to your doorstep in minutes.',
      features: [
        '10-Min Delivery',
        'Fresh Grocery',
        'Best Deals',
      ],
      ctaLabel: 'Shop Now',
      accentColor: const Color(0xFF8E24AA),
      icon: Icons.shopping_bag_rounded,
      imagePath: 'assets/images/ad4.png',
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
    // Horizontal slide only — no zoom / scale.
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _phraseCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _phraseCtrl, curve: Curves.easeOut);

    _phraseCtrl.forward();
    _startAutoPlay();
  }
  void _startAutoPlay() {
    _autoTimer?.cancel();

    _autoTimer = Timer.periodic(widget.autoPlayInterval, (_) {

      if (_hasFocus) return;

      final next = (_currentPage + 1) % _slides.length;

      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
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
    _bannerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Fixed-height banner — constant across every slide ───────────────
        TvFocusWrapper(
          focusNode: _bannerFocus,
          onFocusChange: (focused) {
            setState(() {
              _hasFocus = focused;
            });
          },
          onTap: () {
            debugPrint("Advertisement Selected");
          },
          builder: (context, focused, hovered) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: focused
                      ? const Color(0xFF00D4FF)
                      : Colors.transparent,
                  width: 3,
                ),
                boxShadow: focused
                    ? [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withOpacity(.35),
                    blurRadius: 20,
                  ),
                ]
                    : [],
              ),
              child: SizedBox(
                height: _bannerHeight,
                width: double.infinity,
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
            );
          },
        ),
        const SizedBox(height: 6),
        _buildDotIndicators(),
      ],
    );
  }

  // ── Premium TV dot indicator — small grey dots, glowing accent when active ─
  Widget _buildDotIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (i) {
        final active = i == _currentPage;
        final color = _slides[i].accentColor;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: active ? 10 : 6,
          height: active ? 10 : 6,
          decoration: BoxDecoration(
            color: active ? color : Colors.white.withOpacity(0.22),
            shape: BoxShape.circle,
            boxShadow: active
                ? [
              BoxShadow(
                color: color.withOpacity(0.65),
                blurRadius: 10,
                spreadRadius: 1.5,
              ),
            ]
                : [],
          ),
        );
      }),
    );
  }
}

// ─── Single Slide Card ────────────────────────────────────────────────────────
// Layout, fixed 40 / 45 / 15 split:
//   LEFT   (40%) — image panel, flush to the card edge, BoxFit.cover, never
//                  stretches, gradient fade into the text panel.
//   CENTER (45%) — SPONSORED tag, headline, description, 3 feature bullets.
//   RIGHT  (15%) — large CTA button, rocket icon, "Powered by CRICTRAX".
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
    if (slide.fullImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child:Image.asset(
          slide.imagePath!,
          fit: BoxFit.fill,
        )
      );
    }
    final hasImage = slide.imagePath != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF080E1A),
            const Color(0xFF0A1628),
            slide.accentColor.withOpacity(0.10),
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
            color: slide.accentColor.withOpacity(0.14),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Dot grid texture (full card) ──────────────────────────────
            Positioned.fill(
              child: CustomPaint(painter: _DotGridPainter(slide.accentColor)),
            ),

            // ── Main row: fixed 40 / 45 / 15 split ────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT (40%) — image panel, flush, no padding.
                Expanded(
                  flex: 45,
                  child: hasImage ? _buildImagePanel() : _buildImageFallback(),
                ),

                // CENTER (45%) — text content.
                Expanded(
                  flex: 40,
                  child: FadeTransition(
                    opacity: fadeAnim,
                    child: SlideTransition(
                      position: slideAnim,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
                        child: _buildTextBlock(),
                      ),
                    ),
                  ),
                ),

                // RIGHT (15%) — CTA button + branding.
                Expanded(
                  flex: 15,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: _buildCtaColumn(),
                  ),
                ),
              ],
            ),

            // ── Left accent stripe ─────────────────────────────────────────
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
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
                        color:
                        slide.accentColor.withOpacity(glowAnim.value * 0.7),
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

  // ── LEFT: image panel — fixed-height card, image always centered/cover ───
  Widget _buildImagePanel() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // BoxFit.cover + centered alignment guarantees no stretch/distortion
        // regardless of the source image's own aspect ratio (portrait or
        // landscape) since the panel's own bounds are fixed by the flex.
        Image.asset(
          slide.imagePath!,
          fit: BoxFit.fill,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => _buildImageFallback(),
        ),
        // Gradient fade from the image into the text panel.
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF080E1A).withOpacity(0.0),
                  const Color(0xFF080E1A).withOpacity(0.92),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF080E1A),
            slide.accentColor.withOpacity(0.14),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          slide.icon,
          color: slide.accentColor.withOpacity(0.4),
          size: 48,
        ),
      ),
    );
  }

  // ── CENTER: SPONSORED tag + headline + description + feature bullets ─────
  Widget _buildTextBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        // SPONSORED label
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: glowAnim,
              builder: (_, __) => Container(
                width: 7,
                height: 7,
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
            const SizedBox(width: 8),
            Text(
              'SPONSORED',
              style: TextStyle(
                color: slide.accentColor.withOpacity(0.9),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Headline — 34px bold white
        Text(
          slide.headline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            height: 1.1,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 4),

        // Description — 16px, 70% white
        Text(
          slide.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.70),
            fontSize: 16,
            height: 1.4,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),

        // Feature bullets — 14px
        ...slide.features.map(
              (f) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: slide.accentColor, size: 15),
                const SizedBox(width: 8),
                Text(
                  f,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── RIGHT: CTA button + rocket icon + "Powered by CRICTRAX" ──────────────
  Widget _buildCtaColumn() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        TvFocusWrapper(
            onTap: () {
            debugPrint("CTA Clicked");
            },
              builder: (context, focused, hovered) {
                return AnimatedContainer(
                  width: double.infinity,
                  duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
              color: focused
              ? Colors.white
              : Colors.transparent,
                width: 2,
                ),
               ),
             child: AnimatedBuilder(
               animation: glowAnim,
                    builder: (_, __) => Container(
                  width: double.infinity,
                padding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 8,
                    ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                        colors: [
                          slide.accentColor,
                        slide.accentColor.withOpacity(0.7),
                        ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                ),
                      child: Text(
                     slide.ctaLabel,
                     textAlign: TextAlign.center,
                  ),
                ),
                ),
              );
              },
             ),

        const SizedBox(height: 16),

        // Rocket icon orb
        AnimatedBuilder(
          animation: glowAnim,
          builder: (_, __) => Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.35),
              border: Border.all(
                color: slide.accentColor.withOpacity(glowAnim.value * 0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.accentColor.withOpacity(glowAnim.value * 0.3),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Icon(slide.icon, color: slide.accentColor, size: 20),
          ),
        ),
        const SizedBox(height: 6),

        // Powered by CRICTRAX
        Text(
          'Powered by',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'CRICTRAX',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: slide.accentColor.withOpacity(0.85),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
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