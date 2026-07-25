import 'package:flutter/material.dart';

import '../api/firebase_auth_service.dart';
import '../dev_flags.dart';
import '../models/user_role.dart';
import 'otp_verify_screen.dart';
import 'signup_screen.dart';

/// Login form shown after a role is chosen on [RoleSelectionScreen].
///
/// Sends a Firebase OTP to the number; [OtpVerifyScreen] completes the sign-in.
/// The saved profile's role (not the picked card) decides which home is shown.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Demo account per role — used when the number is left blank so login can
  /// go straight through.
  static String _demoPhone(UserRole role) {
    switch (role) {
      case UserRole.societyAdmin:
        return '9876543210';
      case UserRole.securityGuard:
        return '9876500001';
      case UserRole.resident:
        return '9876500002';
      case UserRole.maintenanceStaff:
        return '9876500003';
    }
  }

  Future<void> _login() async {
    final typed = _phoneController.text.trim();
    // Only the society admin has the blank-login demo shortcut; everyone else
    // must enter the number their admin registered for them.
    if (typed.isEmpty && widget.role != UserRole.societyAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your number to log in')),
      );
      return;
    }
    final phone = typed.isEmpty ? _demoPhone(widget.role) : typed;

    // No name is passed either way: the verify screen treats this as a login,
    // so the backend's stored role decides the home, not the picked card.

    // Seeded demo numbers (and blank) skip OTP entirely.
    if (bypassOtpFor(phone)) {
      _openVerify(phone, verificationId: 'dev-bypass', bypass: true);
      return;
    }
    // A configured local test number shows the OTP screen and checks the code
    // locally (no Firebase) — used while real phone auth isn't set up.
    final testCode = testOtpFor(phone);
    if (testCode != null) {
      _openVerify(phone,
          verificationId: 'local-test', bypass: false, localCode: testCode);
      return;
    }

    setState(() => _loading = true);
    await FirebaseAuthService.instance.sendOtp(
      phone: phone,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() => _loading = false);
        _openVerify(phone,
            verificationId: verificationId,
            resendToken: resendToken,
            bypass: false);
      },
      onFailed: (message) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  void _openVerify(String phone,
      {required String verificationId,
      int? resendToken,
      required bool bypass,
      String? localCode}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerifyScreen(
          phone: phone,
          verificationId: verificationId,
          role: widget.role,
          resendToken: resendToken,
          bypass: bypass,
          localCode: localCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = widget.role;
    return Scaffold(
      appBar: AppBar(title: Text('${role.label} Login')),
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
                  child: Icon(role.icon, color: role.color, size: 32),
                ),
                const SizedBox(height: 20),
                Text('Sign in as ${role.label}',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                    widget.role == UserRole.societyAdmin
                        ? 'Enter your number to get an OTP, or tap Login for the '
                            'demo account'
                        : 'Log in with the number your society admin registered '
                            'for you.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  style: FilledButton.styleFrom(backgroundColor: role.color),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Login'),
                ),
                const SizedBox(height: 8),
                // Only society admins create their own account; residents and
                // staff are added by their admin, then just log in.
                if (role == UserRole.societyAdmin)
                  Center(
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SignupScreen(role: role),
                                ),
                              ),
                      child: const Text("New here? Create an account"),
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
