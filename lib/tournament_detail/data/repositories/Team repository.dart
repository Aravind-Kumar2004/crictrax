import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/Player model.dart';
import '../models/Team model.dart';


/// Brand new, self-contained repository for the Team module.
/// Does NOT touch TournamentDetailRepository or any existing repository.
///
/// Reads only from the collections already defined in the CRICTRAX Firestore
/// schema:
///   users/{uid}/teams/{teamId}
///   users/{uid}/players/{playerId}   (filtered by teamId for a roster)
class TeamRepository {
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Fetches a single team document. Returns null if the user isn't signed
  /// in or the team doesn't exist — never fabricates a team.
  Future<TeamModel?> getTeam(String teamId) async {
    final uid = _uid;
    if (uid == null) return null;

    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('teams')
        .doc(teamId)
        .get();

    if (!doc.exists) return null;
    return TeamModel.fromMap(doc.data() ?? {}, doc.id);
  }

  /// Resolves a captainId (which points at a Players document) to a display
  /// name. Returns null if unavailable, so the UI can hide it gracefully
  /// instead of showing a raw id or invented text.
  Future<String?> getPlayerName(String playerId) async {
    final uid = _uid;
    if (uid == null || playerId.isEmpty) return null;

    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('players')
        .doc(playerId)
        .get();

    if (!doc.exists) return null;
    final name = doc.data()?['playerName'] as String?;
    return (name != null && name.isNotEmpty) ? name : null;
  }

  /// Live roster for a team: every player whose `teamId` matches.
  Stream<List<PlayerModel>> watchPlayersForTeam(String teamId) {
    final uid = _uid;
    if (uid == null) return Stream<List<PlayerModel>>.value(const []);

    return _db
        .collection('users')
        .doc(uid)
        .collection('players')
        .where('teamId', isEqualTo: teamId)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => PlayerModel.fromMap(d.data(), d.id))
        .toList());
  }
  Future<List<TeamModel>> getTeamsByIds(List<String> teamIds) async {
    final uid = _uid;
    if (uid == null || teamIds.isEmpty) return [];
    final results = <TeamModel>[];
    for (var i = 0; i < teamIds.length; i += 10) {
      final chunk = teamIds.sublist(i, i + 10 > teamIds.length ? teamIds.length : i + 10);
      final snap = await _db.collection('users').doc(uid).collection('teams')
          .where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map((d) => TeamModel.fromMap(d.data(), d.id)));
    }
    return results;
  }

  Future<Map<String, List<PlayerModel>>> getPlayersByTeamIds(List<String> teamIds) async {
    final uid = _uid;
    if (uid == null || teamIds.isEmpty) return {};
    final grouped = <String, List<PlayerModel>>{};
    for (var i = 0; i < teamIds.length; i += 10) {
      final chunk = teamIds.sublist(i, i + 10 > teamIds.length ? teamIds.length : i + 10);
      final snap = await _db.collection('users').doc(uid).collection('players')
          .where('teamId', whereIn: chunk).get();
      for (final d in snap.docs) {
        final p = PlayerModel.fromMap(d.data(), d.id);
        grouped.putIfAbsent(p.teamId, () => []).add(p);
      }
    }
    return grouped;
  }
}
