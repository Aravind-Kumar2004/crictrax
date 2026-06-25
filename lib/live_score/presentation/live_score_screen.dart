import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crictrax/login/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import '../data/models/repositories/live_score_repository.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF020810);
  static const surface   = Color(0xFF0A1628);
  static const surfaceH  = Color(0xFF0F1E35);
  static const accent    = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live      = Color(0xFFFF3D3D);
  static const orange    = Color(0xFFFF7A45);
  static const gold      = Color(0xFFFFD700);
  static const success   = Color(0xFF00E676);
  static const warning   = Color(0xFFFFB300);
  static const purple    = Color(0xFF8E5CFF);
  static const danger    = Color(0xFFFF3D3D);

  // Broadcast overlay colors
  static const overlayDark   = Color(0xE5020810);
  static const overlayMid    = Color(0xCC0A1628);
  static const scoreOrange   = Color(0xFFFF7A45);
  static const scoreGold     = Color(0xFFFFD700);
  static const panelBg       = Color(0xF00A1628);
  static const topBarBg      = Color(0xF5050A18);
  static const bottomPanelBg = Color(0xF8071226);
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIVE SCORE SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class LiveScoreScreen extends StatefulWidget {
  final String matchId;
  final String tournamentId;
  final String team1Name;
  final String team2Name;
  final String team1Id;
  final String team2Id;
  final String? sessionId;

  const LiveScoreScreen({
    Key? key,
    required this.matchId,
    required this.tournamentId,
    required this.team1Name,
    required this.team2Name,
    required this.team1Id,
    required this.team2Id,
    this.sessionId,
  }) : super(key: key);

  @override
  State<LiveScoreScreen> createState() => _LiveScoreScreenState();
}

