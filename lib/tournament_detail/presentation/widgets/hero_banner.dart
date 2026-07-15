import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

    // Ground / Organizer / Dates / Format only — City intentionally
    // dropped from the grid per the new card spec. Nothing invented;
    // all four fields already existed as inputs before this pass.
    final cards = <_InfoCardData>[
      if (t.ground.isNotEmpty)
        _InfoCardData(icon: Icons.stadium_rounded, label: 'GROUND', value: t.ground),
      if (t.organizerName.isNotEmpty)
        _InfoCardData(icon: Icons.person_rounded, label: 'ORGANIZER', value: t.organizerName),
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
          height: (493.h).clamp(380.h, 560.h),
          margin: EdgeInsets.fromLTRB(32.w, 24.h, 32.w, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: _focused ? _C.accent.withOpacity(0.75) : Colors.white.withOpacity(0.12),
              width: 1.8.w,
            ),
            boxShadow: _focused
                ? [BoxShadow(color: _C.accent.withOpacity(0.28), blurRadius: 30.r, spreadRadius: 1.r)]
                : [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20.r, offset: Offset(0, 8.h))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22.r),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Glass panel fill — no image of its own anymore. Pure
                // translucent gradients (no blur/BackdropFilter, GPU-safe)
                // so the Tournament Detail Screen's own background shows
                // through the banner, while still giving it a defined
                // glass "panel" identity and enough contrast for the
                // text/cards above to stay readable. ────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _C.surface.withOpacity(0.05),
                        // _C.surface.withOpacity(0.10),
                        // _C.surface.withOpacity(0.10),
                      ],
                      // stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                // Soft diagonal sheen for a glass "shine" — very low
                // opacity, gradient-only.
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.06),
                        Colors.transparent,
                        Colors.white.withOpacity(0.02),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                // Left-side tint so the title/cards keep contrast over
                // whatever shows through, kept translucent so the
                // see-through effect still reads clearly.
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _C.surface.withOpacity(0.30),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6],
                    ),
                  ),
                ),



                // ── Main content column: top row / middle row / footer ─────────
                Padding(
                  padding: EdgeInsets.fromLTRB(40.w, 28.h, 40.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ── TOP ROW: title + subtitle (left), status badge (top-right) ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t.name.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 54.sp,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                    letterSpacing: -0.9,
                                    shadows: [
                                      Shadow(color: _C.accent.withOpacity(0.45), blurRadius: 22.r),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 10.h),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded,
                                        color: _C.accent.withOpacity(0.75), size: 16.sp),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Official Tournament',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.62),
                                        fontSize: 17.sp,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 20.w),
                          _StatusBadge(meta: meta, pulseAnim: _pulseAnim),
                        ],
                      ),

                      // ── MIDDLE ROW: small poster (left) + info cards (center) ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (poster != null) ...[
                            _PosterFrame(url: poster),
                            SizedBox(width: 26.w),
                          ],
                          if (cards.isNotEmpty) Expanded(child: _InfoCardsGrid(cards: cards)),
                        ],
                      ),

                      // ── FOOTER: organizer strip ─────────────────────────────
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

// ── Status Badge — same mapping/pulse as before, now used top-right ────────
class _StatusBadge extends StatelessWidget {
  final _StatusMeta meta;
  final Animation<double> pulseAnim;
  const _StatusBadge({required this.meta, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 26.w, vertical: 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [meta.color.withOpacity(0.32), meta.colorDim.withOpacity(0.22)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: meta.color.withOpacity(0.68), width: 1.8.w),
        boxShadow: [BoxShadow(color: meta.color.withOpacity(0.38), blurRadius: 26.r)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (meta.label == 'LIVE') ...[
            AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, __) => Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: meta.color,
                  boxShadow: [
                    BoxShadow(
                      color: meta.color.withOpacity(0.6 * pulseAnim.value),
                      blurRadius: (10 + 8 * pulseAnim.value).r,
                      spreadRadius: (1.3 + 2.4 * pulseAnim.value).r,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12.w),
          ] else ...[
            Icon(
              meta.label == 'UPCOMING' ? Icons.schedule_rounded : Icons.check_circle_rounded,
              color: meta.color,
              size: 18.sp,
            ),
            SizedBox(width: 10.w),
          ],
          Text(
            '${meta.label} TOURNAMENT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small framed tournament poster — middle-left ────────────────────────────
// Uses the same `_posterUrl` lookup and error fallback as before; only the
// presentation changed, from a 36x36 avatar to a proper small poster frame.
class _PosterFrame extends StatelessWidget {
  final String url;
  const _PosterFrame({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118.w,
      height: 158.h,
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.accent.withOpacity(0.55), Colors.white.withOpacity(0.08)],
        ),
        boxShadow: [
          BoxShadow(color: _C.accent.withOpacity(0.18), blurRadius: 18.r, offset: Offset(0, 6.h)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13.r),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: _C.surface,
            alignment: Alignment.center,
            child: Icon(Icons.emoji_events_rounded, color: _C.accent.withOpacity(0.6), size: 30.sp),
          ),
        ),
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
class _InfoCardsGrid extends StatelessWidget {
  final List<_InfoCardData> cards;
  const _InfoCardsGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    final rows = <List<_InfoCardData?>>[];
    for (var i = 0; i < cards.length; i += 2) {
      final second = (i + 1 < cards.length) ? cards[i + 1] : null;
      rows.add([cards[i], second]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: 14.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _InfoCard(data: rows[r][0]!)),
              SizedBox(width: 16.w),
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

// ── Glass card with a gradient border (outer gradient + inset glass fill) ──
class _InfoCard extends StatelessWidget {
  final _InfoCardData data;
  const _InfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(1.4.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.accent.withOpacity(0.35), Colors.white.withOpacity(0.05)],
        ),
        boxShadow: [
          BoxShadow(color: _C.accent.withOpacity(0.10), blurRadius: 18.r, offset: Offset(0, 6.h)),
        ],
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 15.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.035)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(data.icon, color: _C.accent.withOpacity(0.9), size: 18.sp),
                SizedBox(width: 9.w),
                Expanded(
                  child: Text(
                    data.label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              data.value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Organizer Footer — centered, soft divider either side ──────────────────
class _OrganizerFooter extends StatelessWidget {
  final String organizerName;
  const _OrganizerFooter({required this.organizerName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.16))),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded, color: _C.accent.withOpacity(0.75), size: 17.sp),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'OFFICIAL TOURNAMENT',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Organized by $organizerName',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 16.sp,
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