class MatchEntity {
  final String id;
  final String tournamentId;
  final String teamId1Name;
  final String teamId2Name;
  final bool isCompleted;
  final int batBowlFlag;

  const MatchEntity({
    required this.id,
    required this.tournamentId,
    required this.teamId1Name,
    required this.teamId2Name,
    required this.isCompleted,
    required this.batBowlFlag,
  });

  bool get isLive => !isCompleted && batBowlFlag > 0;
}