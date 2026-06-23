import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/repositories/match_detail_repository.dart';
import '../../live_score/presentation/live_score_screen.dart';
import 'widgets/innings_card_widget.dart';

class MatchDetailScreen extends StatelessWidget {
  final String matchId;
  final String tournamentId;
  final String team1Name;
  final String team2Name;
  final int overs;
  final bool isLive;
  final bool isCompleted;

  const MatchDetailScreen({
    Key? key,
    required this.matchId,
    required this.tournamentId,
    required this.team1Name,
    required this.team2Name,
    required this.overs,
    required this.isLive,
    required this.isCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final repo = MatchDetailRepository();

    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: Row(
        children: [
          Container(
            width: 80,
            color: Colors.white.withOpacity(0.02),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Focus(
                  child: Builder(builder: (context) {
                    final isFocused = Focus.of(context).hasFocus;
                    return GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? const Color(0xFF00A3FF)
                              : Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 22),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: repo.watchInnings(tournamentId, matchId),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF00A3FF)));
                        }

                        final innings = snap.data!.docs;
                        if (innings.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.sports_cricket,
                                    color: Colors.white24, size: 60),
                                const SizedBox(height: 16),
                                Text('$team1Name  vs  $team2Name',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(
                                  isLive
                                      ? 'Match in progress'
                                      : 'Match not started yet',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: innings.map((inn) {
                            return Expanded(
                              child: Padding(
                                padding:
                                const EdgeInsets.only(right: 16),
                                child: InningsCardWidget(
                                  innData: inn.data()
                                  as Map<String, dynamic>,
                                  inningsNumber:
                                  innings.indexOf(inn) + 1,
                                  tournamentId: tournamentId,
                                  matchId: matchId,
                                  inningsId: inn.id,
                                  team1Name: team1Name,
                                  team2Name: team2Name,
                                  repo: repo,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLive
                  ? Colors.redAccent.withOpacity(0.4)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(team1Name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                  ),
                  Column(children: [
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(children: [
                          Icon(Icons.circle, color: Colors.white, size: 8),
                          SizedBox(width: 4),
                          Text('LIVE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ]),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.white.withOpacity(0.1)
                              : const Color(0xFF00A3FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                            isCompleted ? 'COMPLETED' : 'UPCOMING',
                            style: TextStyle(
                                color: isCompleted
                                    ? Colors.white54
                                    : const Color(0xFF00A3FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    const SizedBox(height: 8),
                    const Text('VS',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$overs overs',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 13)),
                  ]),
                  Expanded(
                    child: Text(team2Name,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (isLive) ...[
                const SizedBox(height: 20),
                Focus(
                  child: Builder(builder: (context) {
                    final isFocused = Focus.of(context).hasFocus;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveScoreScreen(
                            matchId: matchId,
                            tournamentId: tournamentId,
                            team1Name: team1Name,
                            team2Name: team2Name,
                          ),
                        ),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isFocused
                                ? [Colors.redAccent, Colors.red]
                                : [
                              Colors.redAccent.withOpacity(0.7),
                              Colors.red.withOpacity(0.7)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Watch Live Score',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}