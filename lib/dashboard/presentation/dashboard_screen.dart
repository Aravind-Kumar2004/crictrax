import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/physics.dart';

import '../../services/background_music_service.dart';
import 'widgets/ad_banner_widget.dart';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../ data/models/repositories/dashboard_repository.dart';
import '../ data/models/tournament_model.dart';
import '../../login/presentation/login_screen.dart';
import '../../tournament_detail/presentation/tournament_detail_screen.dart';
import 'widgets/tournament_card_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../settings/presentation/settings_screen.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _DS {
  // Palette
  static const bg = Color(0xFF050A18);
  static const surface = Color(0xFF0A1628);
  static const surfaceHigh = Color(0xFF0F1E35);
  static const accent = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live = Color(0xFFFF6B35);
  static const success = Color(0xFF00E676);
  static const warning = Color(0xFFFFB300);
  static const danger = Color(0xFFFF3D3D);
  static Color teamColor(String seed) {
    final hue = (seed.codeUnits.fold(0, (a, b) => a + b) * 37) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.75, 0.55).toColor();
  }

  // Nav rail width
  // Nav rail widths (collapsed = icon-only, expanded = hover state with labels)
  static const navWidthCollapsed = 76.0;
  static const navWidthExpanded = 200.0;
  static const navWidth =
      navWidthCollapsed; // kept for existing references (bg spacer, waveform, glow positions)

  // Radius
  static const r12 = Radius.circular(12);
  static const r16 = Radius.circular(16);
  static const r20 = Radius.circular(20);
  static const r24 = Radius.circular(24);

  // Gradients
  static const accentGrad = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const cardGrad = LinearGradient(
    colors: [Color(0xFF0F1E35), Color(0xFF080E1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const liveGrad = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFCC3300)],
  );
}

// ─── Silk Scroll Behavior ─────────────────────────────────────────────────────
// Removes scrollbar overlay (repaints every frame) and overscroll glow
class _SilkScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child; // no glow

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child; // no scrollbar repaint layer

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const _SilkScrollPhysics();
}

// ─── Silk Scroll Physics ──────────────────────────────────────────────────────
// Crisp response + fast smooth deceleration — no spring bounce
class _SilkScrollPhysics extends ScrollPhysics {
  const _SilkScrollPhysics({super.parent});

  @override
  _SilkScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _SilkScrollPhysics(parent: buildParent(ancestor));

  // How quickly velocity decays — higher = faster stop, snappier feel
  @override
  double get dragStartDistanceMotionThreshold => 1.0;

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Already at rest
    if (velocity.abs() < 0.5) return null;

    // Out of range — snap back with a tight spring
    if ((velocity > 0 && position.pixels >= position.maxScrollExtent) ||
        (velocity < 0 && position.pixels <= position.minScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    // Friction simulation — feels like glass on silk
    return FrictionSimulation(
      0.12, // friction: lower = longer glide, 0.12 = royal smooth
      position.pixels,
      velocity * 0.91, // slight velocity damping for elegance
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // 1:1 finger-to-scroll mapping — zero lag on drag start
    return offset;
  }

  @override
  bool get allowImplicitScrolling => false;
}

// ─── Dashboard Screen ─────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  final String userId;
  final String displayName;
  final String email;
  final String? sessionId;

  const DashboardScreen({
    Key? key,
    required this.userId,
    this.displayName = '',
    this.email = '',
    this.sessionId,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _repo = DashboardRepository();
  List<TournamentModel> _tournaments = [];
  bool _loading = true;
  int _selectedNavIndex = 0;
  StreamSubscription? _logoutSub;

  // Drives ad-banner collapse/fade on scroll
  final ScrollController _scrollCtrl = ScrollController();
  final _adFade = ValueNotifier<double>(1.0);
  static const double _adCollapseDistance = 160.0;

  // Animation controllers
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    BackgroundMusicService.instance.startMusic();
    _scrollCtrl.addListener(_onScroll); // NEW

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _fetchTournaments();
    _listenForLogout();
  }

  // ── Business Logic (UNCHANGED) ────────────────────────────────────────────

  void _listenForLogout() {
    if (widget.sessionId == null) {
      debugPrint(
        '⚠️ DashboardScreen: no sessionId provided — TV forced-logout listener not attached',
      );
      return;
    }
    debugPrint(
      '👂 DashboardScreen: listening for logout on tv_sessions/${widget.sessionId}',
    );
    _logoutSub = FirebaseFirestore.instance
        .collection('tv_sessions')
        .doc(widget.sessionId)
        .snapshots()
        .listen(
          (snap) {
            if (!snap.exists) return;
            final data = snap.data()!;
            if (data['loggedOut'] == true && mounted) {
              debugPrint(
                '🚪 DashboardScreen: loggedOut flag detected, showing forced logout modal',
              );
              _logoutSub?.cancel();
              _showForcedLogoutModal();
            }
          },
          onError: (e) {
            debugPrint('❌ DashboardScreen: logout listener error: $e');
          },
        );
  }

  void _showForcedLogoutModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => _ForcedLogoutDialog(),
    );
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;

      await BackgroundMusicService.instance.stopMusic();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    });
  }

  // Collapses + fades the ad banner as the user scrolls
