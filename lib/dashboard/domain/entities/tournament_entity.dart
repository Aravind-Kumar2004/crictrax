class TournamentEntity {
  final String id;
  final String name;
  final String city;
  final String ground;
  final String format;
  final String organizerName;
  final String createdBy;
  final DateTime? startDate;
  final DateTime? endDate;

  const TournamentEntity({
    required this.id,
    required this.name,
    required this.city,
    required this.ground,
    required this.format,
    required this.organizerName,
    required this.createdBy,
    this.startDate,
    this.endDate,
  });

  String get status {
    final now = DateTime.now();
    if (endDate != null && now.isAfter(endDate!)) {
      return 'Completed';
    }
    if (startDate != null && now.isBefore(startDate!)) {
      return 'Upcoming';
    }
    return 'Active';
  }
}