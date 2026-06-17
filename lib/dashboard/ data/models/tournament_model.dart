import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/tournament_entity.dart';

class TournamentModel extends TournamentEntity {
  const TournamentModel({
    required super.id,
    required super.name,
    required super.city,
    required super.ground,
    required super.format,
    required super.organizerName,
    required super.createdBy,
    super.startDate,
    super.endDate,
  });

  factory TournamentModel.fromMap(
      Map<String, dynamic> data, String id) {
    return TournamentModel(
      id: id,
      name: data['name'] ?? '',
      city: data['city'] ?? '',
      ground: data['ground'] ?? '',
      format: (data['format'] ?? '')
          .toString()
          .replaceAll('_', ' '),
      organizerName: data['organizerName'] ?? '',
      createdBy: data['createdBy'] ?? '',
      startDate:
      (data['startDate'] as Timestamp?)?.toDate(),
      endDate:
      (data['endDate'] as Timestamp?)?.toDate(),
    );
  }
}