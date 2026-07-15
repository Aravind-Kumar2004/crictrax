import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../data/models/match_model.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bgCard    = Color(0xFF080F1F);
  static const surface   = Color(0xFF0A1628);
  static const accent    = Color(0xFF00D4FF);
  static const live      = Color(0xFFFF3D3D);
  static const upcoming  = Color(0xFF00D4FF);
  static const completed = Color(0xFF8A8FA8);
  static const fixtures  = Color(0xFF8E5CFF);
}

// ─── Robust DateTime Parser (UNCHANGED LOGIC) ─────────────────────────────────
class _DateTimeParts {
  final String date;
  final String time;
  final DateTime? raw;
  const _DateTimeParts({required this.date, required this.time, this.raw});
}

_DateTimeParts _parseMatchDate(dynamic value) {
  if (value == null) return const _DateTimeParts(date: '—', time: '—');
  DateTime? dt;
  if (value is DateTime) dt = value;

  if (dt == null && value is String) {
    final s = value.trim();
    if (s.isEmpty) return const _DateTimeParts(date: '—', time: '—');
    final tsMatch = RegExp(r'seconds=(\d+)').firstMatch(s);
    if (tsMatch != null) {
      final seconds = int.tryParse(tsMatch.group(1) ?? '');
      if (seconds != null) dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    if (dt == null) {
      try { dt = DateTime.parse(s); } catch (_) {}
    }
    if (dt == null) return _DateTimeParts(date: s, time: '—');
  }

  if (dt == null) return _DateTimeParts(date: value.toString(), time: '—');

  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  final timeStr = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  return _DateTimeParts(date: dateStr, time: timeStr, raw: dt);
}

// ─── Sort Helper (UNCHANGED LOGIC) ────────────────────────────────────────────
List<TournamentMatchModel> _sortMatches(List<TournamentMatchModel> src) {
  final indexed = src.asMap().entries.toList();
  indexed.sort((a, b) {
    final da = _parseMatchDate(a.value.matchDate).raw;
    final db = _parseMatchDate(b.value.matchDate).raw;
    if (da != null && db != null) {
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
    } else if (da != null) return -1;
    else if (db != null) return 1;
    final sa = a.value.matchDate?.toString() ?? '';
    final sb = b.value.matchDate?.toString() ?? '';
    final sc = sa.compareTo(sb);
    if (sc != 0) return sc;
    return a.key.compareTo(b.key);
  });
  return indexed.map((e) => e.value).toList();
}

// ─── Venue Helper (UNCHANGED LOGIC) ───────────────────────────────────────────
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
  try { final v = (m as dynamic).venue as String?;      if (v != null && v.isNotEmpty) return v; } catch (_) {}
  try { final v = (m as dynamic).ground as String?;     if (v != null && v.isNotEmpty) return v; } catch (_) {}
  try { final v = (m as dynamic).groundName as String?; if (v != null && v.isNotEmpty) return v; } catch (_) {}
  try { final v = (m as dynamic).location as String?;   if (v != null && v.isNotEmpty) return v; } catch (_) {}
  return '';
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC: FIXTURES TABLE WIDGET
// Always renders in clean league-table format (no Semi/Quarter/Final labels),
// matching the reference design.
//
// MAJOR TV RESCALE PASS (relative to the previous incremental pass):
//   • Outer side margin cut 20.w → 12.w so the table occupies ~95% of the
//     available width instead of ~85–90%.
//   • Row vertical padding +43% (28.h → 40.h) for genuinely taller rows.
//   • Team name font raised to 30.sp as requested; avatar 56.w → 72.w;
//     VS text and Team1↔VS↔Team2 spacing both increased.
//   • Date, Venue, Overs typography and the Status badge all scaled up
//     substantially (see chat summary table for exact before/after values).
//   • DATE/VENUE/OVERS/STATUS fixed column widths increased just enough to
//     comfortably hold the larger typography without wrapping/overflow.
//     MATCH remains the row's only `Expanded` child, so the width freed up
//     by the smaller outer margin — plus the fact that fixed columns are
//     still a small fraction of a TV-width canvas — flows straight into
//     MATCH, giving team names materially more breathing room.
//   • Header typography and padding scaled up to match the bigger rows.
// No sorting, date-parsing, venue-resolution, match-tap, focus/D-pad, or
// status logic was touched — only sizes and column-width allocation.
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
    if (matches.isEmpty) return const _EmptyFixturesState();

    final sorted = _sortMatches(matches);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 36.h),
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('LEAGUE FIXTURES',
                    style: TextStyle(
                      color: _C.accent,
                      fontSize: 22.sp, fontWeight: FontWeight.w800, letterSpacing: 0.8,
                    )),
                const Spacer(),
                Text('All matches in league format',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 15.sp, fontWeight: FontWeight.w500,
                    )),
              ],
            ),
            SizedBox(height: 20.h),
            _FixturesTable(matches: sorted, onMatchTap: onMatchTap),
            SizedBox(height: 24.h),
            Center(
              child: Text('All times are in IST (Indian Standard Time)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.22), fontSize: 15.sp,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────
class _EmptyFixturesState extends StatelessWidget {
  const _EmptyFixturesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 104.w, height: 104.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.fixtures.withOpacity(0.05),
              border: Border.all(color: _C.fixtures.withOpacity(0.15), width: 1.5),
            ),
            child: Icon(Icons.calendar_today_rounded,
                color: _C.fixtures.withOpacity(0.3), size: 40.sp),
          ),
          SizedBox(height: 24.h),
          Text('No Fixtures Yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 25.sp, fontWeight: FontWeight.w700, letterSpacing: -0.2,
              )),
          SizedBox(height: 9.h),
          Text('Matches will appear here once they are scheduled.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.22), fontSize: 16.sp, height: 1.5,
              )),
        ],
      ),
    );
  }
}

