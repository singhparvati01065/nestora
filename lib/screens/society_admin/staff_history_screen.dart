import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../../models/staff.dart';
import '../../models/user_role.dart';
import '../../api/api_client.dart';

/// Removed (archived) staff — where a guard / maintenance worker lands after the
/// admin removes them. From here they can be permanently deleted.
class StaffHistoryScreen extends StatefulWidget {
  const StaffHistoryScreen({super.key});

  @override
  State<StaffHistoryScreen> createState() => _StaffHistoryScreenState();
}

class _StaffHistoryScreenState extends State<StaffHistoryScreen> {
  final _repo = StaffRepository.instance;
  Color get _accent => UserRole.societyAdmin.color;

  late Future<List<Staff>> _future = _repo.fetchArchived();
  bool _busy = false;

  Future<void> _reload() async {
    setState(() => _future = _repo.fetchArchived());
    await _future;
  }

  Future<void> _confirmDelete(Staff staff) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_forever,
            color: Theme.of(context).colorScheme.error),
        title: const Text('Delete permanently?'),
        content: Text(
            '${staff.name} (${staff.roleLabel}) will be deleted for good. This '
            'cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _repo.remove(staff.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.messageFor(e))),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Removed Staff'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: _accent,
        child: FutureBuilder<List<Staff>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final staff = snap.data ?? const [];
            if (staff.isEmpty) {
              return ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
                children: [
                  Icon(Icons.history,
                      size: 64, color: _accent.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No removed staff.\nRemoved guards and maintenance show '
                      'up here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: staff.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final s = staff[i];
                final initial = s.name.trim().isEmpty
                    ? '?'
                    : s.name.trim()[0].toUpperCase();
                return Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.14),
                          child: Text(initial,
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${s.roleLabel} • ${s.phone}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete permanently',
                          icon: const Icon(Icons.delete_forever, size: 20),
                          color: Colors.red,
                          onPressed: _busy ? null : () => _confirmDelete(s),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
