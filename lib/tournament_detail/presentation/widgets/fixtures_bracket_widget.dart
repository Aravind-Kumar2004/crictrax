import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/models/match_model.dart';

class FixturesBracketWidget extends StatelessWidget {
  final List<TournamentMatchModel> matches;
  final String tournamentName;
  final String tournamentFormat; // 'league', 'single_elimination', etc.
  final void Function(TournamentMatchModel) onMatchTap;

  const FixturesBracketWidget({
    Key? key,
    required this.matches,
    required this.tournamentName,
    required this.tournamentFormat,
    required this.onMatchTap,
  }) : super(key: key);

  bool get _isLeagueFormat =>
      tournamentFormat.toLowerCase().contains('league');

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Center(
        child: Text('No fixtures yet', style: TextStyle(color: Colors.white38, fontSize: 20)),
      );
    }

    return _isLeagueFormat ? _buildLeagueView() : _buildBracketView();
  }

  // ═══════════════════════════════════════════════════════════
  // LEAGUE FORMAT — flat grid of all fixtures, grouped by status,
  // no fake "round" labels since league play has no bracket shape.
  // ═══════════════════════════════════════════════════════════
  Widget _buildLeagueView() {
    final sorted = [...matches]..sort((a, b) {
      final da = a.matchDate ?? '';
      final db = b.matchDate ?? '';
      return da.compareTo(db);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_bulleted, color: Color(0xFF8E5CFF), size: 26),
              const SizedBox(width: 10),
              const Text(
                'League Fixtures',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${sorted.length} matches',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: 1.15,
            ),
            itemCount: sorted.length,
            itemBuilder: (context, i) =>
                _FixtureCard(match: sorted[i], onTap: () => onMatchTap(sorted[i])),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // KNOCKOUT / BRACKET FORMAT — only used for single_elimination etc
  // ═══════════════════════════════════════════════════════════
  Widget _buildBracketView() {
    final rounds = _groupIntoRounds(matches);

    if (rounds.isEmpty) {
      return const Center(
        child: Text('Unable to build fixtures', style: TextStyle(color: Colors.white38, fontSize: 18)),
      );
    }

    const cardHeight = 150.0;
    final maxMatchesInAnyRound = rounds.map((r) => r.length).fold(1, (a, b) => a > b ? a : b);
    final columnHeight = (maxMatchesInAnyRound * cardHeight).clamp(300.0, 1400.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: Color(0xFF8E5CFF), size: 26),
              const SizedBox(width: 10),
              const Text(
                'Tournament Fixtures',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: columnHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(rounds.length, (i) {
                  final isFinal = i == rounds.length - 1;
                  return _RoundColumn(
                    roundLabel: _roundLabel(i, rounds.length),
                    matches: rounds[i],
                    isFinal: isFinal,
                    onMatchTap: onMatchTap,
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<List<TournamentMatchModel>> _groupIntoRounds(List<TournamentMatchModel> matches) {
    final sorted = [...matches]..sort((a, b) {
      final da = a.matchDate ?? '';
      final db = b.matchDate ?? '';
      return da.compareTo(db);
    });

    if (sorted.isEmpty) return [];
    if (sorted.length == 1) return [sorted];

    final isBracketSized = _looksLikeBracket(sorted.length);

    if (!isBracketSized) {
      const chunkSize = 4;
      final rounds = <List<TournamentMatchModel>>[];
      for (var i = 0; i < sorted.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, sorted.length);
        rounds.add(sorted.sublist(i, end));
      }
      return rounds;
    }

    final rounds = <List<TournamentMatchModel>>[];
    var remaining = sorted;
    var roundSize = (sorted.length / 2).ceil();

    while (remaining.isNotEmpty) {
      final take = roundSize.clamp(1, remaining.length);
      rounds.add(remaining.sublist(0, take));
      remaining = remaining.sublist(take);
      roundSize = (roundSize / 2).ceil();
      if (roundSize < 1) roundSize = 1;
    }
    return rounds;
  }

  bool _looksLikeBracket(int total) {
    const validSizes = [1, 2, 3, 4, 7, 8, 15, 16, 31, 32];
    return validSizes.contains(total);
  }

  String _roundLabel(int index, int totalRounds) {
    if (totalRounds == 1) return 'Matches';
    final remaining = totalRounds - index;
    if (remaining == 1) return 'Final';
    if (remaining == 2) return 'Semi Finals';
    if (remaining == 3) return 'Quarter Finals';
    return 'Round ${index + 1}';
  }
}

class _RoundColumn extends StatelessWidget {
  final String roundLabel;
  final List<TournamentMatchModel> matches;
  final bool isFinal;
  final void Function(TournamentMatchModel) onMatchTap;

  const _RoundColumn({
    required this.roundLabel,
    required this.matches,
    required this.isFinal,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 28),
      child: SizedBox(
        width: 230,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isFinal
                      ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                      : [const Color(0xFF1E3A6E), const Color(0xFF0F2447)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                roundLabel.toUpperCase(),
                style: TextStyle(
                  color: isFinal ? Colors.black87 : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...matches.map((m) => _FixtureCard(match: m, onTap: () => onMatchTap(m))),
          ],
        ),
      ),
    );
  }
}

class _FixtureCard extends StatelessWidget {
  final TournamentMatchModel match;
  final VoidCallback onTap;

  const _FixtureCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // ── FIX: trust isCompleted FIRST, before checking isLive at all.
    // A match that's completed must never show LIVE, regardless of
    // any other flag combination on the underlying data.
    final isCompleted = match.isCompleted;
    final isLive = !isCompleted && match.isLive;

    final statusColor = isLive
        ? Colors.redAccent
        : isCompleted
        ? Colors.white38
        : const Color(0xFF00A3FF);

    return Focus(
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.identity()..scale(isFocused ? 1.03 : 1.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isFocused
                      ? statusColor
                      : (isLive ? statusColor.withOpacity(0.5) : Colors.white.withOpacity(0.12)),
                  width: isFocused ? 2 : 1,
                ),
                boxShadow: isFocused
                    ? [BoxShadow(color: statusColor.withOpacity(0.3), blurRadius: 16, spreadRadius: 1)]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    color: isLive
                        ? Colors.redAccent.withOpacity(0.05)
                        : Colors.white.withOpacity(0.03),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: _teamRow(match.teamId1Name)),
                            if (isLive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('LIVE',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              )
                            else if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('DONE',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('vs',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                        _teamRow(match.teamId2Name),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.sports_cricket, color: Colors.white24, size: 11),
                            const SizedBox(width: 4),
                            Text('${match.overs} ov',
                                style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _teamRow(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00A3FF).withOpacity(0.15),
            border: Border.all(color: const Color(0xFF00A3FF), width: 1),
          ),
          child: Center(
            child: Text(initial,
                style: const TextStyle(
                    color: Color(0xFF00A3FF), fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name.isEmpty ? 'TBD' : name,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}