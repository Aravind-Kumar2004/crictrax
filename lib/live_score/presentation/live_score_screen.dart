import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/models/repositories/live_score_repository.dart';

class LiveScoreScreen extends StatefulWidget {
  final String matchId;
  final String tournamentId;
  final String team1Name;
  final String team2Name;

  const LiveScoreScreen({
    Key? key,
    required this.matchId,
    required this.tournamentId,
    required this.team1Name,
    required this.team2Name,
  }) : super(key: key);

  @override
  State<LiveScoreScreen> createState() => _LiveScoreScreenState();
}

class _LiveScoreScreenState extends State<LiveScoreScreen> {
  final _repo = LiveScoreRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_cricket,
                        color: Colors.white.withOpacity(0.08), size: 120),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.team1Name}  vs  ${widget.team2Name}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _repo.watchInnings(widget.tournamentId, widget.matchId),
              builder: (context, inningsSnap) {
                if (!inningsSnap.hasData || inningsSnap.data!.docs.isEmpty) {
                  return _buildWaitingBar();
                }
                final currentDoc = inningsSnap.data!.docs.last;
                final innData = currentDoc.data() as Map<String, dynamic>;
                return _buildScoreBar(currentDoc.id, innData);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingBar() {
    return Container(
      height: 92,
      color: const Color(0xFF0A0E1A),
      child: Center(
        child: Text(
          'Waiting for match to start...',
          style: TextStyle(
              color: Colors.white.withOpacity(0.4), fontSize: 14),
        ),
      ),
    );
  }

  String _resolveBattingTeamName(Map<String, dynamic> innData) {
    final name = (innData['battingTeamName'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final id = (innData['battingTeamId'] ?? '').toString().trim();
    if (id == widget.team1Name) return widget.team1Name;
    if (id == widget.team2Name) return widget.team2Name;
    if (id.length > 15) return widget.team1Name;

    return id.isNotEmpty ? id : widget.team1Name;
  }

  String _resolveOpponentName(String battingTeamName) {
    if (battingTeamName == widget.team1Name) return widget.team2Name;
    if (battingTeamName == widget.team2Name) return widget.team1Name;
    if (widget.team1Name.isNotEmpty &&
        battingTeamName
            .toLowerCase()
            .contains(widget.team1Name.toLowerCase())) {
      return widget.team2Name;
    }
    return widget.team2Name;
  }

  Widget _buildScoreBar(String inningsId, Map<String, dynamic> innData) {
    final battingTeamName = _resolveBattingTeamName(innData);
    final opponentName = _resolveOpponentName(battingTeamName);

    final runs = innData['totalRuns'] ?? innData['runs'] ?? 0;
    final wickets = innData['totalWickets'] ?? innData['wickets'] ?? 0;
    final overs = innData['totalOvers'] ?? innData['overs'] ?? 0;
    final crr = innData['currentRunRate'] ?? innData['crr'] ?? 0.0;
    final lastBalls = _parseLastBalls(innData);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF08162E),
        border:
        Border(top: BorderSide(color: Color(0xFF1E3A6E), width: 1.5)),
      ),
      height: 92, // fixed — prevents all overflow
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // COL 1
          _Col1BattingTeam(
            teamName: battingTeamName,
            runs: runs,
            wickets: wickets,
            overs: overs,
          ),
          _vDivider(),
          // COL 2
          Expanded(
            flex: 36,
            child: StreamBuilder<QuerySnapshot>(
              stream: _repo.watchBatsmen(
                  widget.tournamentId, widget.matchId, inningsId),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox();
                final batters = snap.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .where((b) => b['isOut'] != true)
                    .toList();
                return _Col2Batsmen(batters: batters);
              },
            ),
          ),
          _vDivider(),
          // COL 3
          Expanded(
            flex: 42,
            child: StreamBuilder<QuerySnapshot>(
              stream: _repo.watchBowlers(
                  widget.tournamentId, widget.matchId, inningsId),
              builder: (context, snap) {
                Map<String, dynamic>? bowler;
                if (snap.hasData && snap.data!.docs.isNotEmpty) {
                  final bowling = snap.data!.docs
                      .map((d) => d.data() as Map<String, dynamic>)
                      .where((b) => b['isBowling'] == true)
                      .toList();
                  bowler = bowling.isNotEmpty
                      ? bowling.first
                      : snap.data!.docs.last.data()
                  as Map<String, dynamic>;
                }
                return _Col3Panel(
                  crr: crr,
                  bowler: bowler,
                  opponentName: opponentName,
                  lastBalls: lastBalls,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<String> _parseLastBalls(Map<String, dynamic> innData) {
    try {
      final raw =
          innData['lastSixBalls'] ?? innData['recentBalls'] ?? [];
      if (raw is List) {
        return raw.map((e) => e.toString()).take(6).toList();
      }
    } catch (_) {}
    return [];
  }

  Widget _vDivider() => Container(
    width: 1,
    color: Colors.white.withOpacity(0.12),
  );
}

// ═══════════════════════════════════════════════════════════════
// COL 1 — [Badge] [Name / Overs]  [Score / Wkts]
// ═══════════════════════════════════════════════════════════════
class _Col1BattingTeam extends StatelessWidget {
  final String teamName;
  final dynamic runs, wickets, overs;

  const _Col1BattingTeam({
    required this.teamName,
    required this.runs,
    required this.wickets,
    required this.overs,
  });

  String _abbr(String n) {
    if (n.isEmpty) return '—';
    final w = n.trim().split(RegExp(r'\s+'));
    if (w.length >= 2) return (w[0][0] + w[1][0]).toUpperCase();
    return n.substring(0, n.length.clamp(0, 4)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TeamBadge(teamName: teamName),
          const SizedBox(width: 8),
          // Name + Overs
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _abbr(teamName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$overs OVR',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Score
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$runs',
                style: const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                '-$wickets wkts',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COL 2 — ▶ Striker  Runs  Balls
//            Non-striker  Runs  Balls
// ═══════════════════════════════════════════════════════════════
class _Col2Batsmen extends StatelessWidget {
  final List<Map<String, dynamic>> batters;
  const _Col2Batsmen({required this.batters});

  @override
  Widget build(BuildContext context) {
    final sorted = [...batters]..sort((a, b) {
      final aS =
      (a['isOnStrike'] == true || a['onStrike'] == true) ? 0 : 1;
      final bS =
      (b['isOnStrike'] == true || b['onStrike'] == true) ? 0 : 1;
      return aS.compareTo(bS);
    });
    final display = sorted.take(2).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: display.map((b) {
          final name = (b['playerName'] ?? b['name'] ?? '').toString();
          final runs = b['runs'] ?? b['runsScored'] ?? 0;
          final balls = b['ballsFaced'] ?? b['balls'] ?? 0;
          final onStrike =
              b['isOnStrike'] == true || b['onStrike'] == true;

          final words = name.trim().split(RegExp(r'\s+'));
          final displayName = words.length >= 2
              ? words.last.toUpperCase()
              : name.length > 10
              ? '${name.substring(0, 10).toUpperCase()}.'
              : name.toUpperCase();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: onStrike
                      ? const Icon(Icons.play_arrow_rounded,
                      color: Color(0xFFFF6B35), size: 14)
                      : null,
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    displayName.isEmpty ? '—' : displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onStrike ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: onStrike
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$runs',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$balls',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COL 3 — [RUN-RATE square] [v Opp] [Bowler name / stats / balls]
// ═══════════════════════════════════════════════════════════════
class _Col3Panel extends StatelessWidget {
  final dynamic crr;
  final Map<String, dynamic>? bowler;
  final String opponentName;
  final List<String> lastBalls;

  const _Col3Panel({
    required this.crr,
    required this.opponentName,
    this.bowler,
    this.lastBalls = const [],
  });

  @override
  Widget build(BuildContext context) {
    final crrStr = crr is double
        ? crr.toStringAsFixed(2)
        : double.tryParse(crr.toString())?.toStringAsFixed(2) ?? '0.00';

    final bowlerName =
    (bowler?['playerName'] ?? bowler?['name'] ?? '—').toString();
    final wkts = bowler?['wickets'] ?? 0;
    final runsConceded = bowler?['runsConceded'] ?? bowler?['runs'] ?? 0;
    final bowlerOvers = bowler?['overs'] ?? 0;

    final bWords = bowlerName.trim().split(RegExp(r'\s+'));
    final bowlerDisplay = bWords.length >= 2
        ? bWords.last.toUpperCase()
        : bowlerName.length > 8
        ? bowlerName.substring(0, 8).toUpperCase()
        : bowlerName.toUpperCase();

    final oWords = opponentName.trim().split(RegExp(r'\s+'));
    final oppAbbr = oWords.length >= 2
        ? (oWords[0][0] + oWords[1][0]).toUpperCase()
        : opponentName
        .substring(0, opponentName.length.clamp(0, 3))
        .toUpperCase();

    final padded = List<String>.filled(6, '');
    for (int i = 0; i < lastBalls.length && i < 6; i++) {
      padded[i] = lastBalls[i];
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Run Rate — square filling full bar height
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            color: const Color(0xFF1565C0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  crrStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'RUN\nRATE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFBBDEFB),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Opponent
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('v',
                  style:
                  TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 3),
              _TeamBadge(teamName: opponentName),
              const SizedBox(height: 3),
              Text(
                oppAbbr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // Bowler + ball dots
        Expanded(
          child: Padding(
            padding:
            const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bowlerDisplay == '—' ? '—' : bowlerDisplay,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Text(
                      '$wkts-$runsConceded',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$bowlerOvers',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: padded.map((ball) {
                    final empty = ball.isEmpty;
                    final col = _ballColor(ball);
                    return Container(
                      width: 19,
                      height: 15,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: empty
                            ? Colors.white.withOpacity(0.07)
                            : col.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: empty
                              ? Colors.white.withOpacity(0.18)
                              : col.withOpacity(0.8),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: empty
                            ? null
                            : Text(
                          ball,
                          style: TextStyle(
                            color: col,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _ballColor(String ball) {
    switch (ball) {
      case 'W':
        return const Color(0xFFFF3B30);
      case '6':
        return const Color(0xFF34C759);
      case '4':
        return const Color(0xFF007AFF);
      case '0':
        return Colors.white30;
      default:
        return Colors.white70;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Shared — Team Badge
// ═══════════════════════════════════════════════════════════════
class _TeamBadge extends StatelessWidget {
  final String teamName;
  const _TeamBadge({required this.teamName});

  @override
  Widget build(BuildContext context) {
    final initial =
    teamName.isNotEmpty ? teamName[0].toUpperCase() : '?';
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF00A3FF).withOpacity(0.15),
        border: Border.all(color: const Color(0xFF00A3FF), width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Color(0xFF00A3FF),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}