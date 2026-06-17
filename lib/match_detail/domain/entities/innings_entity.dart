class InningsEntity {
  final String id;
  final String battingTeamId;
  final String bowlingTeamId;
  final bool isCompleted;
  final bool isSecondInnings;
  final int? targetRuns;

  const InningsEntity({
    required this.id,
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.isCompleted,
    required this.isSecondInnings,
    this.targetRuns,
  });
}