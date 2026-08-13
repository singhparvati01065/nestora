import 'dart:io';
import '../../push_notifications.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_client.dart';
import '../../api/session.dart';
import '../../data/notifications_repository.dart';
import '../../data/society_repository.dart';
import '../../feature_flags.dart';
import '../../models/society.dart';
import '../../models/user_role.dart';
import '../avatar_image.dart';
import '../loadable.dart';
import '../picture_options_sheet.dart';
import 'bills/bills_screen.dart';
import 'complaints/complaints_screen.dart';
import '../content_screen.dart';
import 'amenities_admin_screen.dart';
import 'announcements_screen.dart';
import 'staff_screen.dart';
import 'support_screen.dart';
import 'notices/notices_screen.dart';
import 'notifications/notifications_screen.dart';
import 'residents/residents_screen.dart';
import 'society_details_screen.dart';
import 'society_setup_screen.dart';
import 'tower_detail_screen.dart';

/// Shell for the Society Admin: a bottom nav over the overview and the four
/// management sections.
///
/// The sections are full screens with their own app bars and FABs, so they are
/// hosted as-is. An [IndexedStack] keeps each one alive, so switching tabs does
/// not refetch or lose scroll position.
class SocietyAdminHome extends StatefulWidget {
  const SocietyAdminHome({super.key});

  @override
  State<SocietyAdminHome> createState() => _SocietyAdminHomeState();
}

class _SocietyAdminHomeState extends State<SocietyAdminHome> {
  int _index = 0;

  /// Lets the More tab refresh the overview after a structure edit, since the
  /// two are siblings in the stack rather than parent and child.
  final _overviewKey = GlobalKey<_OverviewTabState>();

