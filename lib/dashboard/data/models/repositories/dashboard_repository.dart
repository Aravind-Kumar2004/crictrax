import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../match_model.dart';
import '../tournament_model.dart';

class DashboardRepository {
  final _db = FirebaseFirestore.instance;

  Future<List<TournamentModel>> getUserTournaments(
      String userId) async {
    final snap = await _db
        .collection('tournaments')
        .where('createdBy', isEqualTo: userId)
        .get();
    return snap.docs
        .map((d) => TournamentModel.fromMap(d.data(), d.id))
        .toList();
  }
Stream<List<MatchModel>> watchLocalMatches(String userId) async* {
  // Resolve team names once up front (same pattern as TournamentDetailRepository)
  final teamsSnap = await _db
      .collection('users')
      .doc(userId)
      .collection('teams')
      .get();

  final teamNameById = <String, String>{};
  for (final t in teamsSnap.docs) {
    final data = t.data();
    teamNameById[t.id] = data['teamName'] ?? '';
  }

  yield* _db
      .collection('users')
      .doc(userId)
      .collection('matches')
      .snapshots()
      .asyncMap((snap) async {
    final results = <MatchModel>[];

    for (final d in snap.docs) {
      final data = d.data();
      final teamId1 = data['teamId1'] ?? '';
      final teamId2 = data['teamId2'] ?? '';

      final team1Name = (data['teamId1Name'] as String?)?.isNotEmpty == true
          ? data['teamId1Name'] as String
          : (teamNameById[teamId1]?.isNotEmpty == true
              ? teamNameById[teamId1]!
              : 'Team 1');

      final team2Name = (data['teamId2Name'] as String?)?.isNotEmpty == true
          ? data['teamId2Name'] as String
          : (teamNameById[teamId2]?.isNotEmpty == true
              ? teamNameById[teamId2]!
              : 'Team 2');

      var isCompleted = data['isCompleted'] == true;

      // ── Same fallback as TournamentDetailRepository.watchMatches:
      // if the match doc's isCompleted flag is stale, check the second
      // innings doc directly so Ongoing/Completed grouping stays accurate.
      if (!isCompleted) {
        final inningsSnap = await _db
            .collection('users')
            .doc(userId)
            .collection('matches')
            .doc(d.id)
            .collection('innings')
            .get();

        final secondInnings = inningsSnap.docs.where((inn) {
          final innData = inn.data();
          return innData['isSecondInnings'] == true;
        }).toList();

        if (secondInnings.isNotEmpty) {
          final secondInnData = secondInnings.first.data();
          if (secondInnData['isCompleted'] == true) {
            isCompleted = true;
          }
        }
      }

      final patchedData = {
        ...data,
        'teamId1Name': team1Name,
        'teamId2Name': team2Name,
        'isCompleted': isCompleted,
      };

      results.add(MatchModel.fromMap(patchedData, d.id, 'standalone'));
    }

    return results;
  });
}

  Stream<List<MatchModel>> watchLiveMatches(
      List<TournamentModel> tournaments) {
    if (tournaments.isEmpty) {
      return Stream.value(<MatchModel>[]);
    }

    final streams = tournaments.map((tour) {
      return _db
          .collection('tournaments')
          .doc(tour.id)
          .collection('matches')
          .where('isCompleted', isEqualTo: false)
          .snapshots()
          .map((snap) {
        return snap.docs
            .map((d) =>
            MatchModel.fromMap(d.data(), d.id, tour.id))
            .where((m) => m.batBowlFlag > 0)
            .toList();
      });
    }).toList();

    return _combineLatest(streams);
  }

  

  Stream<List<MatchModel>> _combineLatest(
      List<Stream<List<MatchModel>>> streams) {
    final controller = StreamController<List<MatchModel>>();
    final latest = List<List<MatchModel>>.filled(
        streams.length, const []);
    final subs = <StreamSubscription>[];
    var receivedCount = 0;

    for (var i = 0; i < streams.length; i++) {
      subs.add(streams[i].listen((data) {
        latest[i] = data;
        receivedCount++;
        controller.add(latest.expand((e) => e).toList());
      }, onError: (e) {
        // ignore stream errors from individual tournaments
      }));
    }

    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };

    return controller.stream;
  }
}