void _onScroll() {
    final offset = _scrollCtrl.offset.clamp(0.0, _adCollapseDistance);
    final fade = 1.0 - (offset / _adCollapseDistance);
    if ((fade - _adFade.value).abs() > 0.01) {
      _adFade.value = fade;
    }
  }

@override
  void dispose() {
    _logoutSub?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _waveCtrl.dispose();
    _adFade.dispose();
    super.dispose();
  }

  Future<void> _fetchTournaments() async {
    final tournaments = await _repo.getUserTournaments(widget.userId);
    if (mounted) {
      setState(() {
        _tournaments = tournaments;
        _loading = false;
      });
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _LogoutDialog(
        onConfirm: () async {
          Navigator.pop(context);

          await BackgroundMusicService.instance.stopMusic();

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
          );
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _LoadingScreen();

    return Scaffold(
      backgroundColor: _DS.bg,
      body: Stack(
        children: [
          // ── Stadium background (content area only, nav excluded) ──────────
          Row(
            children: [
              // Spacer that matches nav rail width — keeps bg off the nav
              const SizedBox(width: 0),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Stadium photo
                    Image.asset('assets/images/dash_bg.png', fit: BoxFit.cover),
                    // Dark overlay so content stays readable
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _DS.bg.withOpacity(0.82),
                            _DS.bg.withOpacity(0.70),
                            _DS.bg.withOpacity(0.88),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                    // Left-edge fade so content blends into nav seamlessly
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_DS.bg, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── Crowd waveform overlay ────────────────────────────────────────
          Positioned(
            left: _DS.navWidth,
            top: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) =>
                  CustomPaint(painter: _CrowdWaveformPainter(_waveCtrl.value)),
            ),
          ),
          // ── Ambient glows ─────────────────────────────────────────────────
          Positioned(
            top: -120,
            left: _DS.navWidth + 60,
            child: _AmbientGlow(color: _DS.accent, size: 400),
          ),
          Positioned(
            bottom: -80,
            right: 100,
            child: _AmbientGlow(color: const Color(0xFF6C3AFF), size: 300),
          ),
          // ── Main layout ───────────────────────────────────────────────────
          // ── Main layout ───────────────────────────────────────────────────
          Row(
            children: [
              const SizedBox(
                width: _DS.navWidthCollapsed,
              ), // fixed slot, rail overlays on top
              Expanded(child: _buildMainContent()),
            ],
          ),
          // Rail drawn last so it overlays content while expanding —
          // doesn't push or reflow the main content during animation.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _SideNavRail(
              selectedIndex: _selectedNavIndex,
              onIndexChanged: (i) {
                if (i == 3) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const SettingsScreen(initialNavIndex: 3),
                    ),
                  );
                } else {
                  setState(() => _selectedNavIndex = i);
                }
              },
              onLogout: () => _showLogoutDialog(context),
              tournamentCount: _tournaments.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 40, right: 48, bottom: 24),
      child: ScrollConfiguration(
        behavior: _SilkScrollBehavior(),
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          physics: const _SilkScrollPhysics(),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _adFade,
                builder: (_, fade, __) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: fade,
                        child: Opacity(
                          opacity: fade,
                          child: const AdBannerWidget(),
                        ),
                      ),
                    ),
                    SizedBox(height: 20 * fade),
                  ],
                ),
              ),
