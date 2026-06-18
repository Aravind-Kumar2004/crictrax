import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/models/repositories/live_score_repository.dart';


class BowlersCardWidget extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final String inningsId;

  const BowlersCardWidget({
    Key? key,
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
  }) : super(key: key);

  @override
  State<BowlersCardWidget> createState() => _BowlersCardWidgetState();
}

class _BowlersCardWidgetState extends State<BowlersCardWidget> {
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
              const Text('Bowlers',
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
                  Text('O  R  W  Econ',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
              const Divider(color: Colors.white12, height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _repo.watchBowlers(
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
                        (b['bowlingTeamId'] ?? '').toString();
                        final overs = b['overs'] ?? 0;
                        final runs = b['runsConceded'] ?? 0;
                        final wkts = b['wickets'] ?? 0;
                        final econ = overs > 0
                            ? (runs / overs).toStringAsFixed(1)
                            : '0.0';

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
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$overs  $runs  $wkts  $econ',
                                    style: const TextStyle(
                                      color: Color(0xFF00A3FF),
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