class _LiveScoreScreenState extends State<LiveScoreScreen>
    with SingleTickerProviderStateMixin {
  // ── Business Logic State (COMPLETELY UNCHANGED) ──────────────────────────
  final _repo = LiveScoreRepository();
  bool _hasNavigatedAway = false;
  Timer? _autoDismissTimer;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempt = 0;
  Stream<QuerySnapshot>? _inningsStream;
  String? _lastInningsId;
  Map<String, dynamic>? _lastInningsData;
  String? _lastFirstInningsBattingTeamName;
  StreamSubscription? _logoutSub;
  StreamSubscription<DocumentSnapshot>? _matchSub;
  DateTime _lastMatchUpdate = DateTime.now();
  Map<String, dynamic>? _lastMatchData;
  bool _showInningsBreak = false;
  int _firstInningsRuns = 0;
  int _firstInningsWickets = 0;

  // ── UI-only animation ─────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _initMatchSubscription();
    _inningsStream = _repo.watchInnings(widget.tournamentId, widget.matchId);
    _listenForLogout();
    _startHeartbeat();
  }

  // ── Business Logic (COMPLETELY UNCHANGED) ────────────────────────────────
  void _listenForLogout() {
    if (widget.sessionId == null) return;
    _logoutSub = FirebaseFirestore.instance
        .collection('tv_sessions')
        .doc(widget.sessionId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['loggedOut'] == true && mounted && !_hasNavigatedAway) {
        _hasNavigatedAway = true;
        _logoutSub?.cancel();
        _showForcedLogoutModal();
      }
    }, onError: (e) {
      debugPrint('❌ LiveScoreScreen: logout listener error: $e');
    });
  }

  void _showForcedLogoutModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => _PremiumForcedLogoutDialog(),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    });
  }

  void _initMatchSubscription() {
    _matchSub?.cancel();
    _matchSub = _repo
        .watchMatch(widget.tournamentId, widget.matchId)
        .listen((snap) {
      _lastMatchUpdate = DateTime.now();
      _reconnectAttempt = 0;
      if (!snap.exists || !mounted) return;
      final matchData = snap.data() as Map<String, dynamic>? ?? {};
      final isCompleted = matchData['isCompleted'] == true;
      debugPrint('📡 match snapshot received — isCompleted=$isCompleted');
      _lastMatchData = matchData;
      if (isCompleted && !_hasNavigatedAway) {
        _hasNavigatedAway = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showMatchEndedAndPop(context, matchData);
        });
      }
    }, onError: (e) {
      debugPrint('❌ match stream error: $e');
      _scheduleReconnect();
    });
  }

  void _checkInningsCompletion(List<QueryDocumentSnapshot> docs) {
    if (_hasNavigatedAway) return;

    final firstInningsDocs = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['isSecondInnings'] != true;
    }).toList();

    final secondInningsDocs = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['isSecondInnings'] == true;
    }).toList();

    final firstInningsComplete = firstInningsDocs.isNotEmpty &&
        (firstInningsDocs.first.data()
        as Map<String, dynamic>)['isCompleted'] ==
            true;

    final hasSecondInnings = secondInningsDocs.isNotEmpty;

    final secondInningsComplete = hasSecondInnings &&
        (secondInningsDocs.first.data()
        as Map<String, dynamic>)['isCompleted'] ==
            true;

    if (firstInningsComplete && secondInningsComplete) {
      debugPrint('✅ both innings complete — match over, navigating');
      if (_showInningsBreak) setState(() => _showInningsBreak = false);
      _hasNavigatedAway = true;
      final resultText =
          _lastMatchData?['result'] as String? ?? 'Match Completed';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMatchEndedAndPop(context, {'result': resultText});
      });
      return;
    }

    if (firstInningsComplete && !hasSecondInnings) {
      final firstData =
      firstInningsDocs.first.data() as Map<String, dynamic>;
      final runs = (firstData['totalRuns'] as num?)?.toInt() ?? 0;
      final wickets = (firstData['totalWickets'] as num?)?.toInt() ?? 0;
      debugPrint(
          '🏏 innings 1 complete — showing innings break. Score: $runs/$wickets');
      if (!_showInningsBreak) {
        setState(() {
          _showInningsBreak = true;
          _firstInningsRuns = runs;
          _firstInningsWickets = wickets;
        });
      }
      return;
    }

    if (hasSecondInnings && _showInningsBreak) {
      setState(() => _showInningsBreak = false);
    }

    if (firstInningsComplete && !hasSecondInnings) {
      if (_lastMatchData?['isCompleted'] == true) {
        debugPrint('✅ single innings match complete — navigating');
        _hasNavigatedAway = true;
        final resultText =
            _lastMatchData?['result'] as String? ?? 'Match Completed';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showMatchEndedAndPop(context, {'result': resultText});
        });
      }
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final staleSince =
          DateTime.now().difference(_lastMatchUpdate).inSeconds;
      if (staleSince > 15) {
        debugPrint(
            '💔 match stream stale for ${staleSince}s — reconnecting');
        _scheduleReconnect();
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay =
    Duration(seconds: (2 * (++_reconnectAttempt)).clamp(2, 10));
    _reconnectTimer = Timer(delay, () {
      if (!mounted) return;
      debugPrint(
          '🔄 reconnecting match stream (attempt $_reconnectAttempt)');
      _initMatchSubscription();
      setState(() {
        _inningsStream =
            _repo.watchInnings(widget.tournamentId, widget.matchId);
      });
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _matchSub?.cancel();
    _logoutSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // ── Stadium background ──────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/stadium_bg.jpeg',
              fit: BoxFit.cover,
            ),
          ),

          // ── Cinematic dark gradient layers ─────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xE8020810), // very dark top
                    Color(0x88020810), // semi-transparent middle
                    Color(0xCC020810), // darkens again
                    Color(0xFF020810), // solid bottom
                  ],
                  stops: [0.0, 0.28, 0.62, 1.0],
                ),
              ),
            ),
          ),

          // ── Ambient glow top-left ───────────────────────────────────────
          Positioned(
            top: -80,
            left: -60,
            child: _AmbientGlow(color: _C.accent, size: 300),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: _AmbientGlow(color: _C.live, size: 220),
          ),

          // ── Innings break overlay ───────────────────────────────────────
          if (_showInningsBreak)
            _InningsBreakOverlay(
              firstInningsRuns: _firstInningsRuns,
              firstInningsWickets: _firstInningsWickets,
              pulseAnim: _pulseAnim,
            ),

          // ── Main broadcast layout ───────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── TOP BROADCAST BAR ─────────────────────────────────
                _BroadcastTopBar(
                  team1Name: widget.team1Name,
                  team2Name: widget.team2Name,
                  pulseAnim: _pulseAnim,
                  onBack: () => Navigator.pop(context),
                ),

                // ── CENTER — Big match display ────────────────────────
                Expanded(
                  child: Center(
                    child: _CenterMatchDisplay(
                      team1Name: widget.team1Name,
                      team2Name: widget.team2Name,
                      pulseAnim: _pulseAnim,
                    ),
                  ),
                ),

                // ── BOTTOM BROADCAST PANEL ────────────────────────────
                StreamBuilder<QuerySnapshot>(
                  stream: _inningsStream,
                  builder: (context, inningsSnap) {
                    if (inningsSnap.hasError) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _scheduleReconnect();
                      });
                      return _lastInningsId != null
                          ? _buildCachedBar()
                          : _buildErrorBar(
                          inningsSnap.error.toString());
                    }

                    if (inningsSnap.connectionState ==
                        ConnectionState.waiting) {
                      return _lastInningsId != null
                          ? _buildCachedBar()
                          : _buildStatusBar(
                          label: 'Connecting to live feed…');
                    }

                    if (!inningsSnap.hasData ||
                        inningsSnap.data!.docs.isEmpty) {
                      return _lastInningsId != null
                          ? _buildCachedBar()
                          : _buildStatusBar(
                          label: 'Waiting for match to start…');
                    }

                    _reconnectAttempt = 0;
                    _reconnectTimer?.cancel();

                    final docs = inningsSnap.data!.docs;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _checkInningsCompletion(docs);
                    });

                    final secondInningsDocs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['isSecondInnings'] == true;
                    }).toList();

                    final currentDoc = secondInningsDocs.isNotEmpty
                        ? secondInningsDocs.first
                        : docs.first;

                    final innData =
                    currentDoc.data() as Map<String, dynamic>;

                    final firstInningsDocs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['isSecondInnings'] != true;
                    }).toList();

                    String? firstInningsBattingTeamName;
                    if (firstInningsDocs.isNotEmpty) {
                      final firstData = firstInningsDocs.first.data()
                      as Map<String, dynamic>;
                      firstInningsBattingTeamName =
                          (firstData['battingTeamName'] ?? '')
                              .toString()
                              .trim();
                    }

                    _lastInningsId = currentDoc.id;
                    _lastInningsData =
                    Map<String, dynamic>.from(innData);
                    _lastFirstInningsBattingTeamName =
                        firstInningsBattingTeamName;

                    // Pull first innings score for target display
                    int? firstInningsTotal;
                    if (secondInningsDocs.isNotEmpty &&
                        firstInningsDocs.isNotEmpty) {
                      final fd = firstInningsDocs.first.data()
                      as Map<String, dynamic>;
                      firstInningsTotal =
                          (fd['totalRuns'] as num?)?.toInt();
                    }

                    return _BroadcastBottomPanel(
                      tournamentId: widget.tournamentId,
                      matchId: widget.matchId,
                      inningsId: currentDoc.id,
                      innData: innData,
                      team1Name: widget.team1Name,
                      team2Name: widget.team2Name,
                      team1Id: widget.team1Id,
                      team2Id: widget.team2Id,
                      repo: _repo,
                      firstInningsBattingTeamName:
                      firstInningsBattingTeamName,
                      firstInningsTotal: firstInningsTotal,
                      pulseAnim: _pulseAnim,
                      isSecondInnings: secondInningsDocs.isNotEmpty,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedBar() {
    return _BroadcastBottomPanel(
      tournamentId: widget.tournamentId,
      matchId: widget.matchId,
      inningsId: _lastInningsId!,
      innData: _lastInningsData!,
      team1Name: widget.team1Name,
      team2Name: widget.team2Name,
      team1Id: widget.team1Id,
      team2Id: widget.team2Id,
      repo: _repo,
      firstInningsBattingTeamName: _lastFirstInningsBattingTeamName,
      firstInningsTotal: null,
      pulseAnim: _pulseAnim,
      isSecondInnings: false,
    );
  }

  void _showMatchEndedAndPop(
      BuildContext context, Map<String, dynamic> matchData) {
    final resultText =
        matchData['result'] as String? ?? 'Match Completed';

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (dialogContext) => _MatchEndedDialog(
        resultText: resultText,
        onBack: () => _dismissAndPop(),
      ),
    );

    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _dismissAndPop();
    });
  }

  void _dismissAndPop() {
    _autoDismissTimer?.cancel();
    final nav = Navigator.of(context);
    nav.popUntil((route) {
      return route.settings.name != null ||
          route.isFirst ||
          _isOnTournamentDetail(route);
    });
    if (nav.canPop()) nav.pop();
    if (nav.canPop()) nav.pop();
  }

  bool _isOnTournamentDetail(Route route) {
    return route.settings.name == '/tournament_detail';
  }

  Widget _buildStatusBar(
      {String label = 'Waiting for match to start…'}) {
    return _BroadcastStatusBar(label: label, isError: false);
  }

  Widget _buildErrorBar(String error) {
    return _BroadcastStatusBar(
      label: 'Live data error — reconnecting…',
      isError: true,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BROADCAST TOP BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _BroadcastTopBar extends StatelessWidget {
  final String team1Name, team2Name;
  final Animation<double> pulseAnim;
  final VoidCallback onBack;

  const _BroadcastTopBar({
    required this.team1Name,
    required this.team2Name,
    required this.pulseAnim,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: _C.topBarBg,
            border: Border(
              bottom: BorderSide(
                  color: Colors.white.withOpacity(0.07), width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Back button
                Focus(
                  child: Builder(builder: (ctx) {
                    final focused = Focus.of(ctx).hasFocus;
                    return GestureDetector(
                      onTap: onBack,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: focused
                              ? _C.accent.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: focused
                                ? _C.accent.withOpacity(0.6)
                                : Colors.white.withOpacity(0.1),
                          ),
                          boxShadow: focused
                              ? [
                            BoxShadow(
                                color:
                                _C.accent.withOpacity(0.3),
                                blurRadius: 12)
                          ]
                              : [],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: focused
                              ? _C.accent
                              : Colors.white.withOpacity(0.55),
                          size: 18,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(width: 20),

                // Brand mark
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: const LinearGradient(
                      colors: [_C.accent, _C.accentDim],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: _C.accent.withOpacity(0.35),
                          blurRadius: 8),
                    ],
                  ),
                  child: const Icon(Icons.sports_cricket,
                      color: Colors.white, size: 13),
                ),
                const SizedBox(width: 10),
                Text(
                  'CRICTRAX',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                  ),
                ),

                const Spacer(),

                // Match title chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(
                    '$team1Name  ·  $team2Name',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Animated LIVE badge
                AnimatedBuilder(
                  animation: pulseAnim,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _C.live.withOpacity(
                          0.15 + 0.07 * pulseAnim.value),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _C.live.withOpacity(
                            0.45 + 0.25 * pulseAnim.value),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _C.live
                              .withOpacity(0.25 * pulseAnim.value),
                          blurRadius: 16,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _C.live,
                            boxShadow: [
                              BoxShadow(
                                color: _C.live.withOpacity(
                                    0.9 * pulseAnim.value),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: _C.live,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CENTER MATCH DISPLAY — Cinematic team vs team
// ═══════════════════════════════════════════════════════════════════════════════
class _CenterMatchDisplay extends StatelessWidget {
  final String team1Name, team2Name;
  final Animation<double> pulseAnim;

  const _CenterMatchDisplay({
    required this.team1Name,
    required this.team2Name,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CinematicTeamBadge(name: team1Name),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // VS with decorative rings
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.04),
                            width: 1,
                          ),
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.07),
                            width: 1,
                          ),
                        ),
                      ),
                      Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Broadcast label
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter:
                      ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.07)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sports_cricket,
                                color: Colors.white.withOpacity(0.2),
                                size: 11),
                            const SizedBox(width: 6),
                            Text(
                              'Live Score Update',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
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
            _CinematicTeamBadge(name: team2Name),
          ],
        ),
      ],
    );
  }
}

