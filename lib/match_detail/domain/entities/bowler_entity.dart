class BowlerEntity {
  final String id;
  final String playerName;
  final int overs;
  final int runsConceded;
  final int wickets;
  final double economy;

  const BowlerEntity({
    required this.id,
    required this.playerName,
    required this.overs,
    required this.runsConceded,
    required this.wickets,
    required this.economy,
  });
}