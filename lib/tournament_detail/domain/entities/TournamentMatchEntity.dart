class TournamentMatchEntity {
  final String id;
  final String teamId1Name;
  final String teamId2Name;
  final String teamId1;
  final String teamId2;
  final dynamic overs;
  final bool isCompleted;
  final int batBowlFlag;
  final String status;     // ← ADD
  final dynamic matchDate;

  const TournamentMatchEntity({
    required this.id,
    required this.teamId1Name,
    required this.teamId2Name,
    required this.teamId1,
    required this.teamId2,
    required this.overs,
    required this.isCompleted,
    required this.batBowlFlag,
    required this.status,    // ← ADD
    this.matchDate,
  });

  bool get isLive => !isCompleted && status == 'live';  // ← ADD
}