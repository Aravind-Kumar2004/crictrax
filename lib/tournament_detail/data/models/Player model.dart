import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/Player entity.dart';


class PlayerModel extends PlayerEntity {
  const PlayerModel({
    required super.id,
    required super.playerName,
    required super.photo,
    required super.role,
    required super.battingStyle,
    required super.bowlingStyle,
    required super.jerseyNumber,
    required super.teamId,
    super.createdAt,
  });

  factory PlayerModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) created = rawCreated.toDate();

    final rawJersey = data['jerseyNumber'];
    final jersey = rawJersey is int
        ? rawJersey
        : int.tryParse(rawJersey?.toString() ?? '') ?? 0;

    return PlayerModel(
      id: id,
      playerName: (data['playerName'] as String?) ?? '',
      photo: (data['photo'] as String?) ?? '',
      role: (data['role'] as String?) ?? '',
      battingStyle: (data['battingStyle'] as String?) ?? '',
      bowlingStyle: (data['bowlingStyle'] as String?) ?? '',
      jerseyNumber: jersey,
      teamId: (data['teamId'] as String?) ?? '',
      createdAt: created,
    );
  }
}