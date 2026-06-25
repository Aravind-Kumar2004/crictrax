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

  // Animation controllers
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

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

    _fetchTournaments();
    _listenForLogout();
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
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _LoadingScreen();

    return Scaffold(
      backgroundColor: _DS.bg,
      body: Stack(
        children: [
          // Ambient background glow
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
                        builder: (context) => const SettingsScreen(initialNavIndex: 3),
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
    return Padding(
      padding: const EdgeInsets.only(top: 36, left: 40, right: 48, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 28),
          _buildBroadcastBanner(),
          const SizedBox(height: 36),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('My Tournaments', _tournaments.length),
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
    );
  }

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
        // Stats chips row
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

  Widget _buildBroadcastBanner() {
    return Container(
      width: double.infinity,
      height: 148,
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
            // Subtle cricket field pattern overlay
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
              padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
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
                          color: _DS.accent.withOpacity(0.12), width: 1),
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
        // Decorative line
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

  Widget _buildTournamentGrid() {
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
        return TournamentCardWidget(
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
        );
      },
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
                border:
                Border.all(color: _DS.accent.withOpacity(0.10), width: 1.5),
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
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _DS.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _DS.accent.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android_rounded,
                      color: _DS.accent, size: 16),
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
          // Logo mark
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

          // Nav items
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

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: Colors.white.withOpacity(0.06),
              height: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Logout
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
          final activeColor =
          isDanger ? _DS.danger : _DS.accent;

          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
      padding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  valueColor:
                  AlwaysStoppedAnimation<Color>(_DS.accent),
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
                  child: Icon(Icons.logout_rounded,
                      color: _DS.danger, size: 32),
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