// ── Fixtures Table ─────────────────────────────────────────────────────────────
// Column width plan (major TV rescale):
//   DATE & TIME : fixed 140.w   (was 120.w)
//   MATCH       : flex 8, remainder — now claims far more of the row
//   VENUE       : fixed 160.w   (was 140.w)
//   OVERS       : fixed 90.w    (was 80.w)
//   STATUS      : fixed 130.w   (was 110.w, badge itself also enlarged)
class _FixturesTable extends StatelessWidget {
  final List<TournamentMatchModel> matches;
  final void Function(TournamentMatchModel) onMatchTap;

  const _FixturesTable({required this.matches, required this.onMatchTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 32.r, offset: Offset(0, 9.h)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: Column(
          children: [
            const _ColumnHeader(),
            Container(height: 1, color: Colors.white.withOpacity(0.06)),
            ...matches.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              return _FixtureRow(
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

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 26.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.fixtures.withOpacity(0.12), _C.fixtures.withOpacity(0.04)],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 140.w, child: Text('DATE & TIME', style: _headerStyle)),
          Expanded(flex: 8, child: Text('MATCH', style: _headerStyle, textAlign: TextAlign.center)),
          SizedBox(width: 160.w, child: Text('VENUE', style: _headerStyle)),
          SizedBox(width: 90.w, child: Text('OVERS', style: _headerStyle, textAlign: TextAlign.center)),
          SizedBox(width: 130.w, child: Text('STATUS', style: _headerStyle, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
    color: _C.fixtures.withOpacity(0.7),
    fontSize: 18.sp, fontWeight: FontWeight.w800, letterSpacing: 1.2,
  );
}

class _FixtureRow extends StatefulWidget {
  final TournamentMatchModel match;
  final bool isLast;
  final VoidCallback onTap;

  const _FixtureRow({required this.match, required this.isLast, required this.onTap});

  @override
  State<_FixtureRow> createState() => _FixtureRowState();
}

class _FixtureRowState extends State<_FixtureRow> {
  bool _focused = false;
  final FocusNode _focusNode = FocusNode(debugLabel: 'fixture_row');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    setState(() => _focused = hasFocus);
    if (hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          _focusNode.context ?? context,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      });
    }
  }

  Color get _statusColor {
    if (widget.match.isCompleted) return _C.completed;
    if (widget.match.isLive && !widget.match.isCompleted) return _C.live;
    return _C.upcoming;
  }

  String get _statusLabel {
    if (widget.match.isCompleted) return 'COMPLETED';
    if (widget.match.isLive && !widget.match.isCompleted) return 'LIVE';
    return 'SCHEDULED';
  }

  @override
  Widget build(BuildContext context) {
    final sc    = _statusColor;
    final dt    = _parseMatchDate(widget.match.matchDate);
    final isLv  = widget.match.isLive && !widget.match.isCompleted;
    final venue = _venueOf(widget.match);

    return FocusableActionDetector(
      focusNode: _focusNode,
      onFocusChange: _handleFocusChange,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _focused
                ? sc.withOpacity(0.1)
                : isLv
                ? _C.live.withOpacity(0.04)
                : Colors.transparent,
            border: Border.all(
              color: _focused ? sc.withOpacity(0.5) : Colors.transparent,
              width: 1.4,
            ),
            borderRadius: widget.isLast
                ? BorderRadius.vertical(bottom: Radius.circular(21.r))
                : BorderRadius.zero,
            boxShadow: _focused ? [BoxShadow(color: sc.withOpacity(0.25), blurRadius: 18.r)] : [],
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 40.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Date & Time
                    SizedBox(
                      width: 140.w,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              color: Colors.white.withOpacity(0.18), size: 20.sp),
                          SizedBox(width: 10.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dt.date,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(_focused ? 0.95 : 0.7),
                                    fontSize: 22.sp, fontWeight: FontWeight.w700,
                                  )),
                              Text(dt.time,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 18.sp, fontWeight: FontWeight.w500,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Match (team1 vs team2) — widest column by far, full
                    // names, no forced uppercase.
                    Expanded(
                      flex: 8,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _TeamCell(name: widget.match.teamId1Name, color: sc, alignEnd: true),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32.w),
                            child: Text('VS',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 22.sp, fontWeight: FontWeight.w800,
                                )),
                          ),
                          Expanded(
                            child: _TeamCell(name: widget.match.teamId2Name, color: sc, alignEnd: false),
                          ),
                        ],
                      ),
                    ),

                    // Venue
                    SizedBox(
                      width: 160.w,
                      child: Text(
                        venue.isEmpty ? '—' : venue,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(venue.isEmpty ? 0.2 : 0.55),
                          fontSize: 19.sp, fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),

                    // Overs
                    SizedBox(
                      width: 90.w,
                      child: Text('${widget.match.overs}\nOVERS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 18.sp, fontWeight: FontWeight.w700, height: 1.35,
                          )),
                    ),

                    // Status
                    SizedBox(
                      width: 130.w,
                      child: Center(
                        child: _StatusBadge(label: _statusLabel, color: sc, isLive: isLv),
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isLast)
                Container(height: 1, color: Colors.white.withOpacity(0.04)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Team Cell (with image slot) ─────────────────────────────────────────────────
// Expanded (not nested Flexible) so the label can actually claim the available
// width, up to 2 lines, without forced uppercase or premature ellipsis.
// Original names from Firestore are shown exactly as-is.
class _TeamCell extends StatelessWidget {
  final String name;
  final Color color;
  final bool alignEnd;

  const _TeamCell({required this.name, required this.color, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final badge = Container(
      width: 72.w, height: 72.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      // TODO: Replace with your own team logo image, e.g.:
      // Image.asset('assets/images/teams/${name.toLowerCase()}.png', fit: BoxFit.cover)
      child: Center(
        child: Text(initial,
            style: TextStyle(color: color, fontSize: 27.sp, fontWeight: FontWeight.w900)),
      ),
    );

    final label = Text(
      name.isEmpty ? 'TBD' : name,
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      maxLines: 2,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white, fontSize: 30.sp, fontWeight: FontWeight.w800, letterSpacing: 0.2, height: 1.15,
      ),
    );

    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: alignEnd
          ? [Expanded(child: label), SizedBox(width: 20.w), badge]
          : [badge, SizedBox(width: 20.w), Expanded(child: label)],
    );
  }
}

// ── Status Badge ────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLive;

  const _StatusBadge({required this.label, required this.color, required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: color.withOpacity(isLive ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(13.r),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: isLive ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 14.r)] : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(width: 10.w, height: 10.w,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            SizedBox(width: 8.w),
          ],
          Text(label,
              style: TextStyle(
                color: color, fontSize: 15.sp, fontWeight: FontWeight.w800, letterSpacing: 0.6,
              )),
        ],
      ),
    );
  }
}