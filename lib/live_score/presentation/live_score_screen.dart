import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crictrax/login/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/commentary_audio_service.dart';
import '../data/models/repositories/live_score_repository.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF050B14);
  static const surface = Color(0xFF0A1628);
  static const surfaceH = Color(0xFF0F1E35);
  static const card = Color(0xFF0C1830);
  static const cardBorder = Color(0x14FFFFFF);
  static const accent = Color(0xFF3FD6EE);
  static const accentDim = Color(0xFF0066CC);
  static const live = Color(0xFFFF3D3D);
  static const orange = Color(0xFFFF7A45);
  static const gold = Color(0xFFFFD700);
  static const success = Color(0xFF00E676);
  static const warning = Color(0xFFFFB300);
  static const purple = Color(0xFF8E5CFF);
  static const danger = Color(0xFFFF3D3D);
  static const textDim = Color(0xFF7C93B3);
}

// ── TV overscan-safe padding (kept as-is; independent of text/element scale) ──
EdgeInsets _tvSafePadding(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final bool isTv = size.width >= 1600;
  if (!isTv) return EdgeInsets.zero;
  return EdgeInsets.symmetric(
    horizontal: size.width * 0.02,
    vertical: size.height * 0.02,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// D-PAD FOCUSABLE WRAPPER — makes any tappable element fully controllable via
// a TV remote's D-pad. Wraps content in a Focus node, listens for the
// remote's OK/Select/Enter key to trigger onTap, and reports focus state to
// the builder so callers can render an accent-colored highlight. Flutter's
// WidgetsApp already binds arrow keys to focus traversal by default, so
// wrapping controls in Focus is all that's needed for D-pad movement between
// them; this widget adds the "press OK to activate" behavior on top.
// ═══════════════════════════════════════════════════════════════════════════════
class _DpadFocusable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool isFocused) builder;
  final FocusNode? focusNode;
  final bool autofocus;

  const _DpadFocusable({
    required this.onTap,
    required this.builder,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<_DpadFocusable> createState() => _DpadFocusableState();
}

class _DpadFocusableState extends State<_DpadFocusable> {
  FocusNode? _ownedNode;
  bool _isFocused = false;

  FocusNode get _node => widget.focusNode ?? (_ownedNode ??= FocusNode());

  @override
  void dispose() {
    _ownedNode?.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      onFocusChange: (focused) {
        if (mounted) setState(() => _isFocused = focused);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(context, _isFocused),
      ),
    );
  }
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
  bool _summaryViewed = false;
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
        .listen(
          (snap) {
        if (!snap.exists) return;
        final data = snap.data()!;
        if (data['loggedOut'] == true && mounted && !_hasNavigatedAway) {
          _hasNavigatedAway = true;
          _logoutSub?.cancel();
          _showForcedLogoutModal();
        }
      },
      onError: (e) {
        debugPrint('❌ LiveScoreScreen: logout listener error: $e');
      },
    );
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
        .listen(
          (snap) {
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
      },
      onError: (e) {
        debugPrint('❌ match stream error: $e');
        _scheduleReconnect();
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUG 2 FIX — Match completion detection.
  //
  // Root cause: this method (and the match-level listener in
  // _initMatchSubscription) previously trusted the `isCompleted` boolean
  // fields on the match/innings documents as the ONLY signal a match had
  // ended. Those flags are known to be written unreliably by the scorer
  // app, so a completed chase could leave the TV stuck on the live panel
  // with nothing telling it the game was actually over.
  //
  // Fix: once we're genuinely in the 2nd innings (hasSecondInnings ==
  // true — this can ONLY mean the chase has begun, never "between
  // innings"), we ALSO derive completion from numbers we're already
  // streaming: target reached, or all overs bowled. This is a pure OR —
  // it never overrides isCompleted, it only fires when isCompleted
  // hasn't caught up yet but the score already proves the result. No
  // Firestore write, repository method, navigation, or timer was touched.
  // ═══════════════════════════════════════════════════════════════════
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

    final firstInningsComplete =
        firstInningsDocs.isNotEmpty &&
            (firstInningsDocs.first.data()
            as Map<String, dynamic>)['isCompleted'] ==
                true;

    final hasSecondInnings = secondInningsDocs.isNotEmpty;

    final secondInningsComplete =
        hasSecondInnings &&
            (secondInningsDocs.first.data()
            as Map<String, dynamic>)['isCompleted'] ==
                true;

    // ── NEW (Bug 2 fix): read-only numeric fallback for chase completion.
    // Only evaluated when hasSecondInnings is true, because that state can
    // never mean "between innings" — it means the chase is genuinely on.
    bool chaseTargetReached = false;
    bool secondInningsOversExhausted = false;
    if (hasSecondInnings && !secondInningsComplete) {
      final secondData =
      secondInningsDocs.first.data() as Map<String, dynamic>;
      final secondRuns = (secondData['totalRuns'] as num?)?.toInt() ?? 0;

      // Same target-resolution pattern _BroadcastBottomPanel already uses:
      // prefer the innings' own targetRuns, fall back to firstInnings+1,
      // unless hasValidTarget explicitly says the target isn't set yet.
      final hasValidTargetFlag = secondData['hasValidTarget'];
      int? target = (secondData['targetRuns'] as num?)?.toInt();
      if (hasValidTargetFlag == false) target = null;
      if (target == null && firstInningsDocs.isNotEmpty) {
        final firstRuns = ((firstInningsDocs.first.data()
        as Map<String, dynamic>)['totalRuns'] as num?)
            ?.toInt();
        if (firstRuns != null) target = firstRuns + 1;
      }
      if (target != null && secondRuns >= target) {
        chaseTargetReached = true;
      }

      // Same idea for "overs used up" — maxOvers/balls are already read
      // elsewhere in this file (_BroadcastBottomPanel), reused here.
      final maxOvers = (secondData['maxOvers'] as num?)?.toInt();
      final balls = (secondData['balls'] as num?)?.toInt();
      if (maxOvers != null && balls != null && balls >= maxOvers * 6) {
        secondInningsOversExhausted = true;
      }
    }

    if (firstInningsComplete &&
        (secondInningsComplete ||
            chaseTargetReached ||
            secondInningsOversExhausted)) {
      debugPrint(
        '✅ match over — navigating (isCompleted=$secondInningsComplete, '
            'targetReached=$chaseTargetReached, oversExhausted=$secondInningsOversExhausted)',
      );
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
      // ✅ single-innings completion is checked FIRST, before we ever set
      // the innings-break UI state, so it's reachable.
      // (Unchanged — we deliberately did NOT add a numeric fallback here:
      // "no second innings yet" is indistinguishable from "we are between
      // innings", so isCompleted has to remain the signal in this branch.)
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

      final firstData = firstInningsDocs.first.data() as Map<String, dynamic>;
      final runs = (firstData['totalRuns'] as num?)?.toInt() ?? 0;
      final wickets = (firstData['totalWickets'] as num?)?.toInt() ?? 0;
      debugPrint(
        '🏏 innings 1 complete — showing innings break. Score: $runs/$wickets',
      );
      if (!_showInningsBreak) {
        setState(() {
          _showInningsBreak = true;
          _firstInningsRuns = runs;
          _firstInningsWickets = wickets;
        });
      }
      return;
    }

    // ── FIX (Bug 2 – secondary root cause): previously this only cleared
    // once the viewer had manually opened the First-Innings scorecard
    // (`_summaryViewed`). If nobody opened it, the TV stayed stuck on the
    // Innings Break overlay forever even though the 2nd innings was
    // already live in Firestore. The break now ends as soon as the 2nd
    // innings genuinely starts streaming — viewing the scorecard is a
    // nice-to-have, not a precondition for the live feed to resume.
    if (hasSecondInnings && _showInningsBreak) {
      setState(() {
        _showInningsBreak = false;
      });
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final staleSince = DateTime.now().difference(_lastMatchUpdate).inSeconds;
      if (staleSince > 15) {
        debugPrint('💔 match stream stale for ${staleSince}s — reconnecting');
        _scheduleReconnect();
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (2 * (++_reconnectAttempt)).clamp(2, 10));
    _reconnectTimer = Timer(delay, () {
      if (!mounted) return;
      debugPrint('🔄 reconnecting match stream (attempt $_reconnectAttempt)');
      _initMatchSubscription();
      setState(() {
        _inningsStream = _repo.watchInnings(
          widget.tournamentId,
          widget.matchId,
        );
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
    final EdgeInsets safe = _tvSafePadding(context);

    return Scaffold(
      backgroundColor: _C.bg,
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Stack(
          children: [
            // ── Stadium background ──────────────────────────────────────
            Positioned.fill(
              child: Image.asset(
                'assets/images/backgrounds/login_bg.jpg',
                fit: BoxFit.cover,
              ),
            ),

            // ── Cinematic dark overlay ──────────────────────────────────
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
              top: -80.h,
              left: -60.w,
              child: _AmbientGlow(color: _C.accent, size: 300.r),
            ),
            Positioned(
              top: -60.h,
              right: -40.w,
              child: _AmbientGlow(color: _C.live, size: 220.r),
            ),

            // ── SIDE AD BANNERS — replaces the old bottom sponsored
            // banner. Shown as two vertical carousels docked to the left
            // and right edges of the screen. Hidden on narrow widths so
            // they don't crowd a phone-sized layout. ─────────────────────
            if (MediaQuery.of(context).size.width >= 1000)
              Positioned(
                left: 16.w,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _SideAdBanner(
                    images: const [
                      'assets/images/ad_banner_1.png',
                      'assets/images/ad_banner_3.png',
                    ],
                  ),
                ),
              ),
            if (MediaQuery.of(context).size.width >= 1000)
              Positioned(
                right: 16.w,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _SideAdBanner(
                    images: const [
                      'assets/images/ad_banner2.png',
                      'assets/images/ad_banner_3.png',
                    ],
                  ),
                ),
              ),

            // ── Discreet back / live chrome strip ─────────────────────────
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  28.w + safe.left,
                  18.h + safe.top,
                  28.w + safe.right,
                  0,
                ),
                child: Row(
                  children: [
                    _DpadFocusable(
                      onTap: () => Navigator.pop(context),
                      builder: (context, focused) => AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: focused
                              ? _C.accent.withOpacity(0.16)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(11.r),
                          border: Border.all(
                            color: focused
                                ? _C.accent
                                : Colors.white.withOpacity(0.1),
                            width: focused ? 2 : 1,
                          ),
                          boxShadow: focused
                              ? [
                            BoxShadow(
                              color: _C.accent.withOpacity(0.45),
                              blurRadius: 14.r,
                            ),
                          ]
                              : [],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: focused
                              ? _C.accent
                              : Colors.white.withOpacity(0.55),
                          size: 26.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Text(
                      'CRICTRAX',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.28),
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.2.sp,
                      ),
                    ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 7.h,
                        ),
                        decoration: BoxDecoration(
                          color: _C.live.withOpacity(
                            0.12 + 0.06 * _pulseAnim.value,
                          ),
                          borderRadius: BorderRadius.circular(9.r),
                          border: Border.all(
                            color: _C.live.withOpacity(
                              0.4 + 0.2 * _pulseAnim.value,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8.r,
                              height: 8.r,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _C.live,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: _C.live,
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.sp,
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

            // ── Main centered card stack ──────────────────────────────────
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1400.w),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24.w + safe.left,
                      24.h + safe.top,
                      24.w + safe.right,
                      24.h + safe.bottom,
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _inningsStream,
                      builder: (context, inningsSnap) {
                        if (inningsSnap.hasError) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _scheduleReconnect();
                          });
                          return _lastInningsId != null
                              ? _buildCachedBar()
                              : _buildErrorBar(inningsSnap.error.toString());
                        }

                        if (inningsSnap.connectionState ==
                            ConnectionState.waiting) {
                          return _lastInningsId != null
                              ? _buildCachedBar()
                              : _buildStatusBar(
                            label: 'Connecting to live feed…',
                          );
                        }

                        if (!inningsSnap.hasData ||
                            inningsSnap.data!.docs.isEmpty) {
                          return _lastInningsId != null
                              ? _buildCachedBar()
                              : _buildStatusBar(
                            label: 'Waiting for match to start…',
                          );
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

                            onSummaryViewed: () {
                              setState(() {
                                _summaryViewed = true;
                                _showInningsBreak = false;
                              });
                            },
                          );
                        }

                        final secondInningsDocs = docs.where((d) {
                          final data = d.data() as Map<String, dynamic>;
                          return data['isSecondInnings'] == true;
                        }).toList();

                        final currentDoc = secondInningsDocs.isNotEmpty
                            ? secondInningsDocs.first
                            : docs.first;

                        final innData = currentDoc.data() as Map<String, dynamic>;

                        final firstInningsDocs = docs.where((d) {
                          final data = d.data() as Map<String, dynamic>;
                          return data['isSecondInnings'] != true;
                        }).toList();

                        String? firstInningsBattingTeamName;
                        if (firstInningsDocs.isNotEmpty) {
                          final firstData =
                          firstInningsDocs.first.data()
                          as Map<String, dynamic>;
                          firstInningsBattingTeamName =
                              (firstData['battingTeamName'] ?? '')
                                  .toString()
                                  .trim();
                        }

                        _lastInningsId = currentDoc.id;
                        _lastInningsData = Map<String, dynamic>.from(innData);
                        _lastFirstInningsBattingTeamName =
                            firstInningsBattingTeamName;

                        int? firstInningsTotal;
                        if (secondInningsDocs.isNotEmpty &&
                            firstInningsDocs.isNotEmpty) {
                          final fd =
                          firstInningsDocs.first.data()
                          as Map<String, dynamic>;
                          firstInningsTotal = (fd['totalRuns'] as num?)?.toInt();
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
      BuildContext context,
      Map<String, dynamic> matchData,
      ) {
    if (!mounted || _dialogShown) return;
    _dialogShown = true;

    final resultText = matchData['result'] as String? ?? 'Match Completed';

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

  Widget _buildStatusBar({
    String label = 'Waiting for match to start…',
  }) {
    return Column(
      children: [
        _TeamsHeaderStatic(
          team1Name: widget.team1Name,
          team2Name: widget.team2Name,
        ),
        SizedBox(height: 26.h),
        _StatusCard(label: label, isError: false),
      ],
    );
  }

  Widget _buildErrorBar(String error) {
    return Column(
      children: [
        _TeamsHeaderStatic(
          team1Name: widget.team1Name,
          team2Name: widget.team2Name,
        ),
        SizedBox(height: 26.h),
        _StatusCard(
          label: 'Live data error — reconnecting…',
          isError: true,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATCH SUMMARY SCREEN
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
  State<_MatchSummaryScreen> createState() => _MatchSummaryScreenState();
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

  // ── UNCHANGED: Firestore load logic ─────────────────────────────────────
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
        _batsmen[inn.id] = bSnap.docs.map((d) => d.data()).toList();
        _bowlers[inn.id] = wSnap.docs.map((d) => d.data()).toList();
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
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Stack(
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
              top: -80.h,
              left: -60.w,
              child: _AmbientGlow(color: _C.accent, size: 300.r),
            ),
            Positioned(
              top: -60.h,
              right: -40.w,
              child: _AmbientGlow(color: _C.gold, size: 220.r),
            ),
            SafeArea(
              child: Column(
                children: [
                  // ══════════════════════════════════════════════════════
                  // ENLARGED APP BAR — back icon, trophy badge, title text,
                  // result text, and "Back to Tournament" button all scaled
                  // up for TV readability from a couch distance.
                  // ══════════════════════════════════════════════════════
                  Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 0),
                    child: _CardShell(
                      padding: EdgeInsets.symmetric(
                        horizontal: 28.w,
                        vertical: 20.h,
                      ),
                      child: Row(
                        children: [
                          _DpadFocusable(
                            onTap: () => Navigator.pop(context),
                            builder: (context, focused) => AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              // ENLARGED: 9.r → 14.r
                              padding: EdgeInsets.all(14.r),
                              decoration: BoxDecoration(
                                color: focused
                                    ? _C.accent.withOpacity(0.16)
                                    : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: focused
                                      ? _C.accent
                                      : Colors.white.withOpacity(0.1),
                                  width: focused ? 2 : 1,
                                ),
                                boxShadow: focused
                                    ? [
                                  BoxShadow(
                                    color: _C.accent.withOpacity(0.45),
                                    blurRadius: 14.r,
                                  ),
                                ]
                                    : [],
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: focused
                                    ? _C.accent
                                    : Colors.white.withOpacity(0.75),
                                // ENLARGED: 18.sp → 26.sp
                                size: 26.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 20.w),
                          Container(
                            // ENLARGED: 8.r → 12.r
                            padding: EdgeInsets.all(12.r),
                            decoration: BoxDecoration(
                              color: _C.gold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: _C.gold.withOpacity(0.25),
                              ),
                            ),
                            child: Icon(
                              Icons.emoji_events,
                              color: _C.gold,
                              // ENLARGED: 20.sp → 28.sp
                              size: 28.sp,
                            ),
                          ),
                          SizedBox(width: 18.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${widget.team1Name} vs ${widget.team2Name}',
                                  // ENLARGED: 20.sp → 30.sp
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  widget.resultText,
                                  // ENLARGED: 15.sp → 20.sp
                                  style: TextStyle(
                                    color: _C.orange,
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16.w),
                          _DpadFocusable(
                            onTap: () => Navigator.pop(context),
                            builder: (context, focused) => AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              // ENLARGED: h16.w v10.h → h24.w v16.h
                              padding: EdgeInsets.symmetric(
                                horizontal: 24.w,
                                vertical: 16.h,
                              ),
                              decoration: BoxDecoration(
                                color: focused
                                    ? _C.accent.withOpacity(0.18)
                                    : _C.accent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(24.r),
                                border: Border.all(
                                  color: focused
                                      ? _C.accent
                                      : _C.accent.withOpacity(0.4),
                                  width: focused ? 2 : 1,
                                ),
                                boxShadow: focused
                                    ? [
                                  BoxShadow(
                                    color: _C.accent.withOpacity(0.4),
                                    blurRadius: 16.r,
                                  ),
                                ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_back,
                                    color: _C.accent,
                                    // ENLARGED: 14.sp → 19.sp
                                    size: 19.sp,
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    'Back to Tournament',
                                    // ENLARGED: 14.sp → 20.sp
                                    style: TextStyle(
                                      color: _C.accent.withOpacity(0.9),
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.w700,
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

                  Expanded(
                    child: _loading
                        ? const Center(
                      child: CircularProgressIndicator(color: _C.accent),
                    )
                        : _buildSummary(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SLIGHTLY REDUCED: scorecard width pulled back from 1560.w → 1400.w,
  // and typography/padding trimmed a notch so the cards aren't as
  // oversized while staying well above the original small version.
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSummary() {
    if (_innData.isEmpty) {
      return Center(
        child: Text(
          'No match data available',
          style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 20.sp),
        ),
      );
    }

    final inningsList = _innData.entries.toList()
      ..sort((a, b) {
        final aS = a.value['isSecondInnings'] == true ? 1 : 0;
        final bS = b.value['isSecondInnings'] == true ? 1 : 0;
        return aS.compareTo(bS);
      });

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: ConstrainedBox(
        // REDUCED: 1560.w → 1400.w
        constraints: BoxConstraints(maxWidth: 1400.w),
        child: Column(
          children: inningsList.map((entry) {
            final innId = entry.key;
            final inn = entry.value;
            final isSecond = inn['isSecondInnings'] == true;
            final batTeam = (inn['battingTeamName'] ?? '').toString();
            final batsmen = _batsmen[innId] ?? [];
            final bowlers = _bowlers[innId] ?? [];
            final totalRuns = (inn['totalRuns'] as num?)?.toInt() ??
                batsmen.fold<int>(
                  0,
                      (s, b) => s + ((b['runs'] ?? 0) as num).toInt(),
                );
            final totalWkts = (inn['totalWickets'] as num?)?.toInt() ??
                batsmen.where((b) => b['isOut'] == true).length;
            final totalBalls = (inn['balls'] as num?)?.toInt() ??
                batsmen.fold<int>(
                  0,
                      (s, b) => s + ((b['ballsFaced'] ?? 0) as num).toInt(),
                );
            final overs = inn['overs'] != null
                ? '${inn['overs']}'
                : '${totalBalls ~/ 6}.${totalBalls % 6}';

            return Padding(
              // REDUCED: 32.h → 26.h
              padding: EdgeInsets.only(bottom: 26.h),
              child: _CardShell(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      // REDUCED: 22.h → 18.h
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 18.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20.r),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: _C.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: _C.purple.withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              'Innings ${isSecond ? 2 : 1}',
                              // REDUCED: 20.sp → 17.sp
                              style: TextStyle(
                                color: _C.purple,
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Text(
                              batTeam.isNotEmpty ? batTeam : 'Batting Team',
                              // REDUCED: 38.sp → 32.sp
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '$totalRuns/$totalWkts ($overs ov)',
                            // REDUCED: 46.sp → 38.sp
                            style: TextStyle(
                              color: _C.orange,
                              fontSize: 38.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      // REDUCED: 32.w → 26.w
                      padding: EdgeInsets.all(26.w),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _summaryLabel('BATTING', _C.orange),
                                SizedBox(height: 10.h),
                                _summaryHeader([
                                  'Batter',
                                  'R',
                                  'B',
                                  '4s',
                                  '6s',
                                  'SR',
                                ]),
                                Divider(color: Colors.white12, height: 12.h),
                                ...(batsmen..sort(
                                      (a, b) => ((b['runs'] ?? 0) as num)
                                      .compareTo((a['runs'] ?? 0) as num),
                                ))
                                    .map((b) => _batsmanRow(b)),
                              ],
                            ),
                          ),
                          // REDUCED: 48.w → 38.w
                          SizedBox(width: 38.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _summaryLabel('BOWLING', _C.accent),
                                SizedBox(height: 10.h),
                                _summaryHeader([
                                  'Bowler',
                                  'O',
                                  'R',
                                  'W',
                                  'Eco',
                                ]),
                                Divider(color: Colors.white12, height: 12.h),
                                ...(bowlers..sort(
                                      (a, b) => ((b['wickets'] ?? 0) as num)
                                      .compareTo(
                                    (a['wickets'] ?? 0) as num,
                                  ),
                                ))
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

  // REDUCED: label 26.sp → 22.sp, accent bar 5.w×24.h → 4.w×20.h
  Widget _summaryLabel(String text, Color color) => Row(
    children: [
      Container(
        width: 4.w,
        height: 20.h,
        color: color,
        margin: EdgeInsets.only(right: 9.w),
      ),
      Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 22.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3.sp,
        ),
      ),
    ],
  );

  // REDUCED: header text 21.sp → 18.sp, column width 62.w → 54.w
  Widget _summaryHeader(List<String> cols) => Padding(
    padding: EdgeInsets.symmetric(vertical: 5.h),
    child: Row(
      children: [
        Expanded(
          child: Text(
            cols[0],
            style: TextStyle(
              color: Colors.white38,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...cols
            .skip(1)
            .map(
              (c) => SizedBox(
            width: 54.w,
            child: Text(
              c,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // REDUCED: row vertical padding 16.h → 12.h, text 23.sp → 20.sp
  Widget _batsmanRow(Map<String, dynamic> b) {
    final name = (b['playerName'] ?? b['name'] ?? '').toString();
    final runs = (b['runs'] ?? 0) as num;
    final balls = (b['ballsFaced'] ?? 0) as num;
    final fours = (b['fours'] ?? 0) as num;
    final sixes = (b['sixes'] ?? 0) as num;
    final sr = balls > 0 ? ((runs / balls) * 100).toStringAsFixed(1) : '0.0';
    final isOut = b['isOut'] == true;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 16 ? '${name.substring(0, 16)}…' : name,
              style: TextStyle(
                color: isOut ? Colors.white54 : Colors.white70,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
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

  // REDUCED: same treatment as _batsmanRow
  Widget _bowlerRow(Map<String, dynamic> b) {
    final name = (b['playerName'] ?? b['name'] ?? '').toString();
    final overs = b['overs'] ?? 0;
    final runs = (b['runsConceded'] ?? b['runs'] ?? 0) as num;
    final wkts = (b['wickets'] ?? 0) as num;
    final eco = (b['economy'] ?? 0) as num;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 16 ? '${name.substring(0, 16)}…' : name,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _sc('$overs'),
          _sc('$runs'),
          _sc('$wkts', bold: true, color: wkts >= 3 ? _C.orange : Colors.white),
          _sc(eco.toStringAsFixed(1)),
        ],
      ),
    );
  }

  // REDUCED: stat cell width 62.w → 54.w, text 23.sp → 20.sp
  Widget _sc(String t, {bool bold = false, Color? color}) => SizedBox(
    width: 54.w,
    child: Text(
      t,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color ?? Colors.white60,
        fontSize: 20.sp,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIRST INNINGS SUMMARY SCREEN
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
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Stack(
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
              top: -80.h,
              left: -60.w,
              child: _AmbientGlow(color: _C.accent, size: 300.r),
            ),
            Positioned(
              top: -60.h,
              right: -40.w,
              child: _AmbientGlow(color: _C.gold, size: 220.r),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 0),
                    child: _CardShell(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 14.h,
                      ),
                      child: Row(
                        children: [
                          _DpadFocusable(
                            onTap: () => Navigator.pop(context),
                            builder: (context, focused) => AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: EdgeInsets.all(9.r),
                              decoration: BoxDecoration(
                                color: focused
                                    ? _C.accent.withOpacity(0.16)
                                    : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(9.r),
                                border: Border.all(
                                  color: focused
                                      ? _C.accent
                                      : Colors.white.withOpacity(0.1),
                                  width: focused ? 2 : 1,
                                ),
                                boxShadow: focused
                                    ? [
                                  BoxShadow(
                                    color: _C.accent.withOpacity(0.45),
                                    blurRadius: 14.r,
                                  ),
                                ]
                                    : [],
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: focused
                                    ? _C.accent
                                    : Colors.white.withOpacity(0.75),
                                size: 18.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: _C.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(9.r),
                              border: Border.all(
                                color: _C.orange.withOpacity(0.25),
                              ),
                            ),
                            child: Icon(
                              Icons.sports_cricket,
                              color: _C.orange,
                              size: 20.sp,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${widget.team1Name} vs ${widget.team2Name}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '1st Innings Scorecard',
                                  style: TextStyle(
                                    color: _C.textDim,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                      child: CircularProgressIndicator(color: _C.accent),
                    )
                        : SingleChildScrollView(
                      padding: EdgeInsets.all(24.w),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 960.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CardShell(
                              child: Column(
                                children: [
                                  Text(
                                    battingTeam.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5.sp,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '${widget.firstInningsRuns}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 56.sp,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        '/${widget.firstInningsWickets}',
                                        style: TextStyle(
                                          color: _C.accent,
                                          fontSize: 56.sp,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 18.w,
                                      vertical: 10.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _C.gold.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(
                                        12.r,
                                      ),
                                      border: Border.all(
                                        color: _C.gold.withOpacity(0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.flag_rounded,
                                          color: _C.gold,
                                          size: 16.sp,
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          'Target: $target runs to win',
                                          style: TextStyle(
                                            color: _C.gold,
                                            fontSize: 18.sp,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24.h),
                            _CardShell(
                              padding: EdgeInsets.all(24.w),
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        _fiLabel('BATTING', _C.orange),
                                        SizedBox(height: 8.h),
                                        _fiHeader([
                                          'Batter',
                                          'R',
                                          'B',
                                          '4s',
                                          '6s',
                                          'SR',
                                        ]),
                                        Divider(
                                          color: Colors.white12,
                                          height: 8.h,
                                        ),
                                        if (_batsmen.isEmpty)
                                          Padding(
                                            padding:
                                            EdgeInsets.symmetric(
                                              vertical: 12.h,
                                            ),
                                            child: Text(
                                              'No batting data available',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.35),
                                                fontSize: 15.sp,
                                              ),
                                            ),
                                          )
                                        else
                                          ...(_batsmen..sort(
                                                (a, b) =>
                                                ((b['runs'] ?? 0)
                                                as num)
                                                    .compareTo(
                                                  (a['runs'] ?? 0)
                                                  as num,
                                                ),
                                          ))
                                              .map(_fiBatsmanRow),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 32.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        _fiLabel('BOWLING', _C.accent),
                                        SizedBox(height: 8.h),
                                        _fiHeader([
                                          'Bowler',
                                          'O',
                                          'R',
                                          'W',
                                          'Eco',
                                        ]),
                                        Divider(
                                          color: Colors.white12,
                                          height: 8.h,
                                        ),
                                        if (_bowlers.isEmpty)
                                          Padding(
                                            padding:
                                            EdgeInsets.symmetric(
                                              vertical: 12.h,
                                            ),
                                            child: Text(
                                              'No bowling data available',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.35),
                                                fontSize: 15.sp,
                                              ),
                                            ),
                                          )
                                        else
                                          ...(_bowlers..sort(
                                                (a, b) =>
                                                ((b['wickets'] ?? 0)
                                                as num)
                                                    .compareTo(
                                                  (a['wickets'] ??
                                                      0)
                                                  as num,
                                                ),
                                          ))
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
      ),
    );
  }

  Widget _fiLabel(String text, Color color) => Row(
    children: [
      Container(
        width: 3.w,
        height: 16.h,
        color: color,
        margin: EdgeInsets.only(right: 8.w),
      ),
      Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 15.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2.sp,
        ),
      ),
    ],
  );

  Widget _fiHeader(List<String> cols) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4.h),
    child: Row(
      children: [
        Expanded(
          child: Text(
            cols[0],
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...cols
            .skip(1)
            .map(
              (c) => SizedBox(
            width: 42.w,
            child: Text(
              c,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fiBatsmanRow(Map<String, dynamic> b) {
    final name = (b['playerName'] ?? b['name'] ?? '').toString();
    final runs = (b['runs'] ?? 0) as num;
    final balls = (b['ballsFaced'] ?? 0) as num;
    final fours = (b['fours'] ?? 0) as num;
    final sixes = (b['sixes'] ?? 0) as num;
    final sr = balls > 0 ? ((runs / balls) * 100).toStringAsFixed(1) : '0.0';
    final isOut = b['isOut'] == true;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 16 ? '${name.substring(0, 16)}…' : name,
              style: TextStyle(
                color: isOut ? Colors.white54 : Colors.white70,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
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
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 16 ? '${name.substring(0, 16)}…' : name,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _fiCell('$overs'),
          _fiCell('$runs'),
          _fiCell(
            '$wkts',
            bold: true,
            color: wkts >= 3 ? _C.orange : Colors.white,
          ),
          _fiCell(eco.toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _fiCell(String t, {bool bold = false, Color? color}) => SizedBox(
    width: 42.w,
    child: Text(
      t,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color ?? Colors.white60,
        fontSize: 16.sp,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED CARD SHELL — glassmorphism, sized via flutter_screenutil.
// ═══════════════════════════════════════════════════════════════════════════════
class _CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _CardShell({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24.r, sigmaY: 24.r),
        child: Container(
          padding: padding ?? EdgeInsets.all(32.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.06),
                _C.card.withOpacity(0.50),
              ],
            ),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24.r,
                offset: Offset(0, 10.h),
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
// STATIC TEAM BADGE + HEADER
// ═══════════════════════════════════════════════════════════════════════════════
class _TeamBadge extends StatelessWidget {
  final String name;
  const _TeamBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46.r,
          height: 46.r,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13.r),
            gradient: const LinearGradient(colors: [_C.accent, _C.accentDim]),
            boxShadow: [
              BoxShadow(color: _C.accent.withOpacity(0.3), blurRadius: 12.r),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Text(
          name.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 42.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5.sp,
          ),
        ),
      ],
    );
  }
}

class _TeamsHeaderStatic extends StatelessWidget {
  final String team1Name, team2Name;
  const _TeamsHeaderStatic({
    required this.team1Name,
    required this.team2Name,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 28.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TeamBadge(name: team1Name),
          Text(
            'VS',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 21.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5.sp,
            ),
          ),
          _TeamBadge(name: team2Name),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final bool isError;
  const _StatusCard({required this.label, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? _C.danger : _C.accent;
    return _CardShell(
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 36.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isError)
            Icon(
              Icons.error_outline_rounded,
              color: color.withOpacity(0.8),
              size: 24.sp,
            )
          else
            SizedBox(
              width: 20.r,
              height: 20.r,
              child: CircularProgressIndicator(
                strokeWidth: 2.5.r,
                color: color,
              ),
            ),
          SizedBox(width: 16.w),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.75),
              fontSize: 21.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BROADCAST BOTTOM PANEL — business logic UNCHANGED, visuals via ScreenUtil.
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
  State<_BroadcastBottomPanel> createState() => _BroadcastBottomPanelState();
}

class _BroadcastBottomPanelState extends State<_BroadcastBottomPanel> {
  // ── Business Logic (UNCHANGED) ────────────────────────────────────────────
  List<Map<String, dynamic>> _cachedBatsmen = [];
  Map<String, dynamic>? _cachedBowler;

  late String _trackedInningsId = widget.inningsId;
  late Stream<QuerySnapshot> _batsmenStream = widget.repo.watchBatsmen(
    widget.tournamentId,
    widget.matchId,
    widget.inningsId,
  );
  late Stream<QuerySnapshot> _bowlersStream = widget.repo.watchBowlers(
    widget.tournamentId,
    widget.matchId,
    widget.inningsId,
  );

  @override
  void didUpdateWidget(covariant _BroadcastBottomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inningsId != _trackedInningsId) {
      _trackedInningsId = widget.inningsId;
      setState(() {
        _cachedBatsmen = [];
        _cachedBowler = null;
        _batsmenStream = widget.repo.watchBatsmen(
          widget.tournamentId,
          widget.matchId,
          widget.inningsId,
        );
        _bowlersStream = widget.repo.watchBowlers(
          widget.tournamentId,
          widget.matchId,
          widget.inningsId,
        );
      });
    }
  }

  String _resolveBattingTeamName() {
    final battingTeamId = (widget.innData['battingTeamId'] ?? '')
        .toString()
        .trim();
    debugPrint(
      'battingTeamId=$battingTeamId  team1Id=${widget.team1Id}  team2Id=${widget.team2Id}',
    );
    if (battingTeamId.isNotEmpty) {
      if (battingTeamId == widget.team1Id) return widget.team1Name;
      if (battingTeamId == widget.team2Id) return widget.team2Name;
    }
    final name = (widget.innData['battingTeamName'] ?? '').toString().trim();
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
        final batsmenStillConnecting =
            batSnap.connectionState == ConnectionState.waiting &&
                _cachedBatsmen.isEmpty;

        final calculatedRuns = allBatsmen.fold<int>(
          0,
              (s, b) => s + ((b['runs'] ?? 0) as num).toInt(),
        );
        final calculatedWickets =
            allBatsmen.where((b) => b['isOut'] == true).length;
        final calculatedBallsFromBatsmen = allBatsmen.fold<int>(
          0,
              (s, b) => s + ((b['ballsFaced'] ?? 0) as num).toInt(),
        );

        final totalRuns =
            (widget.innData['totalRuns'] as num?)?.toInt() ?? calculatedRuns;
        final totalWickets =
            (widget.innData['totalWickets'] as num?)?.toInt() ??
                calculatedWickets;

        final totalBalls =
            (widget.innData['balls'] as num?)?.toInt() ??
                calculatedBallsFromBatsmen;

        final completedOvers = totalBalls ~/ 6;
        final ballsInOver = totalBalls % 6;
        final currentOverNumber = (ballsInOver == 0 && totalBalls > 0)
            ? completedOvers - 1
            : completedOvers;
        final oversDisplay = widget.innData['overs'] != null
            ? '${widget.innData['overs']}'
            : (widget.innData['totalOvers'] != null && totalBalls == 0
            ? widget.innData['totalOvers']
            : '$completedOvers.$ballsInOver');

        final activeBatsmen = allBatsmen
            .where((b) => b['isOut'] != true)
            .toList();

        final target = (widget.innData['targetRuns'] as num?)?.toInt() ??
            (widget.firstInningsTotal != null
                ? widget.firstInningsTotal! + 1
                : null);
        final runsNeeded =
            (widget.innData['runsNeeded'] as num?)?.toInt() ??
                (target != null
                    ? (target - totalRuns).clamp(0, 9999)
                    : null);
        final maxOvers = (widget.innData['maxOvers'] as num?)?.toInt();
        final ballsRemaining =
            (widget.innData['ballsRemaining'] as num?)?.toInt() ??
                (maxOvers != null
                    ? ((maxOvers * 6) - totalBalls).clamp(0, 9999)
                    : null);
        final oversRemaining = ballsRemaining != null
            ? '${ballsRemaining ~/ 6}.${ballsRemaining % 6}'
            : null;

        final activeBatsmenForPanel = activeBatsmen;

        return StreamBuilder<QuerySnapshot>(
          stream: _bowlersStream,
          builder: (context, bowlSnap) {
            if (bowlSnap.hasData && bowlSnap.data!.docs.isNotEmpty) {
              final bowlers = bowlSnap.data!.docs
                  .map((d) => d.data() as Map<String, dynamic>)
                  .toList();

              double parseOvers(dynamic raw) {
                if (raw == null) return 0.0;
                if (raw is num) return raw.toDouble();
                return double.tryParse(raw.toString()) ?? 0.0;
              }

              bool isMidOver(Map<String, dynamic> b) {
                final ov = parseOvers(b['overs']);
                final ballsDigit = (ov * 10).round() % 10;
                return ballsDigit > 0;
              }

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
                  final withTimestamp = bowlers
                      .where((b) => b['lastUpdated'] is Timestamp)
                      .toList();
                  if (withTimestamp.isNotEmpty) {
                    withTimestamp.sort(
                          (a, b) => (b['lastUpdated'] as Timestamp).compareTo(
                        a['lastUpdated'] as Timestamp,
                      ),
                    );
                    _cachedBowler = withTimestamp.first;
                  } else {
                    _cachedBowler = bowlers.last;
                  }
                }
              }
            }
            final bowler = _cachedBowler;
            final bowlerStillConnecting =
                bowlSnap.connectionState == ConnectionState.waiting &&
                    _cachedBowler == null;
            final crr = totalBalls > 0
                ? (totalRuns / totalBalls) * 6
                : (widget.innData['currentRunRate'] ?? 0.0);

            double? rrr;
            if (widget.innData['requiredRunRate'] != null) {
              rrr = (widget.innData['requiredRunRate'] as num).toDouble();
            } else if (runsNeeded != null &&
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
              activeBatsmen: activeBatsmenForPanel,
              bowler: bowler,
              crr: crr,
              rrr: rrr,
              target: target,
              runsNeeded: runsNeeded,
              ballsRemaining: ballsRemaining,
              oversRemaining: oversRemaining,
              currentOverNumber: currentOverNumber,
              batsmenConnecting: batsmenStillConnecting,
              bowlerConnecting: bowlerStillConnecting,
            );
          },
        );
      },
    );
  }

  // ── Visual layer, ScreenUtil-scaled ─────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════
  // UI UPDATE (per latest request):
  //  1. Bottom sponsored banner removed from here entirely — replaced by
  //     the two _SideAdBanner widgets docked to the screen edges in
  //     LiveScoreScreen.build().
  //  2. Score digits enlarged (100.sp → 132.sp) for far-distance
  //     readability; the overs/CRR pill and the FULL SCORECARD button now
  //     sit together directly under the score inside the same header
  //     card, instead of overs/CRR alone up top and the scorecard button
  //     as a separate element down at the bottom of the page.
  //  3. Target/runs-needed/balls-remaining bar (_TargetInfoBar) kept as
  //     its own row directly below that pill/button row, still inside the
  //     header card — just repositioned as part of the same reshuffle.
  //  4. FULL SCORECARD button: same onTap/navigation, same
  //     _MatchSummaryScreen push — only its position changed.
  // No stream, Firestore, or state logic touched below.
  // ═══════════════════════════════════════════════════════════════════
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
    required bool batsmenConnecting, // NEW (Bug 1 fix)
    required bool bowlerConnecting,
  }) {
    final crrStr = crr is double
        ? crr.toStringAsFixed(2)
        : double.tryParse(crr.toString())?.toStringAsFixed(2) ?? '0.00';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── HEADER CARD: teams + big score + overs/CRR + Full Scorecard ──
        _CardShell(
          padding: EdgeInsets.fromLTRB(38.w, 32.h, 38.w, 30.h),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TeamBadge(name: widget.team1Name),
                  Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5.sp,
                    ),
                  ),
                  _TeamBadge(name: widget.team2Name),
                ],
              ),
              SizedBox(height: 26.h),
              // ── BIG SCORE (enlarged: 100.sp → 132.sp) ───────────────
              Center(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$totalRuns',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 132.sp,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -2.sp,
                        ),
                      ),
                      TextSpan(
                        text: '/$totalWickets',
                        style: TextStyle(
                          color: _C.accent,
                          fontSize: 132.sp,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -2.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 22.h),
              // ── OVERS / CRR pill + FULL SCORECARD (moved up here from
              // the bottom of the page; same onTap/navigation) ──────────
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14.w,
                runSpacing: 12.h,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 26.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(36.r),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$oversDisplay',
                          style: TextStyle(
                            color: _C.accent,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'OVERS',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2.sp,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Container(
                          width: 5.r,
                          height: 5.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _C.accent.withOpacity(0.6),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Text(
                          'CRR:',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          crrStr,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── FULL SCORECARD BUTTON — same onTap/navigation as
                  // before, only its position changed (was a standalone
                  // Center() block at the bottom of the page). ──────────
                  _DpadFocusable(
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
                    builder: (context, focused) => AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                        horizontal: 22.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: focused
                            ? _C.accent.withOpacity(0.16)
                            : _C.accent.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(36.r),
                        border: Border.all(
                          color: _C.accent.withOpacity(focused ? 1 : 0.55),
                          width: focused ? 2.5 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _C.accent.withOpacity(
                              focused ? 0.35 : 0.18,
                            ),
                            blurRadius: focused ? 24.r : 16.r,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            color: _C.accent,
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'FULL SCORECARD',
                            style: TextStyle(
                              color: _C.accent,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (target != null && runsNeeded != null) ...[
                SizedBox(height: 20.h),
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

        SizedBox(height: 24.h),

        // ── BATSMAN / BOWLER CARDS ────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _BatsmenCard(
                battingTeamName: battingTeamName,
                batters: activeBatsmen,
                isConnecting: batsmenConnecting,
                pulseAnim: widget.pulseAnim,
              ),
            ),
            SizedBox(width: 24.w),
            Expanded(
              child: _BowlerCard(bowlingTeamName: opponentName, bowler: bowler,  isConnecting: bowlerConnecting,),
            ),
          ],
        ),

        SizedBox(height: 24.h),

        // ── RECENT BALLS ──────────────────────────────────────────────────
        _CardShell(
          padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 22.h),
          child: _BallByBallTracker(
            tournamentId: widget.tournamentId,
            matchId: widget.matchId,
            inningsId: widget.inningsId,
            repo: widget.repo,
            overNumber: currentOverNumber,
          ),
        ),

        SizedBox(height: 24.h),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TARGET INFO BAR
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
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: urgentColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: urgentColor.withOpacity(0.25)),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 24.w,
          runSpacing: 8.h,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag_rounded, color: urgentColor, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  'TARGET $target',
                  style: TextStyle(
                    color: urgentColor,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2.sp,
                  ),
                ),
              ],
            ),
            _TargetStat(
              label: 'NEED',
              value: '$runsNeeded runs',
              color: _C.orange,
            ),
            if (ballsRemaining != null)
              _TargetStat(
                label: 'FROM',
                value: '$ballsRemaining balls',
                color: Colors.white.withOpacity(0.6),
              ),
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
  const _TargetStat({
    required this.label,
    required this.value,
    required this.color,
  });

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
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2.sp,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 21.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATSMAN CARD
// ═══════════════════════════════════════════════════════════════════════════════
// UI UPDATE: added a clear on-strike (current striker) indicator — a
// highlighted, bordered row with a glowing accent bar and a "STRIKE" chip,
// plus a subtle pulse using the same pulseAnim already driving the LIVE
// badge elsewhere on this screen. Sorting/data logic is unchanged.
// ═══════════════════════════════════════════════════════════════════════════════
class _BatsmenCard extends StatelessWidget {
  final String battingTeamName;
  final List<Map<String, dynamic>> batters;
  final bool isConnecting;
  final Animation<double>? pulseAnim;
  const _BatsmenCard({
    required this.battingTeamName,
    required this.batters,
    this.isConnecting = false,
    this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...batters]
      ..sort((a, b) {
        final aS = (a['isOnStrike'] == true || a['onStrike'] == true) ? 0 : 1;
        final bS = (b['isOnStrike'] == true || b['onStrike'] == true) ? 0 : 1;
        return aS.compareTo(bS);
      });
    final display = sorted.take(2).toList();

    return _CardShell(
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 26.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'BATSMAN',
                style: TextStyle(
                  color: _C.textDim,
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.sp,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 52.w,
                child: Text(
                  'R',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _C.textDim,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              SizedBox(
                width: 40.w,
                child: Text(
                  'B',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _C.textDim,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (display.isEmpty)
            Text(
              // FIX (Bug 1): previously always "Yet to bat" — identical
              // whether Firestore was still connecting or genuinely had no
              // opener data yet. Now it reflects which one is true.
              isConnecting
                  ? 'Connecting to live feed…'
                  : 'Match live — openers not yet recorded',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 20.sp,
              ),
            )
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

              final row = Container(
                margin: EdgeInsets.only(bottom: 16.h),
                padding: EdgeInsets.symmetric(
                  horizontal: onStrike ? 14.w : 0,
                  vertical: onStrike ? 10.h : 0,
                ),
                decoration: onStrike
                    ? BoxDecoration(
                  color: _C.accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: _C.accent.withOpacity(0.45),
                    width: 1.5,
                  ),
                )
                    : null,
                child: Row(
                  children: [
                    if (onStrike)
                      Container(
                        width: 5.r,
                        height: 30.r,
                        margin: EdgeInsets.only(right: 12.w),
                        decoration: BoxDecoration(
                          color: _C.accent,
                          borderRadius: BorderRadius.circular(3.r),
                          boxShadow: [
                            BoxShadow(
                              color: _C.accent.withOpacity(0.6),
                              blurRadius: 8.r,
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(
                                  onStrike ? 1 : 0.55,
                                ),
                                fontSize: 25.sp,
                                fontWeight: onStrike
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (onStrike) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: _C.accent,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sports_cricket,
                                    color: _C.bg,
                                    size: 12.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'STRIKE',
                                    style: TextStyle(
                                      color: _C.bg,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 52.w,
                      child: Text(
                        '$runs${onStrike ? '*' : ''}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    SizedBox(
                      width: 40.w,
                      child: Text(
                        '$balls',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 23.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (onStrike && pulseAnim != null) {
                return AnimatedBuilder(
                  animation: pulseAnim!,
                  builder: (_, child) => Opacity(
                    opacity: 0.85 + 0.15 * pulseAnim!.value,
                    child: child,
                  ),
                  child: row,
                );
              }
              return row;
            }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOWLER CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _BowlerCard extends StatelessWidget {
  final String bowlingTeamName;
  final Map<String, dynamic>? bowler;
  final bool isConnecting;
  const _BowlerCard({
    required this.bowlingTeamName,
    required this.bowler,
    this.isConnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    final bowlerName = (bowler?['playerName'] ?? bowler?['name'] ?? '')
        .toString();
    final wkts = bowler?['wickets'] ?? 0;
    final runsConceded = bowler?['runsConceded'] ?? bowler?['runs'] ?? 0;
    final maidens = bowler?['maidens'] ?? 0;
    final bowlerOvers = bowler?['overs'] ?? 0;
    final bowlerDisplay = bowlerName.isEmpty
        ? (isConnecting ? '…' : 'Yet to bowl')
        : (bowlerName.length > 18
        ? '${bowlerName.substring(0, 18)}…'
        : bowlerName);

    return _CardShell(
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 26.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'BOWLER',
                style: TextStyle(
                  color: _C.textDim,
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.sp,
                ),
              ),
              const Spacer(),
              _colHeader('O'),
              SizedBox(width: 14.w),
              _colHeader('M'),
              SizedBox(width: 14.w),
              _colHeader('R'),
              SizedBox(width: 14.w),
              _colHeader('W'),
            ],
          ),
          SizedBox(height: 20.h),
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
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _colVal('$bowlerOvers'),
              SizedBox(width: 14.w),
              _colVal('$maidens'),
              SizedBox(width: 14.w),
              _colVal('$runsConceded'),
              SizedBox(width: 14.w),
              SizedBox(
                width: 36.w,
                child: Text(
                  '$wkts',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _C.accent,
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _colHeader(String t) => SizedBox(
    width: 36.w,
    child: Text(
      t,
      textAlign: TextAlign.right,
      style: TextStyle(
        color: _C.textDim,
        fontSize: 19.sp,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _colVal(String t) => SizedBox(
    width: 36.w,
    child: Text(
      t,
      textAlign: TextAlign.right,
      style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 23.sp,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIDE AD BANNER — vertical image carousel docked to the left/right edges
// of the screen. Replaces the old bottom-of-page _SponsoredBanner. Same
// 30-second auto-rotate cadence as before, just laid out vertically and
// positioned at the screen edges instead of stacked at the bottom.
// ═══════════════════════════════════════════════════════════════════════════════
class _SideAdBanner extends StatefulWidget {
  final List<String> images;
  const _SideAdBanner({required this.images});

  @override
  State<_SideAdBanner> createState() => _SideAdBannerState();
}

class _SideAdBannerState extends State<_SideAdBanner> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !_pageController.hasClients || widget.images.isEmpty) {
        return;
      }
      _index = (_index + 1) % widget.images.length;
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

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 96.w,
      height: 420.h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.r, sigmaY: 20.r),
          child: Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.06),
                  _C.card.withOpacity(0.50),
                ],
              ),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: Image.asset(
                    widget.images[i],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INNINGS BREAK OVERLAY
// ═══════════════════════════════════════════════════════════════════════════════
class _InningsBreakOverlay extends StatelessWidget {
  final String tournamentId;
  final String matchId;
  final LiveScoreRepository repo;
  final String? firstInningsId;

  final String team1Name;
  final String team2Name;
  final String? battingTeamName;

  final int firstInningsRuns;
  final int firstInningsWickets;

  final Animation<double> pulseAnim;

  final VoidCallback onSummaryViewed;

  const _InningsBreakOverlay({
    super.key,
    required this.tournamentId,
    required this.matchId,
    required this.repo,
    this.firstInningsId,

    required this.team1Name,
    required this.team2Name,
    this.battingTeamName,

    required this.firstInningsRuns,
    required this.firstInningsWickets,

    required this.pulseAnim,

    required this.onSummaryViewed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TeamsHeaderStatic(
          team1Name: team1Name,
          team2Name: team2Name,
        ),
        SizedBox(height: 26.h),
        _CardShell(
          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 50.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84.r,
                height: 84.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.accent.withOpacity(0.08),
                  border: Border.all(color: _C.accent.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: _C.accent.withOpacity(0.15),
                      blurRadius: 24.r,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.sports_cricket,
                  color: _C.accent,
                  size: 36.sp,
                ),
              ),
              SizedBox(height: 26.h),
              Text(
                'INNINGS BREAK',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 5.sp,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                '2nd Innings Starting Soon',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.5.sp,
                ),
              ),
              SizedBox(height: 30.h),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 34.w,
                  vertical: 20.h,
                ),
                decoration: BoxDecoration(
                  color: _C.orange.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(18.r),
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
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5.sp,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$firstInningsRuns',
                          style: TextStyle(
                            color: _C.orange,
                            fontSize: 66.sp,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          '/$firstInningsWickets',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 38.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.w,
                  vertical: 12.h,
                ),
                decoration: BoxDecoration(
                  color: _C.gold.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(13.r),
                  border: Border.all(color: _C.gold.withOpacity(0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_rounded, color: _C.gold, size: 18.sp),
                    SizedBox(width: 10.w),
                    Text(
                      'Target: ${firstInningsRuns + 1} runs',
                      style: TextStyle(
                        color: _C.gold,
                        fontSize: 23.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 22.h),
              // ── Full Scorecard button — D-pad focusable ──────────────
              _DpadFocusable(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FirstInningsSummaryScreen(
                        tournamentId: tournamentId,
                        matchId: matchId,
                        repo: repo,
                        firstInningsId: firstInningsId,
                        team1Name: team1Name,
                        team2Name: team2Name,
                        battingTeamName: battingTeamName,
                        firstInningsRuns: firstInningsRuns,
                        firstInningsWickets: firstInningsWickets,
                      ),
                    ),
                  );
                  onSummaryViewed();
                },
                builder: (context, focused) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    horizontal: 28.w,
                    vertical: 16.h,
                  ),
                  decoration: BoxDecoration(
                    color: focused
                        ? _C.accent.withOpacity(0.16)
                        : _C.accent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(32.r),
                    border: Border.all(
                      color: _C.accent.withOpacity(focused ? 1 : 0.5),
                      width: focused ? 2.5 : 1.5,
                    ),
                    boxShadow: focused
                        ? [
                      BoxShadow(
                        color: _C.accent.withOpacity(0.4),
                        blurRadius: 24.r,
                      ),
                    ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        color: _C.accent,
                        size: 19.sp,
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        'FULL SCORECARD',
                        style: TextStyle(
                          color: _C.accent,
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30.h),
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: CircularProgressIndicator(
                        color: _C.accent.withOpacity(
                          0.6 + 0.4 * pulseAnim.value,
                        ),
                        strokeWidth: 2.5.r,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Waiting for 2nd innings…',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.28),
                        fontSize: 20.sp,
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
// MATCH ENDED DIALOG
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24.r, sigmaY: 24.r),
          child: Container(
            width: 440.w,
            padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 52.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _C.surfaceH.withOpacity(0.96),
                  _C.surface.withOpacity(0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(28.r),
              border: Border.all(color: _C.gold.withOpacity(0.28), width: 1.5),
              boxShadow: [
                BoxShadow(color: _C.gold.withOpacity(0.12), blurRadius: 48.r),
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 28.r,
                ),
              ],
            ),
            // ── D-pad traversal for this dialog's two actions ──────────
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76.r,
                    height: 76.r,
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
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _C.gold.withOpacity(0.2),
                          blurRadius: 24.r,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: _C.gold,
                      size: 36.sp,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'MATCH COMPLETE',
                    style: TextStyle(
                      color: _C.gold.withOpacity(0.55),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Match Ended',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5.sp,
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 22.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      color: _C.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: _C.orange.withOpacity(0.25)),
                    ),
                    child: Text(
                      resultText,
                      style: TextStyle(
                        color: _C.orange,
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'What would you like to do?',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 15.sp,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: _DpadFocusable(
                      onTap: onViewSummary,
                      builder: (context, focused) => AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        decoration: BoxDecoration(
                          color: focused
                              ? _C.purple.withOpacity(0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: _C.purple,
                            width: focused ? 2.5 : 1.5,
                          ),
                          boxShadow: focused
                              ? [
                            BoxShadow(
                              color: _C.purple.withOpacity(0.4),
                              blurRadius: 18.r,
                            ),
                          ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bar_chart, color: _C.purple, size: 18.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'View Match Summary',
                              style: TextStyle(
                                color: _C.purple,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: _DpadFocusable(
                      onTap: onBack,
                      builder: (context, focused) => AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: focused
                                ? [_C.accent, _C.accentDim]
                                : [
                              _C.accent.withOpacity(0.85),
                              _C.accentDim.withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                          border: focused
                              ? Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          )
                              : null,
                          boxShadow: focused
                              ? [
                            BoxShadow(
                              color: _C.accent.withOpacity(0.4),
                              blurRadius: 20.r,
                            ),
                          ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            'Back to Tournament',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// FORCED LOGOUT DIALOG — no interactive controls, auto-navigates.
// ═══════════════════════════════════════════════════════════════════════════════
class _PremiumForcedLogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24.r, sigmaY: 24.r),
          child: Container(
            width: 400.w,
            padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 52.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _C.surfaceH.withOpacity(0.96),
                  _C.surface.withOpacity(0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(28.r),
              border: Border.all(
                color: _C.danger.withOpacity(0.22),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _C.danger.withOpacity(0.1),
                  blurRadius: 40.r,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72.r,
                  height: 72.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.danger.withOpacity(0.07),
                    border: Border.all(color: _C.danger.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: _C.danger.withOpacity(0.15),
                        blurRadius: 20.r,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: _C.danger,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 28.h),
                Text(
                  'Session Ended',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'You have been logged out remotely.\nRedirecting to login…',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 16.sp,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: 24.r,
                  height: 24.r,
                  child: CircularProgressIndicator(
                    color: _C.accent,
                    strokeWidth: 2.5.r,
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
// BALL BY BALL TRACKER — business logic UNCHANGED, visuals via ScreenUtil.
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
  State<_BallByBallTracker> createState() => _BallByBallTrackerState();
}

class _BallByBallTrackerState extends State<_BallByBallTracker> {
  late int _trackedOver = widget.overNumber;
  late Stream<QuerySnapshot> _ballsStream = widget.repo.watchCurrentOverBalls(
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
                fontSize: 19.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Container(
              width: 1,
              height: 26.h,
              color: Colors.white.withOpacity(0.1),
            ),
            SizedBox(width: 18.w),
            Expanded(
              child: balls.isEmpty
                  ? Text(
                'No balls bowled yet this over',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 19.sp,
                ),
              )
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: balls.map((b) => _BallChip(ball: b)).toList(),
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
// BALL CHIP
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
    final col = _color();
    final label = _label();
    final isWicket = ball?['isWicket'] == true;
    final isBoundary = ball?['runs'] == 6 || ball?['runs'] == 4;

    return Container(
      width: 46.r,
      height: 46.r,
      margin: EdgeInsets.only(left: 10.w),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isWicket ? col : Colors.white.withOpacity(0.04),
        border: Border.all(
          color: isWicket
              ? col
              : isBoundary
              ? col.withOpacity(0.7)
              : Colors.white.withOpacity(0.15),
          width: isWicket || isBoundary ? 2 : 1,
        ),
        boxShadow: isWicket
            ? [BoxShadow(color: col.withOpacity(0.4), blurRadius: 10.r)]
            : isBoundary
            ? [BoxShadow(color: col.withOpacity(0.25), blurRadius: 8.r)]
            : [],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isWicket ? Colors.white : col,
            fontSize: (label.length > 1 ? 17 : 22).sp,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ══════════════
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