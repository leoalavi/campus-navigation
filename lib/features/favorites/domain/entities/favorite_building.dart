import 'package:flutter/foundation.dart';

@immutable
class FavoriteBuilding {
  const FavoriteBuilding({
    required this.id,
    required this.buildingId,
    required this.buildingName,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String buildingId;
  final String buildingName;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FavoriteBuilding.fromJson(Map<String, dynamic> json) {
    return FavoriteBuilding(
      id: json['id'] as String,
      buildingId: json['building_id'] as String,
      buildingName: json['building_name'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'building_id': buildingId,
    'building_name': buildingName,
    'note': note,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  FavoriteBuilding copyWith({
    String? id,
    String? buildingId,
    String? buildingName,
    String? note,
    bool clearNote = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FavoriteBuilding(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      buildingName: buildingName ?? this.buildingName,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteBuilding &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FavoriteBuilding($buildingId, $buildingName)';
}
