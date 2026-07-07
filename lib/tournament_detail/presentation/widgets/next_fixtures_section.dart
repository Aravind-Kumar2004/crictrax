import 'package:flutter/material.dart';
import '../../data/models/match_model.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const surface  = Color(0xFF0A1628);
  static const surfaceH = Color(0xFF0F1E35);
  static const upcoming = Color(0xFF00D4FF);
}

// ── Local display-only date parsing (mirrors the pattern already used in
// FixturesBracketWidget — no repository / model changes involved) ────────────
class _DateParts {
  final String date;
  final String time;
  final DateTime? raw;
  const _DateParts({required this.date, required this.time, this.raw});
}

_DateParts _parseDate(dynamic value) {
  if (value == null) return const _DateParts(date: '—', time: '—');
  DateTime? dt;
  if (value is DateTime) dt = value;
  if (dt == null && value is String) {
    final s = value.trim();
    if (s.isEmpty) return const _DateParts(date: '—', time: '—');
    final tsMatch = RegExp(r'seconds=(\d+)').firstMatch(s);
    if (tsMatch != null) {
      final seconds = int.tryParse(tsMatch.group(1) ?? '');
      if (seconds != null) dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    if (dt == null) {
      try { dt = DateTime.parse(s); } catch (_) {}
    }
    if (dt == null) return _DateParts(date: s, time: '—');
  }
  if (dt == null) return _DateParts(date: value.toString(), time: '—');
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  return _DateParts(date: dateStr, time: timeStr, raw: dt);
}

String _venueOf(TournamentMatchModel m) {
  try {
    final dyn = m as dynamic;
    for (final key in ['venue', 'ground', 'groundName', 'location']) {
      try {
        final v = dyn[key] as String?;
        if (v != null && v.isNotEmpty) return v;
      } catch (_) {}
    }
  } catch (_) {}
  try { final v = (m as dynamic).venue as String?; if (v != null && v.isNotEmpty) return v; } catch (_) {}
  try { final v = (m as dynamic).ground as String?; if (v != null && v.isNotEmpty) return v; } catch (_) {}
  try { final v = (m as dynamic).groundName as String?; if (v != null && v.isNotEmpty) return v; } catch (_) {}
  try { final v = (m as dynamic).location as String?; if (v != null && v.isNotEmpty) return v; } catch (_) {}
  return '';
}

List<TournamentMatchModel> _sortByDate(List<TournamentMatchModel> src) {
  final list = [...src];
  list.sort((a, b) {
    final da = _parseDate(a.matchDate).raw;
    final db = _parseDate(b.matchDate).raw;
    if (da != null && db != null) return da.compareTo(db);
    if (da != null) return -1;
    if (db != null) return 1;
    return (a.matchDate?.toString() ?? '').compareTo(b.matchDate?.toString() ?? '');
  });
  return list;
}

// ═══════════════════════════════════════════════════════════════════════════
// NEXT FIXTURES — next 3 upcoming matches only
// ═══════════════════════════════════════════════════════════════════════════
class NextFixturesSection extends StatelessWidget {
  final List<TournamentMatchModel> upcomingMatches;
  final ValueChanged<TournamentMatchModel> onTap;

  const NextFixturesSection({
    Key? key,
    required this.upcomingMatches,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (upcomingMatches.isEmpty) return const SizedBox.shrink();
    final next3 = _sortByDate(upcomingMatches).take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT FIXTURES',
              style: TextStyle(color: _C.upcoming, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 14),
          FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Row(
              children: [
                for (int i = 0; i < next3.length; i++) ...[
                  Expanded(child: _FixtureCard(match: next3[i], onTap: () => onTap(next3[i]))),
                  if (i != next3.length - 1) const SizedBox(width: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FixtureCard extends StatefulWidget {
  final TournamentMatchModel match;
  final VoidCallback onTap;
  const _FixtureCard({required this.match, required this.onTap});

  @override
  State<_FixtureCard> createState() => _FixtureCardState();
}

class _FixtureCardState extends State<_FixtureCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final dt = _parseDate(m.matchDate);
    final venue = _venueOf(m);

    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _C.surfaceH.withOpacity(0.85),
              border: Border.all(
                color: _focused ? _C.upcoming.withOpacity(0.6) : Colors.white.withOpacity(0.07),
                width: _focused ? 1.5 : 1,
              ),
              boxShadow: _focused ? [BoxShadow(color: _C.upcoming.withOpacity(0.2), blurRadius: 16)] : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.calendar_today_rounded, color: _C.upcoming.withOpacity(0.7), size: 12),
                  const SizedBox(width: 6),
                  Text(dt.date,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text(dt.time,
                      style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 14),
                Text(m.teamId1Name.isEmpty ? 'TBD' : m.teamId1Name,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('vs', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                Text(m.teamId2Name.isEmpty ? 'TBD' : m.teamId2Name,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(Icons.location_on_rounded, color: Colors.white.withOpacity(0.25), size: 12),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(venue,
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}