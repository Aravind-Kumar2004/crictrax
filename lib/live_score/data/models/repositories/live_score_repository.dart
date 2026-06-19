import 'package:cloud_firestore/cloud_firestore.dart';

class LiveScoreRepository {
  final _db = FirebaseFirestore.instance;

  Stream<DocumentSnapshot> watchMatch(
      String tournamentId,
      String matchId,
      ) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .snapshots();
  }

  // ── FIX: explicit descending order is NOT needed — ascending is correct
  // since the screen takes `.docs.last`. But we add `.handleError` so a
  // missing-index or permission error doesn't silently look like "no innings".
  Stream<QuerySnapshot> watchInnings(
      String tournamentId,
      String matchId,
      ) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .collection('innings')
        .orderBy('inningsNumber')
        .snapshots()
        .handleError((error) {
      // Surface to console immediately instead of the UI silently
      // falling back to the waiting bar with no diagnostic trail.
      // ignore: avoid_print
      print('watchInnings ERROR (tournament=$tournamentId, match=$matchId): $error');
    });
  }

  Stream<QuerySnapshot> watchBatsmen(
      String tournamentId,
      String matchId,
      String inningsId,
      ) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .collection('innings')
        .doc(inningsId)
        .collection('batsmen')
        .snapshots()
        .handleError((error) {
      // ignore: avoid_print
      print('watchBatsmen ERROR (innings=$inningsId): $error');
    });
  }

  Stream<QuerySnapshot> watchBowlers(
      String tournamentId,
      String matchId,
      String inningsId,
      ) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .collection('innings')
        .doc(inningsId)
        .collection('bowlers')
        .snapshots()
        .handleError((error) {
      // ignore: avoid_print
      print('watchBowlers ERROR (innings=$inningsId): $error');
    });
  }

  Stream<QuerySnapshot> watchCurrentOverBalls(
      String tournamentId,
      String matchId,
      String inningsId,
      int overNumber,
      ) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .collection('innings')
        .doc(inningsId)
        .collection('balls')
        .where('overNumber', isEqualTo: overNumber)
        .orderBy('ballInOver')
        .snapshots()
        .handleError((error) {
      // This is the most likely real culprit: a missing composite index
      // on (overNumber ==, ballInOver asc). Firestore will throw
      // FAILED_PRECONDITION with a console link to auto-create it.
      // ignore: avoid_print
      print('watchCurrentOverBalls ERROR (over=$overNumber): $error');
    });
  }

  Future<String> resolvePlayerName(
      String tournamentId,
      String teamId,
      String playerId,
      ) async {
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