  Color get _accent => UserRole.societyAdmin.color;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _OverviewTab(key: _overviewKey),
          const ResidentsScreen(),
          // Bills and Complaints are platform modules the super admin can
          // switch off; the destinations below follow the same conditions so
          // the indices stay aligned.
          if (FeatureFlags.instance.payments) const BillsScreen(),
          if (FeatureFlags.instance.complaints) const ComplaintsScreen(),
          _MoreTab(
            onStructureChanged: () => _overviewKey.currentState?.refresh(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: _accent.withValues(alpha: 0.16),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Residents',
          ),
          if (FeatureFlags.instance.payments)
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Bills',
            ),
          if (FeatureFlags.instance.complaints)
            const NavigationDestination(
              icon: Icon(Icons.report_problem_outlined),
              selectedIcon: Icon(Icons.report_problem),
              label: 'Complaints',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// The admin's profile: the society they run — its picture and name — plus the
/// actions that belong to neither a list nor a tab.
class _MoreTab extends StatefulWidget {
  const _MoreTab({required this.onStructureChanged});

  /// The overview is a sibling in the stack, so editing here has to tell it to
  /// reload rather than returning a result to it.
  final VoidCallback onStructureChanged;

  @override
  State<_MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<_MoreTab> {
  final _picker = ImagePicker();
  bool _busy = false;

  Color get _accent => UserRole.societyAdmin.color;

  /// Changes the society picture from the camera badge.
  ///
  /// This is the same `Society.logoUrl` that the Society details screen edits
  /// and the home header shows — one picture, three places, so changing it
  /// anywhere changes it everywhere. Unlike Society details, there is no Save
  /// button here, so each choice is applied immediately.
  Future<void> _changePicture() async {
    final hasPicture = SocietyRepository.instance.society?.logoUrl != null;
    final action = await showPictureOptions(
      context,
      accent: _accent,
      canRemove: hasPicture,
    );
    if (action == null || !mounted) return;

    String? url;
    if (action != PictureAction.remove) {
      final picked = await _picker.pickImage(
        source: action == PictureAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        // Shown at ~88px; anything larger is wasted bytes.
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
      await SocietyRepository.instance.updateProfile(logoUrl: url);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onStructureChanged(); // the home header shows it too
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(ApiClient.messageFor(e));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSocietyDetails() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SocietyDetailsScreen()),
    );
    if (changed == true) {
      widget.onStructureChanged(); // the overview shows name/address/logo too
      if (mounted) setState(() {});
    }
  }

  Future<void> _openStructure() async {
    final society = SocietyRepository.instance.society;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SocietySetupScreen(existing: society)),
    );
    if (saved == true) widget.onStructureChanged();
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

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Nestora',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(Icons.apartment_rounded, color: _accent, size: 36),
      children: const [Text('Your society, simplified.')],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.instance.user;
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
            // The society is the headline — an admin's profile is really the
            // society they run, so its name and picture lead.
            title: society?.name ?? 'No society yet',
            phone: user?.phone ?? '',
            userName: user?.name ?? 'Admin',
            pictureUrl: society?.logoUrl,
            accent: _accent,
            busy: _busy,
            // No society yet means nothing to attach a picture to.
            onChangePicture: (_busy || society == null) ? null : _changePicture,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel('Society'),
                const SizedBox(height: 10),
                // Notices has its own tab — no second door to it from here.
                _MoreRow(
                  label: 'Society details',
                  subtitle: 'Name and address',
                  icon: Icons.apartment_outlined,
                  accent: _accent,
                  onTap: _openSocietyDetails,
                ),
                _MoreRow(
                  label: 'Edit structure',
                  subtitle: 'Towers, floors and flats',
                  icon: Icons.tune,
                  accent: _accent,
                  onTap: _openStructure,
                ),
                _MoreRow(
                  label: 'Staff',
                  subtitle: 'Guards & maintenance — add and manage logins',
                  icon: Icons.groups_outlined,
                  accent: _accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StaffScreen()),
                  ),
                ),
                if (FeatureFlags.instance.amenities)
                  _MoreRow(
                    label: 'Amenities',
                    subtitle: 'Manage amenities & approve bookings',
                    icon: Icons.deck_outlined,
                    accent: _accent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AmenitiesAdminScreen(),
                      ),
                    ),
                  ),
                _MoreRow(
                  label: 'Announcements',
                  subtitle: 'Updates from Nestora',
                  icon: Icons.campaign_outlined,
                  accent: _accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AnnouncementsScreen(),
                    ),
                  ),
                ),
                _MoreRow(
                  label: 'Support',
                  subtitle: 'Raise a ticket & track its status',
                  icon: Icons.support_agent_outlined,
                  accent: _accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  ),
                ),
                const SizedBox(height: 26),
                const _SectionLabel('Help & Legal'),
                const SizedBox(height: 10),
                for (final c in kContentPages)
                  _MoreRow(
                    label: c.title,
                    subtitle: c.subtitle,
                    icon: Icons.article_outlined,
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
                const SizedBox(height: 26),
                const _SectionLabel('Account'),
                const SizedBox(height: 10),
                _MoreRow(
                  label: 'About Nestora',
                  subtitle: 'Version and licences',
                  icon: Icons.info_outline,
                  accent: _accent,
                  onTap: _showAbout,
                ),
                _MoreRow(
                  label: 'Log out',
                  subtitle: 'Sign out of this device',
                  icon: Icons.logout,
                  accent: _accent,
                  danger: true,
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The profile banner: the society's picture and name, and the admin's number.
/// Sits flush under the app bar in the same accent, so the two read as one
/// block.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.title,
    required this.phone,
    required this.userName,
    required this.pictureUrl,
    required this.accent,
    required this.busy,
    required this.onChangePicture,
  });

  /// The headline — the society's name.
  final String title;

  final String phone;

  /// Named in the role chip below the picture.
  final String userName;

  /// `Society.logoUrl` — the same picture the home header and Society details
  /// show.
  final String? pictureUrl;

  final Color accent;
  final bool busy;

  /// Null while an upload is in flight, or when there is no society yet.
  final VoidCallback? onChangePicture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                path: pictureUrl,
                name: title,
                size: 88,
                background: Colors.white.withValues(alpha: 0.18),
                foreground: Colors.white,
                borderColor: Colors.white.withValues(alpha: 0.5),
                borderWidth: 2,
                fallbackIcon: Icons.apartment_rounded,
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
              // Camera badge, so the photo reads as changeable rather than
              // decorative.
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onChangePicture,
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
            title,
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
                  'Admin • $userName',
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

