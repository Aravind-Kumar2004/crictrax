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

  // NEW: real-time stream version, used instead of getMatches() in the screen
  Stream<List<TournamentMatchModel>> watchMatches(String tournamentId) async* {
    // Fetch team names once (they rarely change mid-tournament)
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
        .map((snap) {
      return snap.docs.map((d) {
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
    });
  }
}