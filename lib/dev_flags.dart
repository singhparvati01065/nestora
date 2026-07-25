import 'package:flutter/foundation.dart';

/// ⚠️ TEMPORARY SCAFFOLDING — remove once Firebase phone auth is enabled.
///
/// Skips the real OTP: "Send OTP" goes straight to the verify screen without
/// texting anything, and the verify screen signs in through the backend's
/// `/auth/dev-login` (which trusts the phone number outright) instead of
/// checking a code. This keeps a REAL backend JWT and the role from Postgres,
/// so the rest of the app behaves normally while it is being built.
///
/// `kDebugMode` is a hard floor: even if this is left as `true`, a release
/// build cannot take the bypass.
///
/// To go back to real OTP: set this to `false`, enable the Phone provider and
/// the +91 SMS region in the Firebase console, then delete this file, the
/// `/auth/dev-login` route, and `DEV_LOGIN_ENABLED` from `backend/.env`.
const bool kBypassOtp = kDebugMode && true;

/// The seeded demo accounts. They have no Firebase entry, so they keep using the
/// dev-login bypass while any other (real / Firebase test) number goes through
/// actual phone OTP. Keep in sync with the backend seed + `_demoPhone` in the
/// login screen.
const Set<String> kDemoPhones = {
  '9876543210', // society admin
  '9876500001', // security guard
  '9876500002', // resident
  '9876500003', // maintenance staff
};

/// Whether a sign-in for [phone] should skip real OTP and use `/auth/dev-login`.
/// Only the seeded demo numbers bypass, and only when [kBypassOtp] is on.
bool bypassOtpFor(String phone) =>
    kBypassOtp && kDemoPhones.contains(phone.trim());

/// The universal local OTP code used in dev while real Firebase phone auth is
/// off. Any non-demo number signs in through the local OTP screen with this
/// code, then `/auth/dev-login` — which still refuses a number that has no
/// account. So an admin-registered resident can log in with their number + this
/// code, without needing a real Firebase test number set up for each one.
const String kDevOtpCode = '123456';

/// The expected local OTP code for [phone], or null when the number should take
/// another path: real Firebase (release), or the instant demo bypass.
String? testOtpFor(String phone) {
  if (!kBypassOtp) return null;
  final p = phone.trim();
  // Blank + seeded demo numbers use the instant bypass instead of an OTP code.
  if (p.isEmpty || kDemoPhones.contains(p)) return null;
  return kDevOtpCode;
}
