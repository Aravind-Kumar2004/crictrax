import '../../domain/entities/match_entity.dart';

class TournamentMatchModel extends TournamentMatchEntity {
  const TournamentMatchModel({
    required super.id,
    required super.teamId1Name,
    required super.teamId2Name,
    required super.teamId1,
    required super.teamId2,
    required super.overs,
    required super.isCompleted,
    required super.batBowlFlag,
    super.matchDate,
  });

  factory TournamentMatchModel.fromMapWithNames(
      Map<String, dynamic> data,
      String id,
      String team1Name,
      String team2Name) {
    return TournamentMatchModel(
      id: id,
      teamId1Name: team1Name,
      teamId2Name: team2Name,
      teamId1: data['teamId1'] ?? '',
      teamId2: data['teamId2'] ?? '',
      overs: data['overs'] ?? 0,
      isCompleted: data['isCompleted'] ?? false,
      batBowlFlag: data['batBowlFlag'] ?? 0,
      matchDate: data['matchDate'],
    );
  }
}