import 'dart:io';
import '../push_notifications.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import 'content_screen.dart';
import '../api/auth_api.dart';
import '../api/session.dart';
import '../data/society_repository.dart';
import '../models/society.dart';
import '../models/user_role.dart';
import 'avatar_image.dart';
import 'picture_options_sheet.dart';
import 'user_profile_edit_screen.dart';

/// The account screen for a person (guard, resident, maintenance).
///
/// Shows who is signed in — their photo, name, phone, role and society — and
/// lets them change their photo and name and sign out. This is the counterpart
/// to the Society Admin's Profile tab, which is society-centric; here the person
/// is the subject, and it uses `User.photoUrl` rather than the society logo.
///
/// Reads everything from [Session] and [SocietyRepository], so it needs no
/// arguments and works for any role.
class UserProfileTab extends StatefulWidget {
  const UserProfileTab({super.key});

  @override
  State<UserProfileTab> createState() => _UserProfileTabState();
}

class _UserProfileTabState extends State<UserProfileTab> {
  final _picker = ImagePicker();
  bool _busy = false;

  AuthUser? get _user => Session.instance.user;
  Color get _accent => (_user?.role ?? UserRole.resident).color;

  /// Camera badge → choose a source, or drop the photo. Applied immediately;
  /// there is no Save button on a profile tab.
  Future<void> _changePhoto() async {
    final action = await showPictureOptions(
      context,
      accent: _accent,
      canRemove: _user?.photoUrl != null,
    );
    if (action == null || !mounted) return;

    String? url;
    if (action != PictureAction.remove) {
      final picked = await _picker.pickImage(
        source: action == PictureAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _busy = true);
      try {
        url = await ApiClient.instance.uploadImage(File(picked.path));
      } catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(ApiClient.messageFor(e));
        return;
      }
    } else {
      setState(() => _busy = true);
    }

    try {
      // A null url here is an explicit "clear it", not "leave it alone".
      await AuthApi.instance.updateMe(photoUrl: url);
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(ApiClient.messageFor(e));
    }
  }

  /// Opens the full editor (photo + name) and refreshes on return.
  Future<void> _editProfile() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const UserProfileEditScreen()),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need your number to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Before the session goes: unregistering needs the token it carries.
    await PushNotifications.instance.unregister();
    await Session.instance.clear();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Closes the account for good. Play requires this to be reachable from
  /// inside the app; the wording spells out what survives (the society's own
  /// records) so nobody expects their flat's bill history to vanish too.
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'Your name, photo and number are removed and you will be signed out '
          'everywhere. Your society keeps its own records — bills, complaints '
          'and gate entries — without your details on them.\n\n'
          'This cannot be undone. To use the app again, your society admin has '
          'to add your number back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      // Same order as signing out: the device token goes while it is still
      // usable, then the account, then the session.
      await PushNotifications.instance.unregister();
      await AuthApi.instance.deleteAccount();
      await Session.instance.clear();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(ApiClient.messageFor(e));
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Nestora',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(Icons.apartment_rounded, color: _accent, size: 36),
      children: const [Text('Your society, simplified.')],
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final society = SocietyRepository.instance.society;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ProfileHeader(
            name: user?.name ?? 'Member',
            phone: user?.phone ?? '',
            photoUrl: user?.photoUrl,
            roleLabel: user?.role.label ?? '',
            society: society?.name,
            accent: _accent,
            busy: _busy,
            onChangePhoto: _busy ? null : _changePhoto,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (user?.role == UserRole.maintenanceStaff) ...[
                  const _SectionLabel('Work you handle'),
                  const SizedBox(height: 10),
                  // Display only — editing happens through Edit profile below.
                  _TradesCard(
                    trades: user?.trades ?? const [],
                    accent: _accent,
                  ),
                  const SizedBox(height: 26),
                ],
                // Residents, guards and staff cannot edit the society, but they
                // should be able to see where it is — the address only lived on
                // the society admin's screens until now.
                if (society != null) ...[
                  const _SectionLabel('Your society'),
                  const SizedBox(height: 10),
                  _SocietyCard(society: society, accent: _accent),
                  const SizedBox(height: 26),
                ],
                const _SectionLabel('Help & Legal'),
                const SizedBox(height: 10),
                for (final c in kContentPages)
                  _ProfileRow(
                    label: c.title,
                    subtitle: c.subtitle,
                    icon: c.icon,
                    accent: _accent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ContentScreen(
                          contentKey: c.key,
                          title: c.title,
                          accent: _accent,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const _SectionLabel('Account'),
                const SizedBox(height: 10),
                _ProfileRow(
                  label: 'Edit profile',
                  subtitle: user?.role == UserRole.maintenanceStaff
                      ? 'Your photo, name and work'
                      : 'Your photo and name',
                  icon: Icons.badge_outlined,
                  accent: _accent,
                  onTap: _busy ? null : _editProfile,
                ),
                _ProfileRow(
                  label: 'About Nestora',
                  subtitle: 'Version and licences',
                  icon: Icons.info_outline,
                  accent: _accent,
                  onTap: _showAbout,
                ),
                _ProfileRow(
                  label: 'Log out',
                  subtitle: 'Sign out of this device',
                  icon: Icons.logout,
                  accent: _accent,
                  danger: true,
                  onTap: _logout,
                ),
                _ProfileRow(
                  label: 'Delete account',
                  subtitle: 'Remove your details for good',
                  icon: Icons.person_remove_outlined,
                  accent: _accent,
                  danger: true,
                  onTap: _busy ? null : _deleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The maintenance staff's trades as chips — the categories they receive.
/// Display only; editing is through Edit profile.
class _TradesCard extends StatelessWidget {
  const _TradesCard({required this.trades, required this.accent});

  final List<String> trades;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: trades.isEmpty
          ? Text(
              'No work set yet — add it in Edit profile.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in trades)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Where the society is: its logo, name and full address. Read-only — only the
/// society admin can change any of it, from Profile → Society details.
class _SocietyCard extends StatelessWidget {
  const _SocietyCard({required this.society, required this.accent});

  final Society society;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = society.fullAddress.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarImage(
            path: society.logoUrl,
            name: society.name,
            size: 44,
            background: accent.withValues(alpha: 0.10),
            foreground: accent,
            fallbackIcon: Icons.apartment_rounded,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  society.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        address.isEmpty ? 'No address added yet' : address,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// The banner: the person's photo, name, number and role. Sits flush under the
/// app bar in the same accent.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.phone,
    required this.photoUrl,
    required this.roleLabel,
    required this.society,
    required this.accent,
    required this.busy,
    required this.onChangePhoto,
  });

  final String name;
  final String phone;
  final String? photoUrl;
  final String roleLabel;
  final String? society;
  final Color accent;
  final bool busy;

  /// Null while an upload is in flight.
  final VoidCallback? onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // "Security Guard • Green Valley" — drops the dot when there is no society.
    final chip = society == null ? roleLabel : '$roleLabel • $society';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent, Color.lerp(accent, Colors.black, 0.22)!],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              AvatarImage(
                path: photoUrl,
                name: name,
                size: 88,
                background: Colors.white.withValues(alpha: 0.18),
                foreground: Colors.white,
                borderColor: Colors.white.withValues(alpha: 0.5),
                borderWidth: 2,
                fallbackIcon: Icons.person,
              ),
              if (busy)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onChangePhoto,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 16,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              phone,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  chip,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the account list.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  /// Tints the row red — used for logging out.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = danger ? theme.colorScheme.error : accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: tint, size: 21),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: danger ? tint : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
