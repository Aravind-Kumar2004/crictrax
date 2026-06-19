import '../../domain/entities/match_entity.dart';

class MatchModel extends MatchEntity {
  const MatchModel({
    required super.id,
    required super.tournamentId,
    required super.teamId1Name,
    required super.teamId2Name,
    required super.isCompleted,
    required super.batBowlFlag,
  });

  factory MatchModel.fromMap(
      Map<String, dynamic> data, String id, String tournamentId) {
    return MatchModel(
      id: id,
      tournamentId: tournamentId,
      teamId1Name: (data['teamId1Name'] ?? data['teamId1'] ?? 'Team 1')
          .toString(),
      teamId2Name: (data['teamId2Name'] ?? data['teamId2'] ?? 'Team 2')
          .toString(),
      isCompleted: data['isCompleted'] == true,
      batBowlFlag: (data['batBowlFlag'] ?? 0) is int
          ? data['batBowlFlag'] ?? 0
          : int.tryParse(data['batBowlFlag'].toString()) ?? 0,
    );
  }
}