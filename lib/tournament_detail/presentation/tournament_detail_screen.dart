import 'dart:async';
import 'package:flutter/material.dart';
import '../../../dashboard/domain/entities/tournament_entity.dart';
import '../../background/background_manager.dart';
import '../data/models/match_model.dart';
import '../data/repositories/tournament_detail_repository.dart';
import '../../match_detail/presentation/match_detail_screen.dart';
import 'widgets/match_card_widget.dart';
import '../../live_score/presentation/live_score_screen.dart';
import 'widgets/fixtures_bracket_widget.dart';
import '../../background/dynamic_background_view.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF050A18);
  static const surface   = Color(0xFF0A1628);
  static const surfaceH  = Color(0xFF0F1E35);
  static const accent    = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live      = Color(0xFFFF3D3D);
  static const upcoming  = Color(0xFF00D4FF);
  static const completed = Color(0xFF8A8FA8);
  static const fixtures  = Color(0xFF8E5CFF);
  static const success   = Color(0xFF00E676);
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

  // ── Business Logic State (COMPLETELY UNCHANGED) ─────────────────────────────
  final _repo = TournamentDetailRepository();
  List<TournamentMatchModel> _live      = [];
  List<TournamentMatchModel> _upcoming  = [];
  List<TournamentMatchModel> _completed = [];
  List<TournamentMatchModel> _all       = [];
  bool _loading = true;
  MatchTab _selectedTab = MatchTab.fixtures;
  StreamSubscription<List<TournamentMatchModel>>? _matchesSub;
  late final BackgroundManager<MatchTab> _backgroundManager;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _backgroundManager = BackgroundManager<MatchTab>(
      leftPlayerAsset: 'assets/images/players/left_player.png',

      tabAssets: {
        MatchTab.fixtures: const TabPlayerAssets(
          rightPlayerAsset: 'assets/images/players/fixtures_player.png',
        ),

        MatchTab.live: const TabPlayerAssets(
          rightPlayerAsset: 'assets/images/players/live_player.png',
        ),

        MatchTab.upcoming: const TabPlayerAssets(
          rightPlayerAsset: 'assets/images/players/upcoming_player.png',
        ),

        MatchTab.completed: const TabPlayerAssets(
          rightPlayerAsset: 'assets/images/players/completed_player.png',
        ),
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _backgroundManager.precacheAll(context);
    });

    //────────────────────────────────────
    // Existing Animation Controller
    //────────────────────────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = CurvedAnimation(
      parent: _pulseCtrl,
      curve: Curves.easeInOut,
    );

    //────────────────────────────────────
    // Existing Match Listener
    //────────────────────────────────────
    _watchMatches();
  }

  // ── Business Logic (COMPLETELY UNCHANGED) ────────────────────────────────────
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

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingScreen();


    return Scaffold(
      backgroundColor: _C.bg,
      body: DynamicBackgroundView<MatchTab>(
        backgroundImage: 'assets/images/backgrounds/tournament_bg.jpg',

        manager: _backgroundManager,

        selectedTab: _selectedTab,

        foreground: Stack(
          children: [

            // Ambient glow
            Positioned(
              top: -100,
              left: -60,
              child: _Glow(
                color: _C.fixtures,
                size: 340,
              ),
            ),

            Positioned(
              bottom: -80,
              right: -40,
              child: _Glow(
                color: _C.accent,
                size: 280,
              ),
            ),

            // Your existing UI
            Row(
              children: [
                _LeftSidebar(
                  tournament: widget.tournament,
                  selectedTab: _selectedTab,
                  liveCount: _live.length,
                  upcomingCount: _upcoming.length,
                  completedCount: _completed.length,
                  pulseAnim: _pulseAnim,
                  onTabChanged: (t) => setState(() => _selectedTab = t),
                  onBack: () => Navigator.pop(context),
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TournamentHeaderCard(
                        tournament: widget.tournament,
                      ),

                      _HorizontalTabBar(
                        selectedTab: _selectedTab,
                        liveCount: _live.length,
                        upcomingCount: _upcoming.length,
                        completedCount: _completed.length,
                        pulseAnim: _pulseAnim,
                        onTabChanged: (t) =>
                            setState(() => _selectedTab = t),
                      ),

                      Expanded(
                        child: _buildContentPanel(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
      ),
    );
  }

  Widget _buildContentPanel() {
    if (_all.isEmpty && _selectedTab == MatchTab.fixtures) {
      return _buildEmptyState(
          'No matches scheduled yet', 'Matches will appear here once they are added.');
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
        return _buildMatchList(_live, _C.live,
            emptyText: 'No live matches right now',
            emptySub: 'Live matches will appear here when they start.');
      case MatchTab.upcoming:
        return _buildMatchList(_upcoming, _C.upcoming,
            emptyText: 'No upcoming matches',
            emptySub: 'Scheduled matches will appear here.');
      case MatchTab.completed:
        return _buildMatchList(_completed, _C.completed,
            emptyText: 'No completed matches',
            emptySub: 'Finished matches will be listed here.');
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMatchList(
      List<TournamentMatchModel> matches,
      Color color, {
        required String emptyText,
        required String emptySub,
      }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (matches.isEmpty)
            _buildEmptyState(emptyText, emptySub)
          else
            ...matches.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: MatchCardWidget(match: m, onTap: () => _openMatch(m)),
            )),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Center(
        child: Column(children: [
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
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEFT SIDEBAR  (220 px, semi-transparent so player image bleeds through)
// ═══════════════════════════════════════════════════════════════════════════════
class _LeftSidebar extends StatelessWidget {
  final TournamentEntity tournament;
  final MatchTab selectedTab;
  final int liveCount, upcomingCount, completedCount;
  final Animation<double> pulseAnim;
  final ValueChanged<MatchTab> onTabChanged;
  final VoidCallback onBack;

  const _LeftSidebar({
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
      width: 220,
      decoration: BoxDecoration(
        // Semi-transparent so the player image is faintly visible behind it
        color: _C.surface.withOpacity(0.82),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo bar ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [_C.accent, _C.accentDim],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: _C.accent.withOpacity(0.35), blurRadius: 10)],
                ),
                child: const Icon(Icons.sports_cricket, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: 'CRICTRAX ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5,
                    ),
                  ),
                  const TextSpan(
                    text: 'TV',
                    style: TextStyle(
                      color: _C.accent,
                      fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5,
                    ),
                  ),
                ]),
              ),
            ]),
          ),

          // ── Back button ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Focus(
              child: Builder(builder: (ctx) {
                final f = Focus.of(ctx).hasFocus;
                return GestureDetector(
                  onTap: onBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: f
                          ? _C.accent.withOpacity(0.12)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: f
                            ? _C.accent.withOpacity(0.35)
                            : Colors.white.withOpacity(0.07),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.arrow_back_rounded,
                          color: f
                              ? _C.accent
                              : Colors.white.withOpacity(0.45),
                          size: 16),
                      const SizedBox(width: 8),
                      Text('Back',
                          style: TextStyle(
                            color: f
                                ? _C.accent
                                : Colors.white.withOpacity(0.4),
                            fontSize: 13, fontWeight: FontWeight.w600,
                          )),
                    ]),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 22),
          _Divider(),
          const SizedBox(height: 18),

          // ── Nav tiles ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: [
              _NavTile(
                icon: Icons.calendar_today_rounded,
                label: 'Fixtures',
                color: _C.fixtures,
                count: null,
                isSelected: selectedTab == MatchTab.fixtures,
                onTap: () => onTabChanged(MatchTab.fixtures),
              ),
              const SizedBox(height: 6),
              _NavTile(
                icon: Icons.sensors_rounded,
                label: 'Live',
                color: _C.live,
                count: liveCount,
                isSelected: selectedTab == MatchTab.live,
                onTap: () => onTabChanged(MatchTab.live),
                pulseAnim: liveCount > 0 ? pulseAnim : null,
              ),
              const SizedBox(height: 6),
              _NavTile(
                icon: Icons.schedule_rounded,
                label: 'Upcoming',
                color: _C.upcoming,
                count: upcomingCount,
                isSelected: selectedTab == MatchTab.upcoming,
                onTap: () => onTabChanged(MatchTab.upcoming),
              ),
              const SizedBox(height: 6),
              _NavTile(
                icon: Icons.check_circle_rounded,
                label: 'Completed',
                color: _C.completed,
                count: completedCount,
                isSelected: selectedTab == MatchTab.completed,
                onTap: () => onTabChanged(MatchTab.completed),
              ),
            ]),
          ),

          const Spacer(),

          // ── Status badge at bottom ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 26),
            child: _StatusBadge(status: tournament.status),
          ),
        ],
      ),
    );
  }
}

// ── Nav Tile ──────────────────────────────────────────────────────────────────
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
        final active  = focused || isSelected;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: active ? color.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? color.withOpacity(0.4)
                    : Colors.white.withOpacity(0.05),
              ),
              boxShadow: active
                  ? [BoxShadow(color: color.withOpacity(0.14), blurRadius: 12)]
                  : [],
            ),
            child: Row(children: [
              pulseAnim != null
                  ? AnimatedBuilder(
                animation: pulseAnim!,
                builder: (_, __) => Icon(icon,
                    color: color.withOpacity(0.5 + 0.5 * pulseAnim!.value),
                    size: 15),
              )
                  : Icon(icon,
                  color: active ? color : Colors.white.withOpacity(0.25),
                  size: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    )),
              ),
              if (count != null && count! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text('$count',
                      style: TextStyle(
                          color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
        );
      }),
    );
  }
}

// ── Status Badge (bottom of sidebar) ─────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    switch (status) {
      case 'Active':
        color = _C.success; icon = Icons.circle;
      case 'Upcoming':
        color = _C.accent;  icon = Icons.schedule_rounded;
      default:
        color = _C.completed; icon = Icons.check_circle_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 8),
        Text(
          '$status Tournament',
          style: TextStyle(
              color: color, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOURNAMENT HEADER CARD  (top of main content — matching reference image 5)
// ═══════════════════════════════════════════════════════════════════════════════
class _TournamentHeaderCard extends StatelessWidget {
  final TournamentEntity tournament;
  const _TournamentHeaderCard({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 20, 36, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tournament logo / trophy ──────────────────────────────────────
          // TODO: Replace with your tournament emblem image:
          //   Image.asset('assets/images/tournament_logo.png', width: 90, height: 90, fit: BoxFit.cover)
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _C.fixtures.withOpacity(0.08),
              border: Border.all(color: _C.fixtures.withOpacity(0.25)),
              boxShadow: [BoxShadow(color: _C.fixtures.withOpacity(0.15), blurRadius: 20)],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/tournament_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.emoji_events_rounded, color: _C.fixtures, size: 36),
            ),
          ),
          const SizedBox(width: 20),

          // ── Name + meta chips ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.emoji_events_rounded, color: _C.accent, size: 13),
                  const SizedBox(width: 6),
                  Text('TOURNAMENT',
                      style: TextStyle(
                        color: _C.accent,
                        fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6,
                      )),
                ]),
                const SizedBox(height: 5),
                Text(
                  t.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28, fontWeight: FontWeight.w900,
                    letterSpacing: -0.3, height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Meta chips row — mirrors the reference image chips
                Wrap(
                  spacing: 10, runSpacing: 8,
                  children: [
                    if (_hasField(t, 'startDate') || _hasField(t, 'endDate'))
                      _MetaChip(
                        icon: Icons.calendar_today_rounded,
                        label: _dateLine(t),
                      ),
                    if (t.ground.isNotEmpty || t.city.isNotEmpty)
                      _MetaChip(
                        icon: Icons.location_on_rounded,
                        label: [t.ground, t.city]
                            .where((s) => s.isNotEmpty)
                            .join(', ')
                            .toUpperCase(),
                      ),
                    if (t.format.isNotEmpty)
                      _MetaChip(
                        icon: Icons.format_list_bulleted_rounded,
                        label: '${t.format.toUpperCase()} FORMAT',
                      ),
                    if (t.organizerName.isNotEmpty)
                      _MetaChip(
                        icon: Icons.person_rounded,
                        label: t.organizerName,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Active status badge (top-right, matches image 5) ───────────────
          _StatusBadge(status: t.status),
        ],
      ),
    );
  }

  // Safely read startDate/endDate from entity (they exist per your live data)
  bool _hasField(TournamentEntity t, String field) {
    try {
      final dyn = t as dynamic;
      final v = field == 'startDate' ? dyn.startDate : dyn.endDate;
      return v != null && (v as String).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _dateLine(TournamentEntity t) {
    try {
      final dyn = t as dynamic;
      final start = (dyn.startDate as String?) ?? '';
      final end   = (dyn.endDate   as String?) ?? '';
      if (start.isNotEmpty && end.isNotEmpty) return '$start – $end';
      if (start.isNotEmpty) return start;
      if (end.isNotEmpty)   return end;
    } catch (_) {}
    return '';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _C.accent.withOpacity(0.7), size: 12),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3,
            )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HORIZONTAL TAB BAR  (Fixtures / Live / Upcoming / Completed)
// ═══════════════════════════════════════════════════════════════════════════════
class _HorizontalTabBar extends StatelessWidget {
  final MatchTab selectedTab;
  final int liveCount, upcomingCount, completedCount;
  final Animation<double> pulseAnim;
  final ValueChanged<MatchTab> onTabChanged;

  const _HorizontalTabBar({
    required this.selectedTab,
    required this.liveCount,
    required this.upcomingCount,
    required this.completedCount,
    required this.pulseAnim,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 18, 36, 0),
      child: Row(children: [
        _TabPill(
          icon: Icons.calendar_today_rounded,
          label: 'FIXTURES',
          color: _C.fixtures,
          isSelected: selectedTab == MatchTab.fixtures,
          onTap: () => onTabChanged(MatchTab.fixtures),
        ),
        const SizedBox(width: 10),
        _TabPill(
          icon: Icons.sensors_rounded,
          label: 'LIVE',
          color: _C.live,
          isSelected: selectedTab == MatchTab.live,
          onTap: () => onTabChanged(MatchTab.live),
          pulseAnim: liveCount > 0 ? pulseAnim : null,
        ),
        const SizedBox(width: 10),
        _TabPill(
          icon: Icons.schedule_rounded,
          label: 'UPCOMING',
          color: _C.upcoming,
          isSelected: selectedTab == MatchTab.upcoming,
          onTap: () => onTabChanged(MatchTab.upcoming),
        ),
        const SizedBox(width: 10),
        _TabPill(
          icon: Icons.check_circle_rounded,
          label: 'COMPLETED',
          color: _C.completed,
          isSelected: selectedTab == MatchTab.completed,
          onTap: () => onTabChanged(MatchTab.completed),
        ),
      ]),
    );
  }
}

class _TabPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final Animation<double>? pulseAnim;

  const _TabPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;
        final active  = focused || isSelected;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: active ? color.withOpacity(0.14) : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? color.withOpacity(0.55) : Colors.white.withOpacity(0.07),
                width: active ? 1.4 : 1,
              ),
              boxShadow: active
                  ? [BoxShadow(color: color.withOpacity(0.18), blurRadius: 14)]
                  : [],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              pulseAnim != null
                  ? AnimatedBuilder(
                animation: pulseAnim!,
                builder: (_, __) => Icon(icon,
                    color: color.withOpacity(0.5 + 0.5 * pulseAnim!.value),
                    size: 13),
              )
                  : Icon(icon,
                  color: active ? color : Colors.white.withOpacity(0.3),
                  size: 13),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  )),
            ]),
          ),
        );
      }),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.08),
            Colors.transparent,
          ]),
        ),
      ),
    );
  }
}

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
        gradient: RadialGradient(colors: [
          color.withOpacity(0.07),
          color.withOpacity(0.02),
          Colors.transparent,
        ]),
      ),
    );
  }
}