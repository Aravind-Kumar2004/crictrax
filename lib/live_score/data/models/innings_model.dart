import '../../domain/entities/innings_entity.dart';

class LiveInningsModel extends LiveInningsEntity {
  const LiveInningsModel({
    required super.id,
    required super.battingTeamId,
    required super.isSecondInnings,
    super.targetRuns,
  });

  factory LiveInningsModel.fromMap(
      Map<String, dynamic> data, String id) {
    return LiveInningsModel(
      id: id,
      battingTeamId: data['battingTeamId'] ?? '',
      isSecondInnings: data['isSecondInnings'] ?? false,
      targetRuns: data['targetRuns'],
    );
  }
}