import 'package:flutter/material.dart';
import '../../../match_detail/data/repositories/match_detail_repository.dart';

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

  /// Resolve a team ID to a display name using the passed team names
  String _resolveTeamName(String? id) {
    if (id == null || id.isEmpty) return '—';
    if (id == widget.team1Name) return widget.team1Name;
    if (id == widget.team2Name) return widget.team2Name;
    // Check if it matches the IDs stored on the innings doc itself and
    // map them to the display names we received from the match card.
    // The innings doc has battingTeamId / bowlingTeamId as raw UUIDs.
    // We can't directly map UUID → name here, so fall back to the name
    // fields if they exist, otherwise try team1Name for inn 1, team2Name for inn 2.
    final battingTeamName =
    (widget.innData['battingTeamName'] ?? '').toString().trim();
    if (battingTeamName.isNotEmpty) return battingTeamName;
    return widget.inningsNumber == 1 ? widget.team1Name : widget.team2Name;
  }

  String _battingTeamName() {
    final name =
    (widget.innData['battingTeamName'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    // Fall back: 1st innings = team1, 2nd innings = team2
    return widget.inningsNumber == 1 ? widget.team1Name : widget.team2Name;
  }

  // Compute total runs + wickets from batsmen subcollection
  int get _totalRuns =>
      _batsmen.fold(0, (s, b) => s + ((b['runs'] ?? 0) as num).toInt());
  int get _totalWickets =>
      _batsmen.where((b) => b['isOut'] == true).length;
  int get _totalBalls =>
      _batsmen.fold(
          0, (s, b) => s + ((b['ballsFaced'] ?? 0) as num).toInt());

  String get _oversDisplay {
    final comp = _totalBalls ~/ 6;
    final rem = _totalBalls % 6;
    return '$comp.$rem';
  }

  @override
  Widget build(BuildContext context) {
    final battingTeam = _battingTeamName();
    final targetRuns = (widget.innData['targetRuns'] ?? 0) as num;
    final isSecond = widget.innData['isSecondInnings'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Innings ${widget.inningsNumber}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      battingTeam,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF00A3FF)))
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$_totalRuns',
                            style: const TextStyle(
                                color: Color(0xFFFF7A45),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                height: 1),
                          ),
                          Text(
                            '/$_totalWickets',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Text(
                        '$_oversDisplay overs',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── Target badge for 2nd innings
          if (isSecond && targetRuns > 0)
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A45).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFF7A45).withOpacity(0.4)),
                ),
                child: Text(
                  'Target: $targetRuns',
                  style: const TextStyle(
                      color: Color(0xFFFF7A45),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF00A3FF))),
            )
          else ...[
            // ── Batsmen table
            _sectionHeader('Batting'),
            _batsmenTable(),

            const SizedBox(height: 8),

            // ── Bowlers table
            _sectionHeader('Bowling'),
            _bowlersTable(),

            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        title,
        style: const TextStyle(
            color: Color(0xFF00A3FF),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _batsmenTable() {
    if (_batsmen.isEmpty) {
      return _emptyRow('No batting data');
    }

    // Sort: on-strike first, then by runs desc
    final sorted = [..._batsmen]..sort((a, b) {
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
        // Table header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              const Expanded(
                  child: Text('Batter',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
              _thCell('R'),
              _thCell('B'),
              _thCell('4s'),
              _thCell('6s'),
              _thCell('SR'),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        ...sorted.map((b) => _batsmanRow(b)),
      ],
    );
  }

  Widget _batsmanRow(Map<String, dynamic> b) {
    final name = (b['playerName'] ?? b['name'] ?? 'Unknown').toString();
    final runs = (b['runs'] ?? 0) as num;
    final balls = (b['ballsFaced'] ?? 0) as num;
    final fours = (b['fours'] ?? 0) as num;
    final sixes = (b['sixes'] ?? 0) as num;
    final isOut = b['isOut'] == true;
    final onStrike =
        b['isOnStrike'] == true || b['onStrike'] == true;
    final dismissal =
    (b['dismissalType'] ?? '').toString().trim();
    final sr = balls > 0
        ? ((runs / balls) * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        border: const Border(
            bottom: BorderSide(color: Colors.white10, width: 0.5)),
        color: onStrike
            ? const Color(0xFF00A3FF).withOpacity(0.05)
            : Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onStrike)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.sports_cricket,
                            color: Color(0xFFFF7A45), size: 12),
                      ),
                    Flexible(
                      child: Text(
                        name.length > 16
                            ? '${name.substring(0, 16)}…'
                            : name,
                        style: TextStyle(
                          color: isOut
                              ? Colors.white54
                              : (onStrike
                              ? Colors.white
                              : Colors.white70),
                          fontSize: 13,
                          fontWeight: onStrike
                              ? FontWeight.w700
                              : FontWeight.w500,
                          decoration: isOut
                              ? TextDecoration.none
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isOut && dismissal.isNotEmpty)
                  Text(
                    dismissal,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10),
                  ),
                if (!isOut && !onStrike)
                  const Text('not out',
                      style:
                      TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          _tdCell('$runs',
              bold: true,
              color: runs >= 50
                  ? const Color(0xFFFFD700)
                  : Colors.white),
          _tdCell('$balls'),
          _tdCell('$fours'),
          _tdCell('$sixes'),
          _tdCell(sr,
              color: double.tryParse(sr) != null &&
                  double.parse(sr) >= 150
                  ? const Color(0xFF34C759)
                  : Colors.white60),
        ],
      ),
    );
  }

  Widget _bowlersTable() {
    if (_bowlers.isEmpty) {
      return _emptyRow('No bowling data');
    }

    final sorted = [..._bowlers]
      ..sort((a, b) => ((b['wickets'] ?? 0) as num)
          .compareTo((a['wickets'] ?? 0) as num));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              const Expanded(
                  child: Text('Bowler',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
              _thCell('O'),
              _thCell('R'),
              _thCell('W'),
              _thCell('Eco'),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        ...sorted.map((b) => _bowlerRow(b)),
      ],
    );
  }

  Widget _bowlerRow(Map<String, dynamic> b) {
    final name = (b['playerName'] ?? b['name'] ?? 'Unknown').toString();
    final overs = (b['overs'] ?? b['balls'] ?? 0);
    final runs = (b['runsConceded'] ?? b['runs'] ?? 0) as num;
    final wkts = (b['wickets'] ?? 0) as num;
    final eco = (b['economy'] ?? 0) as num;
    final isBowling = b['isBowling'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        border: const Border(
            bottom: BorderSide(color: Colors.white10, width: 0.5)),
        color: isBowling
            ? const Color(0xFF8E5CFF).withOpacity(0.06)
            : Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (isBowling)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.sports_baseball,
                        color: Color(0xFF8E5CFF), size: 12),
                  ),
                Flexible(
                  child: Text(
                    name.length > 16
                        ? '${name.substring(0, 16)}…'
                        : name,
                    style: TextStyle(
                      color: isBowling ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isBowling
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _tdCell('$overs'),
          _tdCell('$runs'),
          _tdCell('$wkts',
              bold: true,
              color: (wkts >= 3)
                  ? const Color(0xFFFF7A45)
                  : Colors.white),
          _tdCell(eco.toStringAsFixed(1),
              color: eco <= 6
                  ? const Color(0xFF34C759)
                  : eco >= 12
                  ? Colors.redAccent
                  : Colors.white60),
        ],
      ),
    );
  }

  Widget _thCell(String t) => SizedBox(
    width: 36,
    child: Text(t,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600)),
  );

  Widget _tdCell(String t, {bool bold = false, Color? color}) => SizedBox(
    width: 36,
    child: Text(t,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color ?? Colors.white70,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
  );

  Widget _emptyRow(String msg) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Text(msg,
        style:
        const TextStyle(color: Colors.white38, fontSize: 13)),
  );
}