import '../../domain/entities/innings_entity.dart';

class InningsModel extends InningsEntity {
  const InningsModel({
    required super.id,
    required super.battingTeamId,
    required super.bowlingTeamId,
    required super.isCompleted,
    required super.isSecondInnings,
    super.targetRuns,
  });

  factory InningsModel.fromMap(
      Map<String, dynamic> data, String id) {
    return InningsModel(
      id: id,
      battingTeamId: data['battingTeamId'] ?? '',
      bowlingTeamId: data['bowlingTeamId'] ?? '',
     isCompleted: data['isCompleted'] == true,
isSecondInnings: data['isSecondInnings'] == true,
      targetRuns: data['targetRuns'],
    );
  }
}