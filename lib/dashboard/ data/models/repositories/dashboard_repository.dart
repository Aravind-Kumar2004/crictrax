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