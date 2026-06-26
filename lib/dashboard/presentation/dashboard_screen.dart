import 'dart:async';
import 'dart:math' as math;
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

  // NEW — additional broadcast palette
  static const gold = Color(0xFFFFD700);
  static const purple = Color(0xFF9B59B6);
  static const teal = Color(0xFF1ABC9C);

  // Nav rail width
  static const navWidth = 110.0;

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

  // NEW gradients
  static const goldGrad = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const successGrad = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00897B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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

  // NEW — live match data (optional, non-breaking)
  Map<String, dynamic>? _featuredLiveMatch;
  StreamSubscription? _liveMatchSub;

  // NEW — connection status
  bool _isConnected = true;
  StreamSubscription? _connectivitySub;

  // NEW — date/time ticker
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // NEW — ad carousel
  late PageController _adPageCtrl;
  late Timer _adTimer;
  int _currentAdPage = 0;

  // Animation controllers
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _pulseAnim;

  // NEW animation controllers
  late AnimationController _cardEntranceCtrl;
  late AnimationController _tickerCtrl;
  late AnimationController _heroBannerCtrl;
  late Animation<double> _cardEntranceAnim;
  late Animation<double> _heroBannerAnim;

  // ── Ad content ─────────────────────────────────────────────────────────────
  static const _adSlides = [
    _AdSlide(
      tag: 'ADVERTISEMENT',
      headline: 'Ad Space Available',
      subline: 'Premium placement for tournament sponsors',
      icon: Icons.sports_cricket,
      color: Color(0xFF00D4FF),
    ),
    _AdSlide(
      tag: 'SPONSOR',
      headline: 'Powered by CRICTRAX',
      subline: 'The #1 cricket tournament management platform',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFFFD700),
    ),
    _AdSlide(
      tag: 'BROADCAST',
      headline: 'Live Scoring. Live Glory.',
      subline: 'Real-time scores for every ball, every moment',
      icon: Icons.live_tv_rounded,
      color: Color(0xFFFF6B35),
    ),
  ];

  // ── News ticker items ───────────────────────────────────────────────────────
  static const _tickerItems = [
    '🏏  CRICTRAX TV — Live Cricket Scoring Dashboard',
    '📡  Stay connected to all your tournaments in real-time',
    '🏆  View detailed scorecards, ball-by-ball commentary and player stats',
    '📱  Manage tournaments from the CRICTRAX mobile app',
    '🎯  Create new tournaments, add teams and start scoring instantly',
    '🔴  Live matches stream automatically to this TV dashboard',
  ];

  @override
  void initState() {
    super.initState();

    // Existing controllers (UNCHANGED)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // NEW controllers
    _cardEntranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _cardEntranceAnim = CurvedAnimation(
      parent: _cardEntranceCtrl,
      curve: Curves.easeOutCubic,
    );

    _tickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _heroBannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroBannerAnim = CurvedAnimation(
      parent: _heroBannerCtrl,
      curve: Curves.easeOutBack,
    );

    _adPageCtrl = PageController();

    // NEW timers
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _adTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final next = (_currentAdPage + 1) % _adSlides.length;
      _adPageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });

    _fetchTournaments();
    _listenForLogout();
    _listenForLiveMatch();
    _listenConnectivity();
  }

  // ── Business Logic (UNCHANGED) ────────────────────────────────────────────

  void _listenForLogout() {
    if (widget.sessionId == null) {
      debugPrint(
          '⚠️ DashboardScreen: no sessionId provided — TV forced-logout listener not attached');
      return;
    }
    debugPrint(
        '👂 DashboardScreen: listening for logout on tv_sessions/${widget.sessionId}');
    _logoutSub = FirebaseFirestore.instance
        .collection('tv_sessions')
        .doc(widget.sessionId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['loggedOut'] == true && mounted) {
        debugPrint(
            '🚪 DashboardScreen: loggedOut flag detected, showing forced logout modal');
        _logoutSub?.cancel();
        _showForcedLogoutModal();
      }
    }, onError: (e) {
      debugPrint('❌ DashboardScreen: logout listener error: $e');
    });
  }

  void _showForcedLogoutModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => _ForcedLogoutDialog(),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _logoutSub?.cancel();
    _liveMatchSub?.cancel();
    _connectivitySub?.cancel();
    _clockTimer.cancel();
    _adTimer.cancel();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _cardEntranceCtrl.dispose();
    _tickerCtrl.dispose();
    _heroBannerCtrl.dispose();
    _adPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTournaments() async {
    final tournaments = await _repo.getUserTournaments(widget.userId);
    if (mounted) {
      setState(() {
        _tournaments = tournaments;
        _loading = false;
      });
      _cardEntranceCtrl.forward();
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _LogoutDialog(
        onConfirm: () {
          Navigator.pop(context);
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
          );
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  // ── NEW: non-breaking live match listener ─────────────────────────────────
  void _listenForLiveMatch() {
    try {
      _liveMatchSub = FirebaseFirestore.instance
          .collection('matches')
          .where('userId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'live')
          .limit(1)
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          setState(() => _featuredLiveMatch = data);
          if (!_heroBannerCtrl.isCompleted) _heroBannerCtrl.forward();
        } else {
          setState(() => _featuredLiveMatch = null);
          _heroBannerCtrl.reverse();
        }
      }, onError: (_) {
        // Non-breaking: silently ignore if collection doesn't exist
      });
    } catch (_) {}
  }

  // ── NEW: Firebase connectivity monitor ───────────────────────────────────
  void _listenConnectivity() {
    try {
      _connectivitySub = FirebaseFirestore.instance
          .collection('.info')
          .doc('connected')
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        final connected = snap.data()?['connected'] as bool? ?? true;
        setState(() => _isConnected = connected);
      }, onError: (_) {
        // Non-breaking
      });
    } catch (_) {}
  }

  // ── Computed stats from existing _tournaments (no new Firestore queries) ──
  int get _liveTournamentCount =>
      _tournaments.where((t) => t.status?.toLowerCase() == 'live').length;
  int get _completedTournamentCount =>
      _tournaments.where((t) => t.status?.toLowerCase() == 'completed').length;
  int get _upcomingTournamentCount =>
      _tournaments.where((t) => t.status?.toLowerCase() == 'upcoming').length;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _LoadingScreen();

    return Scaffold(
      backgroundColor: _DS.bg,
      body: Stack(
        children: [
          // Ambient background glow (UNCHANGED)
          Positioned(
            top: -120,
            left: 60,
            child: _AmbientGlow(color: _DS.accent, size: 400),
          ),
          Positioned(
            bottom: -80,
            right: 100,
            child: _AmbientGlow(color: const Color(0xFF6C3AFF), size: 300),
          ),
          // NEW — subtle top broadcast stripe
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    _DS.accent,
                    _DS.live,
                    _DS.accent,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main layout
          Row(
            children: [
              _SideNavRail(
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
              Expanded(child: _buildMainContent()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // NEW — top status bar (news ticker + time + connection)
        _buildStatusBar(),
        Expanded(
          child: Padding(
            padding:
            const EdgeInsets.only(top: 20, left: 40, right: 48, bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                // NEW — stats bar
                _buildStatsBar(),
                const SizedBox(height: 20),
                // Featured live match (shown only when live match exists)
                if (_featuredLiveMatch != null) ...[
                  _buildFeaturedLiveCard(),
                  const SizedBox(height: 20),
                ],
                // Ad carousel (replaces static banner)
                _buildAdCarousel(),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // NEW — Quick Action Panel
                        _buildQuickActionPanel(),
                        const SizedBox(height: 28),
                        _buildSectionHeader(
                            'My Tournaments', _tournaments.length),
                        const SizedBox(height: 20),
                        _tournaments.isEmpty
                            ? _buildEmptyState()
                            : _buildTournamentGrid(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── NEW: Status Bar ────────────────────────────────────────────────────────
  Widget _buildStatusBar() {
    final h = _now.hour;
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC'
    ];
    final dayStr =
        '${weekdays[_now.weekday - 1]}  ${_now.day} ${months[_now.month - 1]}';

    return Container(
      height: 36,
      color: const Color(0xFF020712),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Ticker
          Expanded(
            child: _NewsTicker(
              items: _tickerItems,
              controller: _tickerCtrl,
            ),
          ),
          const SizedBox(width: 24),
          // Date
          Text(
            dayStr,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 16),
          // Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$h12:$m:$s',
                style: TextStyle(
                  color: _DS.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                period,
                style: TextStyle(
                  color: _DS.accent.withOpacity(0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Connection dot
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected
                        ? _DS.success.withOpacity(
                        _isConnected ? _pulseAnim.value : 0.3)
                        : _DS.danger,
                    boxShadow: _isConnected
                        ? [
                      BoxShadow(
                        color: _DS.success.withOpacity(0.5),
                        blurRadius: 6,
                      )
                    ]
                        : [],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _isConnected ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                    color: _isConnected ? _DS.success : _DS.danger,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── EXISTING: Header (UNCHANGED, kept exactly) ─────────────────────────────
  Widget _buildHeader() {
    final initial =
    widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : 'U';
    final name =
    widget.displayName.isNotEmpty ? widget.displayName : 'Player';

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
        // Stats chips row (UNCHANGED)
        Row(
          children: [
            _StatChip(
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

  // ── NEW: Stats Bar ─────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    final stats = [
      _StatCard(
        label: 'TOTAL',
        value: '${_tournaments.length}',
        icon: Icons.emoji_events_rounded,
        color: _DS.accent,
        gradient: _DS.accentGrad,
      ),
      _StatCard(
        label: 'LIVE',
        value: '$_liveTournamentCount',
        icon: Icons.sensors_rounded,
        color: _DS.live,
        gradient: _DS.liveGrad,
        isPulsing: true,
      ),
      _StatCard(
        label: 'COMPLETED',
        value: '$_completedTournamentCount',
        icon: Icons.check_circle_rounded,
        color: _DS.success,
        gradient: _DS.successGrad,
      ),
      _StatCard(
        label: 'UPCOMING',
        value: '$_upcomingTournamentCount',
        icon: Icons.schedule_rounded,
        color: _DS.warning,
        gradient: _DS.goldGrad,
      ),
    ];

    return AnimatedBuilder(
      animation: _cardEntranceAnim,
      builder: (_, __) {
        return Row(
          children: List.generate(stats.length, (i) {
            final delay = i / stats.length;
            final t = (_cardEntranceAnim.value - delay).clamp(0.0, 1.0) /
                (1.0 - delay + 0.001);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < stats.length - 1 ? 14 : 0),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - t)),
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: _buildStatCard(stats[i]),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildStatCard(_StatCard s) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _DS.surfaceHigh,
        border: Border.all(
          color: s.color.withOpacity(0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: s.color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Subtle gradient tint on left
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(gradient: s.gradient),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.color.withOpacity(0.1),
                    ),
                    child: s.isPulsing
                        ? AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Icon(
                        s.icon,
                        color: s.color.withOpacity(
                            0.5 + _pulseAnim.value * 0.5),
                        size: 18,
                      ),
                    )
                        : Icon(s.icon, color: s.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        s.value,
                        style: TextStyle(
                          color: s.color,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        s.label,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
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
    );
  }

  // ── NEW: Featured Live Match Hero Card ─────────────────────────────────────
  Widget _buildFeaturedLiveCard() {
    final match = _featuredLiveMatch!;
    final team1 = match['team1Name'] as String? ?? 'Team A';
    final team2 = match['team2Name'] as String? ?? 'Team B';
    final score1 = match['team1Score'] as String? ?? '—';
    final score2 = match['team2Score'] as String? ?? '—';
    final overs = match['currentOvers'] as String? ?? '0.0';
    final status = match['matchStatus'] as String? ?? 'In Progress';

    return ScaleTransition(
      scale: _heroBannerAnim,
      child: FadeTransition(
        opacity: _heroBannerAnim,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A0A00),
                const Color(0xFF2A1000),
                const Color(0xFF0A0A1A),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: _DS.live.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _DS.live.withOpacity(0.2),
                blurRadius: 32,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _GridPatternPainter()),
                ),
                // Live accent stripe
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: _DS.liveGrad,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 18),
                  child: Row(
                    children: [
                      // LIVE badge
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, __) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: _DS.liveGrad,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: _DS.live
                                        .withOpacity(_pulseAnim.value * 0.6),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white
                                          .withOpacity(_pulseAnim.value),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'FEATURED MATCH',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 28),
                      // Team 1
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              team1.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              score1,
                              style: TextStyle(
                                color: _DS.accent,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // VS divider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'VS',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.2),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _DS.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Text(
                                '$overs ov',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Team 2
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              team2.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              score2,
                              style: TextStyle(
                                color: _DS.accent,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _DS.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  // ── NEW: Ad Carousel (replaces static broadcast banner) ───────────────────
  Widget _buildAdCarousel() {
    return SizedBox(
      height: 120,
      child: Stack(
        children: [
          PageView.builder(
            controller: _adPageCtrl,
            onPageChanged: (i) => setState(() => _currentAdPage = i),
            itemCount: _adSlides.length,
            itemBuilder: (_, i) => _buildAdSlide(_adSlides[i]),
          ),
          // Page dots
          Positioned(
            bottom: 10,
            right: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                _adSlides.length,
                    (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _currentAdPage == i ? 18 : 5,
                  height: 5,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: _currentAdPage == i
                        ? _adSlides[i].color
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdSlide(_AdSlide slide) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A1628),
            const Color(0xFF0D1E38),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
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
            Positioned.fill(
              child: CustomPaint(painter: _GridPatternPainter()),
            ),
            // Left accent stripe
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: slide.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: slide.color.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
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
                                color: slide.color.withOpacity(_pulseAnim.value),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: slide.color.withOpacity(0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            slide.tag,
                            style: TextStyle(
                              color: slide.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        slide.headline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slide.subline,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: slide.color.withOpacity(0.05),
                      border: Border.all(
                          color: slide.color.withOpacity(0.12), width: 1),
                    ),
                    child: Icon(
                      slide.icon,
                      color: slide.color.withOpacity(0.22),
                      size: 36,
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

  // ── NEW: Quick Action Panel ─────────────────────────────────────────────────
  Widget _buildQuickActionPanel() {
    final actions = [
      _QuickAction(
        icon: Icons.sensors_rounded,
        label: 'Live\nMatches',
        color: _DS.live,
        onTap: () => setState(() => _selectedNavIndex = 2),
      ),
      _QuickAction(
        icon: Icons.emoji_events_rounded,
        label: 'Tournaments',
        color: _DS.accent,
        onTap: () => setState(() => _selectedNavIndex = 1),
      ),
      _QuickAction(
        icon: Icons.refresh_rounded,
        label: 'Refresh\nData',
        color: _DS.success,
        onTap: () {
          setState(() => _loading = true);
          _fetchTournaments();
        },
      ),
      _QuickAction(
        icon: Icons.settings_rounded,
        label: 'Settings',
        color: _DS.warning,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsScreen(initialNavIndex: 3),
          ),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(actions.length, (i) {
            return Expanded(
              child: Padding(
                padding:
                EdgeInsets.only(right: i < actions.length - 1 ? 12 : 0),
                child: _QuickActionButton(action: actions[i]),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── EXISTING: Section Header (UNCHANGED) ──────────────────────────────────
  Widget _buildSectionHeader(String title, int count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _DS.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:
                      Border.all(color: _DS.accent.withOpacity(0.25)),
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
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _DS.accent.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── EXISTING: Tournament Grid (UNCHANGED) ─────────────────────────────────
  Widget _buildTournamentGrid() {
    return AnimatedBuilder(
      animation: _cardEntranceAnim,
      builder: (_, __) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.4,
          ),
          itemCount: _tournaments.length,
          itemBuilder: (context, index) {
            final t = _tournaments[index];
            final delay = (index / _tournaments.length) * 0.5;
            final t0 = (_cardEntranceAnim.value - delay)
                .clamp(0.0, 1.0) /
                (1.0 - delay + 0.001);

            return Transform.translate(
              offset: Offset(0, 30 * (1 - t0.clamp(0.0, 1.0))),
              child: Opacity(
                opacity: t0.clamp(0.0, 1.0),
                child: TournamentCardWidget(
                  tournament: t,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TournamentDetailScreen(
                        tournamentId: t.id,
                        tournament: t,
                        sessionId: widget.sessionId,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── ENHANCED: Empty State ─────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            // Animated dashed ring
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _DashedCirclePainter(
                    color: _DS.accent.withOpacity(0.2 + _pulseAnim.value * 0.15),
                  ),
                  child: Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _DS.accent.withOpacity(0.04),
                        border: Border.all(
                            color: _DS.accent.withOpacity(0.10), width: 1.5),
                      ),
                      child: Icon(
                        Icons.emoji_events_outlined,
                        color: _DS.accent
                            .withOpacity(0.2 + _pulseAnim.value * 0.1),
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'No Tournaments Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your tournaments will appear here automatically.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Step hints
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EmptyStateStep(
                    step: '1',
                    text: 'Open CRICTRAX\non your phone',
                    color: _DS.accent),
                _EmptyStateArrow(),
                _EmptyStateStep(
                    step: '2',
                    text: 'Create a\ntournament',
                    color: _DS.warning),
                _EmptyStateArrow(),
                _EmptyStateStep(
                    step: '3',
                    text: 'It appears here\nautomatically',
                    color: _DS.success),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data models for new widgets ──────────────────────────────────────────────

class _StatCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;
  final bool isPulsing;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
    this.isPulsing = false,
  });
}

class _AdSlide {
  final String tag;
  final String headline;
  final String subline;
  final IconData icon;
  final Color color;

  const _AdSlide({
    required this.tag,
    required this.headline,
    required this.subline,
    required this.icon,
    required this.color,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// ─── Quick Action Button ──────────────────────────────────────────────────────
class _QuickActionButton extends StatefulWidget {
  final _QuickAction action;
  const _QuickActionButton({required this.action});

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTapDown: (_) => _ctrl.forward(),
          onTapUp: (_) {
            _ctrl.reverse();
            widget.action.onTap();
          },
          onTapCancel: () => _ctrl.reverse(),
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: focused
                    ? widget.action.color.withOpacity(0.18)
                    : _DS.surfaceHigh,
                border: Border.all(
                  color: focused
                      ? widget.action.color.withOpacity(0.5)
                      : widget.action.color.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: focused
                    ? [
                  BoxShadow(
                    color: widget.action.color.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.action.icon,
                    color: widget.action.color,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.action.label.replaceAll('\n', ' '),
                    style: TextStyle(
                      color: focused
                          ? widget.action.color
                          : Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── News Ticker ──────────────────────────────────────────────────────────────
class _NewsTicker extends StatelessWidget {
  final List<String> items;
  final AnimationController controller;

  const _NewsTicker({required this.items, required this.controller});

  @override
  Widget build(BuildContext context) {
    final fullText = items.join('     •     ');
    return ClipRect(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return FractionalTranslation(
            translation: Offset(1.0 - controller.value * 2.0, 0),
            child: Text(
              fullText,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
          );
        },
      ),
    );
  }
}

// ─── Empty State Helpers ──────────────────────────────────────────────────────
class _EmptyStateStep extends StatelessWidget {
  final String step;
  final String text;
  final Color color;

  const _EmptyStateStep(
      {required this.step, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyStateArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(
        Icons.arrow_forward_rounded,
        color: Colors.white.withOpacity(0.15),
        size: 20,
      ),
    );
  }
}

// ─── Dashed Circle Painter (for empty state) ──────────────────────────────────
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const dashCount = 24;
    const dashLength = 2 * math.pi / dashCount;

    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        final start = i * dashLength;
        final end = start + dashLength * 0.55;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          end - start,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

// ─── Side Nav Rail ─────────────────────────────────────────────────────────────
// (UNCHANGED — reproduced exactly)
class _SideNavRail extends StatelessWidget {
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

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.emoji_events_rounded, label: 'Events'),
    (icon: Icons.play_circle_fill_rounded, label: 'Live'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _DS.navWidth,
      decoration: BoxDecoration(
        color: _DS.surface.withOpacity(0.6),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 36),
          Container(
            width: 44,
            height: 44,
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
            child: const Icon(
              Icons.sports_cricket,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'CRICTRAX',
            style: TextStyle(
              color: _DS.accent,
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 40),
          ...List.generate(_items.length, (i) {
            final item = _items[i];
            return _NavItem(
              icon: item.icon,
              label: item.label,
              isSelected: selectedIndex == i,
              onTap: () => onIndexChanged(i),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: Colors.white.withOpacity(0.06),
              height: 1,
            ),
          ),
          const SizedBox(height: 16),
          _NavItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            isSelected: false,
            onTap: onLogout,
            isDanger: true,
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDanger;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Focus(
        child: Builder(builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          final active = isSelected || focused;
          final activeColor = isDanger ? _DS.danger : _DS.accent;

          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
                boxShadow: active && !isDanger
                    ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 0,
                  )
                ]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: active
                        ? activeColor
                        : Colors.white.withOpacity(0.28),
                    size: 24,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? activeColor
                          : Colors.white.withOpacity(0.28),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Stat Chip (UNCHANGED) ────────────────────────────────────────────────────
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

// ─── Loading Screen (UNCHANGED) ───────────────────────────────────────────────
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
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
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
              child: const Icon(Icons.sports_cricket,
                  color: Colors.white, size: 38),
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

// ─── Forced Logout Dialog (UNCHANGED) ─────────────────────────────────────────
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
                  color: _DS.danger.withOpacity(0.2), width: 1.5),
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
                        color: _DS.danger.withOpacity(0.25), width: 1.5),
                  ),
                  child: Icon(Icons.logout_rounded, color: _DS.danger, size: 32),
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

// ─── Logout Confirm Dialog (UNCHANGED) ────────────────────────────────────────
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
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 40,
                ),
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
                      child: Icon(Icons.logout_rounded,
                          color: _DS.danger, size: 20),
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
                        child: Builder(builder: (ctx) {
                          final f = Focus.of(ctx).hasFocus;
                          return GestureDetector(
                            onTap: onCancel,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
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
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Focus(
                        child: Builder(builder: (ctx) {
                          final f = Focus.of(ctx).hasFocus;
                          return GestureDetector(
                            onTap: onConfirm,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: f
                                      ? [
                                    const Color(0xFFFF5252),
                                    const Color(0xFFCC0000)
                                  ]
                                      : [
                                    _DS.danger.withOpacity(0.8),
                                    const Color(0xFF990000)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: f
                                    ? [
                                  BoxShadow(
                                    color: _DS.danger.withOpacity(0.4),
                                    blurRadius: 16,
                                  )
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
                        }),
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

// ─── Ambient Glow (UNCHANGED) ─────────────────────────────────────────────────
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

// ─── Grid Pattern Painter (UNCHANGED) ─────────────────────────────────────────
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