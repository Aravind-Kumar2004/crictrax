import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../dashboard/domain/entities/tournament_entity.dart';

class TournamentCardWidget extends StatelessWidget {
  final TournamentEntity tournament;
  final VoidCallback onTap;

  const TournamentCardWidget({
    Key? key,
    required this.tournament,
    required this.onTap,
  }) : super(key: key);

  // ── Status helpers ──────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return const Color(0xFF00E676);
      case 'Upcoming':
        return const Color(0xFF00D4FF);
      case 'Completed':
        return const Color(0xFFFFB300);
      default:
        return Colors.white38;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Active':
        return Icons.play_circle_fill_rounded;
      case 'Upcoming':
        return Icons.schedule_rounded;
      case 'Completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  LinearGradient _cardTopGradient(String status) {
    switch (status) {
      case 'Active':
        return LinearGradient(
          colors: [
            const Color(0xFF00E676).withOpacity(0.18),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Upcoming':
        return LinearGradient(
          colors: [
            const Color(0xFF00D4FF).withOpacity(0.14),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.04),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  String _formatShortDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(tournament.status);
    final statusIcon = _statusIcon(tournament.status);
    final isActive = tournament.status == 'Active';

    return Focus(
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..scale(isFocused ? 1.035 : 1.0)
              ..translate(
                isFocused ? -4.0 : 0.0,
                isFocused ? -4.0 : 0.0,
              ),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              // Focus ring
              border: Border.all(
                color: isFocused
                    ? statusColor
                    : Colors.white.withOpacity(0.07),
                width: isFocused ? 1.5 : 1,
              ),
              boxShadow: [
                if (isFocused)
                  BoxShadow(
                    color: statusColor.withOpacity(0.35),
                    blurRadius: 32,
                    spreadRadius: -2,
                  ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0F1E35),
                        const Color(0xFF080E1A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Top-left status color wash
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _cardTopGradient(tournament.status),
                          ),
                        ),
                      ),
                      // Active pulse indicator (top-right corner dot)
                      if (isActive)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: _ActivePulse(),
                        ),
                      // Main content
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Status badge row
                            _StatusBadge(
                              label: tournament.status,
                              color: statusColor,
                              icon: statusIcon,
                            ),

                            // Tournament name
                            Text(
                              tournament.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            // Meta info
                            _MetaRow(tournament: tournament),
                          ],
                        ),
                      ),
                      // Bottom accent line when focused
                      if (isFocused)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  statusColor.withOpacity(0.0),
                                  statusColor,
                                  statusColor.withOpacity(0.0),
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

// ── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meta Info Row ─────────────────────────────────────────────────────────────
class _MetaRow extends StatelessWidget {
  final TournamentEntity tournament;

  const _MetaRow({required this.tournament});

  String _formatShortDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetaItem(
          icon: Icons.location_on_rounded,
          text: tournament.ground,
        ),
        const SizedBox(height: 5),
        _MetaItem(
          icon: Icons.format_list_bulleted_rounded,
          text: tournament.format,
        ),
        if (tournament.endDate != null) ...[
          const SizedBox(height: 5),
          _MetaItem(
            icon: Icons.calendar_today_rounded,
            text: 'Ends ${_formatShortDate(tournament.endDate)}',
          ),
        ],
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.28), size: 11),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.38),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

// ── Active Pulse Dot ──────────────────────────────────────────────────────────
class _ActivePulse extends StatefulWidget {
  @override
  State<_ActivePulse> createState() => _ActivePulseState();
}

class _ActivePulseState extends State<_ActivePulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF00E676).withOpacity(0.6 + _anim.value * 0.4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E676)
                  .withOpacity(0.5 * _anim.value),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}