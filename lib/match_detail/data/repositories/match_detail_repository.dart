import 'package:cloud_firestore/cloud_firestore.dart';

class MatchDetailRepository {
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
}