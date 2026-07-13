import 'package:flutter/material.dart';

import '../../domain/entities/Team entity.dart';


// ─── Design Tokens (matches app-wide system) ──────────────────────────────────
class _C {
  static const surface  = Color(0xFF0A1628);
  static const surfaceH = Color(0xFF0F1E35);
  static const accent   = Color(0xFF00D4FF);
  static const fixtures = Color(0xFF8E5CFF);
}

// ═══════════════════════════════════════════════════════════════════════════
// TEAM HEADER — logo, name, and the four requested detail fields.
// Any field that's empty on the entity is hidden rather than shown blank.
//
// This banner has no onTap of its own, so it's intentionally excluded from
// D-pad focus (ExcludeFocus below) to avoid a dead-end stop for the remote.
// ═══════════════════════════════════════════════════════════════════════════
class TeamHeaderWidget extends StatefulWidget {
  final TeamEntity team;
  final String? captainName;

  const TeamHeaderWidget({
    Key? key,
    required this.team,
    required this.captainName,
  }) : super(key: key);

  @override
  State<TeamHeaderWidget> createState() => _TeamHeaderWidgetState();
}

class _TeamHeaderWidgetState extends State<TeamHeaderWidget> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.team;

    final details = <_DetailRow>[
      if (widget.captainName != null && widget.captainName!.isNotEmpty)
        _DetailRow(Icons.military_tech_rounded, 'Captain', widget.captainName!),
      if (t.coach.isNotEmpty) _DetailRow(Icons.sports_rounded, 'Coach', t.coach),
      if (t.city.isNotEmpty) _DetailRow(Icons.location_city_rounded, 'City', t.city),
      if (t.country.isNotEmpty) _DetailRow(Icons.flag_rounded, 'Country', t.country),
    ];

    return ExcludeFocus(
      child: FocusableActionDetector(
        descendantsAreFocusable: false,
        onShowFocusHighlight: (f) => setState(() => _focused = f),
        child: AnimatedScale(
          scale: _focused ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_C.fixtures.withOpacity(0.10), _C.surfaceH.withOpacity(0.92)],
              ),
              border: Border.all(
                color: _focused ? _C.accent.withOpacity(0.7) : Colors.white.withOpacity(0.08),
                width: _focused ? 1.6 : 1,
              ),
              boxShadow: _focused
                  ? [BoxShadow(color: _C.accent.withOpacity(0.25), blurRadius: 26)]
                  : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Team logo ─────────────────────────────────────────────────
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.surface,
                    border: Border.all(color: _C.accent.withOpacity(_focused ? 0.6 : 0.25), width: 1.6),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: t.logo.isNotEmpty
                      ? Image.network(
                    t.logo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _LogoFallback(t.shortName),
                  )
                      : _LogoFallback(t.shortName),
                ),
                const SizedBox(width: 30),

                // ── Name + details ───────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.teamName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 26,
                          runSpacing: 10,
                          children: details,
                        ),
                      ],
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

class _LogoFallback extends StatelessWidget {
  final String shortName;
  const _LogoFallback(this.shortName);

  @override
  Widget build(BuildContext context) {
    final initials = shortName.isNotEmpty ? shortName.toUpperCase() : '?';
    return Container(
      color: _C.surface,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(color: _C.accent.withOpacity(0.7), fontSize: 30, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _C.accent.withOpacity(0.8), size: 16),
        const SizedBox(width: 8),
        Text('$label  ',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }
}