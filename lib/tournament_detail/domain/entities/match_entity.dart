class TournamentMatchEntity {
  final String id;
  final String teamId1Name;
  final String teamId2Name;
  final int overs;
  final bool isCompleted;
  final int batBowlFlag;
  final String? matchDate;

  const TournamentMatchEntity({
    required this.id,
    required this.teamId1Name,
    required this.teamId2Name,
    required this.overs,
    required this.isCompleted,
    required this.batBowlFlag,
    this.matchDate,
  });

  bool get isLive => !isCompleted && batBowlFlag > 0;
  bool get isUpcoming => !isCompleted && batBowlFlag == 0;
}