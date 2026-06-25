import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../tournament_detail/domain/entities/match_entity.dart';

// ─── Design Tokens (matches app-wide system) ──────────────────────────────────
class _C {
  static const bg       = Color(0xFF050A18);
  static const surface  = Color(0xFF0A1628);
  static const surfaceH = Color(0xFF0F1E35);
  static const accent   = Color(0xFF00D4FF);
  static const accentDim= Color(0xFF0066CC);
  static const live     = Color(0xFFFF3D3D);
  static const upcoming = Color(0xFF00D4FF);
  static const completed= Color(0xFF8A8FA8);
  static const gold     = Color(0xFFFFD700);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATCH CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════════
class MatchCardWidget extends StatelessWidget {
  final TournamentMatchEntity match;
  final VoidCallback onTap;

  const MatchCardWidget({
    Key? key,
    required this.match,
    required this.onTap,
  }) : super(key: key);

  // ── Status helpers ──────────────────────────────────────────────────────────
  Color get _statusColor {
    if (match.isLive)      return _C.live;
    if (match.isCompleted) return _C.completed;
    return _C.upcoming;
  }

  String get _statusLabel {
    if (match.isLive)      return 'LIVE';
    if (match.isCompleted) return 'DONE';
    return 'UPCOMING';
  }

  IconData get _statusIcon {
    if (match.isLive)      return Icons.radio_button_checked;
    if (match.isCompleted) return Icons.check_circle_rounded;
    return Icons.schedule_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor;

    return Focus(
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translate(0.0, focused ? -2.0 : 0.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: focused
                    ? sc
                    : match.isLive
                    ? sc.withOpacity(0.35)
                    : Colors.white.withOpacity(0.07),
                width: focused ? 1.5 : 1,
              ),
              boxShadow: [
                if (focused)
                  BoxShadow(
                    color: sc.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                if (match.isLive && !focused)
                  BoxShadow(
                    color: _C.live.withOpacity(0.08),
                    blurRadius: 12,
                  ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: match.isLive
                          ? [
                        _C.live.withOpacity(0.06),
                        _C.surface.withOpacity(0.85),
                      ]
                          : [
                        _C.surfaceH.withOpacity(0.7),
                        _C.surface.withOpacity(0.85),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Left accent stripe
                      Positioned(
                        left: 0, top: 0, bottom: 0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: focused ? 3 : 2,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                sc,
                                sc.withOpacity(0.3),
                              ],
                            ),
                            boxShadow: focused
                                ? [BoxShadow(color: sc.withOpacity(0.6), blurRadius: 8)]
                                : [],
                          ),
                        ),
                      ),

                      // Main content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 20, 18),
                        child: Row(
                          children: [
                            // ── Status pill ──────────────────────────────
                            _StatusPill(
                              label: _statusLabel,
                              icon: _statusIcon,
                              color: sc,
                              isLive: match.isLive,
                            ),

                            const SizedBox(width: 20),

                            // ── Match info ───────────────────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Teams row
                                  Row(
                                    children: [
                                      _TeamAvatar(name: match.teamId1Name, color: sc),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          match.teamId1Name,
                                          style: TextStyle(
                                            color: focused
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.9),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.1,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // VS divider
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 32),
                                        Text(
                                          'vs',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.2),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Container(
                                            height: 1,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withOpacity(0.06),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Team 2 row
                                  Row(
                                    children: [
                                      _TeamAvatar(name: match.teamId2Name, color: sc),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          match.teamId2Name,
                                          style: TextStyle(
                                            color: focused
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.9),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.1,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            // ── Right meta ───────────────────────────────
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Overs chip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.07),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sports_cricket,
                                          color: Colors.white.withOpacity(0.25),
                                          size: 11),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${match.overs} ov',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Arrow chevron
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: focused
                                        ? sc.withOpacity(0.15)
                                        : Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: focused
                                          ? sc.withOpacity(0.4)
                                          : Colors.white.withOpacity(0.06),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    color: focused
                                        ? sc
                                        : Colors.white.withOpacity(0.25),
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Subtle top shimmer line
                      Positioned(
                        top: 0, left: 20, right: 20,
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(focused ? 0.08 : 0.03),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Status Pill ──────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLive;

  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isLive ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isLive ? 0.35 : 0.18),
        ),
        boxShadow: isLive
            ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 10)]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Team Avatar ──────────────────────────────────────────────────────────────
class _TeamAvatar extends StatelessWidget {
  final String name;
  final Color color;

  const _TeamAvatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.25),
            color.withOpacity(0.08),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}