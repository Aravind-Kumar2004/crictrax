import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/models/match_model.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF020810);
  static const bgCard    = Color(0xFF080F1F);
  static const surface   = Color(0xFF0A1628);
  static const surfaceH  = Color(0xFF0F1E35);
  static const surfaceB  = Color(0xFF131F33);
  static const accent    = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live      = Color(0xFFFF3D3D);
  static const upcoming  = Color(0xFF00D4FF);
  static const completed = Color(0xFF8A8FA8);
  static const fixtures  = Color(0xFF8E5CFF);
  static const gold      = Color(0xFFFFD700);
  static const goldDim   = Color(0xFFCC8800);
  static const success   = Color(0xFF00E676);
  static const teal      = Color(0xFF00F5D4);
}

// ─── Format Detection ─────────────────────────────────────────────────────────
enum _TournamentFormat { league, knockout, leagueKnockout, unknown }

_TournamentFormat _detectFormat(String raw) {
  final f = raw.toLowerCase();
  final hasLeague   = f.contains('league');
  final hasKnockout = f.contains('knockout') ||
      f.contains('elimination') ||
      f.contains('cup');
  if (hasLeague && hasKnockout) return _TournamentFormat.leagueKnockout;
  if (hasLeague)                return _TournamentFormat.league;
  if (hasKnockout)              return _TournamentFormat.knockout;
  return _TournamentFormat.unknown;
}

// ─── Robust DateTime Parser ───────────────────────────────────────────────────
// Handles ISO-8601, Firestore Timestamp toString(), and raw strings.
class _DateTimeParts {
  final String date;
  final String time;
  final DateTime? raw;
  const _DateTimeParts({required this.date, required this.time, this.raw});
}

_DateTimeParts _parseMatchDate(dynamic value) {
  if (value == null) return const _DateTimeParts(date: '—', time: '—');

  DateTime? dt;

  // If it's already a DateTime (passed through model conversion)
  if (value is DateTime) {
    dt = value;
  }

  // Try ISO-8601 or standard parse
  if (dt == null && value is String) {
    final s = value.trim();
    if (s.isEmpty) return const _DateTimeParts(date: '—', time: '—');

    // Firestore Timestamp.toString() → "Timestamp(seconds=1718000000, nanoseconds=0)"
    final tsMatch = RegExp(r'seconds=(\d+)').firstMatch(s);
    if (tsMatch != null) {
      final seconds = int.tryParse(tsMatch.group(1) ?? '');
      if (seconds != null) {
        dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }

    // Standard ISO / DateTime.parse
    if (dt == null) {
      try { dt = DateTime.parse(s); } catch (_) {}
    }

    // If still null, show raw string as date
    if (dt == null) {
      return _DateTimeParts(date: s, time: '—');
    }
  }

  if (dt == null) return _DateTimeParts(date: value.toString(), time: '—');

  const months = ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];
  final dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  final timeStr =
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  return _DateTimeParts(date: dateStr, time: timeStr, raw: dt);
}

// ─── Sort Helper ──────────────────────────────────────────────────────────────
// Primary: parsed DateTime ascending. Secondary: original list index (stable).
List<TournamentMatchModel> _sortMatches(List<TournamentMatchModel> src) {
  final indexed = src.asMap().entries.toList();
  indexed.sort((a, b) {
    final da = _parseMatchDate(a.value.matchDate).raw;
    final db = _parseMatchDate(b.value.matchDate).raw;
    if (da != null && db != null) {
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
    } else if (da != null) return -1;
    else if (db != null) return  1;
    // Fallback: string compare
    final sa = a.value.matchDate?.toString() ?? '';
    final sb = b.value.matchDate?.toString() ?? '';
    final sc = sa.compareTo(sb);
    if (sc != 0) return sc;
    // Stable: original index
    return a.key.compareTo(b.key);
  });
  return indexed.map((e) => e.value).toList();
}

