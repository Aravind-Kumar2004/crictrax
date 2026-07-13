import 'package:flutter/material.dart';
import '../../data/models/match_model.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const surface  = Color(0xFF0A1628);
  static const surfaceH = Color(0xFF0F1E35);
  static const live     = Color(0xFFFF3D3D);
}

// ═══════════════════════════════════════════════════════════════════════════
// FEATURED LIVE MATCH
// Renders nothing if there is no live match — never fabricates one.
// Only shows fields that already exist on the match model (team names,
// overs). Score / run-rate / wickets / balls are intentionally omitted
// since they aren't part of TournamentMatchModel.
// ═══════════════════════════════════════════════════════════════════════════
class FeaturedLiveMatch extends StatelessWidget {
  final TournamentMatchModel? match;
  final ValueChanged<TournamentMatchModel> onWatchLive;

  const FeaturedLiveMatch({
    Key? key,
    required this.match,
    required this.onWatchLive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final m = match;
    if (m == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('FEATURED LIVE MATCH',
                style: TextStyle(
                  color: _C.live,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                )),
          ]),
          const SizedBox(height: 14),
          _LiveMatchCard(match: m, onWatchLive: () => onWatchLive(m)),
        ],
      ),
    );
  }
}

class _LiveMatchCard extends StatefulWidget {
  final TournamentMatchModel match;
  final VoidCallback onWatchLive;
  const _LiveMatchCard({required this.match, required this.onWatchLive});

  @override
  State<_LiveMatchCard> createState() => _LiveMatchCardState();
}

class _LiveMatchCardState extends State<_LiveMatchCard> {
  bool _buttonFocused = false;
  final FocusNode _btnFocusNode = FocusNode(debugLabel: 'watch_live_btn');

  @override
  void dispose() {
    _btnFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    if (hasFocus) {
      // Scroll the button into view if the home page has been scrolled
      // such that this card is partially off-screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          _btnFocusNode.context ?? context,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.live.withOpacity(0.10), _C.surfaceH.withOpacity(0.9)],
        ),
        border: Border.all(color: _C.live.withOpacity(0.35), width: 1.2),
        boxShadow: [BoxShadow(color: _C.live.withOpacity(0.14), blurRadius: 22)],
      ),
      child: Row(
        children: [
          // LIVE badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _C.live.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.live.withOpacity(0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.live)),
              const SizedBox(width: 7),
              const Text('LIVE',
                  style: TextStyle(color: _C.live, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ]),
          ),
          const SizedBox(width: 28),

          // Teams
          Expanded(
            child: Row(
              children: [
                Expanded(child: _TeamLabel(name: m.teamId1Name, alignEnd: true)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text('VS',
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13, fontWeight: FontWeight.w800)),
                ),
                Expanded(child: _TeamLabel(name: m.teamId2Name, alignEnd: false)),
              ],
            ),
          ),
          const SizedBox(width: 24),

          // Overs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text('${m.overs} OVERS',
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 20),

          // Watch Live button
          FocusableActionDetector(
            focusNode: _btnFocusNode,
            onShowFocusHighlight: (f) => setState(() => _buttonFocused = f),
            onFocusChange: _handleFocusChange,
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
                widget.onWatchLive();
                return null;
              }),
            },
            child: GestureDetector(
              onTap: widget.onWatchLive,
              child: AnimatedScale(
                scale: _buttonFocused ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 160),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: _buttonFocused ? _C.live : _C.live.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _buttonFocused
                        ? [BoxShadow(color: _C.live.withOpacity(0.5), blurRadius: 18)]
                        : [],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Text('WATCH LIVE',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamLabel extends StatelessWidget {
  final String name;
  final bool alignEnd;
  const _TeamLabel({required this.name, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatar = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _C.live.withOpacity(0.12),
        border: Border.all(color: _C.live.withOpacity(0.35)),
      ),
      child: Center(
        child: Text(initial, style: const TextStyle(color: _C.live, fontSize: 13, fontWeight: FontWeight.w900)),
      ),
    );
    final label = Text(
      name.isEmpty ? 'TBD' : name.toUpperCase(),
      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
      overflow: TextOverflow.ellipsis,
    );
    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [Flexible(child: label), const SizedBox(width: 10), avatar]
          : [avatar, const SizedBox(width: 10), Flexible(child: label)],
    );
  }
}