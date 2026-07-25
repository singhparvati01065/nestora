import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';

/// The authenticated user for the current session.
class AuthUser {
  AuthUser({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    this.photoUrl,
    this.societyId,
    this.flatId,
    this.staffLabel,
    this.trades = const [],
  });

  final String id;
  final String phone;
  final String name;
  final UserRole role;

  /// Stored path of the avatar (e.g. `/uploads/x.jpg`); null falls back to the
  /// name's initial. Resolve with [ApiClient.imageUrl] before loading.
  final String? photoUrl;

  final String? societyId;
  final String? flatId;
  final String? staffLabel;

  /// Complaint categories a maintenance staff handles. Empty for other roles.
  final List<String> trades;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['sub'] ?? json['id']).toString(),
      phone: json['phone'] as String,
      name: json['name'] as String,
      role: roleFromApi(json['role'] as String),
      photoUrl: json['photoUrl'] as String?,
      societyId: json['societyId'] as String?,
      flatId: json['flatId'] as String?,
      staffLabel: json['staffLabel'] as String?,
      trades: ((json['trades'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  /// Round-trips through [SharedPreferences]. Uses the enum's own name rather
  /// than the backend's SCREAMING_CASE so it stays readable and independent.
  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'role': role.name,
        'photoUrl': photoUrl,
        'societyId': societyId,
        'flatId': flatId,
        'staffLabel': staffLabel,
        'trades': trades,
      };

  factory AuthUser.fromStored(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String,
      role: UserRole.values.byName(json['role'] as String),
      photoUrl: json['photoUrl'] as String?,
      societyId: json['societyId'] as String?,
      flatId: json['flatId'] as String?,
      staffLabel: json['staffLabel'] as String?,
      trades: ((json['trades'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// Maps a backend Role enum string to the app's [UserRole].
/// SUPER_ADMIN has no dedicated home yet, so it routes to the admin experience.
UserRole roleFromApi(String role) {
  switch (role) {
    case 'SOCIETY_ADMIN':
    case 'SUPER_ADMIN':
      return UserRole.societyAdmin;
    case 'SECURITY_GUARD':
      return UserRole.securityGuard;
    case 'RESIDENT':
      return UserRole.resident;
    case 'MAINTENANCE_STAFF':
      return UserRole.maintenanceStaff;
    default:
      return UserRole.resident;
  }
}

/// Holds the current Nestora JWT + user for the app's lifetime, and persists
/// both so the session survives restarts.
///
/// The cached user is a convenience copy, not the source of truth: the backend
/// owns name and role, and re-issues them on every sign-in.
class Session {
  Session._();
  static final Session instance = Session._();

  static const _tokenKey = 'nestora_token';
  static const _userKey = 'nestora_user';

  String? token;
  AuthUser? user;

  bool get isLoggedIn => user != null;

  /// Reloads the saved profile into memory. Call once on startup, before any
  /// screen reads [user].
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
    final raw = prefs.getString(_userKey);
    if (raw == null) return;
    try {
      user = AuthUser.fromStored(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A stored profile from an older shape is not worth crashing over.
      await prefs.remove(_userKey);
    }
  }

  Future<void> save(String token, AuthUser user) async {
    this.token = token;
    this.user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
