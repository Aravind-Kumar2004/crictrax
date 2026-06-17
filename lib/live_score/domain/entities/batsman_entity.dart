class LiveBatsmanEntity {
  final String id;
  final String playerName;
  final int ballsFaced;
  final int runs;
  final int fours;
  final int sixes;
  final bool isOut;

  const LiveBatsmanEntity({
    required this.id,
    required this.playerName,
    required this.ballsFaced,
    required this.runs,
    required this.fours,
    required this.sixes,
    required this.isOut,
  });

  String get strikeRate => ballsFaced > 0
      ? ((runs / ballsFaced) * 100).toStringAsFixed(1)
      : '0.0';
}