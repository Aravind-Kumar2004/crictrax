import '../../domain/entities/bowler_entity.dart';

class LiveBowlerModel extends LiveBowlerEntity {
  const LiveBowlerModel({
    required super.id,
    required super.playerName,
    required super.overs,
    required super.runsConceded,
    required super.wickets,
    required super.economy,
  });

  factory LiveBowlerModel.fromMap(
      Map<String, dynamic> data, String id) {
    return LiveBowlerModel(
      id: id,
      playerName: data['playerName'] ?? '',
      overs: data['overs'] ?? 0,
      runsConceded: data['runsConceded'] ?? 0,
      wickets: data['wickets'] ?? 0,
      economy: (data['economy'] ?? 0).toDouble(),
    );
  }
}