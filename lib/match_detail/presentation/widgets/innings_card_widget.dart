import 'dart:ui';
import 'package:flutter/material.dart';
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

  // ── Business Logic (COMPLETELY UNCHANGED) ───────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
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

    return ClipRRect(
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
            mainAxisSize: MainAxisSize.min,
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
              if (_loading)
                _LoadingBody()
              else ...[
                _SectionDivider(label: 'Batting', color: _C.accent),
                _BatsmenTable(batsmen: _batsmen),
                const SizedBox(height: 4),
                _SectionDivider(label: 'Bowling', color: _C.purple),
                _BowlersTable(bowlers: _bowlers),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
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
            top: -18, left: 0, right: 0,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: innings label + team name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Innings pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
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
                    const SizedBox(height: 8),
                    // Team avatar + name
                    Row(
                      children: [
                        Container(
                          width: 32, height: 32,
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
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            battingTeam,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
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

              const SizedBox(width: 16),

              // Right: score
              if (loading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _C.accent,
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
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
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          '/$totalWickets',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Overs
                    Row(
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _C.orange.withOpacity(0.14),
              _C.orange.withOpacity(0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.orange.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(color: _C.orange.withOpacity(0.1), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, color: _C.orange, size: 13),
            const SizedBox(width: 7),
            Text(
              'Target: $targetRuns',
              style: const TextStyle(
                color: _C.orange,
                fontWeight: FontWeight.w800,
                fontSize: 13,
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 3, height: 14,
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
      padding: const EdgeInsets.symmetric(vertical: 32),
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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
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
        ...sorted.map((b) => _BatsmanRow(b: b)),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Strike indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 3,
                  height: onStrike ? 28 : 0,
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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
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
        ...sorted.map((b) => _BowlerRow(b: b)),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: BoxDecoration(
        color: isBowling ? _C.purple.withOpacity(0.05) : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Active bowling indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 3,
                  height: isBowling ? 28 : 0,
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
      width: 36,
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
      width: 36,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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