import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/models/repositories/live_score_repository.dart';


class BatsmenCardWidget extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final String inningsId;

  const BatsmenCardWidget({
    Key? key,
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
  }) : super(key: key);

  @override
  State<BatsmenCardWidget> createState() => _BatsmenCardWidgetState();
}

class _BatsmenCardWidgetState extends State<BatsmenCardWidget> {
  final _repo = LiveScoreRepository();
  final Map<String, String> _resolvedNames = {};

  Future<String> _getName(
      String teamId, String playerId, String fallback) async {
    if (fallback.isNotEmpty) return fallback;
    final cacheKey = '$teamId-$playerId';
    if (_resolvedNames.containsKey(cacheKey)) {
      return _resolvedNames[cacheKey]!;
    }
    final resolved =
    await _repo.resolvePlayerName(widget.tournamentId, teamId, playerId);
    _resolvedNames[cacheKey] = resolved;
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Batsmen',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Player',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  Text('R  B  4s  6s  SR',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
              const Divider(color: Colors.white12, height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _repo.watchBatsmen(
                      widget.tournamentId, widget.matchId, widget.inningsId),
                  builder: (context, snap) {
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return const Center(
                          child: Text('No data',
                              style: TextStyle(color: Colors.white38)));
                    }
                    return ListView(
                      children: snap.data!.docs.map((doc) {
                        final b = doc.data() as Map<String, dynamic>;
                        final rawName = (b['playerName'] ?? '').toString();
                        final playerId = (b['playerId'] ?? '').toString();
                        final teamId =
                        (b['battingTeamId'] ?? '').toString();
                        final runs = b['runs'] ?? 0;
                        final balls = b['ballsFaced'] ?? 0;
                        final fours = b['fours'] ?? 0;
                        final sixes = b['sixes'] ?? 0;
                        final sr = balls > 0
                            ? ((runs / balls) * 100).toStringAsFixed(1)
                            : '0.0';
                        final isOut = b['isOut'] ?? false;

                        return FutureBuilder<String>(
                          future: _getName(teamId, playerId, rawName),
                          builder: (context, nameSnap) {
                            final displayName =
                                nameSnap.data ?? (rawName.isEmpty ? '...' : rawName);
                            return Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      style: TextStyle(
                                        color: isOut
                                            ? Colors.white30
                                            : Colors.white,
                                        fontSize: 15,
                                        decoration: isOut
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$runs  $balls  $fours  $sixes  $sr',
                                    style: TextStyle(
                                      color: isOut
                                          ? Colors.white30
                                          : const Color(0xFF00A3FF),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
    );
  }
}