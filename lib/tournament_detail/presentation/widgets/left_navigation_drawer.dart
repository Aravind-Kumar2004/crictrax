import 'package:flutter/material.dart';

// ─── Design Tokens (matches app-wide system) ──────────────────────────────────
class _C {
  static const surface   = Color(0xFF0A1628);
  static const accent    = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
}

/// Sections available in the new permanent TV drawer.
/// NOTE: intentionally limited to Home / Fixtures / Teams / Points Table
/// per the redesign spec. Players, Statistics, Commentary and Settings are
/// deliberately NOT included yet.
enum NavSection { home, fixtures, teams, pointsTable }

class NavItemData {
  final NavSection section;
  final IconData icon;
  final String label;
  const NavItemData(this.section, this.icon, this.label);
}

const List<NavItemData> kNavItems = [
  NavItemData(NavSection.home, Icons.home_rounded, 'Home'),
  NavItemData(NavSection.fixtures, Icons.calendar_today_rounded, 'Fixtures'),
  NavItemData(NavSection.teams, Icons.groups_rounded, 'Teams'),
  NavItemData(NavSection.pointsTable, Icons.leaderboard_rounded, 'Points Table'),
];

// ═══════════════════════════════════════════════════════════════════════════
// LEFT NAVIGATION DRAWER — permanent, TV-focusable
// ═══════════════════════════════════════════════════════════════════════════
class LeftNavigationDrawer extends StatelessWidget {
  final NavSection selected;
  final ValueChanged<NavSection> onSelect;
  final VoidCallback onBack;

  const LeftNavigationDrawer({
    Key? key,
    required this.selected,
    required this.onSelect,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Container(
        width: 236,
        decoration: BoxDecoration(
          color: _C.surface.withOpacity(0.94),
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: const LinearGradient(
                      colors: [_C.accent, _C.accentDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: _C.accent.withOpacity(0.35), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(Icons.sports_cricket, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: 'CRICTRAX ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const TextSpan(
                      text: 'TV',
                      style: TextStyle(
                        color: _C.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ]),
                ),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _BackTile(onTap: onBack),
            ),

            const SizedBox(height: 18),
            _DrawerDivider(),
            const SizedBox(height: 16),

            // Nav items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  for (final item in kNavItems) ...[
                    _DrawerTile(
                      icon: item.icon,
                      label: item.label,
                      isSelected: selected == item.section,
                      onTap: () => onSelect(item.section),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: Text(
                'D-Pad to navigate  •  Enter to select',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.18),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Back tile ────────────────────────────────────────────────────────────────
class _BackTile extends StatefulWidget {
  final VoidCallback onTap;
  const _BackTile({required this.onTap});

  @override
  State<_BackTile> createState() => _BackTileState();
}

class _BackTileState extends State<_BackTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 160),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _focused ? _C.accent.withOpacity(0.12) : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused ? _C.accent.withOpacity(0.6) : Colors.white.withOpacity(0.07),
                width: _focused ? 1.4 : 1,
              ),
              boxShadow: _focused
                  ? [BoxShadow(color: _C.accent.withOpacity(0.25), blurRadius: 12)]
                  : [],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_rounded,
                  color: _focused ? _C.accent : Colors.white.withOpacity(0.45), size: 16),
              const SizedBox(width: 8),
              Text('Back',
                  style: TextStyle(
                    color: _focused ? _C.accent : Colors.white.withOpacity(0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────────
class _DrawerTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DrawerTile> createState() => _DrawerTileState();
}

class _DrawerTileState extends State<_DrawerTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.isSelected;
    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: active ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: active ? _C.accent.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? _C.accent.withOpacity(0.55) : Colors.white.withOpacity(0.05),
                width: active ? 1.5 : 1,
              ),
              boxShadow: active
                  ? [BoxShadow(color: _C.accent.withOpacity(0.22), blurRadius: 14)]
                  : [],
            ),
            child: Row(children: [
              Icon(widget.icon,
                  color: active ? _C.accent : Colors.white.withOpacity(0.4), size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white.withOpacity(0.45),
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
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