import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../data/staff_repository.dart';
import '../../models/staff.dart';
import '../../models/user_role.dart';

/// Full details for one staff member (guard / maintenance). Edit pops `'edit'`
/// so the list can open the edit sheet; Remove archives and pops `'removed'`.
class StaffDetailScreen extends StatefulWidget {
  const StaffDetailScreen({super.key, required this.staff});

  final Staff staff;

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  Color get _accent => UserRole.societyAdmin.color;
  bool _busy = false;

  Staff get s => widget.staff;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.error),
        title: const Text('Remove staff?'),
        content: Text(
            '${s.name} (${s.roleLabel}) will lose access and move to staff '
            'history. You can delete them for good from there.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await StaffRepository.instance.archive(s.id);
      if (mounted) Navigator.of(context).pop('removed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiClient.messageFor(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _busy ? null : () => Navigator.of(context).pop('edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: _accent.withValues(alpha: 0.14),
                child: Text(
                    s.name.trim().isEmpty ? '?' : s.name.trim()[0].toUpperCase(),
                    style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(s.roleLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: _accent, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: s.phone),
          if (s.address != null && s.address!.trim().isNotEmpty)
            _InfoRow(
                icon: Icons.home_outlined,
                label: 'Address',
                value: s.address!.trim()),
          if (s.joinedAt != null)
            _InfoRow(
                icon: Icons.event_outlined,
                label: 'Joined',
                value: _fmtDate(s.joinedAt!)),
          if (s.salary != null)
            _InfoRow(
                icon: Icons.payments_outlined,
                label: 'Salary',
                value: '₹${s.salary!.toStringAsFixed(0)} / month'),
          if (!s.isGuard && s.trades.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('TRADES',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in s.trades)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(t,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: _accent, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _busy ? null : _confirmRemove,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.5)),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Remove staff'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
