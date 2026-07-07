/// Domain entity for a Player, mirroring the "Players Collection" defined in
/// the CRICTRAX Firestore schema:
///   playerId, playerName, photo, role, battingStyle, bowlingStyle,
///   jerseyNumber, teamId, createdAt
class PlayerEntity {
  final String id;
  final String playerName;
  final String photo;
  final String role;
  final String battingStyle;
  final String bowlingStyle;
  final int jerseyNumber;
  final String teamId;
  final DateTime? createdAt;

  const PlayerEntity({
    required this.id,
    required this.playerName,
    required this.photo,
    required this.role,
    required this.battingStyle,
    required this.bowlingStyle,
    required this.jerseyNumber,
    required this.teamId,
    this.createdAt,
  });
}