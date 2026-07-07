import 'package:cloud_firestore/cloud_firestore.dart';

class LiveScoreRepository {
  final _db = FirebaseFirestore.instance;

  // Resolves to users/{userId}/matches/{matchId} for standalone (local) matches,
  // or tournaments/{tournamentId}/matches/{matchId} for tournament matches.
  DocumentReference<Map<String, dynamic>> _matchRef(
      String tournamentId, String matchId, {String? userId}) {
    if (tournamentId == 'standalone' && userId != null) {
      return _db
          .collection('users')
          .doc(userId)
          .collection('matches')
          .doc(matchId);
    }
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId);
  }

  Stream<DocumentSnapshot> watchMatch(String tournamentId, String matchId,
      {String? userId}) {
    return _matchRef(tournamentId, matchId, userId: userId).snapshots();
  }

  Stream<QuerySnapshot> watchInnings(String tournamentId, String matchId,
      {String? userId}) {
    return _matchRef(tournamentId, matchId, userId: userId)
        .collection('innings')
        .snapshots();
  }

  Stream<QuerySnapshot> watchBatsmen(
      String tournamentId, String matchId, String inningsId,
      {String? userId}) {
    return _matchRef(tournamentId, matchId, userId: userId)
        .collection('innings')
        .doc(inningsId)
        .collection('batsmen')
        .snapshots();
  }

  Stream<QuerySnapshot> watchBowlers(
      String tournamentId, String matchId, String inningsId,
      {String? userId}) {
    return _matchRef(tournamentId, matchId, userId: userId)
        .collection('innings')
        .doc(inningsId)
        .collection('bowlers')
        .snapshots();
  }

  Stream<QuerySnapshot> watchCurrentOverBalls(
      String tournamentId, String matchId, String inningsId, int overNumber,
      {String? userId}) {
    return _matchRef(tournamentId, matchId, userId: userId)
        .collection('innings')
        .doc(inningsId)
        .collection('balls')
        .where('overNumber', isEqualTo: overNumber)
        .orderBy('ballInOver')
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