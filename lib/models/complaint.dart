import 'package:flutter/material.dart';

/// The one list of complaint categories, shared by the resident's complaint
/// form and the maintenance staff's trades. Category == trade, so a complaint
/// routes to any staff whose trades include its category — no mapping needed.
const List<String> kComplaintCategories = [
  'Plumbing',
  'Electrical',
  'Elevator',
  'Cleaning',
  'Security',
  'Other',
];

enum ComplaintStatus {
  open,
  inProgress,
  resolved;

  String get label {
    switch (this) {
      case ComplaintStatus.open:
        return 'Open';
      case ComplaintStatus.inProgress:
        return 'In Progress';
      case ComplaintStatus.resolved:
        return 'Resolved';
    }
  }

  Color get color {
    switch (this) {
      case ComplaintStatus.open:
        return const Color(0xFFD32F2F);
      case ComplaintStatus.inProgress:
        return const Color(0xFFF57C00);
      case ComplaintStatus.resolved:
        return const Color(0xFF2E7D32);
    }
  }

  /// Backend enum value ("OPEN" / "IN_PROGRESS" / "RESOLVED").
  String get api {
    switch (this) {
      case ComplaintStatus.open:
        return 'OPEN';
      case ComplaintStatus.inProgress:
        return 'IN_PROGRESS';
      case ComplaintStatus.resolved:
        return 'RESOLVED';
    }
  }

  static ComplaintStatus fromApi(String value) {
    switch (value) {
      case 'IN_PROGRESS':
        return ComplaintStatus.inProgress;
      case 'RESOLVED':
        return ComplaintStatus.resolved;
      default:
        return ComplaintStatus.open;
    }
  }
}

class Complaint {
  Complaint({
    required this.id,
    required this.title,
    required this.description,
    required this.flatNumber,
    required this.category,
    required this.dateLabel,
    this.status = ComplaintStatus.open,
    this.assignedTo,
  });

  final String id;
  String title;
  String description;
  String flatNumber;
  String category;
  String dateLabel;
  ComplaintStatus status;
  String? assignedTo;

  factory Complaint.fromJson(Map<String, dynamic> json, String dateLabel) {
    return Complaint(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      flatNumber: (json['flat']?['number'] ?? '') as String,
      category: json['category'] as String,
      status: ComplaintStatus.fromApi(json['status'] as String),
      assignedTo: json['assignedTo'] as String?,
      dateLabel: dateLabel,
    );
  }
}
