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
            // Back button row
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

            // Main broadcast video placeholder area
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

            // Broadcast-style score bar at bottom
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
      height: 90,
      color: const Color(0xFF0A0E1A),
      child: Center(
        child: Text(
          'Waiting for match to start...',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildScoreBar(String inningsId, Map<String, dynamic> innData) {
    final battingTeamName =
    (innData['battingTeamName'] ?? innData['battingTeamId'] ?? '') as String;
    final runs = innData['totalRuns'] ?? innData['runs'] ?? 0;
    final wickets = innData['totalWickets'] ?? innData['wickets'] ?? 0;
    final overs = innData['totalOvers'] ?? innData['overs'] ?? 0;
    final crr = innData['currentRunRate'] ?? innData['crr'] ?? 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1A3D),
        border: Border(top: BorderSide(color: Color(0xFF1E3A6E), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Column 1: Batting team + score ──
            Expanded(
              flex: 28,
              child: _Col1BattingTeam(
                teamName: battingTeamName,
                runs: runs,
                wickets: wickets,
                overs: overs,
              ),
            ),

            _divider(),

            // ── Column 2: Striker + Non-striker ──
            Expanded(
              flex: 38,
              child: StreamBuilder<QuerySnapshot>(
                stream: _repo.watchBatsmen(
                    widget.tournamentId, widget.matchId, inningsId),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox();
                  final batters = snap.data!.docs
                      .map((d) => d.data() as Map<String, dynamic>)
                      .where((b) => b['isOut'] != true)
                      .take(2)
                      .toList();
                  return _Col2Batsmen(batters: batters);
                },
              ),
            ),

            _divider(),

            // ── Column 3: Run rate + Bowler ──
            Expanded(
              flex: 34,
              child: StreamBuilder<QuerySnapshot>(
                stream: _repo.watchBowlers(
                    widget.tournamentId, widget.matchId, inningsId),
                builder: (context, snap) {
                  Map<String, dynamic>? bowler;
                  if (snap.hasData && snap.data!.docs.isNotEmpty) {
                    bowler = snap.data!.docs
                        .map((d) => d.data() as Map<String, dynamic>)
                        .firstWhere(
                          (b) => b['isBowling'] == true,
                      orElse: () => snap.data!.docs.last.data()
                      as Map<String, dynamic>,
                    );
                  }
                  return _Col3RunRateBowler(crr: crr, bowler: bowler);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    color: Colors.white.withOpacity(0.12),
  );
}

// ─────────────────────────────────────────
// Column 1 – Batting team name, score, overs
// ─────────────────────────────────────────
class _Col1BattingTeam extends StatelessWidget {
  final String teamName;
  final dynamic runs;
  final dynamic wickets;
  final dynamic overs;

  const _Col1BattingTeam({
    required this.teamName,
    required this.runs,
    required this.wickets,
    required this.overs,
  });

  @override
  Widget build(BuildContext context) {
    // Abbreviate long team names to avoid overflow
    final abbr = teamName.length > 10
        ? teamName.substring(0, 3).toUpperCase()
        : teamName.toUpperCase();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team name badge row
        Row(
          children: [
            _TeamBadge(teamName: teamName),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                abbr,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Score
        Text(
          '$runs-$wickets',
          style: const TextStyle(
            color: Color(0xFFFF6B35),
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        // Overs
        Text(
          '$overs OVR',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Column 2 – Striker & Non-striker
// ─────────────────────────────────────────
class _Col2Batsmen extends StatelessWidget {
  final List<Map<String, dynamic>> batters;

  const _Col2Batsmen({required this.batters});

  @override
  Widget build(BuildContext context) {
    // Sort: striker first
    final sorted = [...batters]..sort((a, b) {
      final aStrike =
      (a['isOnStrike'] == true || a['onStrike'] == true) ? 0 : 1;
      final bStrike =
      (b['isOnStrike'] == true || b['onStrike'] == true) ? 0 : 1;
      return aStrike.compareTo(bStrike);
    });

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sorted.map((b) {
        final name = (b['playerName'] ?? '').toString();
        final runs = b['runs'] ?? 0;
        final balls = b['ballsFaced'] ?? 0;
        final onStrike =
            b['isOnStrike'] == true || b['onStrike'] == true;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              // Strike indicator
              SizedBox(
                width: 14,
                child: onStrike
                    ? const Icon(Icons.play_arrow,
                    color: Color(0xFFFF6B35), size: 12)
                    : null,
              ),
              // Player name
              Expanded(
                child: Text(
                  name.isEmpty ? '—' : name.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onStrike ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight:
                    onStrike ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Runs
              Text(
                '$runs',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 3),
              // Balls
              Text(
                '($balls)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────
// Column 3 – Run rate + Bowler stats
// ─────────────────────────────────────────
class _Col3RunRateBowler extends StatelessWidget {
  final dynamic crr;
  final Map<String, dynamic>? bowler;

  const _Col3RunRateBowler({required this.crr, this.bowler});

  @override
  Widget build(BuildContext context) {
    final crrStr =
    crr is double ? crr.toStringAsFixed(2) : crr.toString();

    final bowlerName =
    bowler != null ? (bowler!['playerName'] ?? '').toString() : '—';
    final wkts = bowler?['wickets'] ?? 0;
    final runsConceded = bowler?['runsConceded'] ?? 0;
    final bowlerOvers = bowler?['overs'] ?? 0;
    final bowlerAbbr = bowlerName.length > 10
        ? bowlerName.substring(0, 10)
        : bowlerName;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Run-rate chip
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0D3B6E),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: const Color(0xFF1E6BB0).withOpacity(0.6), width: 1),
          ),
          child: Column(
            children: [
              Text(
                crrStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'RUN-RATE',
                style: TextStyle(
                  color: Color(0xFF7FBFFF),
                  fontSize: 8,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Bowler row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                bowlerAbbr.isEmpty ? '—' : bowlerAbbr.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$wkts-$runsConceded',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$bowlerOvers',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Shared team badge widget
// ─────────────────────────────────────────
class _TeamBadge extends StatelessWidget {
  final String teamName;

  const _TeamBadge({required this.teamName});

  @override
  Widget build(BuildContext context) {
    final initial = teamName.isNotEmpty ? teamName[0].toUpperCase() : '?';
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF00A3FF).withOpacity(0.15),
        border: Border.all(color: const Color(0xFF00A3FF), width: 1.2),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Color(0xFF00A3FF),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}