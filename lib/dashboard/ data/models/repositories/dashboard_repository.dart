import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../match_model.dart';
import '../tournament_model.dart';

class DashboardRepository {
  final _db = FirebaseFirestore.instance;

  // ── Existing: unchanged ───────────────────────────────────────────────────

  Future<List<TournamentModel>> getUserTournaments(String userId) async {
    final snap = await _db
        .collection('tournaments')
        .where('createdBy', isEqualTo: userId)
        .get();
    return snap.docs
        .map((d) => TournamentModel.fromMap(d.data(), d.id))
        .toList();
  }

  Stream<List<MatchModel>> watchLiveMatches(
      List<TournamentModel> tournaments) {
    if (tournaments.isEmpty) return Stream.value(<MatchModel>[]);

    final streams = tournaments.map((tour) {
      return _db
          .collection('tournaments')
          .doc(tour.id)
          .collection('matches')
          .where('isCompleted', isEqualTo: false)
          .snapshots()
          .map((snap) => snap.docs
          .map((d) => MatchModel.fromMap(d.data(), d.id, tour.id))
          .where((m) => m.batBowlFlag > 0)
          .toList());
    }).toList();

    return _combineLatest(streams);
  }

  // ── NEW: Stream a single live match plus its current innings score ────────
  //
  // Flow:
  //   1. Watch tournaments/{tournamentId}/matches where isCompleted==false
  //      and batBowlFlag > 0 — pick the first result as the "featured" match.
  //   2. For that match, watch its innings sub-collection and pick the active
  //      innings (isCompleted==false, or fallback to the last one).
  //   3. For that innings, watch the scores sub-collection ordered by
  //      timestamp desc, limit 1 — gives us the latest score document.
  //   4. Combine everything into a [LiveMatchData] object and emit.
  //
  // Returns null when no live match exists (caller shows empty state).

  Stream<LiveMatchData?> watchFeaturedLiveMatch(
      List<TournamentModel> tournaments) {
    if (tournaments.isEmpty) return Stream.value(null);

    // Merge all tournament match streams into one flat stream of MatchModel
    final matchStreams = tournaments.map((tour) => _db
        .collection('tournaments')
        .doc(tour.id)
        .collection('matches')
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => MatchModel.fromMap(d.data(), d.id, tour.id))
        .where((m) => m.batBowlFlag > 0)
        .toList()));

    final allMatchesStream = _combineLatest(matchStreams.toList());

    // Switch-map: whenever the match list changes, re-subscribe to the score
    // stream of the first (featured) match only.
    return allMatchesStream.switchMap((matches) {
      if (matches.isEmpty) return Stream.value(null);

      final featured = matches.first;
      return _watchMatchScore(featured);
    });
  }

  // Watch innings + scores for a single MatchModel
  Stream<LiveMatchData?> _watchMatchScore(MatchModel match) {
    // Step A: watch the innings sub-collection of this match
    return _db
        .collection('tournaments')
        .doc(match.tournamentId)
        .collection('matches')
        .doc(match.id)
        .collection('innings')
        .snapshots()
        .switchMap((inningsSnap) {
      if (inningsSnap.docs.isEmpty) {
        // Match started (batBowlFlag>0) but innings not created yet
        return Stream.value(LiveMatchData(
          match: match,
          inningsId: null,
          runs: 0,
          wickets: 0,
          overs: '0.0',
          crr: 0.0,
          targetRuns: null,
          currentOver: [],
        ));
      }

      // Prefer the active (incomplete) innings; fall back to last doc
      QueryDocumentSnapshot<Map<String, dynamic>> activeInnings;
      final incomplete =
      inningsSnap.docs.where((d) => d.data()['isCompleted'] != true);
      activeInnings =
      incomplete.isNotEmpty ? incomplete.first : inningsSnap.docs.last;

      final inningsData = activeInnings.data();
      final targetRuns = inningsData['targetRuns'] as int?;
      final inningsId = activeInnings.id;

      // Step B: watch the scores sub-collection of this innings
      return _db
          .collection('tournaments')
          .doc(match.tournamentId)
          .collection('matches')
          .doc(match.id)
          .collection('innings')
          .doc(inningsId)
          .collection('scores')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .map((scoreSnap) {
        if (scoreSnap.docs.isEmpty) {
          return LiveMatchData(
            match: match,
            inningsId: inningsId,
            runs: 0,
            wickets: 0,
            overs: '0.0',
            crr: 0.0,
            targetRuns: targetRuns,
            currentOver: [],
          );
        }

        final s = scoreSnap.docs.first.data();
        final runs = (s['runs'] as num?)?.toInt() ?? 0;
        final wickets = (s['wickets'] as num?)?.toInt() ?? 0;
        final oversNum = (s['overs'] as num?)?.toDouble() ?? 0.0;
        final crr = (s['crr'] as num?)?.toDouble() ?? 0.0;
        final currentOver = (s['currentOver'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
            [];

        // Format overs as "X.Y"
        final oversStr = oversNum.toStringAsFixed(1);

        return LiveMatchData(
          match: match,
          inningsId: inningsId,
          runs: runs,
          wickets: wickets,
          overs: oversStr,
          crr: crr,
          targetRuns: targetRuns,
          currentOver: currentOver,
        );
      });
    });
  }

  // ── Private: combine list of streams (unchanged logic) ────────────────────

  Stream<List<MatchModel>> _combineLatest(
      List<Stream<List<MatchModel>>> streams) {
    final controller = StreamController<List<MatchModel>>();
    final latest = List<List<MatchModel>>.filled(streams.length, const []);
    final subs = <StreamSubscription>[];

    for (var i = 0; i < streams.length; i++) {
      subs.add(streams[i].listen(
            (data) {
          latest[i] = data;
          controller.add(latest.expand((e) => e).toList());
        },
        onError: (_) {/* ignore per-tournament errors */},
      ));
    }

    controller.onCancel = () {
      for (final s in subs) s.cancel();
    };

    return controller.stream;
  }
}

// ── Data class returned by watchFeaturedLiveMatch ─────────────────────────────

class LiveMatchData {
  final MatchModel match;
  final String? inningsId;
  final int runs;
  final int wickets;
  final String overs; // e.g. "12.3"
  final double crr;
  final int? targetRuns; // null in first innings
  final List<String> currentOver; // ball-by-ball for current over

  const LiveMatchData({
    required this.match,
    required this.inningsId,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.crr,
    required this.targetRuns,
    required this.currentOver,
  });

  // Convenience: score display string e.g. "134/4"
  String get scoreDisplay => '$runs/$wickets';

  // Convenience: overs display e.g. "12.3 ov"
  String get oversDisplay => '$overs ov';

  String get team1Name => match.teamId1Name;
  String get team2Name => match.teamId2Name;
  String get matchStatus => match.status;
}

// ── Extension: switchMap for Stream (avoids adding rxdart dependency) ─────────

extension _SwitchMap<T> on Stream<T> {
  Stream<R> switchMap<R>(Stream<R> Function(T) fn) {
    late StreamController<R> controller;
    StreamSubscription<T>? outerSub;
    StreamSubscription<R>? innerSub;

    controller = StreamController<R>(
      onListen: () {
        outerSub = listen(
              (value) {
            innerSub?.cancel();
            innerSub = fn(value).listen(
              controller.add,
              onError: controller.addError,
            );
          },
          onError: controller.addError,
          onDone: () {
            innerSub?.cancel();
            controller.close();
          },
        );
      },
      onCancel: () {
        outerSub?.cancel();
        innerSub?.cancel();
      },
    );

    return controller.stream;
  }
}