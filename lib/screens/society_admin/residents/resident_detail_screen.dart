import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../data/residents_repository.dart';
import '../../../models/resident.dart';
import '../../../models/user_role.dart';
import 'add_resident_screen.dart';

/// A full screen showing everything on file for a resident, with the option to
/// remove them. Pops `true` after a removal so the list can refresh.
class ResidentDetailScreen extends StatefulWidget {
  const ResidentDetailScreen({
    super.key,
    required this.resident,
    this.archived = false,
  });

  final Resident resident;

  /// True when opened from history — the action becomes a permanent delete.
  final bool archived;

  @override
  State<ResidentDetailScreen> createState() => _ResidentDetailScreenState();
}

class _ResidentDetailScreenState extends State<ResidentDetailScreen> {
  Color get _accent => UserRole.societyAdmin.color;
  bool _removing = false;

  Resident get r => widget.resident;

  String _money(double v) => '₹${v.toStringAsFixed(0)}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddResidentScreen(existing: r)),
    );
    // The resident's data changed; pop back so the list reloads and shows it.
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _remove() async {
    setState(() => _removing = true);
    try {
      if (widget.archived) {
        await ResidentsRepository.instance.remove(r);
      } else {
        await ResidentsRepository.instance.archive(r);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _removing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.messageFor(e))),
      );
    }
  }

  Future<void> _confirmRemove() async {
    final archived = widget.archived;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(archived ? Icons.delete_forever : Icons.delete_outline,
            color: Theme.of(context).colorScheme.error),
        title: Text(archived ? 'Delete permanently?' : 'Remove resident?'),
        content: Text(archived
            ? '${r.name} and all their details will be deleted for good. '
                "This can't be undone."
            : '${r.name} moves to Resident History — you can view or '
                'permanently delete them there.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(archived ? 'Delete' : 'Remove'),
          ),
        ],
      ),
    );
    if (ok == true) _remove();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resident'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        actions: widget.archived
            ? null
            : [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _edit,
                ),
              ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Header.
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: _accent.withValues(alpha: 0.12),
                child: Text(r.initial,
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
                    Text(r.name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Flat ${r.flatNumber}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              _TypeChip(type: r.type),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          _row(Icons.phone_outlined, r.phone, 'Phone'),
          if (r.moveInDate != null)
            _row(Icons.event_outlined, _fmtDate(r.moveInDate!.toLocal()),
                'Move-in date'),
          if (r.monthlyRent != null)
            _row(Icons.home_outlined, _money(r.monthlyRent!), 'Rent'),
          if (r.advanceAmount != null)
            _row(Icons.savings_outlined, _money(r.advanceAmount!),
                'Advance / deposit'),
          if (r.maintenanceAmount != null)
            _row(Icons.handyman_outlined, _money(r.maintenanceAmount!),
                'Maintenance'),
          if (r.occupation != null && r.occupation!.isNotEmpty)
            _row(Icons.work_outline, r.occupation!, 'Occupation'),
          if (r.familyMembers != null)
            _row(Icons.groups_outlined, '${r.familyMembers}',
                'Family members'),
          if (r.documentUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _label('Documents', theme),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.documentUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final url = ApiClient.imageUrl(r.documentUrls[i]);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: url == null
                        ? const SizedBox(width: 110)
                        : Image.network(url,
                            width: 110, height: 110, fit: BoxFit.cover),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 28),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: _removing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(widget.archived
                    ? Icons.delete_forever
                    : Icons.delete_outline),
            label: Text(widget.archived
                ? 'Delete permanently'
                : 'Remove resident'),
            onPressed: _removing ? null : _confirmRemove,
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String title, String subtitle) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: _accent),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(subtitle),
      );

  Widget _label(String text, ThemeData theme) => Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final ResidentType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(type.label,
          style: TextStyle(color: type.color, fontWeight: FontWeight.w600)),
    );
  }
}
