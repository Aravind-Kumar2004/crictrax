import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/repositories/match_detail_repository.dart';
import '../../live_score/presentation/live_score_screen.dart';
import 'widgets/innings_card_widget.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF050A18);
  static const surface   = Color(0xFF0A1628);
  static const surfaceH  = Color(0xFF0F1E35);
  static const accent    = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live      = Color(0xFFFF3D3D);
  static const upcoming  = Color(0xFF00D4FF);
  static const completed = Color(0xFF8A8FA8);
  static const success   = Color(0xFF00E676);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATCH DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class MatchDetailScreen extends StatelessWidget {
  final String matchId;
  final String tournamentId;
  final String team1Name;
  final String team2Name;
  final String team1Id;
  final String team2Id;
  final int overs;
  final bool isLive;
  final bool isCompleted;

  const MatchDetailScreen({
    Key? key,
    required this.matchId,
    required this.tournamentId,
    required this.team1Name,
    required this.team2Name,
    required this.team1Id,
    required this.team2Id,
    required this.overs,
    required this.isLive,
    required this.isCompleted,
  }) : super(key: key);

  Color get _statusColor {
    if (isLive)      return _C.live;
    if (isCompleted) return _C.completed;
    return _C.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final repo = MatchDetailRepository();

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // ── Ambient glows ──────────────────────────────────────────────────
          Positioned(
            top: -100, left: -60,
            child: _Glow(color: _statusColor, size: 360),
          ),
          Positioned(
            bottom: -80, right: -40,
            child: _Glow(color: _C.accent, size: 260),
          ),

          Row(
            children: [
              // ── Left back rail ─────────────────────────────────────────────
              _BackRail(onBack: () => Navigator.pop(context)),

              // ── Main content ───────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 36, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Match header card
                      _MatchHeaderCard(
                        team1Name: team1Name,
                        team2Name: team2Name,
                        team1Id: team1Id,
                        team2Id: team2Id,
                        overs: overs,
                        isLive: isLive,
                        isCompleted: isCompleted,
                        matchId: matchId,
                        tournamentId: tournamentId,
                      ),

                      const SizedBox(height: 28),

                      // ── Innings section label ──────────────────────────────
                      _InningsSectionLabel(isLive: isLive),

                      const SizedBox(height: 16),

                      // ── Innings stream ─────────────────────────────────────
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: repo.watchInnings(tournamentId, matchId),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return _InningsLoadingState();
                            }

                            final innings = snap.data!.docs;

                            if (innings.isEmpty) {
                              return _InningsEmptyState(
                                team1Name: team1Name,
                                team2Name: team2Name,
                                isLive: isLive,
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: innings.map((inn) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: InningsCardWidget(
                                      innData: inn.data() as Map<String, dynamic>,
                                      inningsNumber: innings.indexOf(inn) + 1,
                                      tournamentId: tournamentId,
                                      matchId: matchId,
                                      inningsId: inn.id,
                                      team1Name: team1Name,
                                      team2Name: team2Name,
                                      repo: repo,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ],
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
// LEFT BACK RAIL
// ═══════════════════════════════════════════════════════════════════════════════
class _BackRail extends StatelessWidget {
  final VoidCallback onBack;
  const _BackRail({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: _C.surface.withOpacity(0.5),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Logo mark
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [_C.accent, _C.accentDim],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: _C.accent.withOpacity(0.3), blurRadius: 12),
              ],
            ),
            child: const Icon(Icons.sports_cricket, color: Colors.white, size: 18),
          ),

          const SizedBox(height: 40),

          // Back button
          Focus(
            child: Builder(builder: (ctx) {
              final focused = Focus.of(ctx).hasFocus;
              return GestureDetector(
                onTap: onBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: focused
                        ? _C.accent.withOpacity(0.15)
                        : Colors.white.withOpacity(0.04),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: focused
                          ? _C.accent.withOpacity(0.5)
                          : Colors.white.withOpacity(0.07),
                    ),
                    boxShadow: focused
                        ? [BoxShadow(color: _C.accent.withOpacity(0.25), blurRadius: 14)]
                        : [],
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: focused ? _C.accent : Colors.white.withOpacity(0.45),
                    size: 20,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),
          Text(
            'BACK',
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),

          const Spacer(),

          // Vertical label
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              'MATCH DETAIL',
              style: TextStyle(
                color: Colors.white.withOpacity(0.08),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATCH HEADER CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _MatchHeaderCard extends StatelessWidget {
  final String team1Name, team2Name, team1Id, team2Id;
  final String matchId, tournamentId;
  final int overs;
  final bool isLive, isCompleted;

  const _MatchHeaderCard({
    required this.team1Name,
    required this.team2Name,
    required this.team1Id,
    required this.team2Id,
    required this.overs,
    required this.isLive,
    required this.isCompleted,
    required this.matchId,
    required this.tournamentId,
  });

  Color get _statusColor {
    if (isLive)      return _C.live;
    if (isCompleted) return _C.completed;
    return _C.upcoming;
  }

  String get _statusLabel {
    if (isLive)      return 'LIVE';
    if (isCompleted) return 'COMPLETED';
    return 'UPCOMING';
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLive
                  ? [
                _C.live.withOpacity(0.07),
                _C.surface.withOpacity(0.9),
              ]
                  : [
                _C.surfaceH.withOpacity(0.75),
                _C.surface.withOpacity(0.9),
              ],
            ),
            border: Border.all(
              color: isLive
                  ? _C.live.withOpacity(0.3)
                  : Colors.white.withOpacity(0.07),
              width: 1,
            ),
            boxShadow: [
              if (isLive)
                BoxShadow(color: _C.live.withOpacity(0.1), blurRadius: 24),
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top shimmer line
              Positioned(
                top: 0, left: 24, right: 24,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        sc.withOpacity(0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: Column(
                  children: [
                    // ── Teams row ──────────────────────────────────────────
                    Row(
                      children: [
                        // Team 1
                        Expanded(child: _TeamDisplay(name: team1Name, align: CrossAxisAlignment.start)),

                        // Center status block
                        _CenterStatusBlock(
                          statusLabel: _statusLabel,
                          statusColor: sc,
                          overs: overs,
                          isLive: isLive,
                        ),

                        // Team 2
                        Expanded(child: _TeamDisplay(name: team2Name, align: CrossAxisAlignment.end)),
                      ],
                    ),

                    // ── Watch Live button (only if live) ──────────────────
                    if (isLive) ...[
                      const SizedBox(height: 22),
                      _WatchLiveButton(
                        matchId: matchId,
                        tournamentId: tournamentId,
                        team1Name: team1Name,
                        team2Name: team2Name,
                        team1Id: team1Id,
                        team2Id: team2Id,
                      ),
                    ],
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

// ─── Team Display ─────────────────────────────────────────────────────────────
class _TeamDisplay extends StatelessWidget {
  final String name;
  final CrossAxisAlignment align;

  const _TeamDisplay({required this.name, required this.align});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isEnd = align == CrossAxisAlignment.end;

    return Column(
      crossAxisAlignment: align,
      children: [
        // Avatar
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _C.accent.withOpacity(0.25),
                _C.accentDim.withOpacity(0.1),
              ],
            ),
            border: Border.all(color: _C.accent.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: _C.accent.withOpacity(0.1), blurRadius: 12),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: _C.accent,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: isEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Center Status Block ──────────────────────────────────────────────────────
class _CenterStatusBlock extends StatelessWidget {
  final String statusLabel;
  final Color statusColor;
  final int overs;
  final bool isLive;

  const _CenterStatusBlock({
    required this.statusLabel,
    required this.statusColor,
    required this.overs,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(isLive ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.4)),
              boxShadow: isLive
                  ? [BoxShadow(color: statusColor.withOpacity(0.2), blurRadius: 12)]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLive) ...[
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                      boxShadow: [
                        BoxShadow(color: statusColor.withOpacity(0.8), blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // VS
          Text(
            'VS',
            style: TextStyle(
              color: Colors.white.withOpacity(0.15),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),

          const SizedBox(height: 12),

          // Overs chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_cricket,
                    color: Colors.white.withOpacity(0.25), size: 12),
                const SizedBox(width: 5),
                Text(
                  '$overs overs',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

// ─── Watch Live Button ────────────────────────────────────────────────────────
class _WatchLiveButton extends StatelessWidget {
  final String matchId, tournamentId, team1Name, team2Name, team1Id, team2Id;

  const _WatchLiveButton({
    required this.matchId,
    required this.tournamentId,
    required this.team1Name,
    required this.team2Name,
    required this.team1Id,
    required this.team2Id,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveScoreScreen(
                matchId: matchId,
                tournamentId: tournamentId,
                team1Name: team1Name,
                team2Name: team2Name,
                team1Id: team1Id,
                team2Id: team2Id,
              ),
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 36),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: focused
                    ? [const Color(0xFFFF5252), const Color(0xFFCC0000)]
                    : [_C.live.withOpacity(0.85), const Color(0xFFCC1111)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: focused
                    ? _C.live
                    : _C.live.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: _C.live.withOpacity(focused ? 0.45 : 0.2),
                  blurRadius: focused ? 20 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Watch Live Score',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withOpacity(0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INNINGS SECTION LABEL
// ═══════════════════════════════════════════════════════════════════════════════
class _InningsSectionLabel extends StatelessWidget {
  final bool isLive;
  const _InningsSectionLabel({required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _C.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _C.accent.withOpacity(0.2)),
          ),
          child: Icon(Icons.bar_chart_rounded, color: _C.accent, size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          'Innings Scorecard',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 10),
        if (isLive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _C.live.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _C.live.withOpacity(0.3)),
            ),
            child: Text(
              'UPDATING',
              style: TextStyle(
                color: _C.live,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.accent.withOpacity(0.25), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INNINGS LOADING STATE
// ═══════════════════════════════════════════════════════════════════════════════
class _InningsLoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [_C.accent, _C.accentDim],
              ),
              boxShadow: [
                BoxShadow(color: _C.accent.withOpacity(0.35), blurRadius: 20),
              ],
            ),
            child: const Icon(Icons.sports_cricket, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                backgroundColor: Color(0xFF0F1E35),
                valueColor: AlwaysStoppedAnimation<Color>(_C.accent),
                minHeight: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading scorecard…',
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INNINGS EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════════
class _InningsEmptyState extends StatelessWidget {
  final String team1Name, team2Name;
  final bool isLive;

  const _InningsEmptyState({
    required this.team1Name,
    required this.team2Name,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Teams display
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniTeamBadge(name: team1Name),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'vs',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              _MiniTeamBadge(name: team2Name),
            ],
          ),

          const SizedBox(height: 28),

          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.accent.withOpacity(0.05),
              border: Border.all(color: _C.accent.withOpacity(0.12)),
            ),
            child: Icon(Icons.sports_cricket,
                color: _C.accent.withOpacity(0.25), size: 28),
          ),

          const SizedBox(height: 18),

          Text(
            isLive ? 'Match in Progress' : 'Match Not Started Yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLive
                ? 'Innings data will appear once scoring begins.'
                : 'Scorecard will be available when the match starts.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.22),
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MiniTeamBadge extends StatelessWidget {
  final String name;
  const _MiniTeamBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Column(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                _C.accent.withOpacity(0.2),
                _C.accentDim.withOpacity(0.08),
              ],
            ),
            border: Border.all(color: _C.accent.withOpacity(0.25)),
          ),
          child: Center(
            child: Text(initial,
                style: const TextStyle(
                  color: _C.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Ambient Glow ─────────────────────────────────────────────────────────────
class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.07),
            color.withOpacity(0.02),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}