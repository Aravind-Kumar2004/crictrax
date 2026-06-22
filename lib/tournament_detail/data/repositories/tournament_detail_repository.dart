import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';

class TournamentDetailRepository {
  final _db = FirebaseFirestore.instance;

  Future<List<TournamentMatchModel>> getMatches(String tournamentId) async {
    final matchSnap = await _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .get();

    final teamsSnap = await _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('teams')
        .get();

    final teamNameById = <String, String>{};
    for (final t in teamsSnap.docs) {
      final data = t.data();
      teamNameById[t.id] = data['teamName'] ?? '';
    }

    return matchSnap.docs.map((d) {
      final data = d.data();
      final teamId1 = data['teamId1'] ?? '';
      final teamId2 = data['teamId2'] ?? '';

      final team1Name = (data['teamId1Name'] as String?)?.isNotEmpty == true
          ? data['teamId1Name'] as String
          : (teamNameById[teamId1]?.isNotEmpty == true ? teamNameById[teamId1]! : 'Unknown Team');

      final team2Name = (data['teamId2Name'] as String?)?.isNotEmpty == true
          ? data['teamId2Name'] as String
          : (teamNameById[teamId2]?.isNotEmpty == true ? teamNameById[teamId2]! : 'Unknown Team');

      return TournamentMatchModel.fromMapWithNames(data, d.id, team1Name, team2Name);
    }).toList();
  }


  Stream<List<TournamentMatchModel>> watchMatches(String tournamentId) async* {
    final teamsSnap = await _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('teams')
        .get();

    final teamNameById = <String, String>{};
    for (final t in teamsSnap.docs) {
      final data = t.data();
      teamNameById[t.id] = data['teamName'] ?? '';
    }

    yield* _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .snapshots()
        .asyncMap((snap) async {
      final results = <TournamentMatchModel>[];

      for (final d in snap.docs) {
        final data = d.data();
        final teamId1 = data['teamId1'] ?? '';
        final teamId2 = data['teamId2'] ?? '';

        final team1Name = (data['teamId1Name'] as String?)?.isNotEmpty == true
            ? data['teamId1Name'] as String
            : (teamNameById[teamId1]?.isNotEmpty == true ? teamNameById[teamId1]! : 'Unknown Team');

        final team2Name = (data['teamId2Name'] as String?)?.isNotEmpty == true
            ? data['teamId2Name'] as String
            : (teamNameById[teamId2]?.isNotEmpty == true ? teamNameById[teamId2]! : 'Unknown Team');

        var isCompleted = data['isCompleted'] == true;

        // ── FIX: fallback check — if match.isCompleted was never set by
        // the mobile app, check whether the SECOND INNINGS document under
        // this match reports isCompleted == true. If so, treat the whole
        // match as completed for display purposes, even though the match
        // doc itself is stale. This keeps Live/Completed tabs accurate
        // without requiring an immediate mobile-app fix.
        if (!isCompleted) {
          final inningsSnap = await _db
              .collection('tournaments')
              .doc(tournamentId)
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

        final patchedData = {...data, 'isCompleted': isCompleted};

        results.add(TournamentMatchModel.fromMapWithNames(
          patchedData, d.id, team1Name, team2Name,
        ));
      }

      return results;
    });
  }
}