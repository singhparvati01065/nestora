import 'dart:async';

import 'package:flutter/material.dart';

import '../api/auth_api.dart';
import '../api/firebase_auth_service.dart';
import '../api/session.dart';
import '../dev_flags.dart';
import '../models/user_role.dart';
import 'maintenance/maintenance_staff_home.dart';
import 'resident/resident_home.dart';
import 'security_guard/security_guard_home.dart';
import 'society_admin/society_admin_home.dart';

/// Collects the SMS code and completes sign-in.
///
/// Reached from both login and signup. [name] is non-null only on the signup
/// path — on login the saved profile supplies it.
class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.phone,
    required this.verificationId,
    required this.role,
    this.name,
    this.trades,
    this.resendToken,
    this.bypass = kBypassOtp,
    this.localCode,
  });

  final String phone;
  final String verificationId;
  final UserRole role;
  final String? name;

  /// Maintenance trades chosen at signup; null for other roles/logins.
  final List<String>? trades;

  final int? resendToken;

  /// Skip the real OTP and sign in via `/auth/dev-login`. Decided per-login by
  /// the caller (demo numbers bypass, a real number goes through Firebase), so
  /// it can differ from the global [kBypassOtp] default.
  final bool bypass;

  /// A local test code (from `kTestOtps`): the OTP field is shown and the entered
  /// code is checked against this, then sign-in goes through `/auth/dev-login`.
  /// Non-null means "test login, no Firebase". Null → normal Firebase/bypass.
  final String? localCode;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _loading = false;

  /// Updated when a resend hands back a fresh id/token.
  late String _verificationId = widget.verificationId;
  int? _resendToken;

  Timer? _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _resendToken = widget.resendToken;
    // No resend button in bypass or local-test mode, so no ticker for it either.
    if (!widget.bypass && widget.localCode == null) _startResendCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    // The bypass has no code to validate against, so skip the form check too.
    if (!widget.bypass && !_formKey.currentState!.validate()) return;
    // A local test code is checked here, without hitting Firebase.
    if (widget.localCode != null &&
        _codeController.text.trim() != widget.localCode) {
      _snack('Wrong code. Try again.');
      return;
    }
    setState(() => _loading = true);
    try {
      // Only signup proposes a role (and only a society admin may self-register).
      // Every login — Firebase, bypass, or local test — proposes nothing: an
      // existing account's stored role wins, and an unknown number is refused.
      final proposedRole = widget.name != null ? widget.role : null;
      final proposedTrades = widget.name != null ? widget.trades : null;
      final user = (widget.bypass || widget.localCode != null)
          ? await AuthApi.instance.devLogin(
              phone: widget.phone,
              name: widget.name,
              role: proposedRole,
              trades: proposedTrades,
            )
          : await FirebaseAuthService.instance.verifyOtp(
              verificationId: _verificationId,
              smsCode: _codeController.text.trim(),
              name: widget.name,
              role: proposedRole,
              trades: proposedTrades,
            );
      if (!mounted) return;
      _goHome(user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(FirebaseAuthService.messageFor(e));
    }
  }

  Future<void> _resend() async {
    setState(() => _loading = true);
    await FirebaseAuthService.instance.sendOtp(
      phone: widget.phone,
      resendToken: _resendToken,
      onCodeSent: (id, token) {
        if (!mounted) return;
        setState(() {
          _verificationId = id;
          _resendToken = token;
          _loading = false;
        });
        _startResendCountdown();
        _snack('A new code has been sent.');
      },
      onFailed: (message) {
        if (!mounted) return;
        setState(() => _loading = false);
        _snack(message);
      },
    );
  }

  void _goHome(AuthUser user) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => _homeForRole(user.role)),
      (route) => route.isFirst,
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _homeForRole(UserRole role) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = widget.role;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your number')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: role.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.sms_outlined, color: role.color, size: 32),
                ),
                const SizedBox(height: 20),
                Text(widget.bypass ? 'Skip verification' : 'Enter the code',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                    widget.bypass
                        ? 'No code was sent — OTP is bypassed for development.'
                        : widget.localCode != null
                            ? 'Test login — enter your test code to continue.'
                            : 'We sent a 6-digit code to ${toE164(widget.phone)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                if (widget.bypass) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_outlined,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Dev bypass: signing in as ${toE164(widget.phone)} '
                            'without verifying anything.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                if (!widget.bypass)
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '6-digit code',
                      prefixIcon: Icon(Icons.lock_outline),
                      counterText: '',
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Enter the code';
                      if (s.length != 6) return 'The code is 6 digits';
                      return null;
                    },
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _verify,
                  style: FilledButton.styleFrom(backgroundColor: role.color),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(widget.bypass ? 'Continue' : 'Verify & continue'),
                ),
                const SizedBox(height: 8),
                // Nothing was sent (bypass / local test), so nothing to resend.
                if (!widget.bypass && widget.localCode == null)
                  Center(
                    child: TextButton(
                      onPressed:
                          (_loading || _secondsLeft > 0) ? null : _resend,
                      child: Text(_secondsLeft > 0
                          ? 'Resend code in ${_secondsLeft}s'
                          : 'Resend code'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
