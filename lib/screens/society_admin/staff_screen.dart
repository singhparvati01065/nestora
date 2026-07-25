import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/staff_repository.dart';
import '../../models/complaint.dart';
import '../../models/staff.dart';
import '../../models/user_role.dart';
import '../loadable.dart';
import 'staff_detail_screen.dart';
import 'staff_history_screen.dart';

/// Admin screen to manage the society's staff logins: security guards and
/// maintenance workers. Adding one creates their account, after which they sign
/// in with their number — staff never self-register.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> with LoadableState<StaffScreen> {
  final _repo = StaffRepository.instance;
  Color get _accent => UserRole.societyAdmin.color;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Future<void> load() => _repo.load();

  Future<void> _staffSheet({Staff? existing}) async {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final addressController =
        TextEditingController(text: existing?.address ?? '');
    final salaryController = TextEditingController(
        text: existing?.salary != null
            ? existing!.salary!.toStringAsFixed(0)
            : '');
    String role = existing?.role ?? 'SECURITY_GUARD';
    DateTime joinedAt = existing?.joinedAt ?? DateTime.now();
    final trades = <String>{...?existing?.trades};
    String fmtDate(DateTime d) =>
        '${d.day} ${_months[d.month - 1]} ${d.year}';

    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isEdit ? 'Edit staff' : 'Add staff',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    isEdit
                        ? 'Update this staff member\'s details.'
                        : 'They log in with this number — no signup needed.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                // Role is chosen only when adding; it can't be switched on edit.
                if (!isEdit)
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'SECURITY_GUARD',
                          label: Text('Guard'),
                          icon: Icon(Icons.shield_outlined)),
                      ButtonSegment(
                          value: 'MAINTENANCE_STAFF',
                          label: Text('Maintenance'),
                          icon: Icon(Icons.engineering_outlined)),
                    ],
                    selected: {role},
                    onSelectionChanged: (s) => setSheet(() => role = s.first),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  textCapitalization: TextCapitalization.words,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: joinedAt,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now(),
                      helpText: 'Joining date',
                    );
                    if (picked != null) setSheet(() => joinedAt = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Joining date',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(fmtDate(joinedAt)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: salaryController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Salary (optional)',
                    hintText: 'Monthly salary',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                if (role == 'MAINTENANCE_STAFF') ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Trades',
                        style: Theme.of(context).textTheme.labelLarge),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final t in kComplaintCategories)
                        FilterChip(
                          label: Text(t),
                          selected: trades.contains(t),
                          selectedColor: _accent.withValues(alpha: 0.18),
                          onSelected: (on) => setSheet(() =>
                              on ? trades.add(t) : trades.remove(t)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();
                    if (name.isEmpty) {
                      _snack('Enter a name');
                      return;
                    }
                    if (phone.length < 10) {
                      _snack('Enter a valid mobile number');
                      return;
                    }
                    final address = addressController.text.trim();
                    final salary =
                        double.tryParse(salaryController.text.trim());
                    final tradeList =
                        role == 'MAINTENANCE_STAFF' ? trades.toList() : null;
                    Navigator.of(context).pop(true);
                    runMutation(() => isEdit
                        ? _repo.update(
                            existing.id,
                            name: name,
                            phone: phone,
                            address: address.isEmpty ? null : address,
                            joinedAt: joinedAt,
                            salary: salary,
                            trades: tradeList,
                          )
                        : _repo.create(
                            role: role,
                            name: name,
                            phone: phone,
                            address: address.isEmpty ? null : address,
                            joinedAt: joinedAt,
                            salary: salary,
                            trades: tradeList,
                          ));
                  },
                  child: Text(isEdit ? 'Save' : 'Add staff'),
                ),
              ],
            ),
          );
        });
      },
    );
    if (done == true && mounted) setState(() {});
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDetail(Staff staff) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => StaffDetailScreen(staff: staff)),
    );
    if (!mounted) return;
    if (result == 'edit') {
      _staffSheet(existing: staff);
    } else if (result == 'removed') {
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Removed staff',
            icon: const Icon(Icons.person_off_outlined),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const StaffHistoryScreen(),
              ));
              refresh();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: () => _staffSheet(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add staff'),
      ),
      body: buildLoad(() {
        final guards = _repo.guards;
        final maintenance = _repo.maintenance;
        if (guards.isEmpty && maintenance.isEmpty) {
          return _empty();
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _section('Security Guards', Icons.shield_outlined, guards),
            if (maintenance.isNotEmpty) const SizedBox(height: 20),
            _section(
                'Maintenance Staff', Icons.engineering_outlined, maintenance),
          ],
        );
      }),
    );
  }

  Widget _empty() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined,
                size: 64, color: _accent.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No staff yet.\nAdd a guard or maintenance worker so they can '
                'log in.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Staff> staff) {
    if (staff.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: _accent),
            const SizedBox(width: 8),
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        for (final s in staff) ...[
          _StaffCard(staff: s, accent: _accent, onTap: () => _openDetail(s)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard(
      {required this.staff, required this.accent, required this.onTap});

  final Staff staff;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial =
        staff.name.trim().isEmpty ? '?' : staff.name.trim()[0].toUpperCase();
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.14),
                child: Text(initial,
                    style:
                        TextStyle(color: accent, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staff.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(staff.phone,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
