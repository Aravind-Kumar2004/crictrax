/// Domain entity for a Team, mirroring the "Teams Collection" defined in the
/// CRICTRAX Firestore schema:
///   teamId, teamName, shortName, logo, captainId, coach, city, country, createdAt
///
/// `captainId` points at a document in the Players collection — this entity
/// stores the raw id. Resolving it to a display name is a repository-layer
/// concern (see TeamRepository.getPlayerName), not something baked into the
/// entity itself.
class TeamEntity {
  final String id;
  final String teamName;
  final String shortName;
  final String logo;
  final String captainId;
  final String coach;
  final String city;
  final String country;
  final DateTime? createdAt;

  const TeamEntity({
    required this.id,
    required this.teamName,
    required this.shortName,
    required this.logo,
    required this.captainId,
    required this.coach,
    required this.city,
    required this.country,
    this.createdAt,
  });
}