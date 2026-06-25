import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/models/repositories/live_score_repository.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF050A18);
  static const surface   = Color(0xFF0A1628);
  static const surfaceH  = Color(0xFF0F1E35);
  static const accent    = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const live      = Color(0xFFFF6B35);
  static const success   = Color(0xFF00E676);
  static const wicket    = Color(0xFFFF3D3D);
  static const gold      = Color(0xFFFFB300);

  static const accentGrad = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATSMEN CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════════
class BatsmenCardWidget extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final String inningsId;

  const BatsmenCardWidget({
    Key? key,
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
  }) : super(key: key);

  @override
  State<BatsmenCardWidget> createState() => _BatsmenCardWidgetState();
}

class _BatsmenCardWidgetState extends State<BatsmenCardWidget>
    with SingleTickerProviderStateMixin {
  // ── Business Logic (UNCHANGED) ────────────────────────────────────────────
  final _repo = LiveScoreRepository();
  final Map<String, String> _resolvedNames = {};

  Future<String> _getName(
      String teamId, String playerId, String fallback) async {
    if (fallback.isNotEmpty) return fallback;
    final cacheKey = '$teamId-$playerId';
    if (_resolvedNames.containsKey(cacheKey)) {
      return _resolvedNames[cacheKey]!;
    }
    final resolved =
    await _repo.resolvePlayerName(widget.tournamentId, teamId, playerId);
    _resolvedNames[cacheKey] = resolved;
    return resolved;
  }

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F1E35), Color(0xFF080E1A)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildColumnLabels(),
              _buildDivider(),
              Expanded(child: _buildBatsmenList()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: const LinearGradient(
                colors: [Color(0xFF00E676), Color(0xFF00994D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _C.success.withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: const Icon(
              Icons.sports_baseball_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),

          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BATTING',
                style: TextStyle(
                  color: _C.success.withOpacity(0.55),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              const Text(
                'Batsmen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  height: 1.1,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Live pulse indicator
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _C.success
                    .withOpacity(0.08 + 0.05 * _pulseAnim.value),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _C.success
                      .withOpacity(0.25 + 0.15 * _pulseAnim.value),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.success
                          .withOpacity(0.6 + 0.4 * _pulseAnim.value),
                      boxShadow: [
                        BoxShadow(
                          color: _C.success.withOpacity(0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: _C.success,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Column Labels ─────────────────────────────────────────────────────────
  Widget _buildColumnLabels() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'BATSMAN',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ),
          _ColLabel('R'),
          _ColLabel('B'),
          _ColLabel('4s'),
          _ColLabel('6s'),
          _ColLabel('SR'),
        ],
      ),
    );
  }

  // ── Divider ───────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _C.success.withOpacity(0.2),
            Colors.white.withOpacity(0.04),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  // ── Batsmen List ──────────────────────────────────────────────────────────
  Widget _buildBatsmenList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _repo.watchBatsmen(
          widget.tournamentId, widget.matchId, widget.inningsId),
      builder: (context, snap) {
        if (!snap.hasData) return _buildLoadingState();

        final docs = snap.data!.docs;
        if (docs.isEmpty) return _buildEmptyState();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withOpacity(0.03),
          ),
          itemBuilder: (context, index) {
            final b = docs[index].data() as Map<String, dynamic>;
            final rawName = (b['playerName'] ?? '').toString();
            final playerId = (b['playerId'] ?? '').toString();
            final teamId = (b['battingTeamId'] ?? '').toString();
            final runs = b['runs'] ?? 0;
            final balls = b['ballsFaced'] ?? 0;
            final fours = b['fours'] ?? 0;
            final sixes = b['sixes'] ?? 0;
            final isOut = b['isOut'] ?? false;
            final isOnStrike = b['isOnStrike'] == true;
            final sr = balls > 0
                ? ((runs / balls) * 100).toStringAsFixed(1)
                : '0.0';

            return FutureBuilder<String>(
              future: _getName(teamId, playerId, rawName),
              builder: (context, nameSnap) {
                final displayName =
                    nameSnap.data ?? (rawName.isEmpty ? '…' : rawName);
                return _BatsmanRow(
                  name: displayName,
                  runs: runs,
                  balls: balls,
                  fours: fours,
                  sixes: sixes,
                  strikeRate: sr,
                  isOut: isOut,
                  isOnStrike: isOnStrike,
                  pulseAnim: _pulseAnim,
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Loading State ─────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: _C.success,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Loading batsmen…',
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.success.withOpacity(0.04),
              border: Border.all(color: _C.success.withOpacity(0.1)),
            ),
            child: Icon(
              Icons.sports_baseball_rounded,
              color: _C.success.withOpacity(0.2),
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No batsmen yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Column Label ─────────────────────────────────────────────────────────────
class _ColLabel extends StatelessWidget {
  final String text;
  const _ColLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Batsman Row ──────────────────────────────────────────────────────────────
class _BatsmanRow extends StatelessWidget {
  final String name;
  final dynamic runs;
  final dynamic balls;
  final dynamic fours;
  final dynamic sixes;
  final String strikeRate;
  final bool isOut;
  final bool isOnStrike;
  final Animation<double> pulseAnim;

  const _BatsmanRow({
    required this.name,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.strikeRate,
    required this.isOut,
    required this.isOnStrike,
    required this.pulseAnim,
  });

  // Milestone colour — gold for 50+, cyan for any runs
  Color get _runsColor {
    final r = runs is int ? runs as int : 0;
    if (isOut) return Colors.white.withOpacity(0.25);
    if (r >= 50) return _C.gold;
    return _C.success;
  }

  // SR colour — green > 120, amber 80–120, muted < 80
  Color get _srColor {
    if (isOut) return Colors.white.withOpacity(0.2);
    final sr = double.tryParse(strikeRate) ?? 0;
    if (sr >= 120) return _C.success;
    if (sr >= 80) return _C.gold;
    return Colors.white.withOpacity(0.35);
  }

  @override
  Widget build(BuildContext context) {
    final runCount = runs is int ? runs as int : 0;
    final isMilestone = runCount >= 50;

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: isOut
                ? Colors.transparent
                : isOnStrike
                ? _C.success
                .withOpacity(0.06 + 0.03 * pulseAnim.value)
                : Colors.transparent,
            border: Border.all(
              color: isOnStrike && !isOut
                  ? _C.success
                  .withOpacity(0.18 + 0.1 * pulseAnim.value)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Avatar initial
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isOut
                        ? [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.02),
                    ]
                        : isOnStrike
                        ? [
                      _C.success.withOpacity(0.30),
                      _C.success.withOpacity(0.10),
                    ]
                        : [
                      _C.accent.withOpacity(0.18),
                      _C.accentDim.withOpacity(0.06),
                    ],
                  ),
                  border: Border.all(
                    color: isOut
                        ? Colors.white.withOpacity(0.06)
                        : isOnStrike
                        ? _C.success.withOpacity(0.45)
                        : _C.accent.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isOut
                          ? Colors.white.withOpacity(0.2)
                          : isOnStrike
                          ? _C.success
                          : _C.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Name + badges
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isOut
                              ? Colors.white.withOpacity(0.28)
                              : isOnStrike
                              ? Colors.white
                              : Colors.white.withOpacity(0.78),
                          fontSize: 14,
                          fontWeight: isOnStrike && !isOut
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: -0.1,
                          decoration:
                          isOut ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white.withOpacity(0.2),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOnStrike && !isOut) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _C.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: _C.success.withOpacity(0.35)),
                        ),
                        child: Text(
                          '★',
                          style: TextStyle(
                            color: _C.success,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                    if (isOut) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _C.wicket.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: _C.wicket.withOpacity(0.2)),
                        ),
                        child: Text(
                          'OUT',
                          style: TextStyle(
                            color: _C.wicket.withOpacity(0.6),
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // R — runs with milestone glow
              _StatCell(
                value: '$runs',
                color: _runsColor,
                bold: true,
                glowing: isMilestone && !isOut,
              ),

              // B — balls
              _StatCell(
                value: '$balls',
                color: isOut
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.5),
              ),

              // 4s — fours in accent cyan
              _StatCell(
                value: '$fours',
                color: isOut
                    ? Colors.white.withOpacity(0.2)
                    : (fours is int && fours > 0)
                    ? _C.accent
                    : Colors.white.withOpacity(0.4),
                bold: fours is int && fours > 0 && !isOut,
              ),

              // 6s — sixes in gold
              _StatCell(
                value: '$sixes',
                color: isOut
                    ? Colors.white.withOpacity(0.2)
                    : (sixes is int && sixes > 0)
                    ? _C.gold
                    : Colors.white.withOpacity(0.4),
                bold: sixes is int && sixes > 0 && !isOut,
                glowing: sixes is int && sixes > 0 && !isOut,
              ),

              // SR — strike rate colour-coded
              _StatCell(
                value: strikeRate,
                color: _srColor,
                bold: !isOut,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Stat Cell ────────────────────────────────────────────────────────────────
class _StatCell extends StatelessWidget {
  final String value;
  final Color color;
  final bool bold;
  final bool glowing;

  const _StatCell({
    required this.value,
    required this.color,
    this.bold = false,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          shadows: glowing
              ? [
            Shadow(
              color: color.withOpacity(0.7),
              blurRadius: 10,
            ),
          ]
              : null,
        ),
      ),
    );
  }
}