// ─── Venue Helper ─────────────────────────────────────────────────────────────
// Safely reads a venue/ground field from the model using reflection-free duck
// typing. Extend this list if your model uses a different field name.
String _venueOf(TournamentMatchModel m) {
  try {
    // Try common field names via dynamic access
    final dyn = m as dynamic;
    for (final key in ['venue', 'ground', 'groundName', 'location']) {
      try {
        final v = dyn[key] as String?;   // map-like access
        if (v != null && v.isNotEmpty) return v;
      } catch (_) {}
      try {
        // Property access via noSuchMethod-backed proxy isn't possible in
        // Dart without code-gen, so we attempt the most common names directly.
      } catch (_) {}
    }
  } catch (_) {}
  // Direct property attempts (add more if your model differs)
  try { final v = (m as dynamic).venue as String?;     if (v != null && v.isNotEmpty) return v; } catch (_) {}
  try { final v = (m as dynamic).ground as String?;    if (v != null && v.isNotEmpty) return v; } catch (_) {}
  try { final v = (m as dynamic).groundName as String?;if (v != null && v.isNotEmpty) return v; } catch (_) {}
  try { final v = (m as dynamic).location as String?;  if (v != null && v.isNotEmpty) return v; } catch (_) {}
  return '';
}

// ─── Stage Helper ─────────────────────────────────────────────────────────────
// Returns 'league', 'knockout', or '' if unknown/absent.
String _stageOf(TournamentMatchModel m) {
  try { final v = (m as dynamic).stage as String?; if (v != null) return v.toLowerCase().trim(); } catch (_) {}
  try { final v = (m as dynamic).round as String?; if (v != null) return v.toLowerCase().trim(); } catch (_) {}
  try { final v = (m as dynamic).matchStage as String?; if (v != null) return v.toLowerCase().trim(); } catch (_) {}
  return '';
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC: FIXTURES BRACKET WIDGET
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

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return _EmptyFixturesState();

    switch (_detectFormat(tournamentFormat)) {
      case _TournamentFormat.league:
        return _LeagueFixturesBoard(
          matches: matches,
          onMatchTap: onMatchTap,
        );

      case _TournamentFormat.knockout:
      case _TournamentFormat.unknown:
        return _KnockoutBracketView(
          matches: matches,
          onMatchTap: onMatchTap,
        );

      case _TournamentFormat.leagueKnockout:
        return _LeagueKnockoutView(
          matches: matches,
          onMatchTap: onMatchTap,
        );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyFixturesState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.fixtures.withOpacity(0.05),
              border: Border.all(color: _C.fixtures.withOpacity(0.15), width: 1.5),
            ),
            child: Icon(Icons.account_tree_rounded,
                color: _C.fixtures.withOpacity(0.3), size: 38),
          ),
          const SizedBox(height: 22),
          Text(
            'No Fixtures Yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Matches will appear here once they are scheduled.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.22),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED: HEADER COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.22)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 16)],
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                )),
            const SizedBox(height: 3),
            Text(subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.28),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                )),
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
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED: STATS SUMMARY BAR
// ══════════════════════════════════════════════════════════════════════════════
class _StatsSummaryBar extends StatelessWidget {
  final List<TournamentMatchModel> matches;

  const _StatsSummaryBar({required this.matches});

  @override
  Widget build(BuildContext context) {
    final live      = matches.where((m) => m.isLive && !m.isCompleted).length;
    final done      = matches.where((m) => m.isCompleted).length;
    final upcoming  = matches.where((m) => !m.isLive && !m.isCompleted).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          _StatItem(label: 'LIVE',      value: live,           color: _C.live,      icon: Icons.sensors_rounded),
          _VertDivider(),
          _StatItem(label: 'UPCOMING',  value: upcoming,       color: _C.upcoming,  icon: Icons.schedule_rounded),
          _VertDivider(),
          _StatItem(label: 'COMPLETED', value: done,           color: _C.completed, icon: Icons.check_circle_rounded),
          _VertDivider(),
          _StatItem(label: 'TOTAL',     value: matches.length, color: _C.fixtures,  icon: Icons.sports_cricket),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label, required this.value,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color.withOpacity(0.65), size: 12),
          const SizedBox(width: 7),
          Text('$value',
              style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 22, color: Colors.white.withOpacity(0.07));
}

