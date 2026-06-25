import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/models/match_model.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFF050A18);
  static const surface  = Color(0xFF0A1628);
  static const surfaceH = Color(0xFF0F1E35);
  static const accent   = Color(0xFF00D4FF);
  static const accentDim= Color(0xFF0066CC);
  static const live     = Color(0xFFFF3D3D);
  static const upcoming = Color(0xFF00D4FF);
  static const completed= Color(0xFF8A8FA8);
  static const fixtures = Color(0xFF8E5CFF);
  static const gold     = Color(0xFFFFD700);
  static const goldDim  = Color(0xFFCC8800);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIXTURES BRACKET WIDGET
// ═══════════════════════════════════════════════════════════════════════════════
class FixturesBracketWidget extends StatelessWidget {
  final List<TournamentMatchModel> matches;
  final String tournamentName;
  final String tournamentFormat;
  final void Function(TournamentMatchModel) onMatchTap;

  const FixturesBracketWidget({
    Key? key,
    required this.matches,
    required this.tournamentName,
    required this.tournamentFormat,
    required this.onMatchTap,
  }) : super(key: key);

  bool get _isLeagueFormat =>
      tournamentFormat.toLowerCase().contains('league');

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return _buildEmptyState();
    }
    return _isLeagueFormat ? _buildLeagueView() : _buildBracketView();
  }

  // ── Empty State ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.fixtures.withOpacity(0.05),
              border: Border.all(color: _C.fixtures.withOpacity(0.15)),
            ),
            child: Icon(Icons.account_tree_rounded,
                color: _C.fixtures.withOpacity(0.3), size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'No Fixtures Yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Matches will appear here once scheduled.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.22),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEAGUE VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLeagueView() {
    final sorted = [...matches]..sort((a, b) {
      final da = a.matchDate ?? '';
      final db = b.matchDate ?? '';
      return da.compareTo(db);
    });

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          _FixturesHeader(
            icon: Icons.format_list_bulleted_rounded,
            title: 'League Fixtures',
            subtitle: '${sorted.length} matches scheduled',
            color: _C.fixtures,
          ),
          const SizedBox(height: 28),

          // Stats summary bar
          _StatsSummaryBar(matches: sorted),
          const SizedBox(height: 28),

          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.05,
            ),
            itemCount: sorted.length,
            itemBuilder: (context, i) => _FixtureCard(
              match: sorted[i],
              index: i,
              onTap: () => onMatchTap(sorted[i]),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BRACKET VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBracketView() {
    final rounds = _groupIntoRounds(matches);

    if (rounds.isEmpty) {
      return Center(
        child: Text(
          'Unable to build fixtures',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 18),
        ),
      );
    }

    const cardHeight = 158.0;
    final maxMatchesInAnyRound =
    rounds.map((r) => r.length).fold(1, (a, b) => a > b ? a : b);
    final columnHeight = (maxMatchesInAnyRound * cardHeight).clamp(300.0, 1400.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          _FixturesHeader(
            icon: Icons.account_tree_rounded,
            title: 'Tournament Bracket',
            subtitle: '${rounds.length} rounds · ${matches.length} matches',
            color: _C.fixtures,
          ),
          const SizedBox(height: 28),

          // Stats summary bar
          _StatsSummaryBar(matches: matches),
          const SizedBox(height: 32),

          // Bracket horizontal scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              height: columnHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(rounds.length, (i) {
                  final isFinal = i == rounds.length - 1;
                  final label = _roundLabel(i, rounds.length);
                  return _RoundColumn(
                    roundLabel: label,
                    roundIndex: i,
                    totalRounds: rounds.length,
                    matches: rounds[i],
                    isFinal: isFinal,
                    onMatchTap: onMatchTap,
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Grouping logic (UNCHANGED) ─────────────────────────────────────────────
  List<List<TournamentMatchModel>> _groupIntoRounds(
      List<TournamentMatchModel> matches) {
    final sorted = [...matches]..sort((a, b) {
      final da = a.matchDate ?? '';
      final db = b.matchDate ?? '';
      return da.compareTo(db);
    });

    if (sorted.isEmpty) return [];
    if (sorted.length == 1) return [sorted];

    final isBracketSized = _looksLikeBracket(sorted.length);

    if (!isBracketSized) {
      const chunkSize = 4;
      final rounds = <List<TournamentMatchModel>>[];
      for (var i = 0; i < sorted.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, sorted.length);
        rounds.add(sorted.sublist(i, end));
      }
      return rounds;
    }

    final rounds = <List<TournamentMatchModel>>[];
    var remaining = sorted;
    var roundSize = (sorted.length / 2).ceil();

    while (remaining.isNotEmpty) {
      final take = roundSize.clamp(1, remaining.length);
      rounds.add(remaining.sublist(0, take));
      remaining = remaining.sublist(take);
      roundSize = (roundSize / 2).ceil();
      if (roundSize < 1) roundSize = 1;
    }
    return rounds;
  }

  bool _looksLikeBracket(int total) {
    const validSizes = [1, 2, 3, 4, 7, 8, 15, 16, 31, 32];
    return validSizes.contains(total);
  }

  String _roundLabel(int index, int totalRounds) {
    if (totalRounds == 1) return 'Matches';
    final remaining = totalRounds - index;
    if (remaining == 1) return 'Final';
    if (remaining == 2) return 'Semi Finals';
    if (remaining == 3) return 'Quarter Finals';
    return 'Round ${index + 1}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED HEADER
// ═══════════════════════════════════════════════════════════════════════════════
class _FixturesHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FixturesHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.12), blurRadius: 16),
            ],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.35), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATS SUMMARY BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _StatsSummaryBar extends StatelessWidget {
  final List<TournamentMatchModel> matches;

  const _StatsSummaryBar({required this.matches});

  @override
  Widget build(BuildContext context) {
    final liveCount = matches.where((m) => m.isLive && !m.isCompleted).length;
    final completedCount = matches.where((m) => m.isCompleted).length;
    final upcomingCount =
        matches.where((m) => !m.isLive && !m.isCompleted).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          _StatItem(
            label: 'Live',
            value: '$liveCount',
            color: _C.live,
            icon: Icons.radio_button_checked,
          ),
          _VertDivider(),
          _StatItem(
            label: 'Upcoming',
            value: '$upcomingCount',
            color: _C.upcoming,
            icon: Icons.schedule_rounded,
          ),
          _VertDivider(),
          _StatItem(
            label: 'Completed',
            value: '$completedCount',
            color: _C.completed,
            icon: Icons.check_circle_rounded,
          ),
          _VertDivider(),
          _StatItem(
            label: 'Total',
            value: '${matches.length}',
            color: _C.fixtures,
            icon: Icons.sports_cricket,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color.withOpacity(0.7), size: 13),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withOpacity(0.07),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROUND COLUMN (Bracket)
// ═══════════════════════════════════════════════════════════════════════════════
class _RoundColumn extends StatelessWidget {
  final String roundLabel;
  final int roundIndex;
  final int totalRounds;
  final List<TournamentMatchModel> matches;
  final bool isFinal;
  final void Function(TournamentMatchModel) onMatchTap;

  const _RoundColumn({
    required this.roundLabel,
    required this.roundIndex,
    required this.totalRounds,
    required this.matches,
    required this.isFinal,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Round label badge
            _RoundBadge(label: roundLabel, isFinal: isFinal),
            const SizedBox(height: 20),
            // Match cards
            ...matches.map((m) => _FixtureCard(
              match: m,
              index: 0,
              onTap: () => onMatchTap(m),
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Round Label Badge ────────────────────────────────────────────────────────
class _RoundBadge extends StatelessWidget {
  final String label;
  final bool isFinal;

  const _RoundBadge({required this.label, required this.isFinal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: isFinal
            ? const LinearGradient(
          colors: [_C.gold, _C.goldDim],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : LinearGradient(
          colors: [
            _C.fixtures.withOpacity(0.2),
            _C.fixtures.withOpacity(0.08),
          ],
        ),
        border: Border.all(
          color: isFinal
              ? _C.gold.withOpacity(0.5)
              : _C.fixtures.withOpacity(0.3),
        ),
        boxShadow: isFinal
            ? [BoxShadow(color: _C.gold.withOpacity(0.2), blurRadius: 12)]
            : [BoxShadow(color: _C.fixtures.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFinal ? Icons.emoji_events_rounded : Icons.account_tree_rounded,
            color: isFinal ? Colors.black87 : _C.fixtures,
            size: 13,
          ),
          const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isFinal ? Colors.black87 : _C.fixtures,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIXTURE CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _FixtureCard extends StatelessWidget {
  final TournamentMatchModel match;
  final int index;
  final VoidCallback onTap;

  const _FixtureCard({
    required this.match,
    required this.index,
    required this.onTap,
  });

  Color get _statusColor {
    if (match.isCompleted)                return _C.completed;
    if (!match.isCompleted && match.isLive) return _C.live;
    return _C.upcoming;
  }

  String get _statusLabel {
    if (match.isCompleted)                return 'DONE';
    if (!match.isCompleted && match.isLive) return 'LIVE';
    return 'SOON';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = match.isCompleted;
    final isLive = !isCompleted && match.isLive;
    final sc = _statusColor;

    return Focus(
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.identity()
                ..translate(0.0, focused ? -2.0 : 0.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: focused
                      ? sc
                      : isLive
                      ? sc.withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
                  width: focused ? 1.5 : 1,
                ),
                boxShadow: [
                  if (focused)
                    BoxShadow(
                      color: sc.withOpacity(0.3),
                      blurRadius: 18,
                      spreadRadius: 0,
                    ),
                  if (isLive && !focused)
                    BoxShadow(
                      color: _C.live.withOpacity(0.08),
                      blurRadius: 10,
                    ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
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
                    ),
                    child: Stack(
                      children: [
                        // Top accent line
                        Positioned(
                          top: 0, left: 16, right: 16,
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withOpacity(focused ? 0.07 : 0.03),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ── Status + overs row ──────────────────────
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _CompactStatusBadge(
                                    label: _statusLabel,
                                    color: sc,
                                    isLive: isLive,
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.sports_cricket,
                                          color: Colors.white.withOpacity(0.2),
                                          size: 10),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${match.overs} ov',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // ── Team 1 ──────────────────────────────────
                              _CardTeamRow(name: match.teamId1Name, color: sc),

                              // ── VS divider ───────────────────────────────
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 30),
                                    Text(
                                      'vs',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.2),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.06),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ── Team 2 ──────────────────────────────────
                              _CardTeamRow(name: match.teamId2Name, color: sc),
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
      }),
    );
  }
}

// ─── Compact Status Badge (for FixtureCard) ────────────────────────────────────
class _CompactStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLive;

  const _CompactStatusBadge({
    required this.label,
    required this.color,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isLive ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: isLive
            ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 6)]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 5, height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.8), blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card Team Row ────────────────────────────────────────────────────────────
class _CardTeamRow extends StatelessWidget {
  final String name;
  final Color color;

  const _CardTeamRow({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.25),
                color.withOpacity(0.06),
              ],
            ),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name.isEmpty ? 'TBD' : name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}