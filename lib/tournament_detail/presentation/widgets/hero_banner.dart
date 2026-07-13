import 'package:flutter/material.dart';
import '../../../../dashboard/domain/entities/tournament_entity.dart';
import '../../../utils/tv_scale.dart';



// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const surface   = Color(0xFF0A1628);
  static const accent    = Color(0xFF00D4FF);
  static const live      = Color(0xFFFF3D3D);
  static const liveDim   = Color(0xFFB0242A);
  static const upcoming  = Color(0xFF00D4FF);
  static const upcomingD = Color(0xFF0066CC);
  static const completed = Color(0xFF8A8FA8);
}

class _StatusMeta {
  final String label;
  final Color color;
  final Color colorDim;
  const _StatusMeta(this.label, this.color, this.colorDim);
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO TOURNAMENT BANNER — refinement pass only.
//
// No layout redesign, no widget-hierarchy rewrite, no business-logic,
// Firestore, repository, navigation, D-pad, or animation changes. Every
// dimension below is still driven by the existing `_tvScale(context)` helper
// (`s`) — TV scaling mechanism is unchanged. What changed in this pass:
// bigger title/typography, larger premium badges, a tighter 2x2 info-card
// grid, a Column using `spaceBetween` (instead of a hard Spacer) so content
// fills the whole banner height instead of clustering top-left, a slightly
// taller banner, a bigger/more visible trophy anchored bottom-right, and a
// richer organizer footer. Constructor, getters, and AnimationController are
// byte-for-byte unchanged from the previous version.
// ═══════════════════════════════════════════════════════════════════════════
class HeroBanner extends StatefulWidget {
  final TournamentEntity tournament;
  const HeroBanner({Key? key, required this.tournament}) : super(key: key);

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> with SingleTickerProviderStateMixin {
  bool _focused = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── unchanged business/data logic ────────────────────────────────────────
  _StatusMeta get _statusMeta {
    switch (widget.tournament.status) {
      case 'Active':
        return const _StatusMeta('LIVE', _C.live, _C.liveDim);
      case 'Upcoming':
        return const _StatusMeta('UPCOMING', _C.upcoming, _C.upcomingD);
      default:
        return const _StatusMeta('COMPLETED', _C.completed, _C.completed);
    }
  }

  // Best-effort read of a poster image field if the entity happens to expose
  // one. Never invents a URL — falls back gracefully if absent.
  String? get _posterUrl {
    try {
      final dyn = widget.tournament as dynamic;
      for (final key in ['posterUrl', 'bannerUrl', 'imageUrl', 'logoUrl']) {
        try {
          final v = dyn[key];
          if (v is String && v.isNotEmpty) return v;
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  String get _dateLine {
    try {
      final dyn = widget.tournament as dynamic;
      final start = (dyn.startDate as String?) ?? '';
      final end = (dyn.endDate as String?) ?? '';
      if (start.isNotEmpty && end.isNotEmpty) return '$start – $end';
      if (start.isNotEmpty) return start;
      if (end.isNotEmpty) return end;
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final meta = _statusMeta;
    final poster = _posterUrl;
    final s = TvScale.scale(context);

    // Only fields that already exist and aren't empty become cards —
    // nothing invented, nothing hard-coded.
    final cards = <_InfoCardData>[
      if (t.city.isNotEmpty)
        _InfoCardData(icon: Icons.location_on_rounded, label: 'CITY', value: t.city),
      if (t.ground.isNotEmpty)
        _InfoCardData(icon: Icons.stadium_rounded, label: 'GROUND', value: t.ground),
      if (_dateLine.isNotEmpty)
        _InfoCardData(icon: Icons.calendar_today_rounded, label: 'DATES', value: _dateLine),
      if (t.format.isNotEmpty)
        _InfoCardData(icon: Icons.format_list_bulleted_rounded, label: 'FORMAT', value: t.format),
    ];

    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      child: AnimatedScale(
        scale: _focused ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: double.infinity,
          // Was 400*s clamped (300–460). Bumped slightly and re-clamped
          // (340–500) so there's more room for the bigger typography/badges
          // and the content can breathe instead of feeling cramped, while
          // still holding sane proportions from 1280x720 up through 4K.
          height: (440 * s).clamp(340.0, 500.0),
          margin: EdgeInsets.fromLTRB(32 * s, 24 * s, 32 * s, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24 * s),
            border: Border.all(
              color: _focused ? _C.accent.withOpacity(0.75) : Colors.transparent,
              width: 1.8 * s,
            ),
            boxShadow: _focused
                ? [BoxShadow(color: _C.accent.withOpacity(0.28), blurRadius: 30 * s, spreadRadius: 1 * s)]
                : [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20 * s, offset: Offset(0, 8 * s))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22 * s),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Full-width stadium background — unchanged, no blur ─────────
                Image.asset(
                  'assets/images/tournaments/hero_bg.png',
                  fit: BoxFit.cover,
                ),

                // ── Gradient overlay for readability. Simple opacity layers
                // only — no BackdropFilter, GPU-friendly. ───────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF050A18).withOpacity(0.50),
                        const Color(0xFF050A18).withOpacity(0.80),
                        const Color(0xFF050A18).withOpacity(0.95),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF050A18).withOpacity(0.50),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65],
                    ),
                  ),
                ),

                // ── Decorative trophy — anchored bottom-right, enlarged and
                // slightly more visible (0.20 → 0.26 opacity) than before so
                // it reads as an intentional broadcast-graphic accent instead
                // of a faint afterthought, while still capped in size so it
                // never competes with the tournament information. ──────────
                Positioned(
                  right: -4 * s,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.26,
                      child: Image.asset(
                        'assets/images/tournaments/trophy.png',
                        width: 190 * s,
                        height: 236 * s,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // ── Main content column ─────────────────────────────────────────
                // Uses spaceBetween across three vertical groups (header,
                // status+cards, footer) instead of a top-aligned stack with a
                // Spacer(). This is what actually fixes "content bunched in
                // the upper-left, center/bottom empty" — the same elements
                // now spread across the full banner height and are
                // vertically balanced, without changing what any element is
                // or does.
                Padding(
                  padding: EdgeInsets.fromLTRB(40 * s, 28 * s, 40 * s, 24 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ── Group 1: Title + Official badge row ────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Tournament Name — larger, more spacing, clearer
                          // hierarchy against the badges below it.
                          Text(
                            t.name.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 46 * s,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                              letterSpacing: -0.8,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 16 * s),

                          // 2. Official Tournament Badge — poster mark, now
                          // larger and more premium (bigger avatar ring,
                          // bigger pill, bigger icon/text).
                          Row(
                            children: [
                              Container(
                                width: 32 * s,
                                height: 32 * s,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _C.surface,
                                  border: Border.all(color: _C.accent.withOpacity(0.45), width: 1.4 * s),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: poster != null
                                    ? Image.network(
                                  poster,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.emoji_events_rounded,
                                    color: _C.accent.withOpacity(0.85),
                                    size: 17 * s,
                                  ),
                                )
                                    : Icon(Icons.emoji_events_rounded,
                                    color: _C.accent.withOpacity(0.85), size: 17 * s),
                              ),
                              SizedBox(width: 11 * s),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 7 * s),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(9 * s),
                                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.verified_rounded, color: _C.accent, size: 15 * s),
                                  SizedBox(width: 6 * s),
                                  Text(
                                    'OFFICIAL TOURNAMENT',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.82),
                                      fontSize: 12.5 * s,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // ── Group 2: Status badge + info cards grid ────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 3. Tournament Status Badge — same premium style,
                          // now larger padding/type/dot so it reads clearly
                          // at TV viewing distance.
                          _StatusBadge(meta: meta, pulseAnim: _pulseAnim),
                          SizedBox(height: 18 * s),

                          // 4. Premium Information Cards — responsive 2x2
                          // grid, tightened internal padding increased for a
                          // fuller, less empty feel.
                          if (cards.isNotEmpty) _InfoCardsGrid(cards: cards),
                        ],
                      ),

                      // ── Group 3: Organizer footer ──────────────────────────
                      if (t.organizerName.isNotEmpty)
                        _OrganizerFooter(organizerName: t.organizerName)
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Status Badge — same premium look, larger and more prominent ────────────
class _StatusBadge extends StatelessWidget {
  final _StatusMeta meta;
  final Animation<double> pulseAnim;
  const _StatusBadge({required this.meta, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final s = TvScale.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 26 * s, vertical: 14 * s),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [meta.color.withOpacity(0.32), meta.colorDim.withOpacity(0.22)],
        ),
        borderRadius: BorderRadius.circular(15 * s),
        border: Border.all(color: meta.color.withOpacity(0.68), width: 1.7 * s),
        boxShadow: [BoxShadow(color: meta.color.withOpacity(0.36), blurRadius: 22 * s)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (meta.label == 'LIVE') ...[
            AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, __) => Container(
                width: 11 * s,
                height: 11 * s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: meta.color,
                  boxShadow: [
                    BoxShadow(
                      color: meta.color.withOpacity(0.6 * pulseAnim.value),
                      blurRadius: (9 + 7 * pulseAnim.value) * s,
                      spreadRadius: (1.2 + 2.2 * pulseAnim.value) * s,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 11 * s),
          ] else ...[
            Icon(
              meta.label == 'UPCOMING' ? Icons.schedule_rounded : Icons.check_circle_rounded,
              color: meta.color,
              size: 17 * s,
            ),
            SizedBox(width: 9 * s),
          ],
          Text(
            '${meta.label} TOURNAMENT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18 * s,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Information card data ────────────────────────────────────────────────────
class _InfoCardData {
  final IconData icon;
  final String label;
  final String value;
  const _InfoCardData({required this.icon, required this.label, required this.value});
}

// ── Responsive 2x2 info card grid ────────────────────────────────────────────
// 4 cards  -> two rows of two.
// 3 cards  -> one row of two, one row of one (+ invisible spacer to keep
//             the second card's width matching the grid above it).
// 1-2 cards-> single row.
class _InfoCardsGrid extends StatelessWidget {
  final List<_InfoCardData> cards;
  const _InfoCardsGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    final s = TvScale.scale(context);
    final rows = <List<_InfoCardData?>>[];
    for (var i = 0; i < cards.length; i += 2) {
      final second = (i + 1 < cards.length) ? cards[i + 1] : null;
      rows.add([cards[i], second]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: 16 * s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _InfoCard(data: rows[r][0]!)),
              SizedBox(width: 16 * s),
              Expanded(
                child: rows[r][1] != null
                    ? _InfoCard(data: rows[r][1]!)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final _InfoCardData data;
  const _InfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final s = TvScale.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 14 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15 * s),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.11),
            Colors.white.withOpacity(0.035),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.16), width: 1.1 * s),
        boxShadow: [
          BoxShadow(color: _C.accent.withOpacity(0.07), blurRadius: 16 * s, offset: Offset(0, 6 * s)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(data.icon, color: _C.accent.withOpacity(0.88), size: 17 * s),
              SizedBox(width: 7 * s),
              Expanded(
                child: Text(
                  data.label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11 * s,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 7 * s),
          Text(
            data.value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17 * s,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Organizer Footer — new dedicated widget for a richer, more premium
// broadcast-style footer (divider + icon + label + name), TV-scaled.
class _OrganizerFooter extends StatelessWidget {
  final String organizerName;
  const _OrganizerFooter({required this.organizerName});

  @override
  Widget build(BuildContext context) {
    final s = TvScale.scale(context);
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.16))),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 14 * s),
          padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 9 * s),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(11 * s),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded, color: _C.accent.withOpacity(0.75), size: 15 * s),
              SizedBox(width: 10 * s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'OFFICIAL TOURNAMENT',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 9.5 * s,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 2 * s),
                  Text(
                    'Organized by $organizerName',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14 * s,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.16))),
      ],
    );
  }
}