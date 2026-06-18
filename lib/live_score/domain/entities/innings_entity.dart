class LiveInningsEntity {
  final String id;
  final String battingTeamId;
  final bool isSecondInnings;
  final int? targetRuns;

  const LiveInningsEntity({
    required this.id,
    required this.battingTeamId,
    required this.isSecondInnings,
    this.targetRuns,
  });
}