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

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFF050A18);
  static const surface  = Color(0xFF0A1628);
  static const surfaceH = Color(0xFF0F1E35);
  static const accent   = Color(0xFF00D4FF);
  static const accentDim= Color(0xFF0066CC);
  static const live     = Color(0xFFFF3D3D);
  static const upcoming = Color(0xFF00D4FF);
  static const completed= Color(0xFF8A8FA8);
  static const fixtures = Color(0xFF8E5CFF);
  static const success  = Color(0xFF00E676);
}

enum MatchTab { live, upcoming, completed, fixtures }

// ═══════════════════════════════════════════════════════════════════════════════
// TOURNAMENT DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  final TournamentEntity tournament;
  final String? sessionId;

  const TournamentDetailScreen({
    Key? key,
    required this.tournamentId,
    required this.tournament,
    this.sessionId,
  }) : super(key: key);

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  // ── Business Logic State (UNCHANGED) ───────────────────────────────────────
  final _repo = TournamentDetailRepository();
  List<TournamentMatchModel> _live      = [];
  List<TournamentMatchModel> _upcoming  = [];
  List<TournamentMatchModel> _completed = [];
  List<TournamentMatchModel> _all       = [];
  bool _loading = true;
  MatchTab _selectedTab = MatchTab.fixtures;
  StreamSubscription<List<TournamentMatchModel>>? _matchesSub;

  // ── Animation ───────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _watchMatches();
  }

  // ── Business Logic (COMPLETELY UNCHANGED) ───────────────────────────────────
  void _watchMatches() {
    _matchesSub?.cancel();
    _matchesSub = _repo.watchMatches(widget.tournamentId).listen((rawMatches) {
      if (!mounted) return;

      final uniqueMatches = <String, TournamentMatchModel>{};
      for (final m in rawMatches) {
        if (uniqueMatches.containsKey(m.id)) {
          if (m.isCompleted) uniqueMatches[m.id] = m;
        } else {
          uniqueMatches[m.id] = m;
        }
      }

      final matches   = uniqueMatches.values.toList();
      final live      = <TournamentMatchModel>[];
      final upcoming  = <TournamentMatchModel>[];
      final completed = <TournamentMatchModel>[];

      for (final m in matches) {
        if (m.isCompleted)  completed.add(m);
        else if (m.isLive)  live.add(m);
        else                upcoming.add(m);
      }

      setState(() {
        _all       = matches;
        _live      = live;
        _upcoming  = upcoming;
        _completed = completed;
        _loading   = false;
      });
    });
  }

  @override
  void dispose() {
    _matchesSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _openMatch(TournamentMatchModel m) {
    if (m.isLive) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => LiveScoreScreen(
          matchId: m.id,
          tournamentId: widget.tournamentId,
          team1Name: m.teamId1Name,
          team2Name: m.teamId2Name,
          team1Id: m.teamId1,
          team2Id: m.teamId2,
          sessionId: widget.sessionId,
        ),
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
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
      ));
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingScreen();

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -100, left: -60,
            child: _Glow(color: _C.fixtures, size: 340),
          ),
          Positioned(
            bottom: -80, right: -40,
            child: _Glow(color: _C.accent, size: 280),
          ),
          Row(
            children: [
              _LeftPanel(
                tournament: widget.tournament,
                selectedTab: _selectedTab,
                liveCount: _live.length,
                upcomingCount: _upcoming.length,
                completedCount: _completed.length,
                pulseAnim: _pulseAnim,
                onTabChanged: (t) => setState(() => _selectedTab = t),
                onBack: () => Navigator.pop(context),
              ),
              Expanded(child: _buildContentPanel()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [_C.accent, _C.accentDim]),
                boxShadow: [BoxShadow(color: _C.accent.withOpacity(0.4), blurRadius: 24)],
              ),
              child: const Icon(Icons.sports_cricket, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  backgroundColor: Color(0xFF0F1E35),
                  valueColor: AlwaysStoppedAnimation<Color>(_C.accent),
                  minHeight: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentPanel() {
    if (_all.isEmpty && _selectedTab == MatchTab.fixtures) {
      return _buildEmptyState('No matches scheduled yet',
          'Matches will appear here once they are added.');
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
        return _buildMatchList(_live, 'Live Now', _C.live,
            icon: Icons.circle, emptyText: 'No live matches right now',
            emptySub: 'Live matches will appear here when they start.');
      case MatchTab.upcoming:
        return _buildMatchList(_upcoming, 'Upcoming', _C.upcoming,
            icon: Icons.schedule_rounded, emptyText: 'No upcoming matches',
            emptySub: 'Scheduled matches will appear here.');
      case MatchTab.completed:
        return _buildMatchList(_completed, 'Completed', _C.completed,
            icon: Icons.check_circle_rounded, emptyText: 'No completed matches',
            emptySub: 'Finished matches will be listed here.');
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMatchList(
      List<TournamentMatchModel> matches,
      String title,
      Color color, {
        required IconData icon,
        required String emptyText,
        required String emptySub,
      }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(36, 36, 36, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title, color: color, icon: icon, count: matches.length),
          const SizedBox(height: 24),
          if (matches.isEmpty)
            _buildEmptyState(emptyText, emptySub)
          else
            ...matches.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MatchCardWidget(match: m, onTap: () => _openMatch(m)),
            )),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.accent.withOpacity(0.04),
                border: Border.all(color: _C.accent.withOpacity(0.1), width: 1),
              ),
              child: Icon(Icons.sports_cricket,
                  color: _C.accent.withOpacity(0.2), size: 32),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(sub,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.22),
                    fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEFT PANEL
// ═══════════════════════════════════════════════════════════════════════════════
class _LeftPanel extends StatelessWidget {
  final TournamentEntity tournament;
  final MatchTab selectedTab;
  final int liveCount, upcomingCount, completedCount;
  final Animation<double> pulseAnim;
  final ValueChanged<MatchTab> onTabChanged;
  final VoidCallback onBack;

  const _LeftPanel({
    required this.tournament,
    required this.selectedTab,
    required this.liveCount,
    required this.upcomingCount,
    required this.completedCount,
    required this.pulseAnim,
    required this.onTabChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: _C.surface.withOpacity(0.6),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Back button & logo bar ──────────────────────────────────────
          _TopBar(onBack: onBack),

          // ── Tournament identity card ────────────────────────────────────
          _TournamentIdentity(tournament: tournament),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Nav tiles ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.account_tree_rounded,
                  label: 'Fixtures',
                  color: _C.fixtures,
                  count: null,
                  isSelected: selectedTab == MatchTab.fixtures,
                  onTap: () => onTabChanged(MatchTab.fixtures),
                ),
                const SizedBox(height: 8),
                _NavTile(
                  icon: Icons.circle,
                  label: 'Live',
                  color: _C.live,
                  count: liveCount,
                  isSelected: selectedTab == MatchTab.live,
                  onTap: () => onTabChanged(MatchTab.live),
                  pulseAnim: liveCount > 0 ? pulseAnim : null,
                ),
                const SizedBox(height: 8),
                _NavTile(
                  icon: Icons.schedule_rounded,
                  label: 'Upcoming',
                  color: _C.upcoming,
                  count: upcomingCount,
                  isSelected: selectedTab == MatchTab.upcoming,
                  onTap: () => onTabChanged(MatchTab.upcoming),
                ),
                const SizedBox(height: 8),
                _NavTile(
                  icon: Icons.check_circle_rounded,
                  label: 'Completed',
                  color: _C.completed,
                  count: completedCount,
                  isSelected: selectedTab == MatchTab.completed,
                  onTap: () => onTabChanged(MatchTab.completed),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Bottom status badge ─────────────────────────────────────────
          _StatusBadge(tournament: tournament),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Top Bar (back button + logo) ─────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Row(
        children: [
          Focus(
            child: Builder(builder: (ctx) {
              final focused = Focus.of(ctx).hasFocus;
              return GestureDetector(
                onTap: onBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: focused
                        ? _C.accent.withOpacity(0.15)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: focused
                          ? _C.accent.withOpacity(0.4)
                          : Colors.white.withOpacity(0.07),
                    ),
                    boxShadow: focused
                        ? [BoxShadow(color: _C.accent.withOpacity(0.2), blurRadius: 12)]
                        : [],
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      color: focused ? _C.accent : Colors.white.withOpacity(0.5),
                      size: 18),
                ),
              );
            }),
          ),
          const SizedBox(width: 12),
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [_C.accent, _C.accentDim],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: _C.accent.withOpacity(0.35), blurRadius: 10)],
            ),
            child: const Icon(Icons.sports_cricket, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Text('CRICTRAX',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              )),
        ],
      ),
    );
  }
}

