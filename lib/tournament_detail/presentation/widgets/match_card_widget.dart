import 'package:flutter/material.dart';
import '../../../tournament_detail/domain/entities/TournamentMatchEntity.dart';

// ─── Design Tokens (matches app-wide system) ──────────────────────────────────
class _C {
  static const bg        = Color(0xFF050A18);
  static const surface   = Color(0xFF0A1628);
  static const surfaceH  = Color(0xFF0F1E35);
  static const accent    = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live      = Color(0xFFFF3D3D);
  static const upcoming  = Color(0xFF00D4FF);
  static const completed = Color(0xFF8A8FA8);
  static const gold      = Color(0xFFFFD700);
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIONAL-FIELD HELPERS
// These never touch business logic or add any new Firestore queries — they only
// peek at extra fields that may already exist on the concrete match model
// (the same way `_venueOf` already does in FixturesBracketWidget). If a field
// isn't present, the getter throws internally, is swallowed, and the related
// UI simply doesn't render. Adjust the candidate names below if your actual
// match_model.dart uses different field names.
// ═══════════════════════════════════════════════════════════════════════════════
String? _firstNonEmptyString(List<String? Function()> getters) {
  for (final g in getters) {
    try {
      final v = g();
      if (v != null && v.trim().isNotEmpty) return v.trim();
    } catch (_) {}
  }
  return null;
}

dynamic _firstNonNull(List<dynamic Function()> getters) {
  for (final g in getters) {
    try {
      final v = g();
      if (v != null) return v;
    } catch (_) {}
  }
  return null;
}

class _MatchOptionalData {
  final String? venue;
  final String? format;
  final String? scoreLine;
  final String? inningsLabel;
  final String? tossLine;
  final String? winnerName;
  final String? resultText;
  final String? endTimeLabel;
  final String? dateLabel;
  final String? timeLabel;

  const _MatchOptionalData({
    this.venue,
    this.format,
    this.scoreLine,
    this.inningsLabel,
    this.tossLine,
    this.winnerName,
    this.resultText,
    this.endTimeLabel,
    this.dateLabel,
    this.timeLabel,
  });

  factory _MatchOptionalData.from(TournamentMatchEntity match) {
    final dyn = match as dynamic;

    final venue = _firstNonEmptyString([
          () => dyn.venue as String?,
          () => dyn.ground as String?,
          () => dyn.groundName as String?,
          () => dyn.location as String?,
    ]);

    final format = _firstNonEmptyString([
          () => dyn.format as String?,
          () => dyn.matchFormat as String?,
    ]);

    final scoreLine = _firstNonEmptyString([
          () => dyn.currentScoreText as String?,
          () => dyn.scoreSummary as String?,
          () => dyn.liveScoreText as String?,
          () => dyn.scoreLine as String?,
    ]);

    final tossWinner = _firstNonEmptyString([
          () => dyn.tossWinnerName as String?,
          () => dyn.tossWinner as String?,
    ]);
    final tossDecision = _firstNonEmptyString([
          () => dyn.tossDecision as String?,
    ]);
    final tossLine = _firstNonEmptyString([
          () => dyn.tossResult as String?,
          () => dyn.tossSummary as String?,
          () => tossWinner != null
          ? (tossDecision != null
          ? '$tossWinner won the toss, chose to $tossDecision'
          : '$tossWinner won the toss')
          : null,
    ]);

    final inningsRaw = _firstNonNull([
          () => dyn.currentInnings,
          () => dyn.inningsNumber,
          () => dyn.inning,
    ]);
    String? inningsLabel;
    if (inningsRaw != null) {
      if (inningsRaw is bool) {
        inningsLabel = inningsRaw ? '2nd Innings' : '1st Innings';
      } else {
        final n = int.tryParse(inningsRaw.toString());
        if (n == 1) inningsLabel = '1st Innings';
        if (n == 2) inningsLabel = '2nd Innings';
      }
    }

    final winnerName = _firstNonEmptyString([
          () => dyn.winnerName as String?,
          () => dyn.winner as String?,
          () => dyn.winningTeamName as String?,
    ]);

    final resultText = _firstNonEmptyString([
          () => dyn.resultText as String?,
          () => dyn.result as String?,
          () => dyn.matchResult as String?,
    ]);

    final endTimeLabel = _firstNonEmptyString([
          () => dyn.matchEndTime as String?,
          () => dyn.endTime as String?,
          () => dyn.completedAt as String?,
    ]);

    final matchDateRaw = _firstNonNull([
          () => dyn.matchDate,
          () => dyn.matchDateTime,
          () => dyn.startDate,
    ]);
    String? dateLabel;
    String? timeLabel;
    if (matchDateRaw != null) {
      final parsed = _parseDate(matchDateRaw);
      if (parsed != null) {
        dateLabel = parsed.$1;
        timeLabel = parsed.$2;
      }
    }

    return _MatchOptionalData(
      venue: venue,
      format: format,
      scoreLine: scoreLine,
      inningsLabel: inningsLabel,
      tossLine: tossLine,
      winnerName: winnerName,
      resultText: resultText,
      endTimeLabel: endTimeLabel,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
    );
  }
}

// Mirrors the display-only date parsing already used in FixturesBracketWidget.
(String, String)? _parseDate(dynamic value) {
  DateTime? dt;
  if (value is DateTime) dt = value;
  if (dt == null && value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;
    final tsMatch = RegExp(r'seconds=(\d+)').firstMatch(s);
    if (tsMatch != null) {
      final seconds = int.tryParse(tsMatch.group(1) ?? '');
      if (seconds != null) dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    if (dt == null) {
      try { dt = DateTime.parse(s); } catch (_) {}
    }
  }
  if (dt == null) return null;
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  return (dateStr, timeStr);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATCH CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════════
class MatchCardWidget extends StatefulWidget {
  final TournamentMatchEntity match;
  final VoidCallback onTap;

  const MatchCardWidget({
    Key? key,
    required this.match,
    required this.onTap,
  }) : super(key: key);

  @override
  State<MatchCardWidget> createState() => _MatchCardWidgetState();
}

class _MatchCardWidgetState extends State<MatchCardWidget> {
  bool _focused = false;
  final FocusNode _focusNode = FocusNode(debugLabel: 'match_card');

  TournamentMatchEntity get match => widget.match;

  Color get _statusColor {
    if (match.isLive)      return _C.live;
    if (match.isCompleted) return _C.completed;
    return _C.upcoming;
  }

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

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor;
    final data = _MatchOptionalData.from(match);

    return RepaintBoundary(
      child: FocusableActionDetector(
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
          child: AnimatedScale(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOut,
            scale: _focused ? 1.018 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 190),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: match.isLive
                      ? [_C.live.withOpacity(0.10), _C.surface.withOpacity(0.95)]
                      : [_C.surfaceH.withOpacity(0.75), _C.surface.withOpacity(0.95)],
                ),
                border: Border.all(
                  color: _focused
                      ? sc
                      : match.isLive
                      ? sc.withOpacity(0.35)
                      : Colors.white.withOpacity(0.07),
                  width: _focused ? 1.6 : 1,
                ),
                boxShadow: [
                  if (_focused)
                    BoxShadow(color: sc.withOpacity(0.32), blurRadius: 26, offset: const Offset(0, 6)),
                  if (match.isLive && !_focused)
                    BoxShadow(color: _C.live.withOpacity(0.10), blurRadius: 14),
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Left accent stripe — status connector
                    Positioned(
                      left: 0, top: 0, bottom: 0,
                      child: Container(
                        width: _focused ? 3.5 : 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [sc, sc.withOpacity(0.25)],
                          ),
                          boxShadow: _focused ? [BoxShadow(color: sc.withOpacity(0.6), blurRadius: 8)] : [],
                        ),
                      ),
                    ),

                    // Subtle top shimmer line
                    Positioned(
                      top: 0, left: 20, right: 20,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(_focused ? 0.10 : 0.03),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 22, 18),
                      child: match.isLive
                          ? _LiveCardBody(match: match, data: data, sc: sc, focused: _focused)
                          : match.isCompleted
                          ? _CompletedCardBody(match: match, data: data, sc: sc, focused: _focused)
                          : _UpcomingCardBody(match: match, data: data, sc: sc, focused: _focused),
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
// LIVE CARD BODY
// LIVE badge · teams · current score/innings/toss (when available) · overs ·
// Watch Live affordance. Tapping anywhere on the card triggers the existing
// onTap (unchanged navigation/watch-live logic).
// ═══════════════════════════════════════════════════════════════════════════════
class _LiveCardBody extends StatelessWidget {
  final TournamentMatchEntity match;
  final _MatchOptionalData data;
  final Color sc;
  final bool focused;

  const _LiveCardBody({required this.match, required this.data, required this.sc, required this.focused});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _PulsingLiveBadge(),
            const Spacer(),
            if (data.inningsLabel != null) ...[
              _InfoChip(icon: Icons.sports_cricket_rounded, label: data.inningsLabel!, color: sc),
              const SizedBox(width: 8),
            ],
            _InfoChip(icon: Icons.timer_outlined, label: '${match.overs} OV', color: sc),
          ],
        ),
        const SizedBox(height: 16),
        _TeamRow(name: match.teamId1Name, color: sc, focused: focused),
        const SizedBox(height: 8),
        _VsDivider(),
        const SizedBox(height: 8),
        _TeamRow(name: match.teamId2Name, color: sc, focused: focused),
        if (data.scoreLine != null) ...[
          const SizedBox(height: 14),
          _ScorePill(text: data.scoreLine!, color: sc),
        ],
        if (data.tossLine != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.casino_outlined, color: Colors.white.withOpacity(0.3), size: 12),
            const SizedBox(width: 6),
            Expanded(
              child: Text(data.tossLine!,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ],
        const SizedBox(height: 16),
        _ActionButton(label: 'WATCH LIVE', icon: Icons.play_arrow_rounded, color: sc, focused: focused, filled: true),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UPCOMING CARD BODY
// SCHEDULED badge · date & time · format/overs · teams · View Details affordance.
// ═══════════════════════════════════════════════════════════════════════════════
class _UpcomingCardBody extends StatelessWidget {
  final TournamentMatchEntity match;
  final _MatchOptionalData data;
  final Color sc;
  final bool focused;

  const _UpcomingCardBody({required this.match, required this.data, required this.sc, required this.focused});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatusBadge(label: 'SCHEDULED', icon: Icons.schedule_rounded, color: sc),
            const Spacer(),
            if (data.format != null) ...[
              _InfoChip(icon: Icons.format_list_bulleted_rounded, label: data.format!.toUpperCase(), color: sc),
              const SizedBox(width: 8),
            ],
            _InfoChip(icon: Icons.sports_cricket_rounded, label: '${match.overs} OV', color: sc),
          ],
        ),
        const SizedBox(height: 14),
        if (data.dateLabel != null)
          Row(children: [
            Icon(Icons.calendar_today_rounded, color: sc.withOpacity(0.6), size: 13),
            const SizedBox(width: 8),
            Text(data.dateLabel!,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            if (data.timeLabel != null) ...[
              const SizedBox(width: 14),
              Icon(Icons.access_time_rounded, color: sc.withOpacity(0.6), size: 13),
              const SizedBox(width: 6),
              Text(data.timeLabel!,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ]),
        if (data.dateLabel != null) const SizedBox(height: 14),
        _TeamRow(name: match.teamId1Name, color: sc, focused: focused),
        const SizedBox(height: 8),
        _VsDivider(),
        const SizedBox(height: 8),
        _TeamRow(name: match.teamId2Name, color: sc, focused: focused),
        const SizedBox(height: 16),
        _ActionButton(label: 'VIEW DETAILS', icon: Icons.chevron_right_rounded, color: sc, focused: focused, filled: false),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPLETED CARD BODY
// COMPLETED badge · winner ribbon (when available) · teams (+ final score when
// available) · result text (when available) · Match Details affordance.
// ═══════════════════════════════════════════════════════════════════════════════
class _CompletedCardBody extends StatelessWidget {
  final TournamentMatchEntity match;
  final _MatchOptionalData data;
  final Color sc;
  final bool focused;

  const _CompletedCardBody({required this.match, required this.data, required this.sc, required this.focused});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatusBadge(label: 'COMPLETED', icon: Icons.check_circle_rounded, color: sc),
            const Spacer(),
            if (data.endTimeLabel != null)
              Text(data.endTimeLabel!,
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        if (data.winnerName != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.emoji_events_rounded, color: _C.gold.withOpacity(0.85), size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text('${data.winnerName} won',
                  style: TextStyle(color: _C.gold.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ],
        const SizedBox(height: 14),
        _TeamRow(
          name: match.teamId1Name,
          color: sc,
          focused: focused,
          highlighted: data.winnerName != null && data.winnerName == match.teamId1Name,
        ),
        const SizedBox(height: 8),
        _VsDivider(),
        const SizedBox(height: 8),
        _TeamRow(
          name: match.teamId2Name,
          color: sc,
          focused: focused,
          highlighted: data.winnerName != null && data.winnerName == match.teamId2Name,
        ),
        if (data.scoreLine != null) ...[
          const SizedBox(height: 14),
          _ScorePill(text: data.scoreLine!, color: sc),
        ],
        if (data.resultText != null) ...[
          const SizedBox(height: 10),
          Text(data.resultText!,
              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
        ],
        const SizedBox(height: 16),
        _ActionButton(label: 'MATCH DETAILS', icon: Icons.chevron_right_rounded, color: sc, focused: focused, filled: false),
      ],
    );
  }
}

// ─── Shared small pieces ──────────────────────────────────────────────────────

class _PulsingLiveBadge extends StatefulWidget {
  const _PulsingLiveBadge();
  @override
  State<_PulsingLiveBadge> createState() => _PulsingLiveBadgeState();
}

class _PulsingLiveBadgeState extends State<_PulsingLiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _C.live.withOpacity(0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.live.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: _C.live.withOpacity(0.25 * _anim.value), blurRadius: 10)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.live.withOpacity(0.5 + 0.5 * _anim.value),
            ),
          ),
          const SizedBox(width: 6),
          const Text('LIVE',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusBadge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white.withOpacity(0.35), size: 11),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String text;
  final Color color;
  const _ScorePill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final Color color;
  final bool focused;
  final bool highlighted;
  const _TeamRow({required this.name, required this.color, required this.focused, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: highlighted
                  ? [_C.gold.withOpacity(0.3), _C.gold.withOpacity(0.08)]
                  : [color.withOpacity(0.26), color.withOpacity(0.08)],
            ),
            border: Border.all(color: (highlighted ? _C.gold : color).withOpacity(0.4), width: 1.2),
          ),
          child: Center(
            child: Text(initial,
                style: TextStyle(color: highlighted ? _C.gold : color, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name.isEmpty ? 'TBD' : name,
            style: TextStyle(
              color: focused ? Colors.white : Colors.white.withOpacity(0.92),
              fontSize: 15,
              fontWeight: highlighted ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: 0.1,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (highlighted)
          Icon(Icons.emoji_events_rounded, color: _C.gold.withOpacity(0.8), size: 15),
      ],
    );
  }
}

class _VsDivider extends StatelessWidget {
  const _VsDivider();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const SizedBox(width: 30),
      const SizedBox(width: 12),
      Text('vs', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.white.withOpacity(0.06), Colors.transparent]),
          ),
        ),
      ),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool focused;
  final bool filled;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.focused,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: filled
            ? color.withOpacity(focused ? 0.9 : 0.75)
            : (focused ? color.withOpacity(0.14) : Colors.white.withOpacity(0.04)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: filled ? Colors.transparent : color.withOpacity(focused ? 0.5 : 0.15)),
        boxShadow: focused ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)] : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: filled ? Colors.black.withOpacity(0.85) : color, size: 15),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                color: filled ? Colors.black.withOpacity(0.85) : color,
                fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6,
              )),
        ],
      ),
    );
  }
}