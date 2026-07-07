import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../dashboard/domain/entities/tournament_entity.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _T {
  static const bgTop = Color(0xFF0F1E35);
  static const bgBottom = Color(0xFF080E1A);
  static const accent = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live = Color(0xFFFD3434);
  static const upcoming = Color(0xFF54E0FF);
  static const completed = Color(0xFF00FF67);
}
String getTournamentPoster(String tournamentName) {
  final name = tournamentName.toLowerCase();

  if (name.contains("ipl")) {
    return "assets/images/tournaments/ipl.png";
  }

  if (name.contains("champions")) {
    return "assets/images/tournaments/champions_league.png";
  }

  if (name.contains("tnpl")) {
    return "assets/images/tournaments/tnpl.png";
  }

  return "assets/images/tournaments/default.png";
}
// ═══════════════════════════════════════════════════════════════════════════
// TOURNAMENT CARD — premium OTT sports card
// ═══════════════════════════════════════════════════════════════════════════
class TournamentCardWidget extends StatefulWidget {
  final TournamentEntity tournament;
  final VoidCallback onTap;

  const TournamentCardWidget({
    Key? key,
    required this.tournament,
    required this.onTap,
  }) : super(key: key);

  @override
  State<TournamentCardWidget> createState() => _TournamentCardWidgetState();
}

class _TournamentCardWidgetState extends State<TournamentCardWidget> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'TournamentCard');
  bool _focused = false;
  bool _hovered = false;

  bool get _highlighted => _focused || _hovered;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return _T.live;
      case 'Upcoming':
        return _T.upcoming;
      case 'Completed':
        return _T.completed;
      default:
        return Colors.white38;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Active':
        return 'LIVE';
      case 'Upcoming':
        return 'UPCOMING';
      case 'Completed':
        return 'COMPLETED';
      default:
        return status.toUpperCase();
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

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final statusColor = _statusColor(t.status);
    final statusLabel = _statusLabel(t.status);

    final String posterAsset = getTournamentPoster(t.name);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fully responsive — every size below is derived from the actual
        // space this card is given by its parent, never a fixed pixel value.
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final posterHeight = h * 0.55;
        final radius = (w * 0.08).clamp(18.0, 24.0);

        return Focus(
          focusNode: _focusNode,
          onFocusChange: (f) => setState(() => _focused = f),
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            onShowHoverHighlight: (v) => setState(() => _hovered = v),
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onTap();
                  return null;
                },
              ),
            },
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
            },
            child: GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedScale(
                scale: _highlighted ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      colors: [_T.bgTop, _T.bgBottom],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: _highlighted
                          ? _T.accent.withOpacity(0.9)
                          : _T.accent.withOpacity(0.18),
                      width: _highlighted ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _highlighted
                            ? _T.accent.withOpacity(0.45)
                            : Colors.black.withOpacity(0.35),
                        blurRadius: _highlighted ? 34 : 16,
                        spreadRadius: _highlighted ? 1 : 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Poster (≈55% of card height) ────────────────
                        SizedBox(
                          height: posterHeight,
                          child: TournamentPoster(
                            posterAsset: posterAsset,
                            tournamentName: t.name,
                            highlighted: _highlighted,
                            statusColor: statusColor,
                            statusLabel: statusLabel,
                          ),
                        ),

                        // ── Info + CTA (≈45% of card height) ────────────
                        Flexible(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: w * 0.06,
                              vertical: h * 0.02,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      t.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    SizedBox(height: h * 0.015),
                                    TournamentInfoRow(
                                      icon: Icons.location_on_rounded,
                                      text: t.ground,
                                    ),
                                    const SizedBox(height: 4),
                                    TournamentInfoRow(
                                      icon: Icons.format_list_bulleted_rounded,
                                      text: t.format,
                                    ),
                                    const SizedBox(height: 4),
                                    // ⚠️ ADJUST FIELD NAME if your entity uses
                                    // a different team-count field.
                                    TournamentInfoRow(
                                      icon: Icons.location_city_rounded,
                                      text: t.city,
                                    ),
                                    if (t.endDate != null) ...[
                                      const SizedBox(height: 4),
                                      TournamentInfoRow(
                                        icon: Icons.calendar_today_rounded,
                                        text:
                                        'Ends ${_formatShortDate(t.endDate)}',
                                      ),
                                    ],
                                  ],
                                ),
                                TournamentActionButton(
                                  highlighted: _highlighted,
                                  onTap: widget.onTap,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TOURNAMENT POSTER — dynamic image, placeholder fallback, status badge
// ═══════════════════════════════════════════════════════════════════════════
class TournamentPoster extends StatelessWidget {
  final String posterAsset;
  final String tournamentName;
  final bool highlighted;
  final Color statusColor;
  final String statusLabel;

  const TournamentPoster({
    Key? key,
    required this.posterAsset,
    required this.tournamentName,
    required this.highlighted,
    required this.statusColor,
    required this.statusLabel,
  }) : super(key: key);



  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Poster image (or placeholder) — no BackdropFilter used anywhere.
      Image.asset(
      posterAsset,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) => _placeholder(),
    ),


        // Brightness shift on focus (replaces "brighten poster" via overlay
        // opacity instead of BackdropFilter).
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          color: Colors.black.withOpacity(highlighted ? 0.05 : 0.22),
        ),

        // Bottom gradient so the poster blends into the info section.
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF080E1A).withOpacity(0.9),
                ],
              ),
            ),
          ),
        ),

        // Status badge, top-right.
        Positioned(
          top: 12,
          right: 12,
          child: TournamentStatusBadge(label: statusLabel, color: statusColor),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F1E35), Color(0xFF080E1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: _T.accent.withOpacity(0.35),
              size: 40,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                tournamentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TOURNAMENT STATUS BADGE
// ═══════════════════════════════════════════════════════════════════════════
class TournamentStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const TournamentStatusBadge({
    Key? key,
    required this.label,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TOURNAMENT INFO ROW — icon + label, single line, ellipsized
// ═══════════════════════════════════════════════════════════════════════════
class TournamentInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const TournamentInfoRow({
    Key? key,
    required this.icon,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.32), size: 12),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TOURNAMENT ACTION BUTTON — "OPEN TOURNAMENT"
// ═══════════════════════════════════════════════════════════════════════════
class TournamentActionButton extends StatelessWidget {
  final bool highlighted;
  final VoidCallback onTap;

  const TournamentActionButton({
    Key? key,
    required this.highlighted,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: highlighted
                ? [_T.accent, _T.accentDim]
                : [_T.accent.withOpacity(0.75), _T.accentDim.withOpacity(0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: highlighted
              ? [
            BoxShadow(
              color: _T.accent.withOpacity(0.5),
              blurRadius: 18,
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              'OPEN TOURNAMENT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}