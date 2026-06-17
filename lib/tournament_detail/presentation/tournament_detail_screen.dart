import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../dashboard/domain/entities/tournament_entity.dart';
import '../data/models/match_model.dart';
import '../data/repositories/tournament_detail_repository.dart';
import '../../match_detail/presentation/match_detail_screen.dart';
import 'widgets/match_card_widget.dart';
import '../../live_score/presentation/live_score_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  final TournamentEntity tournament;

  const TournamentDetailScreen({
    Key? key,
    required this.tournamentId,
    required this.tournament,
  }) : super(key: key);

  @override
  State<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState
    extends State<TournamentDetailScreen> {
  final _repo = TournamentDetailRepository();
  List<TournamentMatchModel> _live = [];
  List<TournamentMatchModel> _upcoming = [];
  List<TournamentMatchModel> _completed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    final matches =
    await _repo.getMatches(widget.tournamentId);
    final live = <TournamentMatchModel>[];
    final upcoming = <TournamentMatchModel>[];
    final completed = <TournamentMatchModel>[];

    for (final m in matches) {
      if (m.isCompleted) {
        completed.add(m);
      } else if (m.isLive) {
        live.add(m);
      } else {
        upcoming.add(m);
      }
    }

    setState(() {
      _live = live;
      _upcoming = upcoming;
      _completed = completed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(
              color: Color(0xFF00A3FF)))
          : Row(
        children: [
          _buildLeftPanel(),
          Expanded(child: _buildMatchesPanel()),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    final t = widget.tournament;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(
            right: BorderSide(
                color: Colors.white.withOpacity(0.08))),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? const Color(0xFF00A3FF)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Back',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          Text(t.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _info(Icons.location_on, t.ground),
          const SizedBox(height: 10),
          _info(Icons.place, t.city),
          const SizedBox(height: 10),
          _info(Icons.format_list_bulleted, t.format),
          const SizedBox(height: 10),
          _info(Icons.person, t.organizerName),
          const SizedBox(height: 32),
          _stat('🔴 Live', _live.length.toString(),
              Colors.redAccent),
          const SizedBox(height: 10),
          _stat('🕐 Upcoming', _upcoming.length.toString(),
              const Color(0xFF00A3FF)),
          const SizedBox(height: 10),
          _stat('✅ Completed',
              _completed.length.toString(), Colors.white38),
        ],
      ),
    );
  }

  Widget _buildMatchesPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_live.isNotEmpty) ...[
            _header('🔴  Live Now', Colors.redAccent),
            const SizedBox(height: 16),
            ..._live.map((m) => MatchCardWidget(
              match: m,
              onTap: () => _openMatch(m),
            )),
            const SizedBox(height: 32),
          ],
          if (_upcoming.isNotEmpty) ...[
            _header('🕐  Upcoming', const Color(0xFF00A3FF)),
            const SizedBox(height: 16),
            ..._upcoming.map((m) => MatchCardWidget(
              match: m,
              onTap: () => _openMatch(m),
            )),
            const SizedBox(height: 32),
          ],
          if (_completed.isNotEmpty) ...[
            _header('✅  Completed', Colors.white38),
            const SizedBox(height: 16),
            ..._completed.map((m) => MatchCardWidget(
              match: m,
              onTap: () => _openMatch(m),
            )),
          ],
          if (_live.isEmpty &&
              _upcoming.isEmpty &&
              _completed.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: Text('No matches scheduled yet',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 20)),
              ),
            ),
        ],
      ),
    );
  }

  void _openMatch(TournamentMatchModel m) {
    if (m.isLive) {
      // Live matches go straight to the live score broadcast view
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveScoreScreen(
            matchId: m.id,
            tournamentId: widget.tournamentId,
            team1Name: m.teamId1Name,
            team2Name: m.teamId2Name,
          ),
        ),
      );
    } else {
      // Upcoming/completed matches go to the detail page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchDetailScreen(
            matchId: m.id,
            tournamentId: widget.tournamentId,
            team1Name: m.teamId1Name,
            team2Name: m.teamId2Name,
            overs: m.overs,
            isLive: m.isLive,
            isCompleted: m.isCompleted,
          ),
        ),
      );
    }
  }

  Widget _header(String title, Color color) => Text(title,
      style: TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.bold));

  Widget _info(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(children: [
      Icon(icon, color: Colors.white38, size: 16),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 14))),
    ]);
  }

  Widget _stat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}