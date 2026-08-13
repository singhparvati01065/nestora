import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../data/bills_repository.dart';
import '../../data/complaints_repository.dart';
import '../../data/notices_repository.dart';
import '../../data/society_repository.dart';
import '../../feature_flags.dart';
import '../../models/user_role.dart';
import '../loadable.dart';
import '../user_profile_tab.dart';
import 'amenities_screen.dart';
import 'my_bills_history_screen.dart';
import 'my_bills_screen.dart';
import 'my_complaints_screen.dart';
import 'pre_approve_screen.dart';
import 'resident_notices_screen.dart';

/// Home for a Resident, scoped to their own flat (from the logged-in account).
class ResidentHome extends StatefulWidget {
  const ResidentHome({super.key});

  @override
  State<ResidentHome> createState() => _ResidentHomeState();
}

class _ResidentHomeState extends State<ResidentHome>
    with LoadableState<ResidentHome> {
  String? _flat; // the resident's flat number, resolved from the society
  int _index = 0;

  Color get _accent => UserRole.resident.color;

  /// Bills are a platform feature the super admin can switch off; when it is
  /// off the Dues and History tabs are not built at all.
  bool get _payments => FeatureFlags.instance.payments;

  @override
  Future<void> load() async {
    final flatId = Session.instance.user?.flatId;
    await SocietyRepository.instance.load();
    final society = SocietyRepository.instance.society;
    _flat = null;
    if (society != null && flatId != null) {
      for (final f in society.allFlats) {
        if (f.id == flatId) {
          _flat = f.number;
          break;
        }
      }
    }
    // A module switched off in the super-admin panel refuses its routes, so
    // don't ask for data this session cannot use.
    if (FeatureFlags.instance.payments) {
      await BillsRepository.instance.load(flatId: flatId);
    }
    if (FeatureFlags.instance.complaints) {
      await ComplaintsRepository.instance.load();
    }
    await NoticesRepository.instance.load();
  }

  Future<void> _openThen(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    refresh(); // reload summary counts on return
  }

  @override
  Widget build(BuildContext context) {
    final flat = _flat;
    return Scaffold(
      // Only the home tab needs this bar; the other tabs are full screens that
      // bring their own.
      appBar: _index == 0
          ? AppBar(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              title: Text(flat != null ? 'Flat $flat' : 'Resident'),
              actions: [
                if (flat != null)
                  IconButton(
                    tooltip: 'Notices',
                    icon: const Icon(Icons.campaign_outlined),
                    onPressed: () => _openThen(const ResidentNoticesScreen()),
                  ),
              ],
            )
          : null,
      body: buildLoad(_buildTabs),
      // Every other tab needs a flat to show, so without one there is nothing
      // to navigate to.
      bottomNavigationBar: flat == null
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              indicatorColor: _accent.withValues(alpha: 0.16),
              // Dues and History are the payments module; they come and go
              // together with its flag, in step with [_buildTabs].
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                if (_payments) ...[
                  const NavigationDestination(
                    icon: Icon(Icons.payments_outlined),
                    selectedIcon: Icon(Icons.payments),
                    label: 'Dues',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history),
                    label: 'History',
                  ),
                ],
                const NavigationDestination(
                  icon: Icon(Icons.account_circle_outlined),
                  selectedIcon: Icon(Icons.account_circle),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }

  Widget _buildTabs() {
    final flat = _flat;
    if (flat == null) return _buildBody();
    return IndexedStack(
      index: _index,
      children: [
        _buildBody(),
        if (_payments) ...[
          MyBillsScreen(flat: flat),
          MyBillsHistoryScreen(
            flat: flat,
            onBack: () => setState(() => _index = 0),
          ),
        ],
        const UserProfileTab(),
      ],
    );
  }

  Widget _buildBody() {
    final society = SocietyRepository.instance.society;
    final flat = _flat;
    if (flat == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Your society is not set up yet, or no flat is linked to your '
            'account. Ask your Society Admin.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final name = Session.instance.user?.name.split(' ').first ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text(
          name.isEmpty ? 'Welcome home 👋' : 'Welcome home, $name 👋',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Flat $flat • ${society?.name ?? ''}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        _SectionLabel('Quick actions', accent: _accent),
        const SizedBox(height: 10),
        // Each action belongs to a module the super admin can switch off.
        if (FeatureFlags.instance.complaints)
          _ActionTile(
            label: 'Raise a complaint',
            subtitle: 'Report an issue in your flat',
            icon: Icons.report_problem_outlined,
            accent: _accent,
            onTap: () => _openThen(MyComplaintsScreen(flat: flat)),
          ),
        if (FeatureFlags.instance.visitors)
          _ActionTile(
            label: 'Pre-approve a visitor',
            subtitle: 'Let the gate expect your guest',
            icon: Icons.person_add_alt_outlined,
            accent: _accent,
            onTap: () => _openThen(PreApproveScreen(flat: flat)),
          ),
        if (FeatureFlags.instance.amenities)
          _ActionTile(
            label: 'Book an amenity',
            subtitle: 'Clubhouse, gym, pool and more',
            icon: Icons.event_available_outlined,
            accent: _accent,
            onTap: () => _openThen(AmenitiesScreen(flat: flat)),
          ),
      ],
    );
  }
}

/// Small section heading used on the resident home.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.accent});

  final String text;
  final Color accent;

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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

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
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: accent, size: 21),
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
