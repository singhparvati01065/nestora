import 'package:flutter/material.dart';

import '../../data/complaints_repository.dart';
import '../../models/user_role.dart';

/// The society's maintenance staff, for the admin — who's on the team and which
/// trades each of them covers. Read-only; staff add themselves at signup and
/// pick their trades in onboarding.
class MaintenanceStaffScreen extends StatefulWidget {
  const MaintenanceStaffScreen({super.key});

  @override
  State<MaintenanceStaffScreen> createState() => _MaintenanceStaffScreenState();
}

class _MaintenanceStaffScreenState extends State<MaintenanceStaffScreen> {
  final _repo = ComplaintsRepository.instance;

  Color get _accent => UserRole.societyAdmin.color;

  late Future<List<StaffMember>> _future = _repo.fetchStaff();

  Future<void> _reload() async {
    setState(() => _future = _repo.fetchStaff());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Staff'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: _accent,
        child: FutureBuilder<List<StaffMember>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _messageList("Couldn't load staff. Pull to retry.");
            }
            final staff = snap.data ?? const [];
            if (staff.isEmpty) {
              return _messageList(
                  'No maintenance staff yet.\nThey appear here once they '
                  'sign up for this society.');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: staff.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _StaffCard(
                  staff: staff[i], accent: _accent, theme: theme),
            );
          },
        ),
      ),
    );
  }

  /// A centered message that still allows pull-to-refresh.
  Widget _messageList(String text) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
        children: [
          Icon(Icons.engineering_outlined,
              size: 64, color: _accent.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

class _StaffCard extends StatelessWidget {
  const _StaffCard(
      {required this.staff, required this.accent, required this.theme});

  final StaffMember staff;
  final Color accent;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final initial =
        staff.name.trim().isEmpty ? '?' : staff.name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: accent.withValues(alpha: 0.14),
            child: Text(initial,
                style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (staff.trades.isEmpty)
                  Text('No trades selected yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in staff.trades)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(t,
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w600)),
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