/// One row in the More list.
class _MoreRow extends StatelessWidget {
  const _MoreRow({
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
  final VoidCallback onTap;

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

/// The overview tab: society header, stats and towers.
class _OverviewTab extends StatefulWidget {
  const _OverviewTab({super.key});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab>
    with LoadableState<_OverviewTab> {
  final _repo = SocietyRepository.instance;
  final _notifs = NotificationsRepository.instance;

  Color get _accent => UserRole.societyAdmin.color;

  @override
  void initState() {
    super.initState();
    // Keep the bell badge live as notifications come and go.
    _notifs.addListener(_onNotifsChanged);
  }

  @override
  void dispose() {
    _notifs.removeListener(_onNotifsChanged);
    super.dispose();
  }

  void _onNotifsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Future<void> load() async {
    await _repo.load();
    // Best-effort — a notifications hiccup shouldn't block the home.
    try {
      await _notifs.load();
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (mounted) setState(() {});
  }

  /// Opens the structure form. Passing the current society switches it to edit
  /// mode, which diffs towers/flats instead of creating a second society.
  Future<void> _openSetup({Society? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SocietySetupScreen(existing: existing)),
    );
    if (saved == true) refresh();
  }

  Future<void> _openNotices() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NoticesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Edit structure and Logout live in the More tab; the structure form is
      // also reachable from the contextual button beside the TOWERS heading.
      appBar: AppBar(
        title: const Text('Society Admin'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: _notifs.unread > 0,
              label: Text('${_notifs.unread}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: _openNotifications,
          ),
          IconButton(
            tooltip: 'Notices',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: _openNotices,
          ),
        ],
      ),
      body: SafeArea(
        child: buildLoad(() {
          final society = _repo.society;
          return society == null
              ? _EmptyState(accent: _accent, onSetup: _openSetup)
              : _SocietyOverview(
                  society: society,
                  accent: _accent,
                  onEdit: () => _openSetup(existing: society),
                );
        }),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.accent, required this.onSetup});

  final Color accent;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_rounded, size: 72, color: accent),
            const SizedBox(height: 16),
            Text(
              'No society set up yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your society details, towers and flats to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onSetup,
              style: FilledButton.styleFrom(backgroundColor: accent),
              icon: const Icon(Icons.add),
              label: const Text('Set Up Society'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocietyOverview extends StatelessWidget {
  const _SocietyOverview({
    required this.society,
    required this.accent,
    required this.onEdit,
  });

  final Society society;
  final Color accent;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SocietyHeader(society: society, accent: accent),
        const SizedBox(height: 12),
        _StatsBar(society: society, accent: accent),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: _SectionLabel(society.hasTowers ? 'Towers' : 'Building'),
            ),
            TextButton.icon(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Edit structure'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final tower in society.towers)
          _TowerTile(
            tower: tower,
            accent: accent,
            hasTowers: society.hasTowers,
          ),
      ],
    );
  }
}

/// Small uppercase heading that separates the page into scannable blocks.
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

class _SocietyHeader extends StatelessWidget {
  const _SocietyHeader({required this.society, required this.accent});

  final Society society;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, Color.lerp(accent, Colors.black, 0.28)!],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarImage(
            path: society.logoUrl,
            name: society.name,
            size: 52,
            radius: 14,
            background: Colors.white.withValues(alpha: 0.18),
            foreground: Colors.white,
            borderColor: Colors.white.withValues(alpha: 0.35),
            borderWidth: 1,
            fallbackIcon: Icons.apartment_rounded,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  society.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        society.address,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
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

/// The three headline numbers, as one card split by dividers rather than three
/// floating tiles — reads as a single summary instead of scattered chips.
class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.society, required this.accent});

  final Society society;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (society.hasTowers) ...[
              _Stat(
                label: 'Towers',
                value: '${society.numberOfTowers}',
                accent: accent,
              ),
              _StatDivider(color: theme.colorScheme.outlineVariant),
            ],
            _Stat(label: 'Floors', value: society.floorsLabel, accent: accent),
            _StatDivider(color: theme.colorScheme.outlineVariant),
            _Stat(
              label: 'Flats',
              value: '${society.totalFlats}',
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => VerticalDivider(
    width: 1,
    thickness: 1,
    indent: 14,
    endIndent: 14,
    color: color,
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TowerTile extends StatelessWidget {
  const _TowerTile({
    required this.tower,
    required this.accent,
    required this.hasTowers,
  });

  final Tower tower;
  final Color accent;

  /// A tower-less society shows the one building without a letter badge.
  final bool hasTowers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TowerDetailScreen(tower: tower)),
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: hasTowers
                        ? Text(
                            tower.letter,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : Icon(
                            Icons.apartment_rounded,
                            color: accent,
                            size: 21,
                          ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tower.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _Chip(
                              text: '${tower.floors} floors',
                              icon: Icons.stairs_outlined,
                            ),
                            const SizedBox(width: 6),
                            _Chip(
                              text: '${tower.flats.length} flats',
                              icon: Icons.meeting_room_outlined,
                            ),
                          ],
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

/// Tiny neutral fact pill used under a tower's name.
class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
