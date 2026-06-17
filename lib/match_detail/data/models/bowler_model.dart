import '../../domain/entities/bowler_entity.dart';

class BowlerModel extends BowlerEntity {
  const BowlerModel({
    required super.id,
    required super.playerName,
    required super.overs,
    required super.runsConceded,
    required super.wickets,
    required super.economy,
  });

  factory BowlerModel.fromMap(
      Map<String, dynamic> data, String id) {
    return BowlerModel(
      id: id,
      playerName: data['playerName'] ?? '',
      overs: data['overs'] ?? 0,
      runsConceded: data['runsConceded'] ?? 0,
      wickets: data['wickets'] ?? 0,
      economy: (data['economy'] ?? 0).toDouble(),
    );
  }
}