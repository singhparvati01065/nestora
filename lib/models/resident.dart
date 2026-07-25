import 'package:flutter/material.dart';

enum ResidentType {
  owner,
  tenant;

  String get label => this == ResidentType.owner ? 'Owner' : 'Tenant';

  /// Backend enum value ("OWNER" / "TENANT").
  String get api => this == ResidentType.owner ? 'OWNER' : 'TENANT';

  static ResidentType fromApi(String value) =>
      value == 'TENANT' ? ResidentType.tenant : ResidentType.owner;

  Color get color =>
      this == ResidentType.owner ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);
}

class Resident {
  Resident({
    required this.id,
    required this.name,
    required this.phone,
    required this.flatNumber,
    required this.type,
    this.flatId,
    this.monthlyRent,
    this.moveInDate,
    this.advanceAmount,
    this.maintenanceAmount,
    this.occupation,
    this.familyMembers,
    this.documentUrls = const [],
    this.archivedAt,
  });

  final String id;
  String name;
  String phone;
  String flatNumber;
  ResidentType type;

  /// Flat id (for editing); the list response nests it under flat.
  final String? flatId;

  /// Monthly rent; when set with [moveInDate], bills auto-generate.
  double? monthlyRent;
  DateTime? moveInDate;

  /// One-time advance / security deposit, and the agreed monthly maintenance.
  double? advanceAmount;
  double? maintenanceAmount;

  String? occupation;
  int? familyMembers;

  /// Uploaded document image paths (e.g. /uploads/x.jpg).
  List<String> documentUrls;

  /// When removed (soft delete); non-null means it's in history.
  DateTime? archivedAt;

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  factory Resident.fromJson(Map<String, dynamic> json) {
    return Resident(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      flatNumber: (json['flat']?['number'] ?? '') as String,
      type: ResidentType.fromApi(json['type'] as String),
      flatId: json['flatId'] as String?,
      // Prisma serialises Decimal as a string, so parse rather than cast.
      monthlyRent: json['monthlyRent'] == null
          ? null
          : double.tryParse(json['monthlyRent'].toString()),
      advanceAmount: json['advanceAmount'] == null
          ? null
          : double.tryParse(json['advanceAmount'].toString()),
      maintenanceAmount: json['maintenanceAmount'] == null
          ? null
          : double.tryParse(json['maintenanceAmount'].toString()),
      moveInDate: json['moveInDate'] == null
          ? null
          : DateTime.tryParse(json['moveInDate'] as String),
      occupation: json['occupation'] as String?,
      familyMembers: (json['familyMembers'] as num?)?.toInt(),
      documentUrls: ((json['documentUrls'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.tryParse(json['archivedAt'] as String),
    );
  }
}