// ─── Tournament Identity Block ────────────────────────────────────────────────
class _TournamentIdentity extends StatelessWidget {
  final TournamentEntity tournament;
  const _TournamentIdentity({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trophy icon + tournament name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _C.fixtures.withOpacity(0.1),
                  border: Border.all(color: _C.fixtures.withOpacity(0.2)),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: _C.fixtures, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Meta info
          if (t.ground.isNotEmpty) _InfoRow(Icons.stadium_rounded, t.ground),
          if (t.city.isNotEmpty)   _InfoRow(Icons.location_on_rounded, t.city),
          if (t.format.isNotEmpty) _InfoRow(Icons.format_list_bulleted_rounded, t.format),
          if (t.organizerName.isNotEmpty)
            _InfoRow(Icons.person_rounded, t.organizerName),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.22), size: 13),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ─── Nav Tile ─────────────────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;
  final Animation<double>? pulseAnim;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;
        final active = focused || isSelected;

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: active ? color.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? color.withOpacity(0.4) : Colors.white.withOpacity(0.05),
                width: active ? 1 : 1,
              ),
              boxShadow: active
                  ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12)]
                  : [],
            ),
            child: Row(
              children: [
                // Icon with optional pulse
                pulseAnim != null
                    ? AnimatedBuilder(
                  animation: pulseAnim!,
                  builder: (_, __) => Icon(icon,
                      color: color.withOpacity(0.5 + 0.5 * pulseAnim!.value),
                      size: 16),
                )
                    : Icon(icon,
                    color: active ? color : Colors.white.withOpacity(0.25),
                    size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        letterSpacing: 0.1,
                      )),
                ),
                if (count != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(active ? 0.18 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Text('$count',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── Status Badge (bottom of left panel) ─────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final TournamentEntity tournament;
  const _StatusBadge({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final status = tournament.status;
    final Color color;
    final IconData icon;
    switch (status) {
      case 'Active':
        color = _C.success; icon = Icons.play_circle_fill_rounded;
      case 'Upcoming':
        color = _C.accent;  icon = Icons.schedule_rounded;
      default:
        color = _C.completed; icon = Icons.check_circle_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Text(
              '$status Tournament',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.color,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                )),
            Text(
              '$count match${count == 1 ? '' : 'es'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Ambient Glow ─────────────────────────────────────────────────────────────
class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.07), color.withOpacity(0.02), Colors.transparent],
        ),
      ),
    );
  }
}