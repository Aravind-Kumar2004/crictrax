import '../../domain/entities/batsman_entity.dart';

class BatsmanModel extends BatsmanEntity {
  const BatsmanModel({
    required super.id,
    required super.playerName,
    required super.ballsFaced,
    required super.runs,
    required super.fours,
    required super.sixes,
    required super.isOut,
  });

  factory BatsmanModel.fromMap(
      Map<String, dynamic> data, String id) {
    return BatsmanModel(
      id: id,
      playerName: data['playerName'] ?? '',
      ballsFaced: data['ballsFaced'] ?? 0,
      runs: data['runs'] ?? 0,
      fours: data['fours'] ?? 0,
      sixes: data['sixes'] ?? 0,
      isOut: data['isOut'] ?? false,
    );
  }
}