class _CinematicTeamBadge extends StatelessWidget {
  final String name;
  const _CinematicTeamBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Outer glow ring
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _C.accent.withOpacity(0.12),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _C.accent.withOpacity(0.22),
                  _C.accentDim.withOpacity(0.08),
                ],
              ),
              border: Border.all(
                  color: _C.accent.withOpacity(0.3), width: 1.5),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: _C.accent,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BROADCAST BOTTOM PANEL — The full TV score overlay
// ═══════════════════════════════════════════════════════════════════════════════
class _BroadcastBottomPanel extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final String inningsId;
  final Map<String, dynamic> innData;
  final String team1Name;
  final String team2Name;
  final String team1Id;
  final String team2Id;
  final LiveScoreRepository repo;
  final String? firstInningsBattingTeamName;
  final int? firstInningsTotal;
  final Animation<double> pulseAnim;
  final bool isSecondInnings;

  const _BroadcastBottomPanel({
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
    required this.innData,
    required this.team1Name,
    required this.team2Name,
    required this.team1Id,
    required this.team2Id,
    required this.repo,
    required this.pulseAnim,
    required this.isSecondInnings,
    this.firstInningsBattingTeamName,
    this.firstInningsTotal,
  });

  @override
  State<_BroadcastBottomPanel> createState() =>
      _BroadcastBottomPanelState();
}

