import 'package:flutter/material.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const surface   = Color(0xFF0A1628);
  static const surfaceH  = Color(0xFF0F1E35);
  static const accent    = Color(0xFF00D4FF);
  static const live      = Color(0xFFFF3D3D);
  static const upcoming  = Color(0xFF00D4FF);
  static const completed = Color(0xFF8A8FA8);
  static const fixtures  = Color(0xFF8E5CFF);
}

class _StatCardData {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  const _StatCardData(this.icon, this.value, this.label, this.color);
}

// ═══════════════════════════════════════════════════════════════════════════
// STATISTICS SECTION
// All five numbers are derived purely from match/team data already loaded by
// TournamentDetailScreen (teams count is the number of unique team IDs seen
// across the already-fetched matches — no new Firestore reads).
//
// These cards are purely informational (no onTap anywhere in this widget or
// its parent), so they are intentionally excluded from D-pad focus below —
// a focusable card with no action would be a dead end for remote navigation.
// ═══════════════════════════════════════════════════════════════════════════
class StatisticsSection extends StatelessWidget {
  final int teamsCount;
  final int matchesCount;
  final int liveCount;
  final int upcomingCount;
  final int completedCount;

  const StatisticsSection({
    Key? key,
    required this.teamsCount,
    required this.matchesCount,
    required this.liveCount,
    required this.upcomingCount,
    required this.completedCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCardData(Icons.groups_rounded, teamsCount, 'Teams', _C.fixtures),
      _StatCardData(Icons.sports_cricket_rounded, matchesCount, 'Matches', _C.accent),
      _StatCardData(Icons.sensors_rounded, liveCount, 'Live', _C.live),
      _StatCardData(Icons.schedule_rounded, upcomingCount, 'Upcoming', _C.upcoming),
      _StatCardData(Icons.check_circle_rounded, completedCount, 'Completed', _C.completed),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: ExcludeFocus(
        child: Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: _StatCard(data: cards[i])),
              if (i != cards.length - 1) const SizedBox(width: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  final _StatCardData data;
  const _StatCard({required this.data});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.data.color;
    return FocusableActionDetector(
      // Not clickable — see the note on StatisticsSection above.
      // (ExcludeFocus on the parent already keeps this out of D-pad
      // traversal; descendantsAreFocusable just belt-and-braces it.)
      descendantsAreFocusable: false,
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      child: AnimatedScale(
        scale: _focused ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.withOpacity(_focused ? 0.22 : 0.10),
                _C.surfaceH.withOpacity(0.85),
              ],
            ),
            border: Border.all(
              color: _focused ? c.withOpacity(0.7) : Colors.white.withOpacity(0.07),
              width: _focused ? 1.6 : 1,
            ),
            boxShadow: _focused ? [BoxShadow(color: c.withOpacity(0.3), blurRadius: 20)] : [],
          ),
          child: Column(
            children: [
              Icon(widget.data.icon, color: c, size: 26),
              const SizedBox(height: 12),
              Text(
                '${widget.data.value}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.data.label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}