// ══════════════════════════════════════════════════════════════════════════════
// LEAGUE FIXTURES BOARD
// TV-friendly schedule table: Match N | Teams | Date | Time | Venue | Status
// No bracket rounds. No Quarter Finals / Semi Finals / Final labels.
// ══════════════════════════════════════════════════════════════════════════════
class _LeagueFixturesBoard extends StatelessWidget {
  final List<TournamentMatchModel> matches;
  final void Function(TournamentMatchModel) onMatchTap;

  const _LeagueFixturesBoard({
    required this.matches,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = _sortMatches(matches);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.format_list_bulleted_rounded,
            title: 'League Fixtures',
            subtitle: '${sorted.length} matches scheduled',
            color: _C.fixtures,
          ),
          const SizedBox(height: 24),
          _StatsSummaryBar(matches: sorted),
          const SizedBox(height: 28),
          _FixturesTable(
            matches: sorted,
            onMatchTap: onMatchTap,
            startIndex: 1,
          ),
        ],
      ),
    );
  }
}

// ─── Shared Fixtures Table (used by both League and League+Knockout views) ────
class _FixturesTable extends StatelessWidget {
  final List<TournamentMatchModel> matches;
  final void Function(TournamentMatchModel) onMatchTap;
  final int startIndex;

  const _FixturesTable({
    required this.matches,
    required this.onMatchTap,
    this.startIndex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            _BoardColumnHeader(),
            Container(height: 1, color: Colors.white.withOpacity(0.06)),
            ...matches.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              return _LeagueMatchRow(
                matchNumber: startIndex + i,
                match: m,
                isLast: i == matches.length - 1,
                onTap: () => onMatchTap(m),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Board Column Header ──────────────────────────────────────────────────────
class _BoardColumnHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _C.fixtures.withOpacity(0.12),
            _C.fixtures.withOpacity(0.04),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          // Match No column
          SizedBox(
            width: 80,
            child: Text('MATCH', style: _headerStyle),
          ),
          const SizedBox(width: 12),
          // Teams column (flexible)
          Expanded(
            flex: 4,
            child: Text('TEAMS', style: _headerStyle),
          ),
          // Date column
          SizedBox(
            width: 110,
            child: Text('DATE', style: _headerStyle),
          ),
          // Time column
          SizedBox(
            width: 72,
            child: Text('TIME', style: _headerStyle),
          ),
          // Venue column
          SizedBox(
            width: 140,
            child: Text('VENUE', style: _headerStyle),
          ),
          // Status column
          SizedBox(
            width: 96,
            child: Text('STATUS', style: _headerStyle, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
    color: _C.fixtures.withOpacity(0.7),
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );
}

// ─── League Match Row ─────────────────────────────────────────────────────────
class _LeagueMatchRow extends StatefulWidget {
  final int matchNumber;
  final TournamentMatchModel match;
  final bool isLast;
  final VoidCallback onTap;

  const _LeagueMatchRow({
    required this.matchNumber,
    required this.match,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_LeagueMatchRow> createState() => _LeagueMatchRowState();
}

class _LeagueMatchRowState extends State<_LeagueMatchRow> {
  bool _focused = false;

  Color get _statusColor {
    if (widget.match.isCompleted)                      return _C.completed;
    if (widget.match.isLive && !widget.match.isCompleted) return _C.live;
    return _C.upcoming;
  }

  String get _statusLabel {
    if (widget.match.isCompleted)                      return 'DONE';
    if (widget.match.isLive && !widget.match.isCompleted) return 'LIVE';
    return 'UPCOMING';
  }

  @override
  Widget build(BuildContext context) {
    final sc   = _statusColor;
    final dt   = _parseMatchDate(widget.match.matchDate);
    final isLv = widget.match.isLive && !widget.match.isCompleted;
    final venue = _venueOf(widget.match);

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..scale(_focused ? 1.03 : 1.0, _focused ? 1.03 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: _focused
                ? sc.withOpacity(0.1)
                : isLv
                ? _C.live.withOpacity(0.04)
                : Colors.transparent,
            border: Border.all(
              color: _focused ? sc.withOpacity(0.55) : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: widget.isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(17))
                : BorderRadius.zero,
            boxShadow: _focused
                ? [
              BoxShadow(color: sc.withOpacity(0.35), blurRadius: 24),
              BoxShadow(color: sc.withOpacity(0.15), blurRadius: 8),
            ]
                : [],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Match Number ────────────────────────────────────
                    SizedBox(
                      width: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Match',
                            style: TextStyle(
                              color: sc.withOpacity(0.5),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.matchNumber}',
                            style: TextStyle(
                              color: sc,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ── Teams ───────────────────────────────────────────
                    Expanded(
                      flex: 4,
                      child: _TeamsCell(
                        team1: widget.match.teamId1Name,
                        team2: widget.match.teamId2Name,
                        color: sc,
                        focused: _focused,
                      ),
                    ),

                    // ── Date ────────────────────────────────────────────
                    SizedBox(
                      width: 110,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              color: Colors.white.withOpacity(0.18), size: 10),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              dt.date,
                              style: TextStyle(
                                color: Colors.white.withOpacity(_focused ? 0.9 : 0.55),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Time ────────────────────────────────────────────
                    SizedBox(
                      width: 72,
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              color: Colors.white.withOpacity(0.18), size: 10),
                          const SizedBox(width: 4),
                          Text(
                            dt.time,
                            style: TextStyle(
                              color: Colors.white.withOpacity(_focused ? 0.9 : 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Venue ───────────────────────────────────────────
                    SizedBox(
                      width: 140,
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              color: Colors.white.withOpacity(0.18), size: 10),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              venue.isEmpty ? '—' : venue,
                              style: TextStyle(
                                color: Colors.white.withOpacity(
                                    venue.isEmpty ? 0.2 : (_focused ? 0.85 : 0.5)),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                fontStyle: venue.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Status Badge ─────────────────────────────────────
                    SizedBox(
                      width: 96,
                      child: Center(
                        child: _LeagueStatusBadge(
                          label: _statusLabel,
                          color: sc,
                          isLive: isLv,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!widget.isLast)
                Container(
                  margin: const EdgeInsets.only(left: 92),
                  height: 1,
                  color: Colors.white.withOpacity(0.04),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Teams Cell ───────────────────────────────────────────────────────────────
class _TeamsCell extends StatelessWidget {
  final String team1, team2;
  final Color color;
  final bool focused;

  const _TeamsCell({
    required this.team1, required this.team2,
    required this.color, required this.focused,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MiniAvatar(name: team1, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team1.isEmpty ? 'TBD' : team1,
                style: TextStyle(
                  color: Colors.white.withOpacity(focused ? 1.0 : 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(
                      'vs',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.18),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      height: 1, width: 24,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ],
                ),
              ),
              Text(
                team2.isEmpty ? 'TBD' : team2,
                style: TextStyle(
                  color: Colors.white.withOpacity(focused ? 1.0 : 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String name;
  final Color color;

  const _MiniAvatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 30, height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(initial,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

// ─── League Status Badge ──────────────────────────────────────────────────────
class _LeagueStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLive;

  const _LeagueStatusBadge({
    required this.label, required this.color, required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(isLive ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: isLive
            ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8)]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            _LiveDot(color: color),
            const SizedBox(width: 5),
          ] else ...[
            Icon(
              label == 'DONE'
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
              color: color,
              size: 9,
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

// ── Animated live dot ─────────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  final Color color;
  const _LiveDot({required this.color});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(0.5 + 0.5 * _anim.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.7 * _anim.value),
              blurRadius: 5,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// KNOCKOUT BRACKET VIEW
// Unchanged grouping logic. Uses StatefulWidget rows for proper TV focus+scale.
// ══════════════════════════════════════════════════════════════════════════════
class _KnockoutBracketView extends StatelessWidget {
  final List<TournamentMatchModel> matches;
  final void Function(TournamentMatchModel) onMatchTap;

  const _KnockoutBracketView({
    required this.matches,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final rounds = _groupIntoRounds(matches);

    if (rounds.isEmpty) {
      return Center(
        child: Text('Unable to build bracket',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 18)),
      );
    }

    const cardHeight = 162.0;
    final maxMatches = rounds.map((r) => r.length).fold(1, (a, b) => a > b ? a : b);
    final colHeight  = (maxMatches * cardHeight).clamp(300.0, 1400.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.account_tree_rounded,
            title: 'Tournament Bracket',
            subtitle: '${rounds.length} rounds · ${matches.length} matches',
            color: _C.fixtures,
          ),
          const SizedBox(height: 24),
          _StatsSummaryBar(matches: matches),
          const SizedBox(height: 32),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              height: colHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(rounds.length, (i) {
                  final isFinal = i == rounds.length - 1;
                  final label   = _roundLabel(i, rounds.length);
                  return _RoundColumn(
                    roundLabel: label,
                    matches:    rounds[i],
                    isFinal:    isFinal,
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

  List<List<TournamentMatchModel>> _groupIntoRounds(List<TournamentMatchModel> all) {
    final sorted = _sortMatches(all);
    if (sorted.isEmpty) return [];
    if (sorted.length == 1) return [sorted];

    if (!_looksLikeBracket(sorted.length)) {
      const chunkSize = 4;
      final rounds = <List<TournamentMatchModel>>[];
      for (var i = 0; i < sorted.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, sorted.length);
        rounds.add(sorted.sublist(i, end));
      }
      return rounds;
    }

    final rounds  = <List<TournamentMatchModel>>[];
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

// ─── Round Column ─────────────────────────────────────────────────────────────
class _RoundColumn extends StatelessWidget {
  final String roundLabel;
  final List<TournamentMatchModel> matches;
  final bool isFinal;
  final void Function(TournamentMatchModel) onMatchTap;

  const _RoundColumn({
    required this.roundLabel,
    required this.matches,
    required this.isFinal,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 28),
      child: SizedBox(
        width: 244,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundBadge(label: roundLabel, isFinal: isFinal),
            const SizedBox(height: 18),
            ...matches.map((m) => _FixtureCard(
              match: m,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: isFinal
            ? const LinearGradient(
          colors: [_C.gold, _C.goldDim],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : LinearGradient(colors: [
          _C.fixtures.withOpacity(0.2),
          _C.fixtures.withOpacity(0.08),
        ]),
        border: Border.all(
          color: isFinal
              ? _C.gold.withOpacity(0.5)
              : _C.fixtures.withOpacity(0.3),
        ),
        boxShadow: isFinal
            ? [BoxShadow(color: _C.gold.withOpacity(0.22), blurRadius: 14)]
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

// ─── Fixture Card (bracket columns) ──────────────────────────────────────────
class _FixtureCard extends StatefulWidget {
  final TournamentMatchModel match;
  final VoidCallback onTap;

  const _FixtureCard({required this.match, required this.onTap});

  @override
  State<_FixtureCard> createState() => _FixtureCardState();
}

class _FixtureCardState extends State<_FixtureCard> {
  bool _focused = false;

  Color get _statusColor {
    if (widget.match.isCompleted)                      return _C.completed;
    if (widget.match.isLive && !widget.match.isCompleted) return _C.live;
    return _C.upcoming;
  }

  String get _statusLabel {
    if (widget.match.isCompleted)                      return 'DONE';
    if (widget.match.isLive && !widget.match.isCompleted) return 'LIVE';
    return 'SOON';
  }

  @override
  Widget build(BuildContext context) {
    final isLv = widget.match.isLive && !widget.match.isCompleted;
    final sc   = _statusColor;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translate(0.0, _focused ? -4.0 : 0.0)
              ..scale(_focused ? 1.04 : 1.0, _focused ? 1.04 : 1.0, 1.0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focused
                    ? sc
                    : isLv
                    ? sc.withOpacity(0.4)
                    : Colors.white.withOpacity(0.08),
                width: _focused ? 1.5 : 1,
              ),
              boxShadow: [
                if (_focused) ...[
                  BoxShadow(color: sc.withOpacity(0.4), blurRadius: 28),
                  BoxShadow(color: sc.withOpacity(0.2), blurRadius: 10),
                ] else if (isLv)
                  BoxShadow(color: _C.live.withOpacity(0.08), blurRadius: 12),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
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
                      colors: isLv
                          ? [_C.live.withOpacity(0.07), _C.surface.withOpacity(0.9)]
                          : [_C.surfaceH.withOpacity(0.75), _C.surface.withOpacity(0.9)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0, left: 14, right: 14,
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(_focused ? 0.07 : 0.03),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _CompactStatusBadge(
                                  label: _statusLabel,
                                  color: sc,
                                  isLive: isLv,
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.sports_cricket,
                                        color: Colors.white.withOpacity(0.2), size: 10),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${widget.match.overs} ov',
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
                            _BracketTeamRow(name: widget.match.teamId1Name, color: sc),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  const SizedBox(width: 28),
                                  Text('vs',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.18),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      )),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [
                                          Colors.white.withOpacity(0.06),
                                          Colors.transparent,
                                        ]),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _BracketTeamRow(name: widget.match.teamId2Name, color: sc),
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
      ),
    );
  }
}

class _BracketTeamRow extends StatelessWidget {
  final String name;
  final Color color;

  const _BracketTeamRow({required this.name, required this.color});

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
              colors: [color.withOpacity(0.25), color.withOpacity(0.06)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(initial,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name.isEmpty ? 'TBD' : name,
            style: const TextStyle(
              color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w700, letterSpacing: 0.1,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CompactStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLive;

  const _CompactStatusBadge({
    required this.label, required this.color, required this.isLive,
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
            _LiveDot(color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                color: color, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 0.8,
              )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LEAGUE + KNOCKOUT VIEW
// ──────────────────────────────────────────────────────────────────────────────
// Stage split logic (in priority order):
//   1. If any match has a non-empty stage/round/matchStage field:
//      → Split by that field. Knockout keywords: 'knockout', 'semi', 'quarter',
//        'final', 'elimination', 'cup round'.
//   2. If NO match has stage info:
//      → Show ALL matches under League Stage only, with a note that knockout
//        stage will appear once stage data is available.
// ══════════════════════════════════════════════════════════════════════════════
class _LeagueKnockoutView extends StatelessWidget {
  final List<TournamentMatchModel> matches;
  final void Function(TournamentMatchModel) onMatchTap;

  const _LeagueKnockoutView({
    required this.matches,
    required this.onMatchTap,
  });

  static const _knockoutKeywords = [
    'knockout', 'semi', 'quarter', 'final', 'elimination', 'cup round', 'playoff',
  ];

  bool _isKnockoutStage(String stage) {
    final s = stage.toLowerCase();
    return _knockoutKeywords.any((kw) => s.contains(kw));
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortMatches(matches);

    // Check whether any match carries explicit stage information
    final anyHasStage = sorted.any((m) => _stageOf(m).isNotEmpty);

    List<TournamentMatchModel> leagueGroup;
    List<TournamentMatchModel> knockoutGroup;

    if (anyHasStage) {
      // Split by actual stage field
      leagueGroup   = sorted.where((m) => !_isKnockoutStage(_stageOf(m))).toList();
      knockoutGroup = sorted.where((m) =>  _isKnockoutStage(_stageOf(m))).toList();
    } else {
      // No stage data — show everything under League Stage
      leagueGroup   = sorted;
      knockoutGroup = [];
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.auto_awesome_mosaic_rounded,
            title: 'Fixtures',
            subtitle: anyHasStage
                ? '${leagueGroup.length} league  ·  ${knockoutGroup.length} knockout'
                : '${sorted.length} matches',
            color: _C.teal,
          ),
          const SizedBox(height: 20),
          _StatsSummaryBar(matches: sorted),
          const SizedBox(height: 36),

          // ══ LEAGUE STAGE ══════════════════════════════════════════════════
          _StageLabel(
            icon: Icons.format_list_bulleted_rounded,
            label: 'LEAGUE STAGE',
            color: _C.upcoming,
          ),
          const SizedBox(height: 20),
          _FixturesTable(
            matches: leagueGroup,
            onMatchTap: onMatchTap,
            startIndex: 1,
          ),

          // ══ KNOCKOUT STAGE ════════════════════════════════════════════════
          if (!anyHasStage) ...[
            const SizedBox(height: 32),
            _KnockoutPendingNote(),
          ] else if (knockoutGroup.isNotEmpty) ...[
            const SizedBox(height: 44),
            _StageLabel(
              icon: Icons.account_tree_rounded,
              label: 'KNOCKOUT STAGE',
              color: _C.gold,
            ),
            const SizedBox(height: 20),
            _KnockoutBracketInline(
              matches: knockoutGroup,
              onMatchTap: onMatchTap,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Knockout Pending Note ────────────────────────────────────────────────────
class _KnockoutPendingNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _C.gold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.gold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _C.gold.withOpacity(0.5), size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Knockout stage matches will appear here once stage information is available.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stage Label Pill ─────────────────────────────────────────────────────────
class _StageLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StageLabel({
    required this.icon, required this.label, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.06)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.35)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
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
}

// ─── Knockout Bracket Inline (no outer padding/header) ───────────────────────
class _KnockoutBracketInline extends StatelessWidget {
  final List<TournamentMatchModel> matches;
  final void Function(TournamentMatchModel) onMatchTap;

  const _KnockoutBracketInline({
    required this.matches, required this.onMatchTap,
  });

  List<List<TournamentMatchModel>> _groupIntoRounds(List<TournamentMatchModel> all) {
    final sorted = _sortMatches(all);
    if (sorted.isEmpty) return [];
    if (sorted.length == 1) return [sorted];

    const validSizes = [1, 2, 3, 4, 7, 8, 15, 16, 31, 32];
    if (!validSizes.contains(sorted.length)) {
      const chunkSize = 4;
      final rounds = <List<TournamentMatchModel>>[];
      for (var i = 0; i < sorted.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, sorted.length);
        rounds.add(sorted.sublist(i, end));
      }
      return rounds;
    }

    final rounds  = <List<TournamentMatchModel>>[];
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

  String _roundLabel(int index, int totalRounds) {
    if (totalRounds == 1) return 'Matches';
    final remaining = totalRounds - index;
    if (remaining == 1) return 'Final';
    if (remaining == 2) return 'Semi Finals';
    if (remaining == 3) return 'Quarter Finals';
    return 'Round ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final rounds = _groupIntoRounds(matches);
    if (rounds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('No knockout matches yet',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 15)),
        ),
      );
    }

    const cardHeight = 162.0;
    final maxMatches = rounds.map((r) => r.length).fold(1, (a, b) => a > b ? a : b);
    final colHeight  = (maxMatches * cardHeight).clamp(200.0, 1200.0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        height: colHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(rounds.length, (i) {
            final isFinal = i == rounds.length - 1;
            final label   = _roundLabel(i, rounds.length);
            return _RoundColumn(
              roundLabel: label,
              matches:    rounds[i],
              isFinal:    isFinal,
              onMatchTap: onMatchTap,
            );
          }),
        ),
      ),
    );
  }
}