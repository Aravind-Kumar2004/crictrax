import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crictrax/login/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import '../../services/commentary_audio_service.dart';
import '../data/models/repositories/live_score_repository.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF050B14);
  static const surface   = Color(0xFF0A1628);
  static const surfaceH  = Color(0xFF0F1E35);
  static const card      = Color(0xFF0C1830);
  static const cardBorder= Color(0x14FFFFFF);
  static const accent    = Color(0xFF3FD6EE);
  static const accentDim = Color(0xFF0066CC);
  static const live      = Color(0xFFFF3D3D);
  static const orange    = Color(0xFFFF7A45);
  static const gold      = Color(0xFFFFD700);
  static const success   = Color(0xFF00E676);
  static const warning   = Color(0xFFFFB300);
  static const purple    = Color(0xFF8E5CFF);
  static const danger    = Color(0xFFFF3D3D);
  static const textDim   = Color(0xFF7C93B3);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TV RESPONSIVE SCALING HELPER
// ─────────────────────────────────────────────────────────────────────────────
// Used exclusively by LiveScoreScreen and the widgets it privately owns, so
// that other screens (e.g. _MatchSummaryScreen, LoginScreen) are completely
// unaffected. Shared widgets (e.g. _CardShell, _TeamBadge) accept an optional
// `scale` parameter that defaults to 1.0, preserving their existing behavior
// everywhere they are used without an explicit scale.
// ═══════════════════════════════════════════════════════════════════════════════
double _tvScale(BuildContext context) {
  final double width = MediaQuery.of(context).size.width;
  final bool isTv = width >= 1600;
  return isTv ? width / 1920 : 1.0;
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
  // ── Business Logic State (UNCHANGED) ──────────────────────────────────────
  final _repo = LiveScoreRepository();
  bool _hasNavigatedAway = false;
  bool _dialogShown = false;
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

  // ── Business Logic (UNCHANGED) ────────────────────────────────────────────
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

  // ── FIXED: single-innings completion check moved ABOVE the innings-break
  // branch so it can actually execute. Previously it was placed after an
  // earlier `return`, making it permanently unreachable — a single-innings
  // match would get stuck showing "Innings Break" forever instead of ending. ──
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
      // ✅ single-innings completion is now checked FIRST, before we ever
      // set the innings-break UI state, so it's reachable.
      if (_lastMatchData?['isCompleted'] == true) {
        debugPrint('✅ single innings match complete — navigating');
        _hasNavigatedAway = true;
        final resultText =
            _lastMatchData?['result'] as String? ?? 'Match Completed';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showMatchEndedAndPop(context, {'result': resultText});
        });
        return;
      }

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
    // (old unreachable duplicate single-innings check removed from here)
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
    // ── TV-responsive scale factor (Android TV @ 1920x1080) ─────────────────
    final double s = _tvScale(context);

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // ── Stadium background ──────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/login_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ── Cinematic dark overlay ──────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.blue.withOpacity(0.08),
                    Colors.black.withOpacity(0.35),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: -80 * s,
            left: -60 * s,
            child: _AmbientGlow(color: _C.accent, size: 300 * s),
          ),
          Positioned(
            top: -60 * s,
            right: -40 * s,
            child: _AmbientGlow(color: _C.live, size: 220 * s),
          ),

          // ── Discreet back / live chrome strip ───────────────────────────
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20 * s, 12 * s, 20 * s, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(8 * s),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8 * s),
                        border:
                        Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          color: Colors.white.withOpacity(0.55), size: 18 * s),
                    ),
                  ),
                  SizedBox(width: 10 * s),
                  Text(
                    'CRICTRAX',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.28),
                      fontSize: 11 * s,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5 * s,
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10 * s, vertical: 5 * s),
                      decoration: BoxDecoration(
                        color:
                        _C.live.withOpacity(0.12 + 0.06 * _pulseAnim.value),
                        borderRadius: BorderRadius.circular(7 * s),
                        border: Border.all(
                            color: _C.live
                                .withOpacity(0.4 + 0.2 * _pulseAnim.value)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6 * s,
                            height: 6 * s,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: _C.live),
                          ),
                          SizedBox(width: 6 * s),
                          Text('LIVE',
                              style: TextStyle(
                                  color: _C.live,
                                  fontSize: 10 * s,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5 * s)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Main centered card stack ────────────────────────────────────
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 960 * s),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: 24 * s, vertical: 24 * s),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _inningsStream,
                    builder: (context, inningsSnap) {
                      if (inningsSnap.hasError) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _scheduleReconnect();
                        });
                        return _lastInningsId != null
                            ? _buildCachedBar(s)
                            : _buildErrorBar(
                            inningsSnap.error.toString(), s);
                      }

                      if (inningsSnap.connectionState ==
                          ConnectionState.waiting) {
                        return _lastInningsId != null
                            ? _buildCachedBar(s)
                            : _buildStatusBar(s,
                            label: 'Connecting to live feed…');
                      }

                      if (!inningsSnap.hasData ||
                          inningsSnap.data!.docs.isEmpty) {
                        return _lastInningsId != null
                            ? _buildCachedBar(s)
                            : _buildStatusBar(s,
                            label: 'Waiting for match to start…');
                      }

                      _reconnectAttempt = 0;
                      _reconnectTimer?.cancel();

                      final docs = inningsSnap.data!.docs;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _checkInningsCompletion(docs);
                      });

                      // ── Innings break: shown in-place, same themed
                      // card stack as the rest of the screen, until the
                      // 2nd innings stream starts flowing. ──────────────
                      if (_showInningsBreak) {
                        // Resolve the 1st-innings doc id so the new "Full
                        // Scorecard" button on the break screen can fetch
                        // that innings' batsmen/bowlers (ADDED — reads
                        // from `docs` which is already available here;
                        // does not touch any existing business logic). ──
                        final firstInningsDocsForBreak = docs.where((d) {
                          final data = d.data() as Map<String, dynamic>;
                          return data['isSecondInnings'] != true;
                        }).toList();
                        final firstInningsIdForBreak =
                        firstInningsDocsForBreak.isNotEmpty
                            ? firstInningsDocsForBreak.first.id
                            : null;

                        return _InningsBreakOverlay(
                          tournamentId: widget.tournamentId,
                          matchId: widget.matchId,
                          repo: _repo,
                          firstInningsId: firstInningsIdForBreak,
                          team1Name: widget.team1Name,
                          team2Name: widget.team2Name,
                          battingTeamName: _lastFirstInningsBattingTeamName,
                          firstInningsRuns: _firstInningsRuns,
                          firstInningsWickets: _firstInningsWickets,
                          pulseAnim: _pulseAnim,
                        );
                      }

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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedBar(double s) {
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
    if (!mounted || _dialogShown) return;
    _dialogShown = true;

    final resultText =
        matchData['result'] as String? ?? 'Match Completed';

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (dialogContext) => _MatchEndedDialog(
        resultText: resultText,
        onViewSummary: () {
          _autoDismissTimer?.cancel();
          try {
            if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
              Navigator.of(dialogContext, rootNavigator: true).pop();
            }
          } catch (_) {}
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => _MatchSummaryScreen(
                  tournamentId: widget.tournamentId,
                  matchId: widget.matchId,
                  team1Name: widget.team1Name,
                  team2Name: widget.team2Name,
                  resultText: resultText,
                  repo: _repo,
                ),
              ),
            );
          }
        },
        onBack: () => _dismissAndPop(),
      ),
    );

    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      _dismissAndPop();
    });
  }

  void _dismissAndPop() {
    _autoDismissTimer?.cancel();
    try {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    } catch (_) {}
    try {
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    } catch (_) {}
  }

  Widget _buildStatusBar(double s,
      {String label = 'Waiting for match to start…'}) {
    return Column(
      children: [
        _TeamsHeaderStatic(
            team1Name: widget.team1Name,
            team2Name: widget.team2Name,
            scale: s),
        SizedBox(height: 20 * s),
        _StatusCard(label: label, isError: false, scale: s),
      ],
    );
  }

  Widget _buildErrorBar(String error, double s) {
    return Column(
      children: [
        _TeamsHeaderStatic(
            team1Name: widget.team1Name,
            team2Name: widget.team2Name,
            scale: s),
        SizedBox(height: 20 * s),
        _StatusCard(
            label: 'Live data error — reconnecting…',
            isError: true,
            scale: s),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATCH SUMMARY SCREEN — UNCHANGED (different screen; not scaled per spec)
// ═══════════════════════════════════════════════════════════════════════════════
class _MatchSummaryScreen extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final String team1Name;
  final String team2Name;
  final String resultText;
  final LiveScoreRepository repo;

  const _MatchSummaryScreen({
    required this.tournamentId,
    required this.matchId,
    required this.team1Name,
    required this.team2Name,
    required this.resultText,
    required this.repo,
  });

  @override
  State<_MatchSummaryScreen> createState() =>
      _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<_MatchSummaryScreen> {
  Map<String, List<Map<String, dynamic>>> _batsmen = {};
  Map<String, List<Map<String, dynamic>>> _bowlers = {};
  Map<String, Map<String, dynamic>> _innData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = FirebaseFirestore.instance;
      final base = db
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('matches')
          .doc(widget.matchId);
      final inningsSnap = await base.collection('innings').get();
      for (final inn in inningsSnap.docs) {
        final innData = inn.data();
        _innData[inn.id] = innData;
        final bSnap = await base
            .collection('innings')
            .doc(inn.id)
            .collection('batsmen')
            .get();
        final wSnap = await base
            .collection('innings')
            .doc(inn.id)
            .collection('bowlers')
            .get();
        _batsmen[inn.id] =
            bSnap.docs.map((d) => d.data()).toList();
        _bowlers[inn.id] =
            wSnap.docs.map((d) => d.data()).toList();
      }
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // ── Stadium background (same as LiveScoreScreen) ────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/stadium_bg.jpeg',
              fit: BoxFit.cover,
            ),
          ),

          // ── Cinematic dark overlay ──────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xF0050B14),
                    Color(0xD9050B14),
                    Color(0xB3050B14),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── Ambient glows ────────────────────────────────────────────────
          Positioned(
            top: -80,
            left: -60,
            child: _AmbientGlow(color: _C.accent, size: 300),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: _AmbientGlow(color: _C.gold, size: 220),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Glass header bar ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _CardShell(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Icon(Icons.arrow_back_rounded,
                                color: Colors.white.withOpacity(0.75),
                                size: 18),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _C.gold.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(9),
                            border:
                            Border.all(color: _C.gold.withOpacity(0.25)),
                          ),
                          child: const Icon(Icons.emoji_events,
                              color: _C.gold, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${widget.team1Name} vs ${widget.team2Name}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.resultText,
                                style: const TextStyle(
                                    color: _C.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _C.accent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _C.accent.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_back,
                                    color: _C.accent, size: 14),
                                const SizedBox(width: 8),
                                Text('Back to Tournament',
                                    style: TextStyle(
                                        color: _C.accent.withOpacity(0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: _loading
                      ? const Center(
                      child: CircularProgressIndicator(
                          color: _C.accent))
                      : _buildSummary(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    if (_innData.isEmpty) {
      return Center(
        child: Text('No match data available',
            style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontSize: 18)),
      );
    }

    final inningsList = _innData.entries.toList()
      ..sort((a, b) {
        final aS = a.value['isSecondInnings'] == true ? 1 : 0;
        final bS = b.value['isSecondInnings'] == true ? 1 : 0;
        return aS.compareTo(bS);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: inningsList.map((entry) {
            final innId = entry.key;
            final inn = entry.value;
            final isSecond = inn['isSecondInnings'] == true;
            final batTeam =
            (inn['battingTeamName'] ?? '').toString();
            final batsmen = _batsmen[innId] ?? [];
            final bowlers = _bowlers[innId] ?? [];
            final totalRuns = batsmen.fold(
                0,
                    (s, b) =>
                s + ((b['runs'] ?? 0) as num).toInt());
            final totalWkts =
                batsmen.where((b) => b['isOut'] == true).length;
            final totalBalls = batsmen.fold(
                0,
                    (s, b) =>
                s +
                    ((b['ballsFaced'] ?? 0) as num).toInt());
            final overs =
                '${totalBalls ~/ 6}.${totalBalls % 6}';

            // ── Glass card shell replaces the old plain Container ───────
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _CardShell(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _C.purple.withOpacity(0.2),
                              borderRadius:
                              BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                  _C.purple.withOpacity(0.4)),
                            ),
                            child: Text(
                              'Innings ${isSecond ? 2 : 1}',
                              style: const TextStyle(
                                  color: _C.purple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              batTeam.isNotEmpty
                                  ? batTeam
                                  : 'Batting Team',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '$totalRuns/$totalWkts ($overs ov)',
                            style: const TextStyle(
                              color: _C.orange,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                _summaryLabel(
                                    'BATTING', _C.orange),
                                const SizedBox(height: 8),
                                _summaryHeader([
                                  'Batter',
                                  'R',
                                  'B',
                                  '4s',
                                  '6s',
                                  'SR'
                                ]),
                                const Divider(
                                    color: Colors.white12,
                                    height: 8),
                                ...(batsmen
                                  ..sort((a, b) =>
                                      ((b['runs'] ?? 0) as num)
                                          .compareTo(
                                          (a['runs'] ?? 0)
                                          as num)))
                                    .map((b) => _batsmanRow(b)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                _summaryLabel(
                                    'BOWLING', _C.accent),
                                const SizedBox(height: 8),
                                _summaryHeader([
                                  'Bowler',
                                  'O',
                                  'R',
                                  'W',
                                  'Eco'
                                ]),
                                const Divider(
                                    color: Colors.white12,
                                    height: 8),
                                ...(bowlers
                                  ..sort((a, b) => ((b['wickets'] ??
                                      0) as num)
                                      .compareTo(
                                      (a['wickets'] ?? 0)
                                      as num)))
                                    .map((b) => _bowlerRow(b)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _summaryLabel(String text, Color color) => Row(
    children: [
      Container(
          width: 3,
          height: 16,
          color: color,
          margin: const EdgeInsets.only(right: 8)),
      Text(text,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2)),
    ],
  );

  Widget _summaryHeader(List<String> cols) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
            child: Text(cols[0],
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w700))),
        ...cols.skip(1).map((c) => SizedBox(
          width: 42,
          child: Text(c,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        )),
      ],
    ),
  );

  Widget _batsmanRow(Map<String, dynamic> b) {
    final name =
    (b['playerName'] ?? b['name'] ?? '').toString();
    final runs = (b['runs'] ?? 0) as num;
    final balls = (b['ballsFaced'] ?? 0) as num;
    final fours = (b['fours'] ?? 0) as num;
    final sixes = (b['sixes'] ?? 0) as num;
    final sr = balls > 0
        ? ((runs / balls) * 100).toStringAsFixed(1)
        : '0.0';
    final isOut = b['isOut'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Colors.white10, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 16
                  ? '${name.substring(0, 16)}…'
                  : name,
              style: TextStyle(
                  color: isOut
                      ? Colors.white54
                      : Colors.white70,
                  fontSize: 13),
            ),
          ),
          _sc('$runs', bold: true, color: _C.orange),
          _sc('$balls'),
          _sc('$fours'),
          _sc('$sixes'),
          _sc(sr),
        ],
      ),
    );
  }

  Widget _bowlerRow(Map<String, dynamic> b) {
    final name =
    (b['playerName'] ?? b['name'] ?? '').toString();
    final overs = b['overs'] ?? 0;
    final runs =
    (b['runsConceded'] ?? b['runs'] ?? 0) as num;
    final wkts = (b['wickets'] ?? 0) as num;
    final eco = (b['economy'] ?? 0) as num;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Colors.white10, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 16
                  ? '${name.substring(0, 16)}…'
                  : name,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13),
            ),
          ),
          _sc('$overs'),
          _sc('$runs'),
          _sc('$wkts',
              bold: true,
              color: wkts >= 3 ? _C.orange : Colors.white),
          _sc(eco.toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _sc(String t,
      {bool bold = false, Color? color}) =>
      SizedBox(
        width: 42,
        child: Text(t,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color ?? Colors.white60,
                fontSize: 13,
                fontWeight: bold
                    ? FontWeight.w800
                    : FontWeight.w500)),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIRST INNINGS SUMMARY SCREEN — NEW. Full scorecard for the completed 1st
// innings plus the target for the chase. Reached only via the "FULL
// SCORECARD" button on the Innings Break screen; popping it returns to the
// LiveScoreScreen underneath (which keeps streaming as normal, unaffected).
// This is purely additive — no existing screen/widget/logic is touched.
// ═══════════════════════════════════════════════════════════════════════════════
class _FirstInningsSummaryScreen extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final String team1Name;
  final String team2Name;
  final String? battingTeamName;
  final int firstInningsRuns;
  final int firstInningsWickets;
  final String? firstInningsId;
  final LiveScoreRepository repo;

  const _FirstInningsSummaryScreen({
    required this.tournamentId,
    required this.matchId,
    required this.team1Name,
    required this.team2Name,
    required this.firstInningsRuns,
    required this.firstInningsWickets,
    required this.repo,
    this.battingTeamName,
    this.firstInningsId,
  });

  @override
  State<_FirstInningsSummaryScreen> createState() =>
      _FirstInningsSummaryScreenState();
}

class _FirstInningsSummaryScreenState
    extends State<_FirstInningsSummaryScreen> {
  List<Map<String, dynamic>> _batsmen = [];
  List<Map<String, dynamic>> _bowlers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.firstInningsId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final base = FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('matches')
          .doc(widget.matchId)
          .collection('innings')
          .doc(widget.firstInningsId);

      final bSnap = await base.collection('batsmen').get();
      final wSnap = await base.collection('bowlers').get();

      if (!mounted) return;
      setState(() {
        _batsmen = bSnap.docs.map((d) => d.data()).toList();
        _bowlers = wSnap.docs.map((d) => d.data()).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.firstInningsRuns + 1;
    final battingTeam = (widget.battingTeamName?.isNotEmpty ?? false)
        ? widget.battingTeamName!
        : widget.team1Name;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/stadium_bg.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xF0050B14),
                    Color(0xD9050B14),
                    Color(0xB3050B14),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -60,
            child: _AmbientGlow(color: _C.accent, size: 300),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: _AmbientGlow(color: _C.gold, size: 220),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _CardShell(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Icon(Icons.arrow_back_rounded,
                                color: Colors.white.withOpacity(0.75),
                                size: 18),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _C.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: _C.orange.withOpacity(0.25)),
                          ),
                          child: const Icon(Icons.sports_cricket,
                              color: _C.orange, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${widget.team1Name} vs ${widget.team2Name}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '1st Innings Scorecard',
                                style: TextStyle(
                                    color: _C.textDim,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                      child: CircularProgressIndicator(color: _C.accent))
                      : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Score + target banner ────────────────────
                          _CardShell(
                            child: Column(
                              children: [
                                Text(
                                  battingTeam.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                  CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${widget.firstInningsRuns}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      '/${widget.firstInningsWickets}',
                                      style: const TextStyle(
                                        color: _C.accent,
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _C.gold.withOpacity(0.08),
                                    borderRadius:
                                    BorderRadius.circular(12),
                                    border: Border.all(
                                        color: _C.gold.withOpacity(0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.flag_rounded,
                                          color: _C.gold, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Target: $target runs to win',
                                        style: const TextStyle(
                                          color: _C.gold,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // ── Batting / bowling tables ──────────────────
                          _CardShell(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      _fiLabel('BATTING', _C.orange),
                                      const SizedBox(height: 8),
                                      _fiHeader(
                                          ['Batter', 'R', 'B', '4s', '6s', 'SR']),
                                      const Divider(
                                          color: Colors.white12, height: 8),
                                      if (_batsmen.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: Text(
                                            'No batting data available',
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.35),
                                                fontSize: 13),
                                          ),
                                        )
                                      else
                                        ...(_batsmen
                                          ..sort((a, b) =>
                                              ((b['runs'] ?? 0) as num)
                                                  .compareTo(
                                                  (a['runs'] ?? 0) as num)))
                                            .map(_fiBatsmanRow),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      _fiLabel('BOWLING', _C.accent),
                                      const SizedBox(height: 8),
                                      _fiHeader(
                                          ['Bowler', 'O', 'R', 'W', 'Eco']),
                                      const Divider(
                                          color: Colors.white12, height: 8),
                                      if (_bowlers.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: Text(
                                            'No bowling data available',
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.35),
                                                fontSize: 13),
                                          ),
                                        )
                                      else
                                        ...(_bowlers
                                          ..sort((a, b) =>
                                              ((b['wickets'] ?? 0) as num)
                                                  .compareTo(
                                                  (a['wickets'] ?? 0) as num)))
                                            .map(_fiBowlerRow),
                                    ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fiLabel(String text, Color color) => Row(
    children: [
      Container(
          width: 3,
          height: 16,
          color: color,
          margin: const EdgeInsets.only(right: 8)),
      Text(text,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2)),
    ],
  );

  Widget _fiHeader(List<String> cols) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
            child: Text(cols[0],
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w700))),
        ...cols.skip(1).map((c) => SizedBox(
          width: 42,
          child: Text(c,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        )),
      ],
    ),
  );

  Widget _fiBatsmanRow(Map<String, dynamic> b) {
    final name = (b['playerName'] ?? b['name'] ?? '').toString();
    final runs = (b['runs'] ?? 0) as num;
    final balls = (b['ballsFaced'] ?? 0) as num;
    final fours = (b['fours'] ?? 0) as num;
    final sixes = (b['sixes'] ?? 0) as num;
    final sr =
    balls > 0 ? ((runs / balls) * 100).toStringAsFixed(1) : '0.0';
    final isOut = b['isOut'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border:
          Border(bottom: BorderSide(color: Colors.white10, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 16 ? '${name.substring(0, 16)}…' : name,
              style: TextStyle(
                  color: isOut ? Colors.white54 : Colors.white70,
                  fontSize: 13),
            ),
          ),
          _fiCell('$runs', bold: true, color: _C.orange),
          _fiCell('$balls'),
          _fiCell('$fours'),
          _fiCell('$sixes'),
          _fiCell(sr),
        ],
      ),
    );
  }

  Widget _fiBowlerRow(Map<String, dynamic> b) {
    final name = (b['playerName'] ?? b['name'] ?? '').toString();
    final overs = b['overs'] ?? 0;
    final runs = (b['runsConceded'] ?? b['runs'] ?? 0) as num;
    final wkts = (b['wickets'] ?? 0) as num;
    final eco = (b['economy'] ?? 0) as num;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border:
          Border(bottom: BorderSide(color: Colors.white10, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 16 ? '${name.substring(0, 16)}…' : name,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          _fiCell('$overs'),
          _fiCell('$runs'),
          _fiCell('$wkts',
              bold: true, color: wkts >= 3 ? _C.orange : Colors.white),
          _fiCell(eco.toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _fiCell(String t, {bool bold = false, Color? color}) => SizedBox(
    width: 42,
    child: Text(t,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color ?? Colors.white60,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED CARD SHELL — enhanced glassmorphism. Accepts an optional `scale`
// (default 1.0) so LiveScoreScreen can render it TV-responsively while every
// other caller (e.g. _MatchSummaryScreen) keeps its exact original look.
// ═══════════════════════════════════════════════════════════════════════════════
class _CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double scale;
  const _CardShell({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20 * s),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24 * s, sigmaY: 24 * s), // stronger blur (was 16)
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.06),  // glassy top-left highlight
                _C.card.withOpacity(0.50),       // lower fill opacity (was 0.72)
              ],
            ),
            borderRadius: BorderRadius.circular(20 * s),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 20 * s,
                offset: Offset(0, 8 * s),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATIC TEAM BADGE + HEADER (used while data is loading, and inside the score card)
// Both accept an optional `scale` (default 1.0), scaled only from LiveScoreScreen.
// ═══════════════════════════════════════════════════════════════════════════════
class _TeamBadge extends StatelessWidget {
  final String name;
  final double scale;
  const _TeamBadge({required this.name, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32 * s,
          height: 32 * s,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9 * s),
            gradient: const LinearGradient(
              colors: [_C.accent, _C.accentDim],
            ),
            boxShadow: [
              BoxShadow(color: _C.accent.withOpacity(0.3), blurRadius: 10 * s),
            ],
          ),
          child: Center(
            child: Text(initial,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14 * s,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        SizedBox(width: 12 * s),
        Text(
          name.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 26 * s,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5 * s,
          ),
        ),
      ],
    );
  }
}

class _TeamsHeaderStatic extends StatelessWidget {
  final String team1Name, team2Name;
  final double scale;
  const _TeamsHeaderStatic(
      {required this.team1Name, required this.team2Name, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return _CardShell(
      scale: s,
      padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 22 * s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TeamBadge(name: team1Name, scale: s),
          Text('VS',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 13 * s,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2 * s)),
          _TeamBadge(name: team2Name, scale: s),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final bool isError;
  final double scale;
  const _StatusCard(
      {required this.label, required this.isError, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final color = isError ? _C.danger : _C.accent;
    return _CardShell(
      scale: s,
      padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 28 * s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isError)
            Icon(Icons.error_outline_rounded,
                color: color.withOpacity(0.8), size: 18 * s)
          else
            SizedBox(
              width: 16 * s,
              height: 16 * s,
              child: CircularProgressIndicator(strokeWidth: 2 * s, color: color),
            ),
          SizedBox(width: 14 * s),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.75),
              fontSize: 14 * s,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BROADCAST BOTTOM PANEL — business logic UNCHANGED, visuals TV-scaled below.
// This widget is only ever used inside LiveScoreScreen, so it computes its own
// scale factor via _tvScale(context) and does not affect any other screen.
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
      setState(() {
        _cachedBatsmen = [];
        _cachedBowler = null;
        _batsmenStream = widget.repo.watchBatsmen(
            widget.tournamentId, widget.matchId, widget.inningsId);
        _bowlersStream = widget.repo.watchBowlers(
            widget.tournamentId, widget.matchId, widget.inningsId);
      });
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

              // Helper: safely parse overs to double
              double parseOvers(dynamic raw) {
                if (raw == null) return 0.0;
                if (raw is num) return raw.toDouble();
                return double.tryParse(raw.toString()) ?? 0.0;
              }

              // Helper: true if bowler is mid-over
              bool isMidOver(Map<String, dynamic> b) {
                final ov = parseOvers(b['overs']);
                final ballsDigit = (ov * 10).round() % 10;
                return ballsDigit > 0;
              }

              // PRIORITY 1: bowler currently mid-over
              final midOverBowlers = bowlers.where(isMidOver).toList();

              if (midOverBowlers.isNotEmpty) {
                midOverBowlers.sort((a, b) {
                  final aActive = a['isBowling'] == true ? 0 : 1;
                  final bActive = b['isBowling'] == true ? 0 : 1;
                  if (aActive != bActive) return aActive.compareTo(bActive);
                  final aTs = a['lastUpdated'];
                  final bTs = b['lastUpdated'];
                  if (aTs is Timestamp && bTs is Timestamp) {
                    return bTs.compareTo(aTs);
                  }
                  return 0;
                });
                _cachedBowler = midOverBowlers.first;

              } else {
                // PRIORITY 2: isBowling flag
                final flaggedBowlers = bowlers
                    .where((b) => b['isBowling'] == true)
                    .toList();

                if (flaggedBowlers.isNotEmpty) {
                  flaggedBowlers.sort((a, b) {
                    final aTs = a['lastUpdated'];
                    final bTs = b['lastUpdated'];
                    if (aTs is Timestamp && bTs is Timestamp) {
                      return bTs.compareTo(aTs);
                    }
                    return 0;
                  });
                  _cachedBowler = flaggedBowlers.first;

                } else {
                  // PRIORITY 3: most recently updated bowler
                  final withTimestamp = bowlers
                      .where((b) => b['lastUpdated'] is Timestamp)
                      .toList();
                  if (withTimestamp.isNotEmpty) {
                    withTimestamp.sort((a, b) =>
                        (b['lastUpdated'] as Timestamp)
                            .compareTo(a['lastUpdated'] as Timestamp));
                    _cachedBowler = withTimestamp.first;
                  } else {
                    // PRIORITY 4: last document as final fallback
                    _cachedBowler = bowlers.last;
                  }
                }
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
              context: context,
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

  // ── Redesigned visual layer (TV-scaled) ─────────────────────────────────────
  Widget _buildBroadcastPanel({
    required BuildContext context,
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
    final double s = _tvScale(context);
    final crrStr = crr is double
        ? crr.toStringAsFixed(2)
        : double.tryParse(crr.toString())?.toStringAsFixed(2) ?? '0.00';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── HEADER CARD: teams + big score + overs/CRR pill ──────────────
        _CardShell(
          scale: s,
          padding: EdgeInsets.fromLTRB(28 * s, 24 * s, 28 * s, 26 * s),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TeamBadge(name: widget.team1Name, scale: s),
                  Text('VS',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 13 * s,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2 * s)),
                  _TeamBadge(name: widget.team2Name, scale: s),
                ],
              ),
              SizedBox(height: 18 * s),
              Center(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$totalRuns',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 64 * s,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -1.5 * s,
                        ),
                      ),
                      TextSpan(
                        text: '/$totalWickets',
                        style: TextStyle(
                          color: _C.accent,
                          fontSize: 64 * s,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -1.5 * s,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 14 * s),
              Container(
                padding:
                EdgeInsets.symmetric(horizontal: 20 * s, vertical: 9 * s),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(30 * s),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$oversDisplay',
                        style: TextStyle(
                            color: _C.accent,
                            fontSize: 15 * s,
                            fontWeight: FontWeight.w800)),
                    SizedBox(width: 6 * s),
                    Text('OVERS',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11 * s,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1 * s)),
                    SizedBox(width: 12 * s),
                    Container(
                      width: 4 * s,
                      height: 4 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.accent.withOpacity(0.6),
                      ),
                    ),
                    SizedBox(width: 12 * s),
                    Text('CRR:',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11 * s,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1 * s)),
                    SizedBox(width: 6 * s),
                    Text(crrStr,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15 * s,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (target != null && runsNeeded != null) ...[
                SizedBox(height: 16 * s),
                _TargetInfoBar(
                  target: target,
                  runsNeeded: runsNeeded,
                  ballsRemaining: ballsRemaining,
                  oversRemaining: oversRemaining,
                  rrr: rrr != null ? rrr.toStringAsFixed(2) : null,
                  pulseAnim: widget.pulseAnim,
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 18 * s),

        // ── BATSMAN / BOWLER CARDS ────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _BatsmenCard(
                    battingTeamName: battingTeamName,
                    batters: activeBatsmen)),
            SizedBox(width: 18 * s),
            Expanded(
                child: _BowlerCard(
                    bowlingTeamName: opponentName, bowler: bowler)),
          ],
        ),

        SizedBox(height: 18 * s),

        // ── RECENT BALLS ──────────────────────────────────────────────────
        _CardShell(
          scale: s,
          padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 16 * s),
          child: _BallByBallTracker(
            tournamentId: widget.tournamentId,
            matchId: widget.matchId,
            inningsId: widget.inningsId,
            repo: widget.repo,
            overNumber: currentOverNumber,
          ),
        ),

        SizedBox(height: 22 * s),

        // ── FULL SCORECARD BUTTON ────────────────────────────────────────
        Center(
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _MatchSummaryScreen(
                    tournamentId: widget.tournamentId,
                    matchId: widget.matchId,
                    team1Name: widget.team1Name,
                    team2Name: widget.team2Name,
                    resultText: 'Live',
                    repo: widget.repo,
                  ),
                ),
              );
            },
            child: Container(
              padding:
              EdgeInsets.symmetric(horizontal: 26 * s, vertical: 14 * s),
              decoration: BoxDecoration(
                color: _C.accent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(30 * s),
                border: Border.all(color: _C.accent.withOpacity(0.55)),
                boxShadow: [
                  BoxShadow(
                      color: _C.accent.withOpacity(0.18), blurRadius: 18 * s),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_outlined,
                      color: _C.accent, size: 16 * s),
                  SizedBox(width: 10 * s),
                  Text(
                    'FULL SCORECARD',
                    style: TextStyle(
                      color: _C.accent,
                      fontSize: 13 * s,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1 * s,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: 18 * s),

        // ── SPONSORED BANNER (now a rotating 3-ad carousel, 30s interval) ──
        const _SponsoredBanner(),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TARGET INFO BAR — chase situation banner (restyled pill), TV-scaled.
// Used only inside LiveScoreScreen; computes its own scale via context.
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
    final double s = _tvScale(context);
    final isClose =
        ballsRemaining != null && runsNeeded <= ballsRemaining! ~/ 2;
    final urgentColor = isClose ? _C.gold : _C.accent;

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Container(
        padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 10 * s),
        decoration: BoxDecoration(
          color: urgentColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14 * s),
          border: Border.all(color: urgentColor.withOpacity(0.25)),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 18 * s,
          runSpacing: 6 * s,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag_rounded, color: urgentColor, size: 13 * s),
                SizedBox(width: 6 * s),
                Text('TARGET $target',
                    style: TextStyle(
                        color: urgentColor,
                        fontSize: 12 * s,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1 * s)),
              ],
            ),
            _TargetStat(label: 'NEED', value: '$runsNeeded runs', color: _C.orange),
            if (ballsRemaining != null)
              _TargetStat(
                  label: 'FROM',
                  value: '$ballsRemaining balls',
                  color: Colors.white.withOpacity(0.6)),
            if (rrr != null)
              _TargetStat(label: 'RRR', value: rrr!, color: _C.warning),
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
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final double s = _tvScale(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$label  ',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 9 * s,
                fontWeight: FontWeight.w700,
                letterSpacing: 1 * s)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13 * s, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATSMAN CARD — matches reference mock table layout, TV-scaled.
// Used only inside LiveScoreScreen; computes its own scale via context.
// ═══════════════════════════════════════════════════════════════════════════════
class _BatsmenCard extends StatelessWidget {
  final String battingTeamName;
  final List<Map<String, dynamic>> batters;
  const _BatsmenCard(
      {required this.battingTeamName, required this.batters});

  @override
  Widget build(BuildContext context) {
    final double s = _tvScale(context);
    final sorted = [...batters]..sort((a, b) {
      final aS = (a['isOnStrike'] == true || a['onStrike'] == true) ? 0 : 1;
      final bS = (b['isOnStrike'] == true || b['onStrike'] == true) ? 0 : 1;
      return aS.compareTo(bS);
    });
    final display = sorted.take(2).toList();

    return _CardShell(
      scale: s,
      padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 18 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('BATSMAN',
                  style: TextStyle(
                      color: _C.textDim,
                      fontSize: 11 * s,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5 * s)),
              const Spacer(),
              SizedBox(
                  width: 40 * s,
                  child: Text('R',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: _C.textDim,
                          fontSize: 11 * s,
                          fontWeight: FontWeight.w800))),
              SizedBox(width: 12 * s),
              SizedBox(
                  width: 30 * s,
                  child: Text('B',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: _C.textDim,
                          fontSize: 11 * s,
                          fontWeight: FontWeight.w800))),
            ],
          ),
          SizedBox(height: 14 * s),
          if (display.isEmpty)
            Text('Yet to bat',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 13 * s))
          else
            ...display.map((b) {
              final name = (b['playerName'] ?? b['name'] ?? '').toString();
              final runs = b['runs'] ?? 0;
              final balls = b['ballsFaced'] ?? 0;
              final onStrike =
                  b['isOnStrike'] == true || b['onStrike'] == true;
              final displayName = name.isEmpty
                  ? 'Unknown'
                  : (name.length > 18 ? '${name.substring(0, 18)}…' : name);

              return Padding(
                padding: EdgeInsets.only(bottom: 12 * s),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white
                                    .withOpacity(onStrike ? 1 : 0.55),
                                fontSize: 16 * s,
                                fontWeight:
                                onStrike ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (onStrike) ...[
                            SizedBox(width: 5 * s),
                            Icon(Icons.star_rounded,
                                color: _C.accent, size: 15 * s),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40 * s,
                      child: Text(
                        '$runs${onStrike ? '*' : ''}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16 * s,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    SizedBox(width: 12 * s),
                    SizedBox(
                      width: 30 * s,
                      child: Text(
                        '$balls',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 15 * s,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOWLER CARD — matches reference mock table layout, TV-scaled.
// Used only inside LiveScoreScreen; computes its own scale via context.
// ═══════════════════════════════════════════════════════════════════════════════
class _BowlerCard extends StatelessWidget {
  final String bowlingTeamName;
  final Map<String, dynamic>? bowler;
  const _BowlerCard({required this.bowlingTeamName, required this.bowler});

  @override
  Widget build(BuildContext context) {
    final double s = _tvScale(context);
    final bowlerName = (bowler?['playerName'] ?? bowler?['name'] ?? '').toString();
    final wkts = bowler?['wickets'] ?? 0;
    final runsConceded = bowler?['runsConceded'] ?? bowler?['runs'] ?? 0;
    final maidens = bowler?['maidens'] ?? 0;
    final bowlerOvers = bowler?['overs'] ?? 0;
    final bowlerDisplay = bowlerName.isEmpty
        ? '—'
        : (bowlerName.length > 18 ? '${bowlerName.substring(0, 18)}…' : bowlerName);

    return _CardShell(
      scale: s,
      padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 18 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('BOWLER',
                  style: TextStyle(
                      color: _C.textDim,
                      fontSize: 11 * s,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5 * s)),
              const Spacer(),
              _colHeader('O', s),
              SizedBox(width: 10 * s),
              _colHeader('M', s),
              SizedBox(width: 10 * s),
              _colHeader('R', s),
              SizedBox(width: 10 * s),
              _colHeader('W', s),
            ],
          ),
          SizedBox(height: 14 * s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  bowlerDisplay,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16 * s,
                      fontWeight: FontWeight.w800),
                ),
              ),
              _colVal('$bowlerOvers', s),
              SizedBox(width: 10 * s),
              _colVal('$maidens', s),
              SizedBox(width: 10 * s),
              _colVal('$runsConceded', s),
              SizedBox(width: 10 * s),
              SizedBox(
                width: 26 * s,
                child: Text('$wkts',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: _C.accent,
                        fontSize: 20 * s,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _colHeader(String t, double s) => SizedBox(
    width: 26 * s,
    child: Text(t,
        textAlign: TextAlign.right,
        style: TextStyle(
            color: _C.textDim, fontSize: 11 * s, fontWeight: FontWeight.w800)),
  );

  Widget _colVal(String t, double s) => SizedBox(
    width: 26 * s,
    child: Text(t,
        textAlign: TextAlign.right,
        style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 15 * s,
            fontWeight: FontWeight.w600)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPONSORED BANNER — rotating carousel of 3 ads, auto-advancing every 30s.
// Decorative only, TV-scaled. Used only inside LiveScoreScreen.
// ═══════════════════════════════════════════════════════════════════════════════
class _SponsoredBanner extends StatefulWidget {
  const _SponsoredBanner();

  @override
  State<_SponsoredBanner> createState() => _SponsoredBannerState();
}

class _SponsoredBannerState extends State<_SponsoredBanner> {
  static const List<Map<String, String>> _ads = [
    {
      'title': 'Get the best cricket gear — 20% off at Cricket Hub',
      'cta': 'SHOP NOW',
      'icon': 'bag',
    },
    {
      'title': 'Live odds, updated every ball — BetXchange',
      'cta': 'PLAY NOW',
      'icon': 'chart',
    },
    {
      'title': 'Stream every match in 4K — SportsFlix',
      'cta': 'SUBSCRIBE',
      'icon': 'play',
    },
  ];

  final PageController _pageController = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !_pageController.hasClients) return;
      _index = (_index + 1) % _ads.length;
      _pageController.animateToPage(
        _index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'chart':
        return Icons.show_chart_rounded;
      case 'play':
        return Icons.play_circle_outline_rounded;
      case 'bag':
      default:
        return Icons.shopping_bag_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double s = _tvScale(context);
    return _CardShell(
      scale: s,
      padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 16 * s),
      child: SizedBox(
        height: 62 * s,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _ads.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final ad = _ads[i];
                return Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(9 * s),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10 * s),
                      ),
                      child: Icon(_iconFor(ad['icon']!),
                          color: Colors.white.withOpacity(0.5), size: 18 * s),
                    ),
                    SizedBox(width: 14 * s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('SPONSORED',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.28),
                                  fontSize: 9 * s,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2 * s)),
                          SizedBox(height: 3 * s),
                          Text(
                            ad['title']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13 * s,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12 * s),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16 * s, vertical: 9 * s),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20 * s),
                        border:
                        Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: Text(
                        ad['cta']!,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11 * s,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5 * s),
                      ),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_ads.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: EdgeInsets.symmetric(horizontal: 3 * s),
                    width: active ? 14 * s : 5 * s,
                    height: 5 * s,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3 * s),
                      color: active
                          ? _C.accent
                          : Colors.white.withOpacity(0.15),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INNINGS BREAK OVERLAY — wired into LiveScoreScreen's build() so it is
// actually shown between innings, TV-scaled. Used only inside LiveScoreScreen.
// Displays: 1st innings score (runs/wickets) and the target for the chase.
// NOW also carries tournamentId/matchId/repo/firstInningsId so it can open
// the new _FirstInningsSummaryScreen via the "FULL SCORECARD" button below.
// ═══════════════════════════════════════════════════════════════════════════════
class _InningsBreakOverlay extends StatelessWidget {
  final String tournamentId;
  final String matchId;
  final LiveScoreRepository repo;
  final String? firstInningsId;
  final String team1Name, team2Name;
  final String? battingTeamName;
  final int firstInningsRuns, firstInningsWickets;
  final Animation<double> pulseAnim;

  const _InningsBreakOverlay({
    required this.tournamentId,
    required this.matchId,
    required this.repo,
    required this.team1Name,
    required this.team2Name,
    required this.firstInningsRuns,
    required this.firstInningsWickets,
    required this.pulseAnim,
    this.firstInningsId,
    this.battingTeamName,
  });

  @override
  Widget build(BuildContext context) {
    final double s = _tvScale(context);
    return Column(
      children: [
        _TeamsHeaderStatic(team1Name: team1Name, team2Name: team2Name, scale: s),
        SizedBox(height: 20 * s),
        _CardShell(
          scale: s,
          padding: EdgeInsets.symmetric(
              horizontal: 32 * s, vertical: 40 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64 * s,
                height: 64 * s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.accent.withOpacity(0.08),
                  border: Border.all(color: _C.accent.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                        color: _C.accent.withOpacity(0.15),
                        blurRadius: 20 * s),
                  ],
                ),
                child: Icon(Icons.sports_cricket,
                    color: _C.accent, size: 28 * s),
              ),
              SizedBox(height: 20 * s),
              Text(
                'INNINGS BREAK',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 11 * s,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4.5 * s,
                ),
              ),
              SizedBox(height: 8 * s),
              Text(
                '2nd Innings Starting Soon',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24 * s,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.5 * s,
                ),
              ),
              SizedBox(height: 24 * s),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 26 * s, vertical: 16 * s),
                decoration: BoxDecoration(
                  color: _C.orange.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14 * s),
                  border: Border.all(color: _C.orange.withOpacity(0.22)),
                ),
                child: Column(
                  children: [
                    Text(
                      (battingTeamName?.isNotEmpty ?? false)
                          ? '${battingTeamName!.toUpperCase()} · 1ST INNINGS'
                          : '1ST INNINGS SCORE',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 10 * s,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2 * s,
                      ),
                    ),
                    SizedBox(height: 8 * s),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$firstInningsRuns',
                          style: TextStyle(
                            color: _C.orange,
                            fontSize: 46 * s,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          '/$firstInningsWickets',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 26 * s,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14 * s),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 18 * s, vertical: 9 * s),
                decoration: BoxDecoration(
                  color: _C.gold.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10 * s),
                  border: Border.all(color: _C.gold.withOpacity(0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_rounded, color: _C.gold, size: 14 * s),
                    SizedBox(width: 8 * s),
                    Text(
                      'Target: ${firstInningsRuns + 1} runs',
                      style: TextStyle(
                        color: _C.gold,
                        fontSize: 15 * s,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18 * s),
              // ── NEW: Full Scorecard button — opens the 1st-innings
              // summary screen; popping it returns here automatically. ──
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _FirstInningsSummaryScreen(
                        tournamentId: tournamentId,
                        matchId: matchId,
                        team1Name: team1Name,
                        team2Name: team2Name,
                        battingTeamName: battingTeamName,
                        firstInningsRuns: firstInningsRuns,
                        firstInningsWickets: firstInningsWickets,
                        firstInningsId: firstInningsId,
                        repo: repo,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 22 * s, vertical: 12 * s),
                  decoration: BoxDecoration(
                    color: _C.accent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(26 * s),
                    border: Border.all(color: _C.accent.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined,
                          color: _C.accent, size: 15 * s),
                      SizedBox(width: 8 * s),
                      Text('FULL SCORECARD',
                          style: TextStyle(
                              color: _C.accent,
                              fontSize: 12 * s,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1 * s)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24 * s),
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14 * s,
                      height: 14 * s,
                      child: CircularProgressIndicator(
                        color: _C.accent.withOpacity(
                            0.6 + 0.4 * pulseAnim.value),
                        strokeWidth: 2 * s,
                      ),
                    ),
                    SizedBox(width: 10 * s),
                    Text(
                      'Waiting for 2nd innings…',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.28),
                        fontSize: 13 * s,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATCH ENDED DIALOG — TV-scaled. Used only inside LiveScoreScreen.
// ═══════════════════════════════════════════════════════════════════════════════
class _MatchEndedDialog extends StatelessWidget {
  final String resultText;
  final VoidCallback onBack;
  final VoidCallback onViewSummary;

  const _MatchEndedDialog({
    required this.resultText,
    required this.onBack,
    required this.onViewSummary,
  });

  @override
  Widget build(BuildContext context) {
    final double s = _tvScale(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28 * s),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24 * s, sigmaY: 24 * s),
          child: Container(
            width: 440 * s,
            padding: EdgeInsets.symmetric(
                horizontal: 48 * s, vertical: 52 * s),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _C.surfaceH.withOpacity(0.96),
                  _C.surface.withOpacity(0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(28 * s),
              border: Border.all(
                  color: _C.gold.withOpacity(0.28), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _C.gold.withOpacity(0.12),
                    blurRadius: 48 * s),
                BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 28 * s),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76 * s,
                  height: 76 * s,
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
                          blurRadius: 24 * s),
                    ],
                  ),
                  child: Icon(Icons.emoji_events_rounded,
                      color: _C.gold, size: 36 * s),
                ),
                SizedBox(height: 24 * s),
                Text(
                  'MATCH COMPLETE',
                  style: TextStyle(
                    color: _C.gold.withOpacity(0.55),
                    fontSize: 10 * s,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4 * s,
                  ),
                ),
                SizedBox(height: 8 * s),
                Text(
                  'Match Ended',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28 * s,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5 * s,
                  ),
                ),
                SizedBox(height: 18 * s),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                      horizontal: 22 * s, vertical: 14 * s),
                  decoration: BoxDecoration(
                    color: _C.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14 * s),
                    border: Border.all(
                        color: _C.orange.withOpacity(0.25)),
                  ),
                  child: Text(
                    resultText,
                    style: TextStyle(
                      color: _C.orange,
                      fontSize: 16 * s,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 10 * s),
                Text(
                  'What would you like to do?',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 13 * s),
                ),
                SizedBox(height: 24 * s),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onViewSummary,
                    icon: Icon(Icons.bar_chart, size: 18 * s),
                    label: Text('View Match Summary',
                        style: TextStyle(fontSize: 15 * s)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.purple,
                      side:
                      BorderSide(color: _C.purple, width: 1.5),
                      padding: EdgeInsets.symmetric(
                          vertical: 16 * s),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14 * s)),
                    ),
                  ),
                ),
                SizedBox(height: 10 * s),
                SizedBox(
                  width: double.infinity,
                  child: Focus(
                    child: Builder(builder: (ctx) {
                      final focused = Focus.of(ctx).hasFocus;
                      return GestureDetector(
                        onTap: onBack,
                        child: AnimatedContainer(
                          duration:
                          const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(
                              vertical: 16 * s),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: focused
                                  ? [_C.accent, _C.accentDim]
                                  : [
                                _C.accent.withOpacity(0.85),
                                _C.accentDim.withOpacity(0.85),
                              ],
                            ),
                            borderRadius:
                            BorderRadius.circular(14 * s),
                            boxShadow: focused
                                ? [
                              BoxShadow(
                                  color: _C.accent
                                      .withOpacity(0.4),
                                  blurRadius: 20 * s)
                            ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              'Back to Tournament',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15 * s,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3 * s,
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
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORCED LOGOUT DIALOG — TV-scaled. Used only inside LiveScoreScreen.
// ═══════════════════════════════════════════════════════════════════════════════
class _PremiumForcedLogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final double s = _tvScale(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28 * s),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24 * s, sigmaY: 24 * s),
          child: Container(
            width: 400 * s,
            padding: EdgeInsets.symmetric(
                horizontal: 48 * s, vertical: 52 * s),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _C.surfaceH.withOpacity(0.96),
                  _C.surface.withOpacity(0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(28 * s),
              border: Border.all(
                  color: _C.danger.withOpacity(0.22), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _C.danger.withOpacity(0.1),
                    blurRadius: 40 * s),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72 * s,
                  height: 72 * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.danger.withOpacity(0.07),
                    border: Border.all(
                        color: _C.danger.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                          color: _C.danger.withOpacity(0.15),
                          blurRadius: 20 * s),
                    ],
                  ),
                  child: Icon(Icons.logout_rounded,
                      color: _C.danger, size: 32 * s),
                ),
                SizedBox(height: 28 * s),
                Text(
                  'Session Ended',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26 * s,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3 * s,
                  ),
                ),
                SizedBox(height: 12 * s),
                Text(
                  'You have been logged out remotely.\nRedirecting to login…',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14 * s,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32 * s),
                SizedBox(
                  width: 24 * s,
                  height: 24 * s,
                  child: CircularProgressIndicator(
                      color: _C.accent, strokeWidth: 2.5 * s),
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
// BALL BY BALL TRACKER — business logic UNCHANGED, TV-scaled visuals.
// Used only inside LiveScoreScreen; computes its own scale via context.
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
  String? _lastPlayedBallId;

  @override
  void didUpdateWidget(covariant _BallByBallTracker oldWidget) {
    super.didUpdateWidget(oldWidget);

    print("Old Over : ${oldWidget.overNumber}");
    print("New Over : ${widget.overNumber}");

    if (widget.overNumber != _trackedOver) {
      print("Changing Stream to Over ${widget.overNumber}");

      _trackedOver = widget.overNumber;
      _lastPlayedBallId = null;

      _ballsStream = widget.repo.watchCurrentOverBalls(
        widget.tournamentId,
        widget.matchId,
        widget.inningsId,
        widget.overNumber,
      );

      setState(() {});
    }
  }

  void _maybePlayCommentary(List<Map<String, dynamic>> balls) {
    if (balls.isEmpty) return;

    final latest = balls.last;

    final String ballId = latest['ballId'] ?? '';

    // Already processed this ball
    if (_lastPlayedBallId == ballId) {
      return;
    }

    _lastPlayedBallId = ballId;

    if (latest['isWicket'] == true) return;
    if (latest['isWide'] == true) return;
    if (latest['isNoBall'] == true) return;
    if (latest['isBye'] == true) return;
    if (latest['isLegBye'] == true) return;

    final runs = (latest['runs'] ?? 0) as int;

    switch (runs) {
      case 1:
        CommentaryAudioService.instance.playSingle();
        break;

      case 2:
        CommentaryAudioService.instance.playDouble();
        break;

      case 4:
        CommentaryAudioService.instance.playFour();
        break;

      case 6:
        CommentaryAudioService.instance.playSix();
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    final double s = _tvScale(context);
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
        _maybePlayCommentary(balls);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'RECENT',
              style: TextStyle(
                color: _C.textDim,
                fontSize: 11 * s,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5 * s,
              ),
            ),
            SizedBox(width: 8 * s),
            Container(
              width: 1,
              height: 20 * s,
              color: Colors.white.withOpacity(0.1),
            ),
            SizedBox(width: 14 * s),
            Expanded(
              child: balls.isEmpty
                  ? Text(
                'No balls bowled yet this over',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 12 * s),
              )
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: balls
                      .map((b) => _BallChip(ball: b))
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BALL CHIP — restyled as a round chip, TV-scaled. Used only inside
// LiveScoreScreen; computes its own scale via context.
// ═══════════════════════════════════════════════════════════════════════════════
class _BallChip extends StatelessWidget {
  final Map<String, dynamic>? ball;

  const _BallChip({required this.ball});

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
    if (ball!['isWide'] == true || ball!['isNoBall'] == true) {
      return _C.warning;
    }
    if (ball!['isBye'] == true || ball!['isLegBye'] == true) {
      return Colors.white.withOpacity(0.35);
    }
    final runs = ball!['runs'] ?? 0;
    if (runs == 6) return _C.success;
    if (runs == 4) return _C.accent;
    if (runs == 0) return Colors.white.withOpacity(0.25);
    return Colors.white.withOpacity(0.65);
  }

  @override
  Widget build(BuildContext context) {
    final double s = _tvScale(context);
    final col = _color();
    final label = _label();
    final isWicket = ball?['isWicket'] == true;
    final isBoundary = ball?['runs'] == 6 || ball?['runs'] == 4;

    return Container(
      width: 34 * s,
      height: 34 * s,
      margin: EdgeInsets.only(left: 8 * s),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isWicket ? col : Colors.white.withOpacity(0.04),
        border: Border.all(
          color: isWicket
              ? col
              : isBoundary
              ? col.withOpacity(0.7)
              : Colors.white.withOpacity(0.15),
          width: isWicket || isBoundary ? 1.5 : 1,
        ),
        boxShadow: isWicket
            ? [BoxShadow(color: col.withOpacity(0.4), blurRadius: 8 * s)]
            : isBoundary
            ? [BoxShadow(color: col.withOpacity(0.25), blurRadius: 6 * s)]
            : [],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isWicket ? Colors.white : col,
            fontSize: (label.length > 1 ? 10 : 13) * s,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AMBIENT GLOW (UNCHANGED — sizes are scaled at the LiveScoreScreen call site,
// so this shared widget itself needs no modification and other screens are
// unaffected)
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