class _BroadcastBottomPanelState extends State<_BroadcastBottomPanel> {
  // ── Business Logic (UNCHANGED) ────────────────────────────────────────────
  List<Map<String, dynamic>> _cachedBatsmen = [];
  Map<String, dynamic>? _cachedBowler;

  late String _trackedInningsId = widget.inningsId;
  late Stream<QuerySnapshot> _batsmenStream = widget.repo.watchBatsmen(
      widget.tournamentId, widget.matchId, widget.inningsId);
  late Stream<QuerySnapshot> _bowlersStream = widget.repo.watchBowlers(
      widget.tournamentId, widget.matchId, widget.inningsId);

  @override
  void didUpdateWidget(covariant _BroadcastBottomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inningsId != _trackedInningsId) {
      _trackedInningsId = widget.inningsId;
      _cachedBatsmen = [];
      _cachedBowler = null;
      _batsmenStream = widget.repo.watchBatsmen(
          widget.tournamentId, widget.matchId, widget.inningsId);
      _bowlersStream = widget.repo.watchBowlers(
          widget.tournamentId, widget.matchId, widget.inningsId);
    }
  }

  String _resolveBattingTeamName() {
    final battingTeamId =
    (widget.innData['battingTeamId'] ?? '').toString().trim();
    debugPrint(
        'battingTeamId=$battingTeamId  team1Id=${widget.team1Id}  team2Id=${widget.team2Id}');
    if (battingTeamId.isNotEmpty) {
      if (battingTeamId == widget.team1Id) return widget.team1Name;
      if (battingTeamId == widget.team2Id) return widget.team2Name;
    }
    final name =
    (widget.innData['battingTeamName'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final isSecondInnings = widget.innData['isSecondInnings'] == true;
    if (isSecondInnings &&
        (widget.firstInningsBattingTeamName?.isNotEmpty ?? false)) {
      return widget.firstInningsBattingTeamName == widget.team1Name
          ? widget.team2Name
          : widget.team1Name;
    }
    return widget.team1Name;
  }

  String _resolveOpponentName(String battingTeamName) {
    if (battingTeamName == widget.team1Name) return widget.team2Name;
    if (battingTeamName == widget.team2Name) return widget.team1Name;
    return widget.team2Name;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final battingTeamName = _resolveBattingTeamName();
    final opponentName = _resolveOpponentName(battingTeamName);

    return StreamBuilder<QuerySnapshot>(
      stream: _batsmenStream,
      builder: (context, batSnap) {
        if (batSnap.hasData && batSnap.data!.docs.isNotEmpty) {
          _cachedBatsmen = batSnap.data!.docs
              .map((d) => d.data() as Map<String, dynamic>)
              .toList();
        }
        final allBatsmen = _cachedBatsmen;

        // ── Score calculations (UNCHANGED) ──────────────────────────
        int totalRuns = 0;
        int totalWickets = 0;
        int totalBalls = 0;
        for (final b in allBatsmen) {
          totalRuns += (b['runs'] ?? 0) as int;
          totalBalls += (b['ballsFaced'] ?? 0) as int;
          if (b['isOut'] == true) totalWickets++;
        }

        if (totalRuns == 0 && widget.innData['totalRuns'] != null) {
          totalRuns =
              (widget.innData['totalRuns'] as num).toInt();
        }
        if (totalWickets == 0 &&
            widget.innData['totalWickets'] != null) {
          totalWickets =
              (widget.innData['totalWickets'] as num).toInt();
        }

        final completedOvers = totalBalls ~/ 6;
        final ballsInOver = totalBalls % 6;
        final currentOverNumber =
        (ballsInOver == 0 && totalBalls > 0)
            ? completedOvers - 1
            : completedOvers;
        final oversDisplay =
        widget.innData['totalOvers'] != null && totalBalls == 0
            ? widget.innData['totalOvers']
            : '$completedOvers.$ballsInOver';

        final activeBatsmen =
        allBatsmen.where((b) => b['isOut'] != true).toList();

        // Target / required run calc (2nd innings)
        final target = widget.firstInningsTotal != null
            ? widget.firstInningsTotal! + 1
            : null;
        final runsNeeded =
        target != null ? (target - totalRuns).clamp(0, 9999) : null;
        final maxOvers = (widget.innData['maxOvers'] as num?)?.toInt();
        final ballsRemaining = maxOvers != null
            ? ((maxOvers * 6) - totalBalls).clamp(0, 9999)
            : null;
        final oversRemaining = ballsRemaining != null
            ? '${ballsRemaining ~/ 6}.${ballsRemaining % 6}'
            : null;

        return StreamBuilder<QuerySnapshot>(
          stream: _bowlersStream,
          builder: (context, bowlSnap) {
            if (bowlSnap.hasData && bowlSnap.data!.docs.isNotEmpty) {
              final bowlers = bowlSnap.data!.docs
                  .map((d) => d.data() as Map<String, dynamic>)
                  .toList();
              final withTimestamp = bowlers
                  .where((b) => b['lastUpdated'] is Timestamp)
                  .toList();
              if (withTimestamp.isNotEmpty) {
                withTimestamp.sort((a, b) =>
                    (b['lastUpdated'] as Timestamp)
                        .compareTo(a['lastUpdated'] as Timestamp));
                _cachedBowler = withTimestamp.first;
              } else {
                final bowling = bowlers
                    .where((b) => b['isBowling'] == true)
                    .toList();
                _cachedBowler = bowling.isNotEmpty
                    ? bowling.first
                    : bowlers.last;
              }
            }
            final bowler = _cachedBowler;

            final crr = totalBalls > 0
                ? (totalRuns / totalBalls) * 6
                : (widget.innData['currentRunRate'] ?? 0.0);

            // Required Run Rate
            double? rrr;
            if (runsNeeded != null &&
                ballsRemaining != null &&
                ballsRemaining > 0) {
              rrr = (runsNeeded / ballsRemaining) * 6;
            }

            return _buildBroadcastPanel(
              battingTeamName: battingTeamName,
              opponentName: opponentName,
              totalRuns: totalRuns,
              totalWickets: totalWickets,
              totalBalls: totalBalls,
              oversDisplay: oversDisplay,
              activeBatsmen: activeBatsmen,
              bowler: bowler,
              crr: crr,
              rrr: rrr,
              target: target,
              runsNeeded: runsNeeded,
              ballsRemaining: ballsRemaining,
              oversRemaining: oversRemaining,
              currentOverNumber: currentOverNumber,
            );
          },
        );
      },
    );
  }

  Widget _buildBroadcastPanel({
    required String battingTeamName,
    required String opponentName,
    required int totalRuns,
    required int totalWickets,
    required int totalBalls,
    required dynamic oversDisplay,
    required List<Map<String, dynamic>> activeBatsmen,
    required Map<String, dynamic>? bowler,
    required dynamic crr,
    required double? rrr,
    required int? target,
    required int? runsNeeded,
    required int? ballsRemaining,
    required String? oversRemaining,
    required int currentOverNumber,
  }) {
    final crrStr = crr is double
        ? crr.toStringAsFixed(2)
        : double.tryParse(crr.toString())?.toStringAsFixed(2) ??
        '0.00';
    final rrrStr =
    rrr != null ? rrr.toStringAsFixed(2) : null;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xDD050A18),
                Color(0xF5050A18),
              ],
            ),
            border: Border(
              top: BorderSide(
                  color: _C.accent.withOpacity(0.2), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Accent top line ──────────────────────────────────
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _C.accent.withOpacity(0.6),
                      _C.accent,
                      _C.accent.withOpacity(0.6),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                  ),
                ),
              ),

              // ── Target bar (2nd innings only) ────────────────────
              if (target != null && runsNeeded != null)
                _TargetInfoBar(
                  target: target,
                  runsNeeded: runsNeeded,
                  ballsRemaining: ballsRemaining,
                  oversRemaining: oversRemaining,
                  rrr: rrrStr,
                  pulseAnim: widget.pulseAnim,
                ),

              // ── Main score row ───────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // SCORE BLOCK
                    _ScoreBlock(
                      teamName: battingTeamName,
                      runs: totalRuns,
                      wickets: totalWickets,
                      oversDisplay: oversDisplay,
                      pulseAnim: widget.pulseAnim,
                    ),

                    _PanelDivider(),

                    // BATSMEN BLOCK
                    Expanded(
                      flex: 30,
                      child: _BatsmenBlock(
                          batters: activeBatsmen,
                          pulseAnim: widget.pulseAnim),
                    ),

                    _PanelDivider(),

                    // BOWLER + CRR BLOCK
                    Expanded(
                      flex: 26,
                      child: _BowlerCrrBlock(
                        bowler: bowler,
                        crr: crrStr,
                        rrr: rrrStr,
                        opponentName: opponentName,
                      ),
                    ),

                    _PanelDivider(),

                    // BALL TRACKER BLOCK
                    Expanded(
                      flex: 34,
                      child: _BallTrackerBlock(
                        tournamentId: widget.tournamentId,
                        matchId: widget.matchId,
                        inningsId: widget.inningsId,
                        repo: widget.repo,
                        currentOverNumber: currentOverNumber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TARGET INFO BAR — chase situation banner
// ═══════════════════════════════════════════════════════════════════════════════
class _TargetInfoBar extends StatelessWidget {
  final int target, runsNeeded;
  final int? ballsRemaining;
  final String? oversRemaining;
  final String? rrr;
  final Animation<double> pulseAnim;

  const _TargetInfoBar({
    required this.target,
    required this.runsNeeded,
    required this.pulseAnim,
    this.ballsRemaining,
    this.oversRemaining,
    this.rrr,
  });

  @override
  Widget build(BuildContext context) {
    final isClose =
        ballsRemaining != null && runsNeeded <= ballsRemaining! ~/ 2;
    final urgentColor = isClose ? _C.gold : _C.accent;

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
        decoration: BoxDecoration(
          color: urgentColor.withOpacity(0.06),
          border: Border(
            bottom: BorderSide(
                color: urgentColor.withOpacity(0.15), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.flag_rounded,
                color: urgentColor, size: 14),
            const SizedBox(width: 8),
            Text(
              'TARGET  $target',
              style: TextStyle(
                color: urgentColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 28),
            _TargetStat(
              label: 'NEED',
              value: '$runsNeeded runs',
              color: _C.orange,
            ),
            if (ballsRemaining != null) ...[
              const SizedBox(width: 20),
              _TargetStat(
                label: 'FROM',
                value: '$ballsRemaining balls',
                color: Colors.white.withOpacity(0.6),
              ),
            ],
            if (rrr != null) ...[
              const SizedBox(width: 20),
              _TargetStat(
                label: 'RRR',
                value: rrr!,
                color: _C.warning,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TargetStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TargetStat(
      {required this.label,
        required this.value,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$label  ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCORE BLOCK — The hero score display
// ═══════════════════════════════════════════════════════════════════════════════
class _ScoreBlock extends StatelessWidget {
  final String teamName;
  final dynamic runs, wickets, oversDisplay;
  final Animation<double> pulseAnim;

  const _ScoreBlock({
    required this.teamName,
    required this.runs,
    required this.wickets,
    required this.oversDisplay,
    required this.pulseAnim,
  });

  String _abbr(String n) {
    if (n.isEmpty) return '—';
    final w = n.trim().split(RegExp(r'\s+'));
    if (w.length >= 2) {
      return (w[0][0] + w[1][0]).toUpperCase();
    }
    return n.substring(0, n.length.clamp(0, 4)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team name abbreviated
          Row(
            children: [
              // Team avatar
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_C.accent, _C.accentDim],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _C.accent.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    teamName.isNotEmpty
                        ? teamName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  teamName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // The big score
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$runs',
                style: const TextStyle(
                  color: _C.scoreOrange,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -2,
                ),
              ),
              Text(
                '/$wickets',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Overs
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: _C.accent.withOpacity(0.18)),
                ),
                child: Text(
                  '$oversDisplay OV',
                  style: const TextStyle(
                    color: _C.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Innings label
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'BATTING',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATSMEN BLOCK — Active batsmen display
// ═══════════════════════════════════════════════════════════════════════════════
class _BatsmenBlock extends StatelessWidget {
  final List<Map<String, dynamic>> batters;
  final Animation<double> pulseAnim;

  const _BatsmenBlock(
      {required this.batters, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final sorted = [...batters]..sort((a, b) {
      final aS =
      (a['isOnStrike'] == true || a['onStrike'] == true)
          ? 0
          : 1;
      final bS =
      (b['isOnStrike'] == true || b['onStrike'] == true)
          ? 0
          : 1;
      return aS.compareTo(bS);
    });
    final display = sorted.take(2).toList();

    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Text(
            'AT THE CREASE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.22),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),

          if (display.isEmpty)
            Text(
              'Yet to bat',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 13,
              ),
            )
          else
            ...display.map((b) {
              final name =
              (b['playerName'] ?? b['name'] ?? '').toString();
              final runs = b['runs'] ?? 0;
              final balls = b['ballsFaced'] ?? 0;
              final fours = b['fours'] ?? 0;
              final sixes = b['sixes'] ?? 0;
              final onStrike = b['isOnStrike'] == true ||
                  b['onStrike'] == true;
              final sr = balls > 0
                  ? ((runs / balls) * 100).toStringAsFixed(0)
                  : '0';
              final displayName = name.isEmpty
                  ? 'Unknown'
                  : (name.length > 14
                  ? '${name.substring(0, 14)}…'
                  : name);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedBuilder(
                  animation: pulseAnim,
                  builder: (_, __) => Row(
                    children: [
                      // Strike indicator bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 3,
                        height: onStrike ? 32 : 0,
                        margin:
                        const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _C.orange,
                              _C.orange.withOpacity(0.4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: onStrike
                              ? [
                            BoxShadow(
                              color: _C.orange
                                  .withOpacity(0.7 *
                                  pulseAnim.value),
                              blurRadius: 6,
                            )
                          ]
                              : [],
                        ),
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (onStrike)
                                  Padding(
                                    padding: const EdgeInsets
                                        .only(right: 5),
                                    child: Icon(
                                      Icons.sports_cricket,
                                      color: _C.orange,
                                      size: 11,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    displayName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: onStrike
                                          ? Colors.white
                                          : Colors.white
                                          .withOpacity(0.45),
                                      fontSize: 14,
                                      fontWeight: onStrike
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '$runs',
                                  style: TextStyle(
                                    color: onStrike
                                        ? Colors.white
                                        : Colors.white
                                        .withOpacity(0.5),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '($balls)',
                                  style: TextStyle(
                                    color: Colors.white
                                        .withOpacity(0.3),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (fours > 0 || sixes > 0)
                                  Container(
                                    padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _C.success
                                          .withOpacity(0.08),
                                      borderRadius:
                                      BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _C.success
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      '${fours}×4  ${sixes}×6',
                                      style: TextStyle(
                                        color: _C.success,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
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
              );
            }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOWLER + CRR BLOCK
// ═══════════════════════════════════════════════════════════════════════════════
class _BowlerCrrBlock extends StatelessWidget {
  final Map<String, dynamic>? bowler;
  final String crr;
  final String? rrr;
  final String opponentName;

  const _BowlerCrrBlock({
    required this.bowler,
    required this.crr,
    required this.opponentName,
    this.rrr,
  });

  @override
  Widget build(BuildContext context) {
    final bowlerName =
    (bowler?['playerName'] ?? bowler?['name'] ?? '').toString();
    final wkts = bowler?['wickets'] ?? 0;
    final runsConceded =
        bowler?['runsConceded'] ?? bowler?['runs'] ?? 0;
    final bowlerOvers = bowler?['overs'] ?? 0;
    final bowlerEco = bowlerOvers > 0
        ? (runsConceded / bowlerOvers).toStringAsFixed(1)
        : '–';
    final bowlerDisplay = bowlerName.isEmpty
        ? '—'
        : (bowlerName.length > 13
        ? '${bowlerName.substring(0, 13)}…'
        : bowlerName);

    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bowler section
          Text(
            'BOWLING',
            style: TextStyle(
              color: Colors.white.withOpacity(0.22),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.purple,
                  boxShadow: [
                    BoxShadow(
                        color: _C.purple.withOpacity(0.6),
                        blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bowlerDisplay,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '$wkts/$runsConceded',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$bowlerOvers ov',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // CRR / RRR row
          Row(
            children: [
              _RateChip(label: 'CRR', value: crr, color: _C.accent),
              if (rrr != null) ...[
                const SizedBox(width: 8),
                _RateChip(
                    label: 'RRR', value: rrr!, color: _C.warning),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RateChip(
      {required this.label,
        required this.value,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.55),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BALL TRACKER BLOCK
// ═══════════════════════════════════════════════════════════════════════════════
class _BallTrackerBlock extends StatelessWidget {
  final String tournamentId, matchId, inningsId;
  final LiveScoreRepository repo;
  final int currentOverNumber;

  const _BallTrackerBlock({
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
    required this.repo,
    required this.currentOverNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BallByBallTracker(
            tournamentId: tournamentId,
            matchId: matchId,
            inningsId: inningsId,
            repo: repo,
            overNumber: currentOverNumber,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PANEL DIVIDER
// ═══════════════════════════════════════════════════════════════════════════════
class _PanelDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      color: Colors.white.withOpacity(0.06),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INNINGS BREAK OVERLAY
// ═══════════════════════════════════════════════════════════════════════════════
class _InningsBreakOverlay extends StatelessWidget {
  final int firstInningsRuns, firstInningsWickets;
  final Animation<double> pulseAnim;

  const _InningsBreakOverlay({
    required this.firstInningsRuns,
    required this.firstInningsWickets,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: _C.bg.withOpacity(0.93),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 60, vertical: 52),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _C.surfaceH.withOpacity(0.85),
                      _C.surface.withOpacity(0.90),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: _C.accent.withOpacity(0.15)),
                  boxShadow: [
                    BoxShadow(
                        color: _C.accent.withOpacity(0.07),
                        blurRadius: 48),
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 32),
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
                        color: _C.accent.withOpacity(0.08),
                        border: Border.all(
                            color: _C.accent.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                              color:
                              _C.accent.withOpacity(0.15),
                              blurRadius: 24),
                        ],
                      ),
                      child: const Icon(Icons.sports_cricket,
                          color: _C.accent, size: 32),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'INNINGS BREAK',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '2nd Innings Starting Soon',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Score
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                      decoration: BoxDecoration(
                        color: _C.orange.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _C.orange.withOpacity(0.22)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '1ST INNINGS SCORE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                            CrossAxisAlignment.baseline,
                            textBaseline:
                            TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$firstInningsRuns',
                                style: const TextStyle(
                                  color: _C.orange,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                              Text(
                                '/$firstInningsWickets',
                                style: TextStyle(
                                  color: Colors.white
                                      .withOpacity(0.65),
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: _C.gold.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _C.gold.withOpacity(0.22)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_rounded,
                              color: _C.gold, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            'Target: ${firstInningsRuns + 1} runs',
                            style: const TextStyle(
                              color: _C.gold,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: _C.accent,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Waiting for 2nd innings…',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.28),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BROADCAST STATUS BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _BroadcastStatusBar extends StatelessWidget {
  final String label;
  final bool isError;

  const _BroadcastStatusBar(
      {required this.label, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? _C.danger : _C.accent;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            color: _C.bottomPanelBg,
            border: Border(
              top: BorderSide(
                  color: color.withOpacity(0.25), width: 1),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isError)
                  Icon(Icons.error_outline_rounded,
                      color: color.withOpacity(0.7), size: 16)
                else
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color),
                  ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: color.withOpacity(0.65),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
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

// ═══════════════════════════════════════════════════════════════════════════════
// MATCH ENDED DIALOG
// ═══════════════════════════════════════════════════════════════════════════════
class _MatchEndedDialog extends StatelessWidget {
  final String resultText;
  final VoidCallback onBack;

  const _MatchEndedDialog(
      {required this.resultText, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.symmetric(
                horizontal: 48, vertical: 52),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _C.surfaceH.withOpacity(0.96),
                  _C.surface.withOpacity(0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: _C.gold.withOpacity(0.28), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _C.gold.withOpacity(0.12),
                    blurRadius: 48),
                BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 28),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Trophy
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _C.gold.withOpacity(0.18),
                        _C.gold.withOpacity(0.04),
                      ],
                    ),
                    border: Border.all(
                        color: _C.gold.withOpacity(0.35),
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: _C.gold.withOpacity(0.2),
                          blurRadius: 24),
                    ],
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: _C.gold, size: 36),
                ),

                const SizedBox(height: 24),

                Text(
                  'MATCH COMPLETE',
                  style: TextStyle(
                    color: _C.gold.withOpacity(0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Match Ended',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Text(
                    resultText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 28),

                Focus(
                  child: Builder(builder: (ctx) {
                    final focused = Focus.of(ctx).hasFocus;
                    return GestureDetector(
                      onTap: onBack,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: double.infinity,
                        padding:
                        const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: focused
                                ? [_C.accent, _C.accentDim]
                                : [
                              _C.accent.withOpacity(0.85),
                              _C.accentDim.withOpacity(0.85)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: focused
                              ? [
                            BoxShadow(
                                color: _C.accent
                                    .withOpacity(0.4),
                                blurRadius: 20)
                          ]
                              : [],
                        ),
                        child: const Center(
                          child: Text(
                            'Back to Tournament',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORCED LOGOUT DIALOG
// ═══════════════════════════════════════════════════════════════════════════════
class _PremiumForcedLogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 400,
            padding: const EdgeInsets.symmetric(
                horizontal: 48, vertical: 52),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _C.surfaceH.withOpacity(0.96),
                  _C.surface.withOpacity(0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: _C.danger.withOpacity(0.22), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _C.danger.withOpacity(0.1),
                    blurRadius: 40),
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
                    color: _C.danger.withOpacity(0.07),
                    border: Border.all(
                        color: _C.danger.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                          color: _C.danger.withOpacity(0.15),
                          blurRadius: 20),
                    ],
                  ),
                  child: const Icon(Icons.logout_rounded,
                      color: _C.danger, size: 32),
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
                const SizedBox(height: 32),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: _C.accent, strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BALL BY BALL TRACKER (business logic UNCHANGED)
// ═══════════════════════════════════════════════════════════════════════════════
class _BallByBallTracker extends StatefulWidget {
  final String tournamentId, matchId, inningsId;
  final LiveScoreRepository repo;
  final int overNumber;

  const _BallByBallTracker({
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
    required this.repo,
    required this.overNumber,
  });

  @override
  State<_BallByBallTracker> createState() =>
      _BallByBallTrackerState();
}

class _BallByBallTrackerState extends State<_BallByBallTracker> {
  late int _trackedOver = widget.overNumber;
  late Stream<QuerySnapshot> _ballsStream =
  widget.repo.watchCurrentOverBalls(
    widget.tournamentId,
    widget.matchId,
    widget.inningsId,
    widget.overNumber,
  );

  @override
  void didUpdateWidget(covariant _BallByBallTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.overNumber != _trackedOver) {
      _trackedOver = widget.overNumber;
      _ballsStream = widget.repo.watchCurrentOverBalls(
          widget.tournamentId,
          widget.matchId,
          widget.inningsId,
          widget.overNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _ballsStream,
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('watchCurrentOverBalls error: ${snap.error}');
        }
        final balls = snap.hasData
            ? snap.data!.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList()
            : <Map<String, dynamic>>[];

        final legalBalls = <Map<String, dynamic>>[];
        final extraBalls = <Map<String, dynamic>>[];

        for (final b in balls) {
          final isExtra = b['isWide'] == true ||
              b['isNoBall'] == true ||
              b['isBye'] == true ||
              b['isLegBye'] == true;
          if (isExtra) {
            extraBalls.add(b);
          } else {
            legalBalls.add(b);
          }
        }

        final mainSlots =
        List<Map<String, dynamic>?>.filled(6, null);
        for (int i = 0; i < legalBalls.length && i < 6; i++) {
          mainSlots[i] = legalBalls[i];
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'OVER ${widget.overNumber + 1}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.22),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                // Over progress dots
                Row(
                  children: List.generate(
                    6,
                        (i) => Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < legalBalls.length
                            ? _C.accent.withOpacity(0.6)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ...mainSlots.map((ball) => _BallChip(ball: ball)),
                if (extraBalls.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 1,
                    height: 28,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  const SizedBox(width: 6),
                  ...extraBalls
                      .take(3)
                      .map((ball) =>
                      _BallChip(ball: ball, isExtraSlot: true)),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BALL CHIP
// ═══════════════════════════════════════════════════════════════════════════════
class _BallChip extends StatelessWidget {
  final Map<String, dynamic>? ball;
  final bool isExtraSlot;

  const _BallChip({required this.ball, this.isExtraSlot = false});

  String _label() {
    if (ball == null) return '';
    if (ball!['isWicket'] == true) return 'W';
    if (ball!['isWide'] == true) return 'Wd';
    if (ball!['isNoBall'] == true) return 'Nb';
    if (ball!['isBye'] == true) return 'B';
    if (ball!['isLegBye'] == true) return 'Lb';
    final runs = ball!['runs'] ?? 0;
    return '$runs';
  }

  Color _color() {
    if (ball == null) return Colors.white.withOpacity(0.12);
    if (ball!['isWicket'] == true) return _C.live;
    if (ball!['isWide'] == true || ball!['isNoBall'] == true)
      return _C.warning;
    if (ball!['isBye'] == true || ball!['isLegBye'] == true)
      return Colors.white.withOpacity(0.35);
    final runs = ball!['runs'] ?? 0;
    if (runs == 6) return _C.success;
    if (runs == 4) return _C.accent;
    if (runs == 0) return Colors.white.withOpacity(0.25);
    return Colors.white.withOpacity(0.65);
  }

  @override
  Widget build(BuildContext context) {
    final empty = ball == null;
    final col = _color();
    final label = _label();
    final isWicket = ball?['isWicket'] == true;
    final isBoundary =
        ball?['runs'] == 6 || ball?['runs'] == 4;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: 30,
      height: 30,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        color: empty
            ? Colors.white.withOpacity(0.03)
            : isWicket
            ? col.withOpacity(0.2)
            : isBoundary
            ? col.withOpacity(0.14)
            : col.withOpacity(0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: empty
              ? Colors.white.withOpacity(0.08)
              : col.withOpacity(isWicket ? 0.9 : 0.55),
          width: isWicket ? 1.5 : 1,
        ),
        boxShadow: (!empty && isWicket)
            ? [
          BoxShadow(
              color: col.withOpacity(0.4), blurRadius: 10)
        ]
            : (!empty && isBoundary)
            ? [
          BoxShadow(
              color: col.withOpacity(0.25),
              blurRadius: 6)
        ]
            : [],
      ),
      child: Center(
        child: empty
            ? null
            : Text(
          label,
          style: TextStyle(
            color: col,
            fontSize: label.length > 1 ? 8 : 11,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AMBIENT GLOW
// ═══════════════════════════════════════════════════════════════════════════════
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
            color.withOpacity(0.08),
            color.withOpacity(0.03),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}