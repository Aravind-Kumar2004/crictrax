import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../match_detail/data/repositories/match_detail_repository.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF050A18);
  static const surface   = Color(0xFF0A1628);
  static const surfaceH  = Color(0xFF0F1E35);
  static const accent    = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live      = Color(0xFFFF3D3D);
  static const gold      = Color(0xFFFFD700);
  static const orange    = Color(0xFFFF7A45);
  static const purple    = Color(0xFF8E5CFF);
  static const success   = Color(0xFF00E676);
  static const danger    = Color(0xFFFF3D3D);
  // Standardized TV focus-highlight color (matches remote focus spec).
  static const focusGlow = Color(0xFF00D4FF);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TV ROW FOCUS WRAPPER (D-PAD NAVIGATION ONLY — no design/business logic here)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Gives an individual batsman/bowler row its own FocusNode so it can be
// targeted directly by the D-pad, independent of the innings card itself
// (the card no longer participates in focus at all — see InningsCardWidget
// below). When a row receives focus it:
//   • asks the nearest enclosing Scrollable (the card's internal
//     SingleChildScrollView) to scroll itself into view, and
//   • reports its focused state to `builder` so the call-site can draw a
//     highlight without altering the row's existing design.
//
// Directional Up/Down movement between rows is resolved automatically by
// Flutter's default directional-focus keyboard shortcuts + traversal
// policy (the same mechanism already relied on for arrow-key movement
// between cards) — no extra shortcut wiring is needed here.
typedef _RowFocusBuilder = Widget Function(BuildContext context, bool focused);

class _TvFocusableRow extends StatefulWidget {
  final _RowFocusBuilder builder;
  final String? debugLabel;

  const _TvFocusableRow({
    Key? key,
    required this.builder,
    this.debugLabel,
  }) : super(key: key);

  @override
  State<_TvFocusableRow> createState() => _TvFocusableRowState();
}

class _TvFocusableRowState extends State<_TvFocusableRow> {
  late final FocusNode _focusNode =
  FocusNode(debugLabel: widget.debugLabel ?? 'TvFocusableRow');
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    if (!mounted) return;
    setState(() => _focused = focused);

    if (focused) {
      // Auto-scroll the innings card's internal scroll view so the
      // newly-focused row is kept visible. Runs after the frame in which
      // focus changed so layout is up to date.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _focusNode.context;
        if (ctx == null || !ctx.mounted) return;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: _handleFocusChange,
      child: widget.builder(context, _focused),
    );
  }
}

// Shared highlight wrapper so batsman/bowler rows get a consistent,
// non-destructive focus treatment (adds a border/glow only — the row's
// own content, colors, and layout are untouched).
Widget _focusHighlightWrap({required Widget child, required bool focused}) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    curve: Curves.easeOut,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: focused ? _C.focusGlow : Colors.transparent,
        width: 2,
      ),
      color: focused ? _C.focusGlow.withOpacity(0.06) : Colors.transparent,
      boxShadow: focused
          ? [
        BoxShadow(
          color: _C.focusGlow.withOpacity(0.35),
          blurRadius: 12,
          spreadRadius: 0.5,
        ),
      ]
          : [],
    ),
    child: child,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// INNINGS CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════════
class InningsCardWidget extends StatefulWidget {
  final Map<String, dynamic> innData;
  final int inningsNumber;
  final String tournamentId;
  final String matchId;
  final String inningsId;
  final String team1Name;
  final String team2Name;
  final MatchDetailRepository repo;

  const InningsCardWidget({
    Key? key,
    required this.innData,
    required this.inningsNumber,
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
    required this.team1Name,
    required this.team2Name,
    required this.repo,
  }) : super(key: key);

  @override
  State<InningsCardWidget> createState() => _InningsCardWidgetState();
}

class _InningsCardWidgetState extends State<InningsCardWidget> {
  List<Map<String, dynamic>> _batsmen = [];
  List<Map<String, dynamic>> _bowlers = [];
  bool _loading = true;

  // NOTE: The innings card itself intentionally holds no FocusNode and is
  // never part of the D-pad focus chain — only the individual batsman and
  // bowler rows inside it are focusable (see _TvFocusableRow above). This
  // matches the requirement that the card as a whole must never receive
  // focus.