_buildSectionHeader('My Tournaments', _tournaments.length),
              const SizedBox(height: 28),
              _tournaments.isEmpty
                  ? _buildEmptyState()
                  : _buildTournamentRows(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final initial = widget.displayName.isNotEmpty
        ? widget.displayName[0].toUpperCase()
        : 'U';
    final name = widget.displayName.isNotEmpty ? widget.displayName : 'Player';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _DS.accentGrad,
            boxShadow: [
              BoxShadow(
                color: _DS.accent.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WELCOME BACK',
              style: TextStyle(
                color: _DS.accent.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                height: 1.1,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Stats chips row
        Row(
          children: [
            _ScoreFlashChip(
              icon: Icons.emoji_events_rounded,
              label: '${_tournaments.length}',
              sublabel: 'Tournaments',
              color: _DS.accent,
            ),
            const SizedBox(width: 12),
            _StatChip(
              icon: Icons.circle,
              label: 'LIVE',
              sublabel: 'Scoring',
              color: _DS.live,
              pulse: true,
              pulseAnim: _pulseAnim,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBroadcastBanner() {
    return Container(
      width: double.infinity,
      height: 148,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [const Color(0xFF0A1628), const Color(0xFF0D1E38)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Subtle cricket field pattern overlay
            Positioned.fill(child: CustomPaint(painter: _GridPatternPainter())),
            // Left accent stripe
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_DS.accent, _DS.accentDim],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, __) => Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _DS.live.withOpacity(_pulseAnim.value),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _DS.live.withOpacity(0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ADVERTISEMENT',
                            style: TextStyle(
                              color: _DS.live,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ad Space',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Premium placement available for sponsors',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Decorative cricket icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _DS.accent.withOpacity(0.05),
                      border: Border.all(
                        color: _DS.accent.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.sports_cricket,
                      color: _DS.accent.withOpacity(0.2),
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '— ${title.toUpperCase()} —',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _DS.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _DS.accent.withOpacity(0.25)),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: _DS.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        // Decorative line
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_DS.accent.withOpacity(0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTournamentModal(BuildContext context, TournamentModel t) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(ctx).size.width * 0.52,
                  constraints: const BoxConstraints(maxWidth: 640),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1628),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: _DS.accent.withOpacity(0.10),
                        blurRadius: 48,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 32,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header stripe
                        Container(
                          height: 4,
                          decoration: const BoxDecoration(
                            gradient: _DS.accentGrad,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title row
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _DS.accent.withOpacity(0.08),
                                      border: Border.all(
                                        color: _DS.accent.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.emoji_events_rounded,
                                      color: _DS.accent,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          t.id,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.3,
                                            ),
                                            fontSize: 11,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(ctx),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.08),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.white.withOpacity(0.4),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              // Divider
                              Divider(
                                color: Colors.white.withOpacity(0.06),
                                height: 1,
                              ),
                              const SizedBox(height: 28),
                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                TournamentDetailScreen(
                                                  tournamentId: t.id,
                                                  tournament: t,
                                                  sessionId: widget.sessionId,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: _DS.accentGrad,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _DS.accent.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 16,
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'Open Tournament',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(ctx),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 20,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.08),
                                        ),
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
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
            ),
          ),
        );
      },
    );
  }

Widget _buildTournamentRows() {
    final live = _tournaments
        .where((t) => t.status.toLowerCase() == 'active')
        .toList();
    final upcoming = _tournaments
        .where((t) => t.status.toLowerCase() == 'upcoming')
        .toList();
    final completed = _tournaments
        .where((t) => t.status.toLowerCase() == 'completed')
        .toList();

    debugPrint('🟢 Live/Active: ${live.length}');
    debugPrint('⏳ Upcoming: ${upcoming.length}');
    debugPrint('✅ Completed: ${completed.length}');
    for (final t in _tournaments) {
      debugPrint('  → ${t.name} | status=${t.status} | start=${t.startDate} | end=${t.endDate}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
     if (live.isNotEmpty) ...[
          _buildRowHeader('Live', live.length, _DS.live,
              Icons.sensors_rounded),
          const SizedBox(height: 14),
          _buildHorizontalRow(live),
          const SizedBox(height: 32),
        ],
      if (upcoming.isNotEmpty) ...[
          _buildRowHeader('Upcoming', upcoming.length, _DS.warning,
              Icons.event_rounded),
          const SizedBox(height: 14),
          _buildHorizontalRow(upcoming),
          const SizedBox(height: 32),
        ],
   if (completed.isNotEmpty) ...[
          _buildRowHeader('Completed', completed.length, _DS.success,
              Icons.workspace_premium_rounded),
          const SizedBox(height: 14),
          _buildHorizontalRow(completed),
          const SizedBox(height: 32),
        ],
        if (live.isEmpty && upcoming.isEmpty && completed.isEmpty)
          _buildEmptyState(),
      ],
    );
  }

 Widget _buildRowHeader(String title, int count, Color color, IconData icon) {
  return Row(
    children: [
      // Icon badge
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 12),
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.3), Colors.transparent],
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildHorizontalRow(List<TournamentModel> list) {
  const cardWidth = 260.0;
  const cardHeight = 195.0;
  const maxVisible = 6; // cards shown before "Show More" tile appears
  final showMore = list.length > maxVisible;
  final visibleList = showMore ? list.take(maxVisible).toList() : list;

  // total items = visible cards + (1 show-more tile if needed)
  final itemCount = visibleList.length + (showMore ? 1 : 0);

  return SizedBox(
    height: cardHeight + 20,
    child: ScrollConfiguration(
      behavior: _SilkScrollBehavior(),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(
          left: 2,
          right: 24,
          top: 8,
          bottom: 8,
        ),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          // ── "Show More" tile at the end ──
          if (showMore && index == visibleList.length) {
            return _ShowMoreTile(
              remaining: list.length - maxVisible,
              width: cardWidth,
              height: cardHeight,
              allTournaments: list,
              sessionId: widget.sessionId,
            );
          }

          final t = visibleList[index];
          return SizedBox(
            width: cardWidth,
            height: cardHeight,
            // ── Uniform card background — fixes dark/black card issue ──
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628), // _DS.surface
                borderRadius: BorderRadius.circular(16),
              ),
    child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _HoverPreviewCard(
                  tournament: t,
                  onTap: () => _showTournamentModal(context, t),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 72),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _DS.accent.withOpacity(0.04),
                border: Border.all(
                  color: _DS.accent.withOpacity(0.10),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.emoji_events_outlined,
                color: _DS.accent.withOpacity(0.25),
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Tournaments Yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Create a tournament in the CRICTRAX mobile app\nand it will appear here automatically.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _DS.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _DS.accent.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    color: _DS.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Open CRICTRAX on your phone to get started',
                    style: TextStyle(
                      color: _DS.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Side Nav Rail ─────────────────────────────────────────────────────────────
class _SideNavRail extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onLogout;
  final int tournamentCount;

  const _SideNavRail({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onLogout,
    required this.tournamentCount,
  });

  @override
  State<_SideNavRail> createState() => _SideNavRailState();
}

class _SideNavRailState extends State<_SideNavRail> {
  bool _expanded = false;

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.emoji_events_rounded, label: 'Events'),
    (icon: Icons.play_circle_fill_rounded, label: 'Live'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _expanded = true),
      onExit: (_) => setState(() => _expanded = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: _expanded ? _DS.navWidthExpanded : _DS.navWidthCollapsed,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: _expanded
                ? [
                    Colors.black.withOpacity(0.52),
                    Colors.black.withOpacity(0.28),
                    Colors.transparent,
                  ]
                : [Colors.black.withOpacity(0.22), Colors.transparent],
            stops: _expanded ? const [0.0, 0.65, 1.0] : const [0.0, 1.0],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 36),
            // Logo mark — shrinks slightly when collapsed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _expanded ? 40 : 36,
                    height: _expanded ? 40 : 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: _DS.accentGrad,
                      boxShadow: [
                        BoxShadow(
                          color: _DS.accent.withOpacity(0.35),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.sports_cricket,
                      color: Colors.white,
                      size: _expanded ? 20 : 18,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: _expanded
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 12),
                              Text(
                                'CRICTRAX',
                                style: TextStyle(
                                  color: _DS.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Nav items
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              return _NavItem(
                icon: item.icon,
                label: item.label,
                isSelected: widget.selectedIndex == i,
                expanded: _expanded,
                onTap: () => widget.onIndexChanged(i),
              );
            }),

            const Spacer(),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white.withOpacity(0.06), height: 1),
            ),
            const SizedBox(height: 16),

            // Logout
            _NavItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              isSelected: false,
              expanded: _expanded,
              onTap: widget.onLogout,
              isDanger: true,
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool expanded;
  final VoidCallback onTap;
  final bool isDanger;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.expanded,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected;
    final hovered = _hovered && !active;
 final activeColor = widget.isDanger ? _DS.danger : _DS.accent;
    final hoverColor = Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedOpacity(
            opacity: active ? 1.0 : (_hovered ? 1.0 : 0.72),
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              padding: EdgeInsets.symmetric(
                vertical: widget.expanded ? 12 : 10,
                horizontal: widget.expanded ? 14 : 4,
              ),
         decoration: BoxDecoration(
                color: active
                    ? activeColor.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active
                      ? activeColor.withOpacity(0.3)
                      : Colors.transparent,
                  width: 1,
                ),
                boxShadow: active && !widget.isDanger
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with its own hover highlight — tight fit
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _hovered && !active
                          ? Colors.white.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: active
                          ? activeColor
                          : _hovered
                          ? Colors.white
                          : Colors.white.withOpacity(0.55),
                      size: widget.expanded ? 20 : 22,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: widget.expanded
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 150),
                                style: TextStyle(
                                  color: active
                                      ? activeColor
                                      : _hovered
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.55),
                                  fontSize: 13,
                                  fontWeight: _hovered || active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                                child: Text(widget.label),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hover Preview Card ───────────────────────────────────────────────────────
// ─── Hover Preview Card ───────────────────────────────────────────────────────
class _HoverPreviewCard extends StatefulWidget {
  final TournamentModel tournament;
  final VoidCallback onTap;

  const _HoverPreviewCard({required this.tournament, required this.onTap});

  @override
  State<_HoverPreviewCard> createState() => _HoverPreviewCardState();
}

class _HoverPreviewCardState extends State<_HoverPreviewCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onEnter(_) {
    setState(() => _hovered = true);
    _ctrl.forward();
  }

  void _onExit(_) {
    _ctrl.reverse().then((_) {
      if (mounted) setState(() => _hovered = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final teamColor = _DS.teamColor(t.name);

    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      cursor: SystemMouseCursors.click,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Base card with animated border + shadow ──
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _hovered
                            ? teamColor.withOpacity(0.7)
                            : Colors.white.withOpacity(0.06),
                        width: _hovered ? 2 : 1,
                      ),
                      boxShadow: _hovered
                          ? [
                              BoxShadow(
                                color: teamColor.withOpacity(0.25),
                                blurRadius: 28,
                                spreadRadius: 2,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // The actual card widget
                          TournamentCardWidget(
                            tournament: t,
                            onTap: widget.onTap,
                          ),
                          // Overlay that fades in on hover — darkens card
                          // so the action button stands out
                          if (_hovered)
                            Positioned.fill(
                              child: FadeTransition(
                                opacity: _fadeAnim,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.15),
                                        Colors.black.withOpacity(0.55),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Top accent bar that slides in
                          if (_hovered)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: FadeTransition(
                                opacity: _fadeAnim,
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [teamColor, _DS.accent],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Bottom action strip
                          if (_hovered)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: FadeTransition(
                                opacity: _fadeAnim,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.8),
                                      ],
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                _DS.accent.withOpacity(0.95),
                                                _DS.accentDim,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _DS.accent.withOpacity(
                                                  0.35,
                                                ),
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                'Open',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final bool pulse;
  final Animation<double>? pulseAnim;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    this.pulse = false,
    this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = pulse && pulseAnim != null
        ? AnimatedBuilder(
            animation: pulseAnim!,
            builder: (_, __) => Icon(
              Icons.circle,
              color: color.withOpacity(pulseAnim!.value),
              size: 8,
            ),
          )
        : Icon(icon, color: color, size: 14);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  color: color.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Score Flash Chip (animates on value change) ───────────────────────────────
class _ScoreFlashChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _ScoreFlashChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  State<_ScoreFlashChip> createState() => _ScoreFlashChipState();
}

class _ScoreFlashChipState extends State<_ScoreFlashChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashCtrl;
  late Animation<double> _flashAnim;
  String? _prevLabel;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);
    _prevLabel = widget.label;
  }

  @override
  void didUpdateWidget(_ScoreFlashChip old) {
    super.didUpdateWidget(old);
    if (old.label != widget.label) {
      _flashCtrl.forward(from: 0);
      _prevLabel = widget.label;
    }
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flashAnim,
      builder: (_, child) {
        final glow = _flashAnim.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.08 + glow * 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.color.withOpacity(0.2 + glow * 0.4),
              width: 1,
            ),
            boxShadow: glow > 0.01
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(glow * 0.55),
                      blurRadius: 18 * glow,
                      spreadRadius: 2 * glow,
                    ),
                  ]
                : [],
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, color: widget.color, size: 14),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _flashAnim,
                builder: (_, __) => Text(
                  widget.label,
                  style: TextStyle(
                    color: Color.lerp(
                      widget.color,
                      const Color(0xFFFFD700),
                      _flashAnim.value,
                    ),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              Text(
                widget.sublabel,
                style: TextStyle(
                  color: widget.color.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Loading Screen ───────────────────────────────────────────────────────────
class _LoadingScreen extends StatefulWidget {
  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: _DS.accentGrad,
                boxShadow: [
                  BoxShadow(
                    color: _DS.accent.withOpacity(0.4),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.sports_cricket,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'CRICTRAX',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'TV SCORECARD',
              style: TextStyle(
                color: _DS.accent.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: _DS.accent.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(_DS.accent),
                  minHeight: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _fade,
              child: Text(
                'Loading your tournaments…',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Forced Logout Dialog ─────────────────────────────────────────────────────
class _ForcedLogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 400,
            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 52),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117).withOpacity(0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _DS.danger.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _DS.danger.withOpacity(0.15),
                  blurRadius: 48,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _DS.danger.withOpacity(0.08),
                    border: Border.all(
                      color: _DS.danger.withOpacity(0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: _DS.danger,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Session Ended',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You have been logged out remotely.\nRedirecting to login…',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: _DS.accent,
                    strokeWidth: 2.5,
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

// ─── Logout Confirm Dialog ────────────────────────────────────────────────────
class _LogoutDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _LogoutDialog({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 380,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628).withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _DS.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: _DS.danger,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Are you sure you want to logout from this TV device?',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Focus(
                        child: Builder(
                          builder: (ctx) {
                            final f = Focus.of(ctx).hasFocus;
                            return GestureDetector(
                              onTap: onCancel,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: f
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: f
                                        ? Colors.white.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Focus(
                        child: Builder(
                          builder: (ctx) {
                            final f = Focus.of(ctx).hasFocus;
                            return GestureDetector(
                              onTap: onConfirm,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: f
                                        ? [
                                            const Color(0xFFFF5252),
                                            const Color(0xFFCC0000),
                                          ]
                                        : [
                                            _DS.danger.withOpacity(0.8),
                                            const Color(0xFF990000),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: f
                                      ? [
                                          BoxShadow(
                                            color: _DS.danger.withOpacity(0.4),
                                            blurRadius: 16,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Sign Out',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Ambient Glow ─────────────────────────────────────────────────────────────
class _AmbientGlow extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientGlow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.07),
            color.withOpacity(0.03),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ─── Grid Pattern Painter ─────────────────────────────────────────────────────
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.018)
      ..strokeWidth = 0.5;

    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPatternPainter _) => false;
}

// ─── Crowd Waveform Painter ────────────────────────────────────────────────────
class _CrowdWaveformPainter extends CustomPainter {
  final double phase;
  const _CrowdWaveformPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final bars = 80;
    final barW = size.width / bars;
    final cx = size.height / 2;
    final rng = math.Random(42);

    for (int i = 0; i < bars; i++) {
      // Each bar has a base height + animated offset that mimics crowd noise
      final base = rng.nextDouble() * 0.28 + 0.04;
      final wave1 = math.sin(phase * 2 * math.pi + i * 0.18) * 0.10;
      final wave2 = math.sin(phase * 2 * math.pi * 0.7 + i * 0.42) * 0.06;
      final h = (base + wave1 + wave2).clamp(0.02, 0.55) * size.height;

      final x = i * barW + barW * 0.15;
      final opacity = (0.04 + (h / size.height) * 0.10).clamp(0.0, 0.14);

      final paint = Paint()
        ..color = const Color(0xFF00D4FF).withOpacity(opacity)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barW * 0.55;

      // Mirror top + bottom for stadium feel
      canvas.drawLine(Offset(x, cx - h / 2), Offset(x, cx + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_CrowdWaveformPainter old) => old.phase != phase;
}
// ─── Show More Tile ───────────────────────────────────────────────────────────
class _ShowMoreTile extends StatefulWidget {
  final int remaining;
  final double width;
  final double height;
  final List<TournamentModel> allTournaments;
  final String? sessionId;

  const _ShowMoreTile({
    required this.remaining,
    required this.width,
    required this.height,
    required this.allTournaments,
    required this.sessionId,
  });

  @override
  State<_ShowMoreTile> createState() => _ShowMoreTileState();
}

class _ShowMoreTileState extends State<_ShowMoreTile> {
  bool _hovered = false;

  void _showAllSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scrollCtrl) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0A1628),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        'ALL TOURNAMENTS',
                        style: TextStyle(
                          color: _DS.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _DS.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _DS.accent.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${widget.allTournaments.length}',
                          style: TextStyle(
                            color: _DS.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  color: Colors.white.withOpacity(0.06),
                  height: 1,
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    itemCount: widget.allTournaments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx2, i) {
                      final t = widget.allTournaments[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx2);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TournamentDetailScreen(
                                tournamentId: t.id,
                                tournament: t,
                                sessionId: widget.sessionId,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1E35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _DS.teamColor(
                                    t.name,
                                  ).withOpacity(0.15),
                                  border: Border.all(
                                    color: _DS.teamColor(
                                      t.name,
                                    ).withOpacity(0.4),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    t.name.isNotEmpty
                                        ? t.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: _DS.teamColor(t.name),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      t.city,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _DS.accent.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _DS.accent.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  t.status,
                                  style: TextStyle(
                                    color: _DS.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white.withOpacity(0.3),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showAllSheet(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _hovered
                ? _DS.accent.withOpacity(0.08)
                : const Color(0xFF0A1628),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? _DS.accent.withOpacity(0.4)
                  : Colors.white.withOpacity(0.06),
              width: _hovered ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _DS.accent.withOpacity(0.08),
                  border: Border.all(color: _DS.accent.withOpacity(0.25)),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _DS.accent,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '+${widget.remaining} more',
                style: TextStyle(
                  color: _DS.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'View all',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}