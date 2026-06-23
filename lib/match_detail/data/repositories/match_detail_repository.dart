import 'package:cloud_firestore/cloud_firestore.dart';

class MatchDetailRepository {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> watchInnings(String tournamentId, String matchId) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .collection('innings')
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> fetchBatsmen(
      String tournamentId, String matchId, String inningsId) async {
    final snap = await _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .collection('innings')
        .doc(inningsId)
        .collection('batsmen')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> fetchBowlers(
      String tournamentId, String matchId, String inningsId) async {
    final snap = await _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .collection('innings')
        .doc(inningsId)
        .collection('bowlers')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }
}