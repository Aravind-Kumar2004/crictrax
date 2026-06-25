import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/models/repositories/live_score_repository.dart';

// ═══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════
class LiveScoreScreen extends StatefulWidget {
  final String matchId;
  final String tournamentId;
  final String team1Name;
  final String team2Name;
  final String team1Id;
  final String team2Id;

  const LiveScoreScreen({
    Key? key,
    required this.matchId,
    required this.tournamentId,
    required this.team1Name,
    required this.team2Name,
    required this.team1Id,
    required this.team2Id,
  }) : super(key: key);

  @override
  State<LiveScoreScreen> createState() => _LiveScoreScreenState();
}

class _LiveScoreScreenState extends State<LiveScoreScreen> {
  final _repo = LiveScoreRepository();
  bool _hasNavigatedAway = false;
  bool _hasShownInningsSummary = false;
  bool _dialogShown = false;
  Timer? _autoDismissTimer;
  Timer? _splashTimer;
  String? _lastBallId;
  String? _lastInningsId;
  Map<String, dynamic>? _lastInningsData;
  String? _lastFirstInningsBattingTeamName;

  // Commentary splash state
  String? _splashLabel;
  Color _splashColor = Colors.white;

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _splashTimer?.cancel();
    super.dispose();
  }

  void _triggerSplash(Map<String, dynamic> ball) {
    String label;
    Color color;

    if (ball['isWicket'] == true) {
      label = 'OUT!';
      color = const Color(0xFFFF3B30);
    } else if (ball['isWide'] == true) {
      label = 'Wide';
      color = const Color(0xFFFFB300);
    } else if (ball['isNoBall'] == true) {
      label = 'No Ball';
      color = const Color(0xFFFFB300);
    } else {
      final runs = (ball['runs'] as num?)?.toInt() ?? 0;
      switch (runs) {
        case 6:
          label = 'SIX!';
          color = const Color(0xFF34C759);
          break;
        case 4:
          label = 'FOUR!';
          color = const Color(0xFF007AFF);
          break;
        case 0:
          label = 'Dot';
          color = Colors.white54;
          break;
        default:
          label = '$runs';
          color = Colors.white;
      }
    }

    setState(() {
      _splashLabel = label;
      _splashColor = color;
    });

    _splashTimer?.cancel();
    _splashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _splashLabel = null);
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // 🟢 UNIFIED FIREBASE UPDATE & POPUP FUNCTION
  // ═══════════════════════════════════════════════════════════════
  Future<void> _markMatchCompleteAndPop(String resultMsg) async {
    if (_hasNavigatedAway) return;

    _hasNavigatedAway = true;

    final matchRef = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('matches')
        .doc(widget.matchId);

    try {
      final matchDoc = await matchRef.get();

      if (matchDoc.exists) {
        final data = matchDoc.data() ?? {};

        if (data['isCompleted'] != true) {
          await matchRef.update({
            'isCompleted': true,
            'isLive': false,
            'matchStatus': 'completed',
            'result': resultMsg,
            'completedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint("Match completion error: $e");
    }

    if (!mounted) return;

    _showMatchEndedAndPop(
      context,
      {'result': resultMsg},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/stadium_bg.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.80),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _repo.watchMatch(widget.tournamentId, widget.matchId),
              builder: (context, matchSnap) {
                Map<String, dynamic> matchData = {};
                int matchOvers = 0;

                if (matchSnap.hasData && matchSnap.data!.exists) {
                  matchData =
                      matchSnap.data!.data() as Map<String, dynamic>? ?? {};
                  matchOvers = (matchData['overs'] as num?)?.toInt() ?? 0;

                  if (matchData['isCompleted'] == true &&
                      !_hasNavigatedAway) {
                    final resultMsg =
                    (matchData['result'] as String? ?? '').trim();
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (!mounted) return;
                      _markMatchCompleteAndPop(resultMsg.isNotEmpty
                          ? resultMsg
                          : 'Match Completed');
                    });
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _repo.watchInnings(
                      widget.tournamentId, widget.matchId),
                  builder: (context, inningsSnap) {
                    if (inningsSnap.hasError) {
                      return _buildFullError(
                          inningsSnap.error.toString());
                    }

                    if (!inningsSnap.hasData ||
                        inningsSnap.data!.docs.isEmpty) {
                      return _buildWaitingScreen();
                    }

                    final docs = inningsSnap.data!.docs;

                    final firstInningsDocs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['isSecondInnings'] != true;
                    }).toList();

                    final secondInningsDocs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['isSecondInnings'] == true;
                    }).toList();

                    // Between innings — show break screen
                    if (firstInningsDocs.isNotEmpty &&
                        secondInningsDocs.isEmpty) {
                      final inn1Data = firstInningsDocs.first.data()
                      as Map<String, dynamic>;
                      if (inn1Data['isCompleted'] == true &&
                          !_hasShownInningsSummary) {
                        return _InningsBreakScreen(
                          innData: inn1Data,
                          inningsId: firstInningsDocs.first.id,
                          tournamentId: widget.tournamentId,
                          matchId: widget.matchId,
                          team1Name: widget.team1Name,
                          team2Name: widget.team2Name,
                          repo: _repo,
                          onDismiss: () {
                            if (mounted) {
                              setState(
                                      () => _hasShownInningsSummary = true);
                            }
                          },
                        );
                      }
                    }

                    final currentDoc = secondInningsDocs.isNotEmpty
                        ? secondInningsDocs.first
                        : docs.first;
                    final innData =
                    currentDoc.data() as Map<String, dynamic>;

                    // Cache first innings batting team name
                    String? firstInningsBattingTeamName;
                    if (firstInningsDocs.isNotEmpty) {
                      final firstData = firstInningsDocs.first.data()
                      as Map<String, dynamic>;
                      firstInningsBattingTeamName =
                          (firstData['battingTeamName'] ?? '')
                              .toString()
                              .trim();
                    }

                    // 🟢 CLEANED UP Completion detection
                    if (!_hasNavigatedAway) {
                      final matchCompleted = matchData['isCompleted'] == true;

                      final secondInningsComplete = docs.any((d) {
                        final map = d.data() as Map<String, dynamic>;
                        return map['isSecondInnings'] == true &&
                            map['isCompleted'] == true;
                      });

                      if (matchCompleted || secondInningsComplete) {
                        String resultMsg = (matchData['result'] as String? ?? '').trim();
                        if (resultMsg.isEmpty) {
                          resultMsg = (innData['result'] as String? ?? '').trim();
                        }
                        if (resultMsg.isEmpty) {
                          resultMsg = 'Match Completed';
                        }

                        // Fire our unified function
                        _markMatchCompleteAndPop(resultMsg);
                      }
                    }

                    _lastInningsId = currentDoc.id;
                    _lastInningsData = Map<String, dynamic>.from(innData);
                    _lastFirstInningsBattingTeamName = firstInningsBattingTeamName;

                    return _TvScoreCard(
                      tournamentId: widget.tournamentId,
                      matchId: widget.matchId,
                      inningsId: currentDoc.id,
                      innData: innData,
                      team1Name: widget.team1Name,
                      team2Name: widget.team2Name,
                      team1Id: widget.team1Id,
                      team2Id: widget.team2Id,
                      repo: _repo,
                      splashLabel: _splashLabel,
                      splashColor: _splashColor,
                      matchOvers: matchOvers,
                      firstInningsBattingTeamName: firstInningsBattingTeamName,

                      // Catch the trigger from the score card when target is chased
                      onMatchEnded: (resultMsg) {
                        _markMatchCompleteAndPop(resultMsg);
                      },

                      onNewBall: (ball, ballId) {
                        if (ballId != _lastBallId) {
                          _lastBallId = ballId;
                          _triggerSplash(ball);
                        }
                      },
                      onBack: () => Navigator.pop(context),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _BackBtn(onTap: () => Navigator.pop(context)),
            ),
          ),
          const Spacer(),
          Icon(Icons.sports_cricket,
              color: Colors.white.withOpacity(0.15), size: 100),
          const SizedBox(height: 24),
          Text(
            '${widget.team1Name}  vs  ${widget.team2Name}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(color: Color(0xFF00A3FF)),
          const SizedBox(height: 16),
          Text(
            'Waiting for match to start...',
            style: TextStyle(
                color: Colors.white.withOpacity(0.45), fontSize: 16),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFullError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text('Error: $error',
              style: const TextStyle(
                  color: Colors.redAccent, fontSize: 14)),
        ],
      ),
    );
  }

  void _showMatchEndedAndPop(
      BuildContext context, Map<String, dynamic> matchData) {
    if (!mounted || _dialogShown) return;
    _dialogShown = true;

    final resultText =
    (matchData['result'] as String? ?? '').isNotEmpty
        ? matchData['result'] as String
        : 'Match Completed';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0C1F3D),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.emoji_events, color: Color(0xFFFFD700)),
              SizedBox(width: 10),
              Text('Match Ended',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A45).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                      const Color(0xFFFF7A45).withOpacity(0.3)),
                ),
                child: Text(
                  resultText,
                  style: const TextStyle(
                      color: Color(0xFFFF7A45),
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'What would you like to do?',
                style:
                TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
          actionsPadding:
          const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _autoDismissTimer?.cancel();
                  if (Navigator.of(dialogContext,
                      rootNavigator: true)
                      .canPop()) {
                    Navigator.of(dialogContext,
                        rootNavigator: true)
                        .pop();
                  }
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => _MatchSummaryScreen(
                          tournamentId: widget.tournamentId,
                          matchId: widget.matchId,
                          team1Name: widget.team1Name,
                          team2Name: widget.team2Name,
                          resultText: resultText,
                          repo: _repo,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.bar_chart, size: 18),
                label: const Text('View Match Summary',
                    style: TextStyle(fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8E5CFF),
                  side: const BorderSide(
                      color: Color(0xFF8E5CFF), width: 1.5),
                  padding:
                  const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _dismissAndPop(dialogContext, context),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to Tournament',
                    style: TextStyle(fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A3FF),
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      try {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          _dismissAndPop(context, context);
        }
      } catch (_) {}
    });
  }

  void _dismissAndPop(
      BuildContext dialogCtx, BuildContext screenCtx) {
    _autoDismissTimer?.cancel();
    try {
      if (Navigator.of(dialogCtx, rootNavigator: true).canPop()) {
        Navigator.of(dialogCtx, rootNavigator: true).pop();
      }
    } catch (_) {}
    try {
      if (Navigator.of(screenCtx).canPop()) {
        Navigator.of(screenCtx).pop();
      }
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════════
// TV SCORE CARD
// ═══════════════════════════════════════════════════════════════
class _TvScoreCard extends StatelessWidget {
  final String tournamentId;
  final String matchId;
  final String inningsId;
  final Map<String, dynamic> innData;
  final String team1Name;
  final String team2Name;
  final String team1Id;
  final String team2Id;
  final LiveScoreRepository repo;
  final String? splashLabel;
  final Color splashColor;
  final void Function(Map<String, dynamic> ball, String ballId) onNewBall;
  final VoidCallback onBack;
  final int matchOvers;
  final String? firstInningsBattingTeamName;
  final void Function(String resultMsg) onMatchEnded;

  const _TvScoreCard({
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
    required this.innData,
    required this.team1Name,
    required this.team2Name,
    required this.team1Id,
    required this.team2Id,
    required this.repo,
    required this.splashLabel,
    required this.splashColor,
    required this.onNewBall,
    required this.onBack,
    required this.matchOvers,
    this.firstInningsBattingTeamName,
    required this.onMatchEnded,
  });

  String _resolveBattingTeam() {
    final battingTeamId = (innData['battingTeamId'] ?? '').toString().trim();
    if (battingTeamId.isNotEmpty) {
      if (battingTeamId == team1Id) return team1Name;
      if (battingTeamId == team2Id) return team2Name;
    }
    final name = (innData['battingTeamName'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final isSecondInnings = innData['isSecondInnings'] == true;
    if (isSecondInnings && (firstInningsBattingTeamName?.isNotEmpty ?? false)) {
      return firstInningsBattingTeamName == team1Name ? team2Name : team1Name;
    }
    return team1Name;
  }

  String _resolveBowlingTeam(String battingTeam) {
    return battingTeam == team1Name ? team2Name : team1Name;
  }

  @override
  Widget build(BuildContext context) {
    final battingTeam = _resolveBattingTeam();
    final bowlingTeam = _resolveBowlingTeam(battingTeam);
    final isSecond = innData['isSecondInnings'] == true;
    final targetRuns = (innData['targetRuns'] ?? 0) as num;

    return StreamBuilder<QuerySnapshot>(
      stream: repo.watchBatsmen(tournamentId, matchId, inningsId),
      builder: (context, batSnap) {
        final allBatsmen = batSnap.hasData
            ? batSnap.data!.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList()
            : <Map<String, dynamic>>[];

        int totalRuns = 0, totalWickets = 0, totalBalls = 0;
        for (final b in allBatsmen) {
          totalRuns += (b['runs'] ?? 0) as int;
          totalBalls += (b['ballsFaced'] ?? 0) as int;
          if (b['isOut'] == true) totalWickets++;
        }

        if (totalRuns == 0 && innData['totalRuns'] != null) {
          totalRuns = (innData['totalRuns'] as num).toInt();
        }
        if (totalWickets == 0 && innData['totalWickets'] != null) {
          totalWickets = (innData['totalWickets'] as num).toInt();
        }

        final ballsBowled = (innData['ballsBowled'] ?? innData['currentBall'] ?? 0) as int;
        if (ballsBowled > 0) totalBalls = ballsBowled;

        final completedOvers = totalBalls ~/ 6;
        final ballsInOver = totalBalls % 6;
        final currentOverNumber = completedOvers.clamp(0, 999);
        final oversDisplay = '$completedOvers.$ballsInOver';

        final activeBatsmen = allBatsmen.where((b) => b['isOut'] != true).toList();
        final onStrikeBatter = activeBatsmen.firstWhere(
              (b) => b['isOnStrike'] == true || b['onStrike'] == true,
          orElse: () => <String, dynamic>{},
        );
        final onStrikeName = onStrikeBatter.isNotEmpty
            ? (onStrikeBatter['playerName'] ?? onStrikeBatter['name'] ?? '').toString()
            : '';

        final configuredOvers = matchOvers > 0
            ? matchOvers
            : ((innData['totalOvers'] ?? innData['matchOvers'] ?? 0) as num).toInt();
        final totalMatchBalls = configuredOvers * 6;

        final int runsNeeded = isSecond && targetRuns > 0
            ? (targetRuns - totalRuns).clamp(0, targetRuns.toInt()).toInt()
            : 0;
        final int ballsLeft = isSecond && totalMatchBalls > 0
            ? (totalMatchBalls - totalBalls).clamp(0, totalMatchBalls).toInt()
            : 0;

        final chaseComplete = isSecond && targetRuns > 0 && totalRuns >= targetRuns;
        final outOfBalls = isSecond && totalMatchBalls > 0 && ballsLeft <= 0;

        final inningsCompleted =
            innData['isCompleted'] == true;

        if (!inningsCompleted &&
            (chaseComplete || outOfBalls)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            String result = '';
            if (chaseComplete) {
              result = '$battingTeam won the match!';
            } else if (outOfBalls) {
              final tieScore = targetRuns - 1;
              if (totalRuns == tieScore) {
                result = 'Match Tied!';
              } else if (totalRuns < tieScore) {
                result = '$bowlingTeam won by ${tieScore - totalRuns} runs!';
              }
            }
            if (result.isNotEmpty) {
              onMatchEnded(result);
            }
          });
        }

        return StreamBuilder<QuerySnapshot>(
          stream: repo.watchBowlers(tournamentId, matchId, inningsId),
          builder: (context, bowlSnap) {
            Map<String, dynamic>? currentBowler;
            if (bowlSnap.hasData && bowlSnap.data!.docs.isNotEmpty) {
              final bowlers = bowlSnap.data!.docs
                  .map((d) => d.data() as Map<String, dynamic>)
                  .toList();
              final withTs = bowlers.where((b) => b['lastUpdated'] is Timestamp).toList();
              if (withTs.isNotEmpty) {
                withTs.sort((a, b) =>
                    (b['lastUpdated'] as Timestamp).compareTo(a['lastUpdated'] as Timestamp));
                currentBowler = withTs.first;
              } else {
                final active = bowlers.where((b) => b['isBowling'] == true).toList();
                currentBowler = active.isNotEmpty ? active.first : bowlers.last;
              }
            }

            final crr = totalBalls > 0
                ? (totalRuns / totalBalls) * 6
                : (innData['currentRunRate'] as num? ?? 0.0).toDouble();

            return Stack(
              children: [
                Column(
                  children: [
                    _TopBar(
                      battingTeam: battingTeam,
                      bowlingTeam: bowlingTeam,
                      inningsNumber: isSecond ? 2 : 1,
                      onBack: onBack,
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _BigScorePanel(
                              battingTeam: battingTeam,
                              runs: totalRuns,
                              wickets: totalWickets,
                              overs: oversDisplay,
                              crr: crr,
                            ),
                          ),
                          Container(width: 1, color: Colors.white.withOpacity(0.08)),
                          Expanded(
                            flex: 4,
                            child: _PlayersPanel(
                              activeBatsmen: activeBatsmen,
                              onStrikeName: onStrikeName,
                              currentBowler: currentBowler,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _BottomBar(
                      tournamentId: tournamentId,
                      matchId: matchId,
                      inningsId: inningsId,
                      repo: repo,
                      overNumber: currentOverNumber,
                      totalBallsFaced: totalBalls,
                      isSecond: isSecond,
                      targetRuns: targetRuns.toInt(),
                      runsNeeded: runsNeeded,
                      ballsLeft: ballsLeft,
                      onNewBall: onNewBall,
                    ),
                  ],
                ),
                if (splashLabel != null)
                  _CommentarySplash(label: splashLabel!, color: splashColor),
              ],
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TOP BAR
// ═══════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final String battingTeam;
  final String bowlingTeam;
  final int inningsNumber;
  final VoidCallback onBack;

  const _TopBar({
    required this.battingTeam,
    required this.bowlingTeam,
    required this.inningsNumber,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          _BackBtn(onTap: onBack),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.white, size: 8),
                SizedBox(width: 5),
                Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF8E5CFF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF8E5CFF).withOpacity(0.4)),
            ),
            child: Text(
              'Innings $inningsNumber',
              style: const TextStyle(
                  color: Color(0xFF8E5CFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const Spacer(),
          Text(
            '$battingTeam  vs  $bowlingTeam',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BIG SCORE PANEL
// ═══════════════════════════════════════════════════════════════
class _BigScorePanel extends StatelessWidget {
  final String battingTeam;
  final int runs;
  final int wickets;
  final String overs;
  final double crr;

  const _BigScorePanel({
    required this.battingTeam,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.crr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              _TeamBadge(teamName: battingTeam, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  battingTeam,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$runs',
                style: const TextStyle(
                  color: Color(0xFFFF7A45),
                  fontSize: 100,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  '/$wickets',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MetaPill(
                icon: Icons.timer_outlined,
                label: '$overs Overs',
                color: const Color(0xFF00A3FF),
              ),
              const SizedBox(width: 12),
              _MetaPill(
                icon: Icons.speed,
                label: 'CRR ${crr.toStringAsFixed(2)}',
                color: const Color(0xFF34C759),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PLAYERS PANEL
// ═══════════════════════════════════════════════════════════════
class _PlayersPanel extends StatelessWidget {
  final List<Map<String, dynamic>> activeBatsmen;
  final String onStrikeName;
  final Map<String, dynamic>? currentBowler;

  const _PlayersPanel({
    required this.activeBatsmen,
    required this.onStrikeName,
    required this.currentBowler,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...activeBatsmen]..sort((a, b) {
      final an = (a['playerName'] ?? a['name'] ?? '').toString();
      final bn = (b['playerName'] ?? b['name'] ?? '').toString();
      return (an == onStrikeName ? 0 : 1).compareTo(bn == onStrikeName ? 0 : 1);
    });
    final display = sorted.take(2).toList();

    final bowlerName = currentBowler != null
        ? (currentBowler!['playerName'] ?? currentBowler!['name'] ?? '').toString()
        : '';
    final wkts = currentBowler?['wickets'] ?? 0;
    final runsConceded = currentBowler?['runsConceded'] ?? currentBowler?['runs'] ?? 0;
    final bowlerOvers = currentBowler?['overs'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'BATTING', color: const Color(0xFFFF7A45)),
          const SizedBox(height: 12),
          ...display.map((b) {
            final name = (b['playerName'] ?? b['name'] ?? '').toString();
            final runs = b['runs'] ?? 0;
            final balls = b['ballsFaced'] ?? 0;
            final fours = b['fours'] ?? 0;
            final sixes = b['sixes'] ?? 0;
            final onStrike = onStrikeName.isNotEmpty && name == onStrikeName;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: onStrike
                    ? const Color(0xFFFF7A45).withOpacity(0.12)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: onStrike
                      ? const Color(0xFFFF7A45).withOpacity(0.4)
                      : Colors.white.withOpacity(0.07),
                  width: onStrike ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: onStrike
                        ? const Icon(Icons.sports_cricket, color: Color(0xFFFF7A45), size: 18)
                        : null,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name.length > 16 ? '${name.substring(0, 16)}…' : name,
                              style: TextStyle(
                                color: onStrike ? Colors.white : Colors.white70,
                                fontSize: 17,
                                fontWeight: onStrike ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                            if (onStrike)
                              const Text(' *',
                                  style: TextStyle(
                                      color: Color(0xFFFF7A45),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                          ],
                        ),
                        if (fours > 0 || sixes > 0)
                          Text(
                            '${fours}×4   ${sixes}×6',
                            style: const TextStyle(color: Color(0xFF34C759), fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$runs',
                        style: TextStyle(
                          color: onStrike ? const Color(0xFFFF7A45) : Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        ' ($balls)',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          _SectionLabel(label: 'BOWLING', color: const Color(0xFF00A3FF)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00A3FF).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sports_baseball, color: Color(0xFF00A3FF), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bowlerName.isEmpty ? 'No bowler yet' : bowlerName,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$wkts/$runsConceded',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$bowlerOvers ov',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BOTTOM BAR
// ═══════════════════════════════════════════════════════════════
class _BottomBar extends StatelessWidget {
  final String tournamentId;
  final String matchId;
  final String inningsId;
  final LiveScoreRepository repo;
  final int overNumber;
  final int totalBallsFaced;
  final bool isSecond;
  final int targetRuns;
  final int runsNeeded;
  final int ballsLeft;
  final void Function(Map<String, dynamic> ball, String ballId) onNewBall;

  const _BottomBar({
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
    required this.repo,
    required this.overNumber,
    required this.totalBallsFaced,
    required this.isSecond,
    required this.targetRuns,
    required this.runsNeeded,
    required this.ballsLeft,
    required this.onNewBall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSecond && targetRuns > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              color: const Color(0xFFFF7A45).withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ChasePill(label: 'TARGET', value: '$targetRuns', color: const Color(0xFFFF7A45)),
                  _chaseDot(),
                  _ChasePill(
                    label: 'NEED',
                    value: '$runsNeeded runs',
                    color: runsNeeded <= 10 ? const Color(0xFF34C759) : const Color(0xFFFF7A45),
                  ),
                  _chaseDot(),
                  _ChasePill(
                    label: 'BALLS LEFT',
                    value: '$ballsLeft',
                    color: ballsLeft <= 6 ? Colors.redAccent : const Color(0xFF00A3FF),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Text(
                  'OVER ${overNumber + 1}',
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _BallTrackerRow(
                    tournamentId: tournamentId,
                    matchId: matchId,
                    inningsId: inningsId,
                    repo: repo,
                    overNumber: overNumber,
                    totalBallsFaced: totalBallsFaced,
                    onNewBall: onNewBall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chaseDot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text('•', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 18)),
  );
}

// ═══════════════════════════════════════════════════════════════
// BALL TRACKER ROW
// ═══════════════════════════════════════════════════════════════
class _BallTrackerRow extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final String inningsId;
  final LiveScoreRepository repo;
  final int overNumber;
  final int totalBallsFaced;
  final void Function(Map<String, dynamic> ball, String ballId) onNewBall;

  const _BallTrackerRow({
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
    required this.repo,
    required this.overNumber,
    required this.totalBallsFaced,
    required this.onNewBall,
  });

  @override
  State<_BallTrackerRow> createState() => _BallTrackerRowState();
}

class _BallTrackerRowState extends State<_BallTrackerRow> {
  late Stream<QuerySnapshot> _scoresStream;
  String? _lastFiredKey;

  @override
  void initState() {
    super.initState();
    _subscribeToStream();
  }

  @override
  void didUpdateWidget(_BallTrackerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inningsId != widget.inningsId) {
      _subscribeToStream();
    }
  }

  void _subscribeToStream() {
    _scoresStream = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('matches')
        .doc(widget.matchId)
        .collection('innings')
        .doc(widget.inningsId)
        .collection('scores')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _scoresStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('Score error: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 10));
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _buildPlaceholders(widget.totalBallsFaced);
        }

        final docs = snap.data!.docs;
        Map<String, dynamic>? scoreData;
        int highestBall = -1;
        String latestDocId = '';

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ball = (data['currentBall'] as num?)?.toInt() ?? 0;
          if (ball > highestBall) {
            highestBall = ball;
            scoreData = data;
            latestDocId = doc.id;
          }
        }

        if (scoreData == null) {
          return _buildPlaceholders(widget.totalBallsFaced);
        }

        List<String> currentOverBalls = [];
        final raw = scoreData['currentOver'];
        if (raw is List) {
          currentOverBalls = raw.map((e) => e.toString()).toList();
        }

        if (currentOverBalls.isNotEmpty) {
          final lastLabel = currentOverBalls.last;
          final fireKey = '$latestDocId-${currentOverBalls.length}-$lastLabel';
          if (fireKey != _lastFiredKey) {
            _lastFiredKey = fireKey;
            final syntheticBall = _buildSyntheticBall(lastLabel);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                widget.onNewBall(syntheticBall, fireKey);
              }
            });
          }
        }

        final legalBalls = <String>[];
        final extraLabels = <String>[];

        for (final label in currentOverBalls) {
          final isExtra = label == 'Wd' ||
              label == 'Nb' ||
              label == 'wd' ||
              label == 'nb' ||
              label.toLowerCase() == 'wide' ||
              label.toLowerCase() == 'noball';
          if (isExtra) {
            extraLabels.add(label);
          } else {
            legalBalls.add(label);
          }
        }

        final mainSlots = List<String?>.filled(6, null);
        for (int i = 0; i < legalBalls.length && i < 6; i++) {
          mainSlots[i] = legalBalls[i];
        }

        return Row(
          children: [
            ...mainSlots.map((label) => _ScoreBallChip(label: label)),
            if (extraLabels.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(width: 1, height: 32, color: Colors.white.withOpacity(0.15)),
              const SizedBox(width: 8),
              ...extraLabels.take(4).map((label) => _ScoreBallChip(label: label, isExtra: true)),
            ],
          ],
        );
      },
    );
  }

  Map<String, dynamic> _buildSyntheticBall(String label) {
    return {
      'display': label,
      'isWicket': label == 'W' || label == 'w',
      'isWide': label == 'Wd' || label == 'wd',
      'isNoBall': label == 'Nb' || label == 'nb',
      'runs': int.tryParse(label) ?? 0,
    };
  }

  Widget _buildPlaceholders(int totalBalls) {
    final bowled = totalBalls % 6;
    final actualBowled = (bowled == 0 && totalBalls > 0) ? 6 : bowled;
    return Row(
      children: List.generate(6, (i) {
        final done = i < actualBowled;
        return _ScoreBallChip(label: null, isPlaceholder: true, filled: done);
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SCORE BALL CHIP
// ═══════════════════════════════════════════════════════════════
class _ScoreBallChip extends StatelessWidget {
  final String? label;
  final bool isExtra;
  final bool isPlaceholder;
  final bool filled;

  const _ScoreBallChip({
    this.label,
    this.isExtra = false,
    this.isPlaceholder = false,
    this.filled = false,
  });

  Color _color() {
    if (label == null) return Colors.white24;
    final l = label!.trim();
    if (l == 'W' || l == 'w') return const Color(0xFFFF3B30);
    if (l == 'Wd' || l == 'wd' || l.toLowerCase() == 'wide') return const Color(0xFFFFB300);
    if (l == 'Nb' || l == 'nb' || l.toLowerCase() == 'noball') return const Color(0xFFFFB300);
    if (l == 'B' || l == 'Lb') return const Color(0xFF9E9E9E);
    final runs = int.tryParse(l) ?? -1;
    if (runs == 6) return const Color(0xFF34C759);
    if (runs == 4) return const Color(0xFF007AFF);
    if (runs == 0) return Colors.white38;
    if (runs > 0) return Colors.white70;
    return Colors.white54;
  }

  @override
  Widget build(BuildContext context) {
    final col = _color();
    final displayLabel = label ?? '';

    if (isPlaceholder) {
      return Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: filled ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: filled ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: filled
            ? Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        )
            : null,
      );
    }

    final empty = label == null;
    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: empty ? Colors.white.withOpacity(0.04) : col.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: empty ? Colors.white.withOpacity(0.12) : col,
          width: 1.5,
        ),
      ),
      child: Center(
        child: empty
            ? null
            : Text(
          displayLabel,
          style: TextStyle(color: col, fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COMMENTARY SPLASH
// ═══════════════════════════════════════════════════════════════
class _CommentarySplash extends StatefulWidget {
  final String label;
  final Color color;

  const _CommentarySplash({required this.label, required this.color});

  @override
  State<_CommentarySplash> createState() => _CommentarySplashState();
}

class _CommentarySplashState extends State<_CommentarySplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: widget.color.withOpacity(0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: widget.color.withOpacity(0.3), blurRadius: 30, spreadRadius: 5),
                    ],
                  ),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [Shadow(color: widget.color.withOpacity(0.5), blurRadius: 20)],
                    ),
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

// ═══════════════════════════════════════════════════════════════
// INNINGS BREAK SCREEN
// ═══════════════════════════════════════════════════════════════
class _InningsBreakScreen extends StatefulWidget {
  final Map<String, dynamic> innData;
  final String inningsId;
  final String tournamentId;
  final String matchId;
  final String team1Name;
  final String team2Name;
  final LiveScoreRepository repo;
  final VoidCallback onDismiss;

  const _InningsBreakScreen({
    required this.innData,
    required this.inningsId,
    required this.tournamentId,
    required this.matchId,
    required this.team1Name,
    required this.team2Name,
    required this.repo,
    required this.onDismiss,
  });

  @override
  State<_InningsBreakScreen> createState() => _InningsBreakScreenState();
}

class _InningsBreakScreenState extends State<_InningsBreakScreen> {
  List<Map<String, dynamic>> _batsmen = [];
  List<Map<String, dynamic>> _bowlers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bSnap = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('matches')
          .doc(widget.matchId)
          .collection('innings')
          .doc(widget.inningsId)
          .collection('batsmen')
          .get();
      final wSnap = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('matches')
          .doc(widget.matchId)
          .collection('innings')
          .doc(widget.inningsId)
          .collection('bowlers')
          .get();
      if (!mounted) return;
      setState(() {
        _batsmen = bSnap.docs.map((d) => d.data()).toList();
        _bowlers = wSnap.docs.map((d) => d.data()).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _runs => _batsmen.fold(0, (s, b) => s + ((b['runs'] ?? 0) as num).toInt());
  int get _wkts => _batsmen.where((b) => b['isOut'] == true).length;
  int get _balls => _batsmen.fold(0, (s, b) => s + ((b['ballsFaced'] ?? 0) as num).toInt());
  String get _overs => '${_balls ~/ 6}.${_balls % 6}';

  String _battingTeam() {
    final n = (widget.innData['battingTeamName'] ?? '').toString().trim();
    return n.isNotEmpty ? n : widget.team1Name;
  }

  String _bowlingTeam() {
    final b = _battingTeam();
    return b == widget.team1Name ? widget.team2Name : widget.team1Name;
  }

  @override
  Widget build(BuildContext context) {
    final bat = _battingTeam();
    final bowl = _bowlingTeam();
    final target = _runs + 1;

    return Container(
      color: const Color(0xFF050A18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            color: Colors.black.withOpacity(0.4),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Innings 1 Complete',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A45).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF7A45).withOpacity(0.5)),
                  ),
                  child: Text(
                    '$bowl needs $target to win',
                    style: const TextStyle(
                        color: Color(0xFFFF7A45), fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A3FF)))
                : Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TeamBadge(teamName: bat, size: 64),
                        const SizedBox(height: 12),
                        Text(bat,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$_runs',
                                style: const TextStyle(
                                    color: Color(0xFFFF7A45),
                                    fontSize: 72,
                                    fontWeight: FontWeight.w900,
                                    height: 1)),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('/$_wkts',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        Text('$_overs overs',
                            style: const TextStyle(color: Colors.white54, fontSize: 18)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'BATTING', color: const Color(0xFFFF7A45)),
                        const SizedBox(height: 10),
                        _tableHeader(['Batter', 'R', 'B', '4s', '6s', 'SR']),
                        const Divider(color: Colors.white12, height: 1),
                        ...(_batsmen
                          ..sort((a, b) =>
                              ((b['runs'] ?? 0) as num).compareTo((a['runs'] ?? 0) as num)))
                            .take(6)
                            .map((b) => _batsmanRow(b)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'BOWLING', color: const Color(0xFF00A3FF)),
                        const SizedBox(height: 10),
                        _tableHeader(['Bowler', 'O', 'R', 'W', 'Eco']),
                        const Divider(color: Colors.white12, height: 1),
                        ...(_bowlers
                          ..sort((a, b) =>
                              ((b['wickets'] ?? 0) as num).compareTo((a['wickets'] ?? 0) as num)))
                            .take(6)
                            .map((b) => _bowlerRow(b)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: Colors.black.withOpacity(0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A3FF))),
                const SizedBox(width: 10),
                Text(
                  'Waiting for $bowl to start batting...',
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(List<String> cols) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(cols[0],
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w700))),
          ...cols.skip(1).map((c) => SizedBox(
            width: 40,
            child: Text(c,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w700)),
          )),
        ],
      ),
    );
  }

  Widget _batsmanRow(Map<String, dynamic> b) {
    final name = (b['playerName'] ?? b['name'] ?? '').toString();
    final runs = (b['runs'] ?? 0) as num;
    final balls = (b['ballsFaced'] ?? 0) as num;
    final fours = (b['fours'] ?? 0) as num;
    final sixes = (b['sixes'] ?? 0) as num;
    final sr = balls > 0 ? ((runs / balls) * 100).toStringAsFixed(1) : '0.0';
    final isOut = b['isOut'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 14 ? '${name.substring(0, 14)}…' : name,
              style: TextStyle(color: isOut ? Colors.white54 : Colors.white70, fontSize: 13),
            ),
          ),
          _tc('$runs', bold: true, color: const Color(0xFFFF7A45)),
          _tc('$balls'),
          _tc('$fours'),
          _tc('$sixes'),
          _tc(sr),
        ],
      ),
    );
  }

  Widget _bowlerRow(Map<String, dynamic> b) {
    final name = (b['playerName'] ?? b['name'] ?? '').toString();
    final overs = b['overs'] ?? 0;
    final runs = (b['runsConceded'] ?? b['runs'] ?? 0) as num;
    final wkts = (b['wickets'] ?? 0) as num;
    final eco = (b['economy'] ?? 0) as num;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 14 ? '${name.substring(0, 14)}…' : name,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          _tc('$overs'),
          _tc('$runs'),
          _tc('$wkts', bold: true, color: wkts >= 3 ? const Color(0xFFFF7A45) : Colors.white),
          _tc(eco.toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _tc(String t, {bool bold = false, Color? color}) => SizedBox(
    width: 40,
    child: Text(t,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color ?? Colors.white60,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
  );
}

// ═══════════════════════════════════════════════════════════════
// MATCH SUMMARY SCREEN
// ═══════════════════════════════════════════════════════════════
class _MatchSummaryScreen extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final String team1Name;
  final String team2Name;
  final String resultText;
  final LiveScoreRepository repo;

  const _MatchSummaryScreen({
    required this.tournamentId,
    required this.matchId,
    required this.team1Name,
    required this.team2Name,
    required this.resultText,
    required this.repo,
  });

  @override
  State<_MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<_MatchSummaryScreen> {
  Map<String, List<Map<String, dynamic>>> _batsmen = {};
  Map<String, List<Map<String, dynamic>>> _bowlers = {};
  Map<String, Map<String, dynamic>> _innData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = FirebaseFirestore.instance;
      final base = db
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('matches')
          .doc(widget.matchId);
      final inningsSnap = await base.collection('innings').get();
      for (final inn in inningsSnap.docs) {
        final innData = inn.data();
        _innData[inn.id] = innData;
        final bSnap = await base.collection('innings').doc(inn.id).collection('batsmen').get();
        final wSnap = await base.collection('innings').doc(inn.id).collection('bowlers').get();
        _batsmen[inn.id] = bSnap.docs.map((d) => d.data()).toList();
        _bowlers[inn.id] = wSnap.docs.map((d) => d.data()).toList();
      }
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            color: Colors.black.withOpacity(0.4),
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
                const SizedBox(width: 20),
                const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.team1Name} vs ${widget.team2Name}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.resultText,
                        style: const TextStyle(
                            color: Color(0xFFFF7A45), fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to Tournament'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3FF), foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A3FF)))
                : _buildSummary(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    if (_innData.isEmpty) {
      return const Center(
        child: Text('No match data available', style: TextStyle(color: Colors.white38, fontSize: 18)),
      );
    }
    final inningsList = _innData.entries.toList()
      ..sort((a, b) {
        final aS = a.value['isSecondInnings'] == true ? 1 : 0;
        final bS = b.value['isSecondInnings'] == true ? 1 : 0;
        return aS.compareTo(bS);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: inningsList.map((entry) {
          final innId = entry.key;
          final inn = entry.value;
          final isSecond = inn['isSecondInnings'] == true;
          final batTeam = (inn['battingTeamName'] ?? '').toString();
          final batsmen = _batsmen[innId] ?? [];
          final bowlers = _bowlers[innId] ?? [];
          final totalRuns = batsmen.fold(0, (s, b) => s + ((b['runs'] ?? 0) as num).toInt());
          final totalWkts = batsmen.where((b) => b['isOut'] == true).length;
          final totalBalls = batsmen.fold(0, (s, b) => s + ((b['ballsFaced'] ?? 0) as num).toInt());
          final overs = '${totalBalls ~/ 6}.${totalBalls % 6}';

          return Container(
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E5CFF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF8E5CFF).withOpacity(0.4)),
                        ),
                        child: Text(
                          'Innings ${isSecond ? 2 : 1}',
                          style: const TextStyle(
                              color: Color(0xFF8E5CFF), fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          batTeam.isNotEmpty ? batTeam : 'Batting Team',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '$totalRuns/$totalWkts ($overs ov)',
                        style: const TextStyle(
                          color: Color(0xFFFF7A45),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'BATTING', color: const Color(0xFFFF7A45)),
                            const SizedBox(height: 8),
                            _summaryHeader(['Batter', 'R', 'B', '4s', '6s', 'SR']),
                            const Divider(color: Colors.white12, height: 8),
                            ...(batsmen
                              ..sort((a, b) =>
                                  ((b['runs'] ?? 0) as num).compareTo((a['runs'] ?? 0) as num)))
                                .map((b) => _batsmanSummaryRow(b)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'BOWLING', color: const Color(0xFF00A3FF)),
                            const SizedBox(height: 8),
                            _summaryHeader(['Bowler', 'O', 'R', 'W', 'Eco']),
                            const Divider(color: Colors.white12, height: 8),
                            ...(bowlers
                              ..sort((a, b) =>
                                  ((b['wickets'] ?? 0) as num).compareTo((a['wickets'] ?? 0) as num)))
                                .map((b) => _bowlerSummaryRow(b)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryHeader(List<String> cols) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(cols[0],
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700))),
          ...cols.skip(1).map((c) => SizedBox(
            width: 42,
            child: Text(c,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700)),
          )),
        ],
      ),
    );
  }

  Widget _batsmanSummaryRow(Map<String, dynamic> b) {
    final name = (b['playerName'] ?? b['name'] ?? '').toString();
    final runs = (b['runs'] ?? 0) as num;
    final balls = (b['ballsFaced'] ?? 0) as num;
    final fours = (b['fours'] ?? 0) as num;
    final sixes = (b['sixes'] ?? 0) as num;
    final sr = balls > 0 ? ((runs / balls) * 100).toStringAsFixed(1) : '0.0';
    final isOut = b['isOut'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 16 ? '${name.substring(0, 16)}…' : name,
              style: TextStyle(color: isOut ? Colors.white54 : Colors.white70, fontSize: 13),
            ),
          ),
          _sc('$runs', bold: true, color: const Color(0xFFFF7A45)),
          _sc('$balls'),
          _sc('$fours'),
          _sc('$sixes'),
          _sc(sr),
        ],
      ),
    );
  }

  Widget _bowlerSummaryRow(Map<String, dynamic> b) {
    final name = (b['playerName'] ?? b['name'] ?? '').toString();
    final overs = b['overs'] ?? 0;
    final runs = (b['runsConceded'] ?? b['runs'] ?? 0) as num;
    final wkts = (b['wickets'] ?? 0) as num;
    final eco = (b['economy'] ?? 0) as num;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.length > 16 ? '${name.substring(0, 16)}…' : name,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          _sc('$overs'),
          _sc('$runs'),
          _sc('$wkts', bold: true, color: wkts >= 3 ? const Color(0xFFFF7A45) : Colors.white),
          _sc(eco.toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _sc(String t, {bool bold = false, Color? color}) => SizedBox(
    width: 42,
    child: Text(t,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color ?? Colors.white60,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
  );
}

// ═══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════
class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: color, margin: const EdgeInsets.only(right: 8)),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ChasePill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ChasePill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
      ],
    );
  }
}


class _TeamBadge extends StatelessWidget {

  final String teamName;

  final double size;

  const _TeamBadge({required this.teamName, this.size = 28});



  @override

  Widget build(BuildContext context) {

    final initial =

    teamName.isNotEmpty ? teamName[0].toUpperCase() : '?';

    return Container(

      width: size,

      height: size,

      decoration: BoxDecoration(

        shape: BoxShape.circle,

        gradient: const LinearGradient(

            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)]),

        boxShadow: [

          BoxShadow(

              color: const Color(0xFF00A3FF).withOpacity(0.4),

              blurRadius: 8,

              spreadRadius: 1),

        ],

      ),

      child: Center(

        child: Text(initial,

            style: TextStyle(

                color: Colors.white,

                fontSize: size * 0.42,

                fontWeight: FontWeight.bold)),

      ),

    );

  }

}