  // ── Business Logic (COMPLETELY UNCHANGED) ───────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    final batsmen = await widget.repo.fetchBatsmen(
        widget.tournamentId, widget.matchId, widget.inningsId);
    final bowlers = await widget.repo.fetchBowlers(
        widget.tournamentId, widget.matchId, widget.inningsId);
    if (!mounted) return;
    setState(() {
      _batsmen = batsmen;
      _bowlers = bowlers;
      _loading = false;
    });
  }

  String _resolveTeamName(String? id) {
    if (id == null || id.isEmpty) return '—';
    if (id == widget.team1Name) return widget.team1Name;
    if (id == widget.team2Name) return widget.team2Name;
    final battingTeamName =
    (widget.innData['battingTeamName'] ?? '').toString().trim();
    if (battingTeamName.isNotEmpty) return battingTeamName;
    return widget.inningsNumber == 1 ? widget.team1Name : widget.team2Name;
  }

  String _battingTeamName() {
    final name = (widget.innData['battingTeamName'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    return widget.inningsNumber == 1 ? widget.team1Name : widget.team2Name;
  }

  int get _totalRuns =>
      _batsmen.fold(0, (s, b) => s + ((b['runs'] ?? 0) as num).toInt());
  int get _totalWickets =>
      _batsmen.where((b) => b['isOut'] == true).length;
  int get _totalBalls =>
      _batsmen.fold(0, (s, b) => s + ((b['ballsFaced'] ?? 0) as num).toInt());

  String get _oversDisplay {
    final comp = _totalBalls ~/ 6;
    final rem  = _totalBalls % 6;
    return '$comp.$rem';
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final battingTeam = _battingTeamName();
    final targetRuns  = (widget.innData['targetRuns'] ?? 0) as num;
    final isSecond    = widget.innData['isSecondInnings'] == true;
    final innLabel    = 'Innings ${widget.inningsNumber}';

    final cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _C.surfaceH.withOpacity(0.75),
                _C.surface.withOpacity(0.9),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Card header ──────────────────────────────────────────────
              _InningsHeader(
                innLabel: innLabel,
                battingTeam: battingTeam,
                loading: _loading,
                totalRuns: _totalRuns,
                totalWickets: _totalWickets,
                oversDisplay: _oversDisplay,
              ),

              // ── Target badge ─────────────────────────────────────────────
              if (isSecond && targetRuns > 0)
                _TargetBadge(targetRuns: targetRuns),

              // ── Body ─────────────────────────────────────────────────────
              // Wrapped in Expanded + SingleChildScrollView so that only
              // this card's batting/bowling content scrolls (via D-pad
              // focus autoscroll) while the header stays put and the rest
              // of the Match Detail page never moves.
              if (_loading)
                _LoadingBody()
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionDivider(label: 'Batting', color: _C.accent),
                        _BatsmenTable(batsmen: _batsmen),
                        const SizedBox(height: 2),
                        _SectionDivider(label: 'Bowling', color: _C.purple),
                        _BowlersTable(bowlers: _bowlers),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // The innings card is a plain, non-focusable subtree. Focus lives only
    // on the individual batsman/bowler rows inside it (see _BatsmenTable /
    // _BowlersTable below), so the card itself is never a stop in the
    // D-pad traversal order.
    return cardContent;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INNINGS HEADER
// ═══════════════════════════════════════════════════════════════════════════════
class _InningsHeader extends StatelessWidget {
  final String innLabel;
  final String battingTeam;
  final bool loading;
  final int totalRuns;
  final int totalWickets;
  final String oversDisplay;

  const _InningsHeader({
    required this.innLabel,
    required this.battingTeam,
    required this.loading,
    required this.totalRuns,
    required this.totalWickets,
    required this.oversDisplay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.02),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Stack(
        children: [
          // Top shimmer
          Positioned(
            top: -12, left: 0, right: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: innings label + team name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Innings pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _C.accent.withOpacity(0.2)),
                      ),
                      child: Text(
                        innLabel.toUpperCase(),
                        style: TextStyle(
                          color: _C.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Team avatar + name
                    Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                _C.accent.withOpacity(0.2),
                                _C.accentDim.withOpacity(0.07),
                              ],
                            ),
                            border: Border.all(
                                color: _C.accent.withOpacity(0.3), width: 1),
                          ),
                          child: Center(
                            child: Text(
                              battingTeam.isNotEmpty
                                  ? battingTeam[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: _C.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            battingTeam,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              // Right: score
              if (loading)
                SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _C.accent,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Runs / Wickets
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$totalRuns',
                          style: const TextStyle(
                            color: _C.orange,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          '/$totalWickets',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Overs
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_cricket,
                            color: Colors.white.withOpacity(0.22), size: 11),
                        const SizedBox(width: 4),
                        Text(
                          '$oversDisplay ov',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.38),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TARGET BADGE
// ═══════════════════════════════════════════════════════════════════════════════
class _TargetBadge extends StatelessWidget {
  final num targetRuns;
  const _TargetBadge({required this.targetRuns});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _C.orange.withOpacity(0.14),
              _C.orange.withOpacity(0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _C.orange.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(color: _C.orange.withOpacity(0.1), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, color: _C.orange, size: 11),
            const SizedBox(width: 6),
            Text(
              'Target: $targetRuns',
              style: const TextStyle(
                color: _C.orange,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION DIVIDER
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionDivider extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionDivider({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Container(
            width: 3, height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.25), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOADING BODY
// ═══════════════════════════════════════════════════════════════════════════════
class _LoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  backgroundColor: Color(0xFF0F1E35),
                  valueColor: AlwaysStoppedAnimation<Color>(_C.accent),
                  minHeight: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Loading scorecard…',
              style: TextStyle(
                color: Colors.white.withOpacity(0.22),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATSMEN TABLE
// ═══════════════════════════════════════════════════════════════════════════════
class _BatsmenTable extends StatelessWidget {
  final List<Map<String, dynamic>> batsmen;
  const _BatsmenTable({required this.batsmen});

  @override
  Widget build(BuildContext context) {
    if (batsmen.isEmpty) {
      return _EmptyDataRow(message: 'No batting data yet');
    }

    final sorted = [...batsmen]..sort((a, b) {
      final aStrike =
      (a['isOnStrike'] == true || a['onStrike'] == true) ? 0 : 1;
      final bStrike =
      (b['isOnStrike'] == true || b['onStrike'] == true) ? 0 : 1;
      if (aStrike != bStrike) return aStrike.compareTo(bStrike);
      return ((b['runs'] ?? 0) as num)
          .compareTo((a['runs'] ?? 0) as num);
    });

    return Column(
      children: [
        // Table header row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Batter',
                  style: TextStyle(
                    color: Color(0xFF5A6A8A),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              _TH('R'), _TH('B'), _TH('4s'), _TH('6s'), _TH('SR'),
            ],
          ),
        ),
        Container(height: 1, color: Colors.white.withOpacity(0.06)),
        // Each row gets its own FocusNode via _TvFocusableRow so the D-pad
        // can move between batsmen individually. A stable key (player
        // name + index) keeps each row's focus/scroll state attached to
        // the same FocusNode across rebuilds even as sort order changes
        // (e.g. when strike changes).
        ...sorted.asMap().entries.map((entry) {
          final index = entry.key;
          final b = entry.value;
          final name = (b['playerName'] ?? b['name'] ?? 'Unknown').toString();
          return _TvFocusableRow(
            key: ValueKey('batsman-$name-$index'),
            debugLabel: 'Batsman-$name',
            builder: (context, focused) =>
                _focusHighlightWrap(focused: focused, child: _BatsmanRow(b: b)),
          );
        }),
      ],
    );
  }
}

class _BatsmanRow extends StatelessWidget {
  final Map<String, dynamic> b;
  const _BatsmanRow({required this.b});

  @override
  Widget build(BuildContext context) {
    final name      = (b['playerName'] ?? b['name'] ?? 'Unknown').toString();
    final runs      = (b['runs'] ?? 0) as num;
    final balls     = (b['ballsFaced'] ?? 0) as num;
    final fours     = (b['fours'] ?? 0) as num;
    final sixes     = (b['sixes'] ?? 0) as num;
    final isOut     = b['isOut'] == true;
    final onStrike  = b['isOnStrike'] == true || b['onStrike'] == true;
    final dismissal = (b['dismissalType'] ?? '').toString().trim();
    final sr        = balls > 0
        ? ((runs / balls) * 100).toStringAsFixed(1)
        : '0.0';
    final srVal     = double.tryParse(sr) ?? 0.0;

    // Milestone colour
    final runsColor = runs >= 100
        ? _C.gold
        : runs >= 50
        ? _C.orange
        : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: onStrike
            ? _C.accent.withOpacity(0.04)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Player name cell
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Strike indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 3,
                  height: onStrike ? 24 : 0,
                  decoration: BoxDecoration(
                    color: _C.orange,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: onStrike
                        ? [BoxShadow(color: _C.orange.withOpacity(0.6), blurRadius: 4)]
                        : [],
                  ),
                ),
                SizedBox(width: onStrike ? 8 : 0),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (onStrike) ...[
                            Icon(Icons.sports_cricket,
                                color: _C.orange, size: 11),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              name.length > 16
                                  ? '${name.substring(0, 16)}…'
                                  : name,
                              style: TextStyle(
                                color: isOut
                                    ? Colors.white.withOpacity(0.35)
                                    : onStrike
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.75),
                                fontSize: 13,
                                fontWeight: onStrike
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isOut && dismissal.isNotEmpty)
                        Text(
                          dismissal,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.28),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (!isOut && !onStrike)
                        Text(
                          'not out',
                          style: TextStyle(
                            color: _C.success.withOpacity(0.5),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Data cells
          _TD('$runs', bold: true, color: runsColor),
          _TD('$balls', color: Colors.white.withOpacity(0.5)),
          _TD('$fours', color: Colors.white.withOpacity(0.65)),
          _TD('$sixes',
              color: sixes > 0 ? _C.accent : Colors.white.withOpacity(0.65)),
          _TD(
            sr,
            color: srVal >= 150
                ? _C.success
                : srVal >= 100
                ? Colors.white.withOpacity(0.8)
                : Colors.white.withOpacity(0.4),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOWLERS TABLE
// ═══════════════════════════════════════════════════════════════════════════════
class _BowlersTable extends StatelessWidget {
  final List<Map<String, dynamic>> bowlers;
  const _BowlersTable({required this.bowlers});

  @override
  Widget build(BuildContext context) {
    if (bowlers.isEmpty) {
      return _EmptyDataRow(message: 'No bowling data yet');
    }

    final sorted = [...bowlers]
      ..sort((a, b) => ((b['wickets'] ?? 0) as num)
          .compareTo((a['wickets'] ?? 0) as num));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Bowler',
                  style: TextStyle(
                    color: Color(0xFF5A6A8A),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              _TH('O'), _TH('R'), _TH('W'), _TH('Eco'),
            ],
          ),
        ),
        Container(height: 1, color: Colors.white.withOpacity(0.06)),
        // Each row gets its own FocusNode via _TvFocusableRow so the D-pad
        // can move between bowlers individually.
        ...sorted.asMap().entries.map((entry) {
          final index = entry.key;
          final b = entry.value;
          final name = (b['playerName'] ?? b['name'] ?? 'Unknown').toString();
          return _TvFocusableRow(
            key: ValueKey('bowler-$name-$index'),
            debugLabel: 'Bowler-$name',
            builder: (context, focused) =>
                _focusHighlightWrap(focused: focused, child: _BowlerRow(b: b)),
          );
        }),
      ],
    );
  }
}

class _BowlerRow extends StatelessWidget {
  final Map<String, dynamic> b;
  const _BowlerRow({required this.b});

  @override
  Widget build(BuildContext context) {
    final name       = (b['playerName'] ?? b['name'] ?? 'Unknown').toString();
    final overs      = (b['overs'] ?? b['balls'] ?? 0);
    final runs       = (b['runsConceded'] ?? b['runs'] ?? 0) as num;
    final wkts       = (b['wickets'] ?? 0) as num;
    final eco        = (b['economy'] ?? 0) as num;
    final isBowling  = b['isBowling'] == true;
    final ecoVal     = eco.toDouble();

    final ecoColor = ecoVal <= 6
        ? _C.success
        : ecoVal >= 12
        ? _C.danger
        : Colors.white.withOpacity(0.55);

    final wktsColor = wkts >= 3
        ? _C.orange
        : wkts > 0
        ? Colors.white.withOpacity(0.9)
        : Colors.white.withOpacity(0.55);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isBowling ? _C.purple.withOpacity(0.05) : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Active bowling indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 3,
                  height: isBowling ? 24 : 0,
                  decoration: BoxDecoration(
                    color: _C.purple,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isBowling
                        ? [BoxShadow(color: _C.purple.withOpacity(0.6), blurRadius: 4)]
                        : [],
                  ),
                ),
                SizedBox(width: isBowling ? 8 : 0),

                if (isBowling) ...[
                  Icon(Icons.sports_baseball,
                      color: _C.purple, size: 11),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    name.length > 16
                        ? '${name.substring(0, 16)}…'
                        : name,
                    style: TextStyle(
                      color: isBowling
                          ? Colors.white
                          : Colors.white.withOpacity(0.65),
                      fontSize: 13,
                      fontWeight:
                      isBowling ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _TD('$overs', color: Colors.white.withOpacity(0.55)),
          _TD('$runs',  color: Colors.white.withOpacity(0.65)),
          _TD('$wkts',  bold: wkts >= 3, color: wktsColor),
          _TD(ecoVal.toStringAsFixed(1), color: ecoColor),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED TABLE CELLS
// ═══════════════════════════════════════════════════════════════════════════════
class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF5A6A8A),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TD extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;

  const _TD(this.text, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? Colors.white.withOpacity(0.65),
          fontSize: 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          height: 1.1,
        ),
      ),
    );
  }
}

// ─── Empty Data Row ───────────────────────────────────────────────────────────
class _EmptyDataRow extends StatelessWidget {
  final String message;
  const _EmptyDataRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.white.withOpacity(0.2), size: 14),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}