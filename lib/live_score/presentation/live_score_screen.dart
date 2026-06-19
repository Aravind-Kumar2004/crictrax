import 'dart:async';

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
  bool _hasNavigatedAway = false;
  Timer? _autoDismissTimer;
  String? _lastInningsId;
  Map<String, dynamic>? _lastInningsData;

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/stadium_bg.jpeg', fit: BoxFit.cover),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.45))),
          SafeArea(
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
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
                        Icon(Icons.sports_cricket, color: Colors.white.withOpacity(0.2), size: 120),
                        const SizedBox(height: 16),
                        Text(
                          '${widget.team1Name} vs ${widget.team2Name}',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),

                // Listen to the MATCH document itself for completion status
                StreamBuilder<DocumentSnapshot>(
                  stream: _repo.watchMatch(widget.tournamentId, widget.matchId),
                  builder: (context, matchSnap) {
                    if (matchSnap.hasData && matchSnap.data!.exists) {
                      final matchData = matchSnap.data!.data() as Map<String, dynamic>? ?? {};
                      final isCompleted = matchData['isCompleted'] == true;

                      if (isCompleted && !_hasNavigatedAway) {
                        _hasNavigatedAway = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _showMatchEndedAndPop(context, matchData);
                          }
                        });
                      }
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: _repo.watchInnings(widget.tournamentId, widget.matchId),
                      builder: (context, inningsSnap) {
                        if (inningsSnap.hasError) {
                          return _buildErrorBar(inningsSnap.error.toString());
                        }

                        if (inningsSnap.connectionState == ConnectionState.waiting) {
                          return _buildWaitingBar(label: 'Connecting...');
                        }

                        if (!inningsSnap.hasData || inningsSnap.data!.docs.isEmpty) {
                          return _buildWaitingBar(label: 'Waiting for match to start...');
                        }

                        final docs = inningsSnap.data!.docs;

                        // ── FIX: pick the CURRENT innings explicitly instead of trusting
                        // Firestore's unordered doc list. Prefer the innings flagged
                        // isSecondInnings == true (the most recently started one) if it
                        // exists; otherwise fall back to the only/first innings present.
                        // This replaces the old `docs.last` which depended on an
                        // orderBy that was silently filtering everything out.
                        final secondInningsDocs = docs.where((d) {
                          final data = d.data() as Map<String, dynamic>;
                          return data['isSecondInnings'] == true;
                        }).toList();

                        final currentDoc = secondInningsDocs.isNotEmpty
                            ? secondInningsDocs.first
                            : docs.first;

                        final innData = currentDoc.data() as Map<String, dynamic>;

                        _lastInningsId = currentDoc.id;
                        _lastInningsData = innData;

                        return _LiveScoreBar(
                          tournamentId: widget.tournamentId,
                          matchId: widget.matchId,
                          inningsId: currentDoc.id,
                          innData: innData,
                          team1Name: widget.team1Name,
                          team2Name: widget.team2Name,
                          repo: _repo,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMatchEndedAndPop(BuildContext context, Map<String, dynamic> matchData) {
    final resultText = matchData['result'] as String? ?? 'Match Completed';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0C1F3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.emoji_events, color: Color(0xFFFFD700)),
            SizedBox(width: 10),
            Text('Match Ended', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(resultText, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        actions: [
          ElevatedButton(
            onPressed: () => _dismissAndPop(dialogContext, context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A3FF)),
            child: const Text('Back to Tournament', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        _dismissAndPop(context, context);
      }
    });
  }

  void _dismissAndPop(BuildContext dialogContext, BuildContext screenContext) {
    _autoDismissTimer?.cancel();
    if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
    }
    if (Navigator.of(screenContext).canPop()) {
      Navigator.of(screenContext).pop();
    }
  }

  Widget _buildWaitingBar({String label = 'Waiting for match to start...'}) {
    // ── FIX: if we have a cached innings from before this snapshot,
    // show that instead of the generic waiting message. This covers
    // the innings-2 creation window where watchInnings briefly emits
    // an empty/incomplete snapshot.
    if (_lastInningsId != null && _lastInningsData != null) {
      return _LiveScoreBar(
        tournamentId: widget.tournamentId,
        matchId: widget.matchId,
        inningsId: _lastInningsId!,
        innData: _lastInningsData!,
        team1Name: widget.team1Name,
        team2Name: widget.team2Name,
        repo: _repo,
      );
    }

    return Container(
      height: 110,
      color: const Color(0xFF0A0E1A),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A3FF)),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBar(String error) {
    // ── FIX: surfaces real Firestore errors (missing index, permission
    // denied, etc) instead of masking them as "waiting for match".
    return Container(
      height: 110,
      color: const Color(0xFF2A0E0E),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Live data error: $error',
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════
// MAIN SCORE BAR — aggregates batsmen+bowlers to compute live totals
// ═══════════════════════════════════════════════════════════════
class _LiveScoreBar extends StatelessWidget {
  final String tournamentId;
  final String matchId;
  final String inningsId;
  final Map<String, dynamic> innData;
  final String team1Name;
  final String team2Name;
  final LiveScoreRepository repo;


  const _LiveScoreBar({
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
    required this.innData,
    required this.team1Name,
    required this.team2Name,
    required this.repo,
  });

  String _resolveBattingTeamName() {
    final name = (innData['battingTeamName'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final id = (innData['battingTeamId'] ?? '').toString().trim();
    if (id == team1Name) return team1Name;
    if (id == team2Name) return team2Name;
    return team1Name;
  }

  String _resolveOpponentName(String battingTeamName) {
    if (battingTeamName == team1Name) return team2Name;
    if (battingTeamName == team2Name) return team1Name;
    return team2Name;
  }

  @override
  Widget build(BuildContext context) {
    final battingTeamName = _resolveBattingTeamName();
    final opponentName = _resolveOpponentName(battingTeamName);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF071226), const Color(0xFF0C1F3D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: const Border(top: BorderSide(color: Color(0xFF1E3A6E), width: 2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      height: 110,
      child: StreamBuilder<QuerySnapshot>(
        stream: repo.watchBatsmen(tournamentId, matchId, inningsId),
        builder: (context, batSnap) {
          final allBatsmen = batSnap.hasData
              ? batSnap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList()
              : <Map<String, dynamic>>[];

          // Aggregate live totals from batsmen subcollection
          int totalRuns = 0;
          int totalWickets = 0;
          int totalBalls = 0;
          for (final b in allBatsmen) {
            totalRuns += (b['runs'] ?? 0) as int;
            totalBalls += (b['ballsFaced'] ?? 0) as int;
            if (b['isOut'] == true) totalWickets++;
          }

          // Fallback to innings-level fields if subcollection sum is zero but fields exist
          if (totalRuns == 0 && innData['totalRuns'] != null) {
            totalRuns = (innData['totalRuns'] as num).toInt();
          }
          if (totalWickets == 0 && innData['totalWickets'] != null) {
            totalWickets = (innData['totalWickets'] as num).toInt();
          }

          final completedOvers = totalBalls ~/ 6;
          final ballsInOver = totalBalls % 6;
          // If totalBalls is an exact multiple of 6 (an over just finished),
          // keep showing the over that JUST completed until the first ball
          // of the next over is actually recorded in the 'balls' subcollection.
          // Without this, the tracker briefly queries an over with zero docs
          // and renders as empty even though runs are already on the board.
          final currentOverNumber = (ballsInOver == 0 && totalBalls > 0)
              ? completedOvers - 1
              : completedOvers;
          final oversDisplay = innData['totalOvers'] != null && totalBalls == 0
              ? innData['totalOvers']
              : '$completedOvers.$ballsInOver';

          final activeBatsmen =
          allBatsmen.where((b) => b['isOut'] != true).toList();

          return StreamBuilder<QuerySnapshot>(
            stream: repo.watchBowlers(tournamentId, matchId, inningsId),
            builder: (context, bowlSnap) {
              Map<String, dynamic>? bowler;
              if (bowlSnap.hasData && bowlSnap.data!.docs.isNotEmpty) {
                final bowlers = bowlSnap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();
                final bowling = bowlers.where((b) => b['isBowling'] == true).toList();
                bowler = bowling.isNotEmpty ? bowling.first : bowlers.last;
              }

              final crr = totalBalls > 0
                  ? (totalRuns / totalBalls) * 6
                  : (innData['currentRunRate'] ?? 0.0);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Col1BattingTeam(
                    teamName: battingTeamName,
                    runs: totalRuns,
                    wickets: totalWickets,
                    overs: oversDisplay,
                  ),
                  _vDivider(),
                  Expanded(
                    flex: 32,
                    child: _Col2Batsmen(batters: activeBatsmen),
                  ),
                  _vDivider(),
                  Expanded(
                    flex: 46,
                    child: _Col3BallTracker(
                      crr: crr,
                      bowler: bowler,
                      opponentName: opponentName,
                      tournamentId: tournamentId,
                      matchId: matchId,
                      inningsId: inningsId,
                      repo: repo,
                      currentOverNumber: currentOverNumber,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _vDivider() => Container(width: 1.5, color: Colors.white.withOpacity(0.1));
}

// ═══════════════════════════════════════════════════════════════
// COL 1 — Batting team score
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
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TeamBadge(teamName: teamName, size: 40),
          const SizedBox(width: 12),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$overs OV',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$runs',
                    style: const TextStyle(
                      color: Color(0xFFFF7A45),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  Text(
                    '/$wickets',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                'WICKETS',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
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
// COL 2 — Batsmen
// ═══════════════════════════════════════════════════════════════
class _Col2Batsmen extends StatelessWidget {
  final List<Map<String, dynamic>> batters;
  const _Col2Batsmen({required this.batters});

  @override
  Widget build(BuildContext context) {
    final sorted = [...batters]..sort((a, b) {
      final aS = (a['isOnStrike'] == true || a['onStrike'] == true) ? 0 : 1;
      final bS = (b['isOnStrike'] == true || b['onStrike'] == true) ? 0 : 1;
      return aS.compareTo(bS);
    });
    final display = sorted.take(2).toList();

    if (display.isEmpty) {
      return Center(
        child: Text(
          'Yet to bat',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: display.map((b) {
          final name = (b['playerName'] ?? b['name'] ?? '').toString();
          final runs = b['runs'] ?? 0;
          final balls = b['ballsFaced'] ?? 0;
          final fours = b['fours'] ?? 0;
          final sixes = b['sixes'] ?? 0;
          final onStrike = b['isOnStrike'] == true || b['onStrike'] == true;

          final displayName = name.isEmpty
              ? 'Unknown'
              : (name.length > 12 ? '${name.substring(0, 12)}…' : name);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: onStrike
                      ? const Icon(Icons.sports_cricket, color: Color(0xFFFF7A45), size: 15)
                      : null,
                ),
                Expanded(
                  child: Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onStrike ? Colors.white : Colors.white60,
                      fontSize: 13,
                      fontWeight: onStrike ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$runs',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '($balls)',
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
                ),
                if (fours > 0 || sixes > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${fours}x4 ${sixes}x6',
                    style: TextStyle(
                      color: const Color(0xFF34C759).withOpacity(0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COL 3 — Run rate + bowler + ball-by-ball tracker (6 balls + extras)
// ═══════════════════════════════════════════════════════════════
class _Col3BallTracker extends StatelessWidget {
  final dynamic crr;
  final Map<String, dynamic>? bowler;
  final String opponentName;
  final String tournamentId;
  final String matchId;
  final String inningsId;
  final LiveScoreRepository repo;
  final int currentOverNumber;

  const _Col3BallTracker({
    required this.crr,
    required this.opponentName,
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
    required this.repo,
    required this.currentOverNumber,
    this.bowler,
  });

  @override
  Widget build(BuildContext context) {
    final crrStr = crr is double
        ? crr.toStringAsFixed(2)
        : double.tryParse(crr.toString())?.toStringAsFixed(2) ?? '0.00';

    final bowlerName = (bowler?['playerName'] ?? bowler?['name'] ?? '').toString();
    final wkts = bowler?['wickets'] ?? 0;
    final runsConceded = bowler?['runsConceded'] ?? bowler?['runs'] ?? 0;
    final bowlerOvers = bowler?['overs'] ?? 0;

    final bowlerDisplay = bowlerName.isEmpty
        ? 'No bowler yet'
        : (bowlerName.length > 14 ? '${bowlerName.substring(0, 14)}…' : bowlerName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Run rate block
        Container(
          width: 78,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                crrStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'RUN RATE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFBBDEFB),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),

        // Bowler info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sports_baseball, color: Colors.white54, size: 12),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        bowlerDisplay,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$wkts/$runsConceded',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$bowlerOvers ov',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Ball-by-ball tracker
        Expanded(
          flex: 2,
          child: _BallByBallTracker(
            tournamentId: tournamentId,
            matchId: matchId,
            inningsId: inningsId,
            repo: repo,
            overNumber: currentOverNumber,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Ball-by-ball tracker — 6 balls + extra slots for wide/noball/etc
// Reads the most recent over's deliveries from a 'balls' subcollection
// ═══════════════════════════════════════════════════════════════
class _BallByBallTracker extends StatelessWidget {
  final String tournamentId;
  final String matchId;
  final String inningsId;
  final LiveScoreRepository repo;
  final int overNumber;

  const _BallByBallTracker({
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
    required this.repo,
    required this.overNumber,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: repo.watchCurrentOverBalls(
          tournamentId, matchId, inningsId, overNumber),
      builder: (context, snap) {
        if (snap.hasError) {
          // Surfaces index/permission errors instead of silently showing empty chips.
          // If this fires, check Firestore console for a missing composite index
          // on (overNumber ==, ballInOver asc) in the 'balls' subcollection.
          debugPrint('watchCurrentOverBalls error: ${snap.error}');
        }
        final balls = snap.hasData
            ? snap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList()
            : <Map<String, dynamic>>[];

        final legalBalls = <Map<String, dynamic>>[];
        final extraBalls = <Map<String, dynamic>>[];

        for (final b in balls) {
          final isExtra = b['isWide'] == true ||
              b['isNoBall'] == true ||
              b['isBye'] == true ||
              b['isLegBye'] == true;
          if (isExtra) {
            extraBalls.add(b);
          } else {
            legalBalls.add(b);
          }
        }

        final mainSlots = List<Map<String, dynamic>?>.filled(6, null);
        for (int i = 0; i < legalBalls.length && i < 6; i++) {
          mainSlots[i] = legalBalls[i];
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OVER ${overNumber + 1}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  ...mainSlots.map((ball) => _BallChip(ball: ball)),
                  if (extraBalls.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(width: 1, height: 22, color: Colors.white.withOpacity(0.15)),
                    const SizedBox(width: 4),
                    ...extraBalls.take(2).map((ball) => _BallChip(ball: ball, isExtraSlot: true)),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BallChip extends StatelessWidget {
  final Map<String, dynamic>? ball;
  final bool isExtraSlot;

  const _BallChip({required this.ball, this.isExtraSlot = false});

  String _label() {
    if (ball == null) return '';
    if (ball!['isWicket'] == true) return 'W';
    if (ball!['isWide'] == true) return 'Wd';
    if (ball!['isNoBall'] == true) return 'Nb';
    if (ball!['isBye'] == true) return 'B';
    if (ball!['isLegBye'] == true) return 'Lb';
    final runs = ball!['runs'] ?? 0;
    return '$runs';
  }

  Color _color() {
    if (ball == null) return Colors.white24;
    if (ball!['isWicket'] == true) return const Color(0xFFFF3B30);
    if (ball!['isWide'] == true || ball!['isNoBall'] == true) return const Color(0xFFFFB300);
    if (ball!['isBye'] == true || ball!['isLegBye'] == true) return const Color(0xFF9E9E9E);
    final runs = ball!['runs'] ?? 0;
    if (runs == 6) return const Color(0xFF34C759);
    if (runs == 4) return const Color(0xFF007AFF);
    if (runs == 0) return Colors.white38;
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    final empty = ball == null;
    final col = _color();
    final label = _label();

    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: empty ? Colors.white.withOpacity(0.05) : col.withOpacity(0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: empty ? Colors.white.withOpacity(0.15) : col,
          width: 1.2,
        ),
      ),
      child: Center(
        child: empty
            ? null
            : Text(
          label,
          style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Shared — Team Badge
// ═══════════════════════════════════════════════════════════════
class _TeamBadge extends StatelessWidget {
  final String teamName;
  final double size;
  const _TeamBadge({required this.teamName, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final initial = teamName.isNotEmpty ? teamName[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00A3FF).withOpacity(0.4), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}