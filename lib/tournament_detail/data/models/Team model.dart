import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/Team entity.dart';


class TeamModel extends TeamEntity {
  const TeamModel({
    required super.id,
    required super.teamName,
    required super.shortName,
    required super.logo,
    required super.captainId,
    required super.coach,
    required super.city,
    required super.country,
    super.createdAt,
  });

  factory TeamModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) created = rawCreated.toDate();

    return TeamModel(
      id: id,
      teamName: (data['teamName'] as String?) ?? '',
      shortName: (data['shortName'] as String?) ?? '',
      logo: (data['logo'] as String?) ?? '',
      captainId: (data['captainId'] as String?) ?? '',
      coach: (data['coach'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      country: (data['country'] as String?) ?? '',
      createdAt: created,
    );
  }
}