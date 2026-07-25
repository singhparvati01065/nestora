import 'package:flutter/material.dart';

import '../api/firebase_auth_service.dart';
import '../dev_flags.dart';
import '../models/user_role.dart';
import 'otp_verify_screen.dart';

/// Account creation for a chosen [role]. Sends a Firebase OTP to the number and
/// hands the name + role to [OtpVerifyScreen], which completes the sign-in.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// A short line telling the user what happens after signing up for this role.
  String get _roleHint {
    switch (widget.role) {
      case UserRole.societyAdmin:
        return "You'll set up your society right after signing up.";
      case UserRole.securityGuard:
      case UserRole.resident:
      case UserRole.maintenanceStaff:
        return 'Your society admin links your account to a flat/society.';
    }
  }

  /// Sends the OTP, then hands the pending name + role to the verify screen.
  /// The account only exists in Firebase once the code is confirmed there.
  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();
    final bypass = bypassOtpFor(phone);

    if (bypass) {
      _openVerify(phone, verificationId: 'dev-bypass', bypass: true);
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
      required bool bypass}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerifyScreen(
          phone: phone,
          verificationId: verificationId,
          role: widget.role,
          name: _nameController.text.trim(),
          resendToken: resendToken,
          bypass: bypass,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = widget.role;
    return Scaffold(
      appBar: AppBar(title: Text('${role.label} Sign up')),
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
                Text('Create your account',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_roleHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Enter mobile number';
                    if (s.length < 10) return 'Enter a valid mobile number';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _signup,
                  style: FilledButton.styleFrom(backgroundColor: role.color),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send OTP'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Already have an account? Log in'),
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
