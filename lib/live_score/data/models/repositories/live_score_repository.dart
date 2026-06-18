import 'package:cloud_firestore/cloud_firestore.dart';

class LiveScoreRepository {
  final _db = FirebaseFirestore.instance;

  Stream<DocumentSnapshot> watchMatch(
      String tournamentId, String matchId) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .snapshots();
  }

  Stream<QuerySnapshot> watchInnings(
      String tournamentId, String matchId) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .collection('innings')
        .snapshots();
  }

  Stream<QuerySnapshot> watchBatsmen(
      String tournamentId, String matchId, String inningsId) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .collection('innings')
        .doc(inningsId)
        .collection('batsmen')
        .snapshots();
  }

  Stream<QuerySnapshot> watchBowlers(
      String tournamentId, String matchId, String inningsId) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .collection('innings')
        .doc(inningsId)
        .collection('bowlers')
        .snapshots();
  }

  Future<String> resolvePlayerName(
      String tournamentId, String teamId, String playerId) async {
    if (playerId.isEmpty) return 'Unknown Player';
    try {
      final doc = await _db
          .collection('tournaments')
          .doc(tournamentId)
          .collection('teams')
          .doc(teamId)
          .collection('members')
          .doc(playerId)
          .get();
      final name = doc.data()?['playerName'] as String?;
      return (name != null && name.isNotEmpty) ? name : 'Unknown Player';
    } catch (_) {
      return 'Unknown Player';
    }
  }
}