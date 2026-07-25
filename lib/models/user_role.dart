import 'package:flutter/material.dart';

/// All roles a person can log in as from the public login flow.
///
/// Super admin is intentionally NOT here — it has a separate/hidden entry and
/// is not shown on the role-selection screen.
enum UserRole {
  societyAdmin,
  securityGuard,
  resident,
  maintenanceStaff;

  /// Human-friendly label shown in the UI.
  String get label {
    switch (this) {
      case UserRole.societyAdmin:
        return 'Society Admin';
      case UserRole.securityGuard:
        return 'Security Guard';
      case UserRole.resident:
        return 'Resident';
      case UserRole.maintenanceStaff:
        return 'Maintenance Staff';
    }
  }

  /// Short description shown under the label on the role picker.
  String get description {
    switch (this) {
      case UserRole.societyAdmin:
        return 'Manage your society, residents & bills';
      case UserRole.securityGuard:
        return 'Log visitors & gate entries';
      case UserRole.resident:
        return 'Pay dues, raise complaints, notices';
      case UserRole.maintenanceStaff:
        return 'View & resolve assigned tasks';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.societyAdmin:
        return Icons.admin_panel_settings_outlined;
      case UserRole.securityGuard:
        return Icons.security_outlined;
      case UserRole.resident:
        return Icons.home_outlined;
      case UserRole.maintenanceStaff:
        return Icons.build_outlined;
    }
  }

  Color get color {
    switch (this) {
      case UserRole.societyAdmin:
        return const Color(0xFF6C4AB6);
      case UserRole.securityGuard:
        return const Color(0xFF2E7D8A);
      case UserRole.resident:
        return const Color(0xFF2E7D32);
      case UserRole.maintenanceStaff:
        return const Color(0xFFB5651D);
    }
  }
}
