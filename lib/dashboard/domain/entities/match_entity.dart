// match_entity.dart

class MatchEntity {
  final String id;
  final String tournamentId;
  final String teamId1Name;
  final String teamId2Name;
  final bool isCompleted;
  final int batBowlFlag;
  final String status; // ← ADD

  const MatchEntity({
    required this.id,
    required this.tournamentId,
    required this.teamId1Name,
    required this.teamId2Name,
    required this.isCompleted,
    required this.batBowlFlag,
    required this.status, // ← ADD
  });

  // Derived helper used by the TV UI
  bool get isLive => !isCompleted && status == 'live';
  bool get isDone => isCompleted && status == 'completed';
}