import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../dashboard/domain/entities/tournament_entity.dart';
import '../data/models/match_model.dart';
import '../data/repositories/tournament_detail_repository.dart';
import '../../match_detail/presentation/match_detail_screen.dart';
import 'widgets/match_card_widget.dart';
import '../../live_score/presentation/live_score_screen.dart';
import 'widgets/fixtures_bracket_widget.dart';

enum MatchTab { live, upcoming, completed, fixtures }

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  final TournamentEntity tournament;
  final String? sessionId; // ← ADD

  const TournamentDetailScreen({
    Key? key,
    required this.tournamentId,
    required this.tournament,
    this.sessionId, // ← ADD
  }) : super(key: key);

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final _repo = TournamentDetailRepository();
  List<TournamentMatchModel> _live = [];
  List<TournamentMatchModel> _upcoming = [];
  List<TournamentMatchModel> _completed = [];
  List<TournamentMatchModel> _all = [];
  bool _loading = true;
  MatchTab _selectedTab = MatchTab.fixtures;
  StreamSubscription<List<TournamentMatchModel>>? _matchesSub;

  @override
  void initState() {
    super.initState();
    _watchMatches();
  }

  void _watchMatches() {
    _matchesSub?.cancel();
    _matchesSub = _repo.watchMatches(widget.tournamentId).listen((rawMatches) {
      if (!mounted) return;


      final uniqueMatches = <String, TournamentMatchModel>{};

      for (final m in rawMatches) {
        if (uniqueMatches.containsKey(m.id)) {
          // If we find a duplicate, always prefer the one that says it is completed
          if (m.isCompleted) {
            uniqueMatches[m.id] = m;
          }
        } else {
          uniqueMatches[m.id] = m;
        }
      }

      // Use our clean, deduplicated list from here on
      final matches = uniqueMatches.values.toList();

      final live = <TournamentMatchModel>[];
      final upcoming = <TournamentMatchModel>[];
      final completed = <TournamentMatchModel>[];

      for (final m in matches) {
        // isCompleted always wins
        if (m.isCompleted) {
          completed.add(m);
        }
        else if (m.isLive) {
          live.add(m);
        }
        else {
          upcoming.add(m);
        }

      }

      setState(() {
        _all = matches;
        _live = live;
        _upcoming = upcoming;
        _completed = completed;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _matchesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A3FF)))
          : Row(
        children: [
          _buildLeftPanel(),
          Expanded(child: _buildContentPanel()),
        ],
      ),
    );
  }

  // ... rest of the file (build_LeftPanel, _navTile, _buildContentPanel,
  // _buildMatchList, _openMatch, _header, _info) stays EXACTLY the same
  // as your current version — no changes needed below this point.

  Widget _buildLeftPanel() {
    final t = widget.tournament;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Focus(
            child: Builder(builder: (context) {
              final isFocused = Focus.of(context).hasFocus;
              return GestureDetector(
                onTap: () => Navigator.pop(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFocused ? const Color(0xFF00A3FF) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Back', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          Text(t.name,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _info(Icons.location_on, t.ground),
          const SizedBox(height: 10),
          _info(Icons.place, t.city),
          const SizedBox(height: 10),
          _info(Icons.format_list_bulleted, t.format),
          const SizedBox(height: 10),
          _info(Icons.person, t.organizerName),
          const SizedBox(height: 32),

          // Fixtures tab (bracket view)
          _navTile(
            icon: Icons.account_tree_outlined,
            label: 'Fixtures',
            color: const Color(0xFF8E5CFF),
            count: null,
            isSelected: _selectedTab == MatchTab.fixtures,
            onTap: () => setState(() => _selectedTab = MatchTab.fixtures),
          ),
          const SizedBox(height: 10),
          _navTile(
            icon: Icons.circle,
            label: 'Live',
            color: Colors.redAccent,
            count: _live.length,
            isSelected: _selectedTab == MatchTab.live,
            onTap: () => setState(() => _selectedTab = MatchTab.live),
          ),
          const SizedBox(height: 10),
          _navTile(
            icon: Icons.access_time,
            label: 'Upcoming',
            color: const Color(0xFF00A3FF),
            count: _upcoming.length,
            isSelected: _selectedTab == MatchTab.upcoming,
            onTap: () => setState(() => _selectedTab = MatchTab.upcoming),
          ),
          const SizedBox(height: 10),
          _navTile(
            icon: Icons.check_circle_outline,
            label: 'Completed',
            color: Colors.white54,
            count: _completed.length,
            isSelected: _selectedTab == MatchTab.completed,
            onTap: () => setState(() => _selectedTab = MatchTab.completed),
          ),
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String label,
    required Color color,
    required int? count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Focus(
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        final highlighted = isFocused || isSelected;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: highlighted ? color.withOpacity(0.16) : color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: highlighted ? color.withOpacity(0.6) : color.withOpacity(0.15),
                width: highlighted ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: highlighted ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500)),
                ),
                if (count != null)
                  Text('$count',
                      style: TextStyle(
                          color: color, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContentPanel() {
    if (_all.isEmpty && _selectedTab == MatchTab.fixtures) {
      return const Center(
        child: Text('No matches found for this tournament',
            style: TextStyle(color: Colors.white38, fontSize: 18)),
      );
    }

    switch (_selectedTab) {
      case MatchTab.fixtures:
        return FixturesBracketWidget(
          matches: _all,
          tournamentName: widget.tournament.name,
          tournamentFormat: widget.tournament.format,
          onMatchTap: _openMatch,
        );
      case MatchTab.live:
        return _buildMatchList(_live, '🔴 Live Now', Colors.redAccent,
            emptyText: 'No live matches right now');
      case MatchTab.upcoming:
        return _buildMatchList(_upcoming, '🕐 Upcoming', const Color(0xFF00A3FF),
            emptyText: 'No upcoming matches scheduled');
      case MatchTab.completed:
        return _buildMatchList(_completed, '✅ Completed', Colors.white54,
            emptyText: 'No completed matches yet');
      default: // ADD THIS — avoids a runtime crash if MatchTab grows
        return const SizedBox.shrink();
    }
  }

  Widget _buildMatchList(List<TournamentMatchModel> matches, String title, Color color,
      {required String emptyText}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(title, color),
          const SizedBox(height: 16),
          if (matches.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Text(emptyText, style: const TextStyle(color: Colors.white38, fontSize: 20)),
              ),
            )
          else
            ...matches.map((m) => MatchCardWidget(match: m, onTap: () => _openMatch(m))),
        ],
      ),
    );
  }

void _openMatch(TournamentMatchModel m) {
    if (m.isLive) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveScoreScreen(
            matchId: m.id,
            tournamentId: widget.tournamentId,
            team1Name: m.teamId1Name,
            team2Name: m.teamId2Name,
            team1Id: m.teamId1,
            team2Id: m.teamId2,
            sessionId: widget.sessionId, // ← ADD
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchDetailScreen(
            matchId: m.id,
            tournamentId: widget.tournamentId,
            team1Name: m.teamId1Name,
            team2Name: m.teamId2Name,
            team1Id: m.teamId1,
            team2Id: m.teamId2,
            overs: m.overs,
            isLive: m.isLive,
            isCompleted: m.isCompleted,
          ),
        ),
      );
    }
  }
  Widget _header(String title, Color color) =>
      Text(title, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold));

  Widget _info(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(children: [
      Icon(icon, color: Colors.white38, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 14))),
    ]);
  }
}