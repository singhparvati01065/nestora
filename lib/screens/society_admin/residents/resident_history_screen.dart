import 'package:flutter/material.dart';

import '../../../data/residents_repository.dart';
import '../../../models/resident.dart';
import '../../../models/user_role.dart';
import 'resident_detail_screen.dart';

/// Removed residents. They're kept here (soft-deleted) so their history stays,
/// and can be permanently deleted from this screen.
class ResidentHistoryScreen extends StatefulWidget {
  const ResidentHistoryScreen({super.key});

  @override
  State<ResidentHistoryScreen> createState() => _ResidentHistoryScreenState();
}

class _ResidentHistoryScreenState extends State<ResidentHistoryScreen> {
  final _repo = ResidentsRepository.instance;
  Color get _accent => UserRole.societyAdmin.color;

  late Future<List<Resident>> _future = _repo.fetchArchived();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  void _reload() => setState(() => _future = _repo.fetchArchived());

  String _removedOn(DateTime? d) {
    if (d == null) return 'Removed';
    final l = d.toLocal();
    return 'Removed ${l.day} ${_months[l.month - 1]} ${l.year}';
  }

  Future<void> _deleteForever(Resident r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_forever,
            color: Theme.of(context).colorScheme.error),
        title: const Text('Delete permanently?'),
        content: Text(
            '${r.name} and all their details will be deleted for good. This '
            "can't be undone."),
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
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.remove(r);
      messenger
          .showSnackBar(SnackBar(content: Text('${r.name} deleted')));
      _reload();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Delete failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resident History'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Resident>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history,
                        size: 64, color: _accent.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text('No removed residents yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = list[i];
              return Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        ResidentDetailScreen(resident: r, archived: true),
                  )),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Text(r.initial,
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(r.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Flat ${r.flatNumber} • ${_removedOn(r.archivedAt)}'),
                  trailing: IconButton(
                    tooltip: 'Delete permanently',
                    icon: Icon(Icons.delete_forever,
                        color: theme.colorScheme.error),
                    onPressed: () => _deleteForever(r),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
