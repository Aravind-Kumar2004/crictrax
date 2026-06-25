import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/models/repositories/live_score_repository.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg         = Color(0xFF050A18);
  static const surface    = Color(0xFF0A1628);
  static const surfaceH   = Color(0xFF0F1E35);
  static const accent     = Color(0xFF00D4FF);
  static const accentDim  = Color(0xFF0066CC);
  static const live       = Color(0xFFFF6B35);
  static const success    = Color(0xFF00E676);
  static const wicket     = Color(0xFFFF3D3D);
  static const gold       = Color(0xFFFFB300);

  static const accentGrad = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOWLERS CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════════
class BowlersCardWidget extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final String inningsId;

  const BowlersCardWidget({
    Key? key,
    required this.tournamentId,
    required this.matchId,
    required this.inningsId,
  }) : super(key: key);

  @override
  State<BowlersCardWidget> createState() => _BowlersCardWidgetState();
}

class _BowlersCardWidgetState extends State<BowlersCardWidget>
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
              Expanded(child: _buildBowlersList()),
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
                colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _C.accent.withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: const Icon(
              Icons.sports_cricket,
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
                'BOWLING',
                style: TextStyle(
                  color: _C.accent.withOpacity(0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              const Text(
                'Bowlers',
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _C.live.withOpacity(0.10 + 0.05 * _pulseAnim.value),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _C.live.withOpacity(0.3 + 0.15 * _pulseAnim.value),
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
                      color: _C.live.withOpacity(0.6 + 0.4 * _pulseAnim.value),
                      boxShadow: [
                        BoxShadow(
                          color: _C.live.withOpacity(0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: _C.live,
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
          // Player label
          Expanded(
            child: Text(
              'BOWLER',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ),
          // Stat column headers — fixed widths matching value columns
          _ColLabel('O'),
          _ColLabel('R'),
          _ColLabel('W'),
          _ColLabel('ECO'),
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
            _C.accent.withOpacity(0.2),
            Colors.white.withOpacity(0.04),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  // ── Bowlers List ──────────────────────────────────────────────────────────
  Widget _buildBowlersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _repo.watchBowlers(
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
            final teamId = (b['bowlingTeamId'] ?? '').toString();
            final overs = b['overs'] ?? 0;
            final runs = b['runsConceded'] ?? 0;
            final wkts = b['wickets'] ?? 0;
            final isBowling = b['isBowling'] == true;
            final econ = overs > 0
                ? (runs / overs).toStringAsFixed(1)
                : '0.0';

            return FutureBuilder<String>(
              future: _getName(teamId, playerId, rawName),
              builder: (context, nameSnap) {
                final displayName =
                    nameSnap.data ?? (rawName.isEmpty ? '…' : rawName);
                return _BowlerRow(
                  name: displayName,
                  overs: overs,
                  runs: runs,
                  wickets: wkts,
                  economy: econ,
                  isBowling: isBowling,
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
              color: _C.accent,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Loading bowlers…',
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
              color: _C.accent.withOpacity(0.04),
              border: Border.all(color: _C.accent.withOpacity(0.1)),
            ),
            child: Icon(
              Icons.sports_cricket,
              color: _C.accent.withOpacity(0.2),
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No bowlers yet',
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
      width: 38,
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

// ─── Bowler Row ───────────────────────────────────────────────────────────────
class _BowlerRow extends StatelessWidget {
  final String name;
  final dynamic overs;
  final dynamic runs;
  final dynamic wickets;
  final String economy;
  final bool isBowling;
  final Animation<double> pulseAnim;

  const _BowlerRow({
    required this.name,
    required this.overs,
    required this.runs,
    required this.wickets,
    required this.economy,
    required this.isBowling,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    final hasWickets = (wickets is int ? wickets : 0) > 0;
    final wicketCount = wickets is int ? wickets : 0;

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: isBowling
                ? _C.live.withOpacity(0.06 + 0.03 * pulseAnim.value)
                : Colors.transparent,
            border: Border.all(
              color: isBowling
                  ? _C.live.withOpacity(0.2 + 0.1 * pulseAnim.value)
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
                    colors: isBowling
                        ? [
                      _C.live.withOpacity(0.35),
                      _C.live.withOpacity(0.12),
                    ]
                        : [
                      _C.accent.withOpacity(0.18),
                      _C.accentDim.withOpacity(0.06),
                    ],
                  ),
                  border: Border.all(
                    color: isBowling
                        ? _C.live.withOpacity(0.45)
                        : _C.accent.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isBowling ? _C.live : _C.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Name + bowling badge
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isBowling
                              ? Colors.white
                              : Colors.white.withOpacity(0.82),
                          fontSize: 14,
                          fontWeight: isBowling
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isBowling) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _C.live.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: _C.live.withOpacity(0.35)),
                        ),
                        child: Text(
                          'NOW',
                          style: TextStyle(
                            color: _C.live,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Overs
              _StatCell(
                value: '$overs',
                color: Colors.white.withOpacity(0.65),
              ),

              // Runs
              _StatCell(
                value: '$runs',
                color: Colors.white.withOpacity(0.65),
              ),

              // Wickets — highlighted if > 0
              _StatCell(
                value: '$wickets',
                color: hasWickets ? _C.wicket : Colors.white.withOpacity(0.65),
                bold: hasWickets,
                glowing: hasWickets,
              ),

              // Economy
              _StatCell(
                value: economy,
                color: _C.accent,
                bold: true,
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
      width: 38,
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
              color: color.withOpacity(0.6),
              blurRadius: 8,
            ),
          ]
              : null,
        ),
      ),
    );
  }
}