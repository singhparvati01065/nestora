import 'package:flutter/material.dart';

import '../models/user_role.dart';
import 'maintenance/maintenance_staff_home.dart';
import 'resident/resident_home.dart';
import 'security_guard/security_guard_home.dart';
import 'society_admin/society_admin_home.dart';

/// The screen a signed-in person lands on. Used after sign-in and again on
/// launch, so a saved session goes straight to work instead of asking the
/// person who they are every single time.
Widget homeForRole(UserRole role) {
  switch (role) {
    case UserRole.societyAdmin:
      return const SocietyAdminHome();
    case UserRole.securityGuard:
      return const SecurityGuardHome();
    case UserRole.resident:
      return const ResidentHome();
    case UserRole.maintenanceStaff:
      return const MaintenanceStaffHome();
  }
}
