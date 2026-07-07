import 'dart:async';
import 'package:flutter/material.dart';

/// Reusable cinematic splash screen, styled after the CRICTRAX TV brand art.
///
/// Two modes, controlled purely by the parameters you pass in — no
/// business logic or Firestore access lives here:
///
///  1. MATCH-START mode (pass only [team1Name] / [team2Name], leave the
///     innings fields null): shows the two teams, VS branding, and a
///     one-shot "LOADING LIVE ACTION…" progress bar that calls
///     [onComplete] once it finishes.
///
///  2. INNINGS-BREAK mode (also pass [firstInningsRuns], and [target]):
///     adds a "1ST INNINGS SCORE" + "Target" panel below the branding.
///     Pass `duration: null` to run an indeterminate looping bar instead
///     of a timed one — useful when the screen should stay up until an
///     external stream condition changes (e.g. 2nd innings data arrives),
///     rather than for a fixed number of seconds.
class MatchSplashScreen extends StatefulWidget {
  final String team1Name;
  final String team2Name;

  /// When non-null (together with [target]), the innings-break info
  /// panel is shown below the loading bar.
  final int? firstInningsRuns;
  final int? firstInningsWickets;
  final int? target;

  /// Optional label for whose innings the score belongs to
  /// (e.g. "India's Innings"). Purely cosmetic.
  final String? firstInningsTeamName;

  /// Total time the one-shot progress bar takes before [onComplete]
  /// fires. Pass `null` for an indeterminate looping bar with no
  /// auto-completion (use this when an external condition, not a
  /// timer, should end the splash).
  final Duration? duration;

  /// Called once the one-shot progress bar reaches 100%.
  /// Ignored when [duration] is null.
  final VoidCallback? onComplete;

  const MatchSplashScreen({
    Key? key,
    required this.team1Name,
    required this.team2Name,
    this.firstInningsRuns,
    this.firstInningsWickets,
    this.firstInningsTeamName,
    this.target,
    this.duration = const Duration(seconds: 3),
    this.onComplete,
  }) : super(key: key);

  @override
  State<MatchSplashScreen> createState() => _MatchSplashScreenState();
}

class _MatchSplashScreenState extends State<MatchSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Timer? _navTimer;

  bool get _isIndeterminate => widget.duration == null;
  bool get _isInningsBreak =>
      widget.firstInningsRuns != null && widget.target != null;

  @override
  void initState() {
    super.initState();
    if (_isIndeterminate) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    } else {
      _ctrl = AnimationController(vsync: this, duration: widget.duration);
      _ctrl.forward();
      _navTimer = Timer(widget.duration!, () {
        if (mounted) widget.onComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF05070C),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Split blue/red backdrop, echoing the reference art ──────────
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF001233), Color(0xFF003A8C)],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF2B0000), Color(0xFF8C0000)],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(color: Colors.black.withOpacity(0.45)),

          Positioned(
            top: 60,
            left: 40,
            child: _Glow(color: const Color(0xFF3FD6EE), size: 260),
          ),
          Positioned(
            bottom: 40,
            right: 40,
            child: _Glow(color: const Color(0xFFFF3D3D), size: 260),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Team badges + VS row ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _TeamBlock(
                              name: widget.team1Name,
                              color: const Color(0xFF3FD6EE),
                              alignRight: false,
                            ),
                          ),
                          const _VsBadge(),
                          Expanded(
                            child: _TeamBlock(
                              name: widget.team2Name,
                              color: const Color(0xFFFF6B4A),
                              alignRight: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 44),

                    // ── CRICTRAX TV wordmark ─────────────────────────────
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [Colors.white, Color(0xFFB8C4D9)],
                      ).createShader(rect),
                      child: const Text(
                        'CRICTRAX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const Text(
                      'TV',
                      style: TextStyle(
                        color: Color(0xFF3FD6EE),
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'LIVE CRICKET. REAL ACTION.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Innings-break panel (only shown between innings) ─
                    if (_isInningsBreak) ...[
                      _InningsBreakPanel(
                        teamName: widget.firstInningsTeamName,
                        runs: widget.firstInningsRuns!,
                        wickets: widget.firstInningsWickets ?? 0,
                        target: widget.target!,
                      ),
                      const SizedBox(height: 32),
                    ],

                    // ── Loading bar ────────────────────────────────────────
                    SizedBox(
                      width: 320,
                      child: Column(
                        children: [
                          Text(
                            _isInningsBreak
                                ? 'STARTING 2ND INNINGS…'
                                : 'LOADING LIVE ACTION…',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedBuilder(
                            animation: _ctrl,
                            builder: (_, __) {
                              return Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      height: 8,
                                      color: Colors.white.withOpacity(0.08),
                                      child: _isIndeterminate
                                          ? Align(
                                        alignment: Alignment(
                                          (_ctrl.value * 2) - 1,
                                          0,
                                        ),
                                        child: FractionallySizedBox(
                                          widthFactor: 0.35,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF3FD6EE),
                                                  Color(0xFF0066CC),
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                      0xFF3FD6EE)
                                                      .withOpacity(0.5),
                                                  blurRadius: 10,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                          : FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: _ctrl.value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF3FD6EE),
                                                Color(0xFF0066CC),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                    0xFF3FD6EE)
                                                    .withOpacity(0.5),
                                                blurRadius: 10,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (!_isIndeterminate)
                                    Text(
                                      '${(_ctrl.value * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: Color(0xFF3FD6EE),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                ],
                              );
                            },
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
    );
  }
}

class _TeamBlock extends StatelessWidget {
  final String name;
  final Color color;
  final bool alignRight;
  const _TeamBlock({
    required this.name,
    required this.color,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Column(
      crossAxisAlignment:
      alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(0.35), color.withOpacity(0.08)],
            ),
            border: Border.all(color: color.withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name.toUpperCase(),
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 10),
          const Text(
            'VS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.15)),
        ],
      ),
    );
  }
}

class _InningsBreakPanel extends StatelessWidget {
  final String? teamName;
  final int runs;
  final int wickets;
  final int target;

  const _InningsBreakPanel({
    required this.teamName,
    required this.runs,
    required this.wickets,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Text(
            teamName != null && teamName!.isNotEmpty
                ? '${teamName!.toUpperCase()} — 1ST INNINGS SCORE'
                : '1ST INNINGS SCORE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$runs',
                style: const TextStyle(
                  color: Color(0xFFFF7A45),
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '/$wickets',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flag_rounded, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 8),
                Text(
                  'Target: $target runs',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(0.25), Colors.transparent]),
      ),
    );
  }
}