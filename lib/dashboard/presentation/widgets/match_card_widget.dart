import 'package:flutter/material.dart';
import '../../data/models/match_model.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────
// Duplicated locally (matches the private _DS palette in dashboard_screen.dart).
// dashboard_screen.dart's _DS is a private class, so it can't be imported here —
// keep these values in sync manually if the dashboard palette ever changes.
class _CardDS {
  static const bg = Color(0xFF050A18);
  static const surface = Color(0xFF0A1628);
  static const accent = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live = Color(0xFFFF6B35);
  static const success = Color(0xFF00E676);

  static const accentGrad = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color teamColor(String seed) {
    final hue = (seed.codeUnits.fold(0, (a, b) => a + b) * 37) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.75, 0.55).toColor();
  }
}

/// Compact summary card for a single match — used in the horizontal
/// "My Matches" rows on the TV dashboard. Mirrors TournamentCardWidget's
/// visual treatment (dark surface, accent gradient, status badge).
///
/// Tapping the card is left to the caller via [onTap] — this widget does
/// not navigate itself, since MatchDetailScreen's required constructor
/// params aren't known at this layer.
class MatchCardWidget extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;

  const MatchCardWidget({
    Key? key,
    required this.match,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final team1Color = _CardDS.teamColor(match.teamId1Name);
    final team2Color = _CardDS.teamColor(match.teamId2Name);
    final isLive = !match.isCompleted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _CardDS.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status badge ──────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isLive ? _CardDS.live : _CardDS.success)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isLive ? _CardDS.live : _CardDS.success)
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLive)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: _CardDS.live,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          isLive ? 'ONGOING' : 'COMPLETED',
                          style: TextStyle(
                            color: isLive ? _CardDS.live : _CardDS.success,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Teams ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TeamRow(name: match.teamId1Name, color: team1Color),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _TeamRow(name: match.teamId2Name, color: team2Color),
                  ],
                ),
              ),

              // ── Footer ────────────────────────────────────────────────
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.sports_cricket,
                    color: Colors.white.withOpacity(0.25),
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isLive ? 'Live scoring' : 'Match finished',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _CardDS.accent.withOpacity(0.5),
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final Color color;

  const _TeamRow({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}