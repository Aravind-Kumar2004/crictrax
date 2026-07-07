import 'package:flutter/material.dart';
import '../../data/models/match_model.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const surfaceH  = Color(0xFF0F1E35);
  static const completed = Color(0xFF8A8FA8);
}

// ═══════════════════════════════════════════════════════════════════════════
// RECENT RESULTS — latest 3 completed matches only.
// Winner / Score / Player of the Match are intentionally NOT shown since
// those fields don't exist on TournamentMatchModel — showing them would
// require fabricated data.
// ═══════════════════════════════════════════════════════════════════════════
class RecentResultsSection extends StatelessWidget {
  final List<TournamentMatchModel> completedMatches;
  final ValueChanged<TournamentMatchModel> onTap;

  const RecentResultsSection({
    Key? key,
    required this.completedMatches,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (completedMatches.isEmpty) return const SizedBox.shrink();
    // Most recently completed first — matches are already appended in
    // arrival order by the existing stream, so a simple reverse-take gives
    // the latest ones without touching any sorting/business logic.
    final latest3 = completedMatches.reversed.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECENT RESULTS',
              style: TextStyle(color: _C.completed, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 14),
          FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Row(
              children: [
                for (int i = 0; i < latest3.length; i++) ...[
                  Expanded(child: _ResultCard(match: latest3[i], onTap: () => onTap(latest3[i]))),
                  if (i != latest3.length - 1) const SizedBox(width: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatefulWidget {
  final TournamentMatchModel match;
  final VoidCallback onTap;
  const _ResultCard({required this.match, required this.onTap});

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
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
          scale: _focused ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _C.surfaceH.withOpacity(0.75),
              border: Border.all(
                color: _focused ? _C.completed.withOpacity(0.6) : Colors.white.withOpacity(0.07),
                width: _focused ? 1.5 : 1,
              ),
              boxShadow: _focused ? [BoxShadow(color: _C.completed.withOpacity(0.18), blurRadius: 14)] : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _C.completed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _C.completed.withOpacity(0.3)),
                  ),
                  child: Text('COMPLETED',
                      style: TextStyle(color: _C.completed, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                ),
                const SizedBox(height: 14),
                Text(m.teamId1Name.isEmpty ? 'TBD' : m.teamId1Name,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('vs', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                Text(m.teamId2Name.isEmpty ? 'TBD' : m.teamId2Name,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}