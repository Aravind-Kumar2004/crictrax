import 'package:flutter/material.dart';
import '../../../../dashboard/domain/entities/tournament_entity.dart';

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
// HERO TOURNAMENT BANNER
// Premium full-width showcase, reusing ONLY fields already present on
// TournamentEntity (name, city, ground, format, status, organizerName,
// startDate/endDate). Anything not available is hidden gracefully — never
// filled in with dummy data.
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
      if (start.isNotEmpty && end.isNotEmpty) return '$start - $end';
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

    // Bottom info row — only fields that already exist and aren't empty.
    final bottomBits = <String>[
      if (t.organizerName.isNotEmpty) 'Organized by ${t.organizerName}',
      if (t.city.isNotEmpty) t.city,
      if (t.ground.isNotEmpty) t.ground,
    ];

    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      child: AnimatedScale(
        scale: _focused ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: double.infinity,
          height: 340,
          margin: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _focused ? _C.accent.withOpacity(0.75) : Colors.transparent,
              width: 1.8,
            ),
            boxShadow: _focused
                ? [BoxShadow(color: _C.accent.withOpacity(0.28), blurRadius: 30, spreadRadius: 1)]
                : [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Full-width stadium background — no blur, no BackdropFilter ──
                Image.asset(
                  'assets/images/tournaments/default.png',
                  fit: BoxFit.cover,
                ),

                // ── Light dark-blue gradient overlay for readability only ──────
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF050A18).withOpacity(0.72),
                        const Color(0xFF0A1E3D).withOpacity(0.30),
                      ],
                    ),
                  ),
                ),

                // ── Main content ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 26, 30, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ── Poster ─────────────────────────────────────────
                            AnimatedScale(
                              scale: _focused ? 1.05 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              child: Container(
                                width: 200,
                                height: 260,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: _C.surface,
                                  border: Border.all(
                                    color: _C.accent.withOpacity(_focused ? 0.55 : 0.25),
                                    width: 1.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 10)),
                                    if (_focused)
                                      BoxShadow(color: _C.accent.withOpacity(0.25), blurRadius: 22),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: poster != null
                                    ? Image.network(
                                  poster,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const _PosterFallback(),
                                )
                                    : const _PosterFallback(),
                              ),
                            ),
                            const SizedBox(width: 34),

                            // ── Name + vertical detail list ────────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t.name.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                      letterSpacing: -0.6,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 20),
                                  if (t.city.isNotEmpty)
                                    _DetailLine(icon: Icons.location_on_rounded, label: t.city),
                                  if (t.ground.isNotEmpty)
                                    _DetailLine(icon: Icons.stadium_rounded, label: t.ground),
                                  if (_dateLine.isNotEmpty)
                                    _DetailLine(icon: Icons.calendar_today_rounded, label: _dateLine),
                                  if (t.format.isNotEmpty)
                                    _DetailLine(icon: Icons.emoji_events_rounded, label: '${t.format} Format'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Bottom information row ───────────────────────────────
                      if (bottomBits.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.08),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          bottomBits.join('   •   '),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Status badge — top right ─────────────────────────────────────
                Positioned(
                  top: 24,
                  right: 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [meta.color.withOpacity(0.28), meta.colorDim.withOpacity(0.20)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: meta.color.withOpacity(0.6), width: 1.4),
                      boxShadow: [BoxShadow(color: meta.color.withOpacity(0.35), blurRadius: 18)],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (meta.label == 'LIVE') ...[
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: meta.color,
                              boxShadow: [
                                BoxShadow(
                                  color: meta.color.withOpacity(0.6 * _pulseAnim.value),
                                  blurRadius: 8 + 6 * _pulseAnim.value,
                                  spreadRadius: 1 + 2 * _pulseAnim.value,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                      ],
                      Text(
                        meta.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ]),
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

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071424),
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF10284B),
            Color(0xFF071424),
          ],
        ),
      ),
      padding: const EdgeInsets.all(0),
      child: Center(
        child: Image.asset(
          'assets/images/tournaments/trophy.png',
          width: 300,
          height: 400,
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, color: _C.accent.withOpacity(0.85), size: 16),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}