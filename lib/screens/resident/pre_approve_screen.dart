import 'package:flutter/material.dart';

import '../../data/pre_approved_repository.dart';
import '../../models/user_role.dart';
import '../loadable.dart';
import '../society_admin/admin_widgets.dart';

/// Lets a resident pre-approve expected visitors for [flat]. These show up in
/// the Security Guard's "Expected" tab.
class PreApproveScreen extends StatefulWidget {
  const PreApproveScreen({super.key, required this.flat});

  final String flat;

  @override
  State<PreApproveScreen> createState() => _PreApproveScreenState();
}

class _PreApproveScreenState extends State<PreApproveScreen>
    with LoadableState<PreApproveScreen> {
  final _repo = PreApprovedRepository.instance;

  Color get _accent => UserRole.resident.color;

  static const _purposes = ['Guest', 'Delivery', 'Cab', 'Service', 'Other'];
  static const _validity = [
    'Today, till 6 PM',
    'Today, till 8 PM',
    'Today, till 10 PM',
    'Tomorrow, all day',
    'This weekend',
  ];

  @override
  Future<void> load() async {
    await PreApprovedRepository.instance.load();
  }

  Future<void> _add() async {
    final nameController = TextEditingController();
    String purpose = _purposes.first;
    String validLabel = _validity.first;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  Text('Pre-approve Visitor',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('For Flat ${widget.flat} • the guard will see this',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Visitor name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: purpose,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Purpose'),
                    items: [
                      for (final p in _purposes)
                        DropdownMenuItem(value: p, child: Text(p)),
                    ],
                    onChanged: (v) =>
                        setModalState(() => purpose = v ?? purpose),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: validLabel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Valid for',
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    items: [
                      for (final v in _validity)
                        DropdownMenuItem(value: v, child: Text(v)),
                    ],
                    onChanged: (v) =>
                        setModalState(() => validLabel = v ?? validLabel),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Enter visitor name')),
                        );
                        return;
                      }
                      Navigator.of(context).pop(true);
                      runMutation(() => _repo.add(
                            name: nameController.text.trim(),
                            purpose: purpose,
                            validLabel: validLabel,
                          ));
                    },
                    child: const Text('Pre-approve'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // NOTE: nameController is intentionally not disposed here — disposing a
    // controller that a still-animating-out bottom sheet references crashes
    // (addListener on a disposed ChangeNotifier). It's GC'd once the route is
    // gone.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-approve Visitors'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Sibling tabs live in the same IndexedStack, so their FABs
        // coexist and would collide on the default hero tag.
        heroTag: 'resident-preapprove-fab',
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Approve'),
      ),
      body: buildLoad(() {
        final list = _repo.forFlat(widget.flat);
        return list.isEmpty
          ? const EmptyMessage(
              icon: Icons.verified_user_outlined,
              text: 'No pre-approved visitors.\nTap Approve to add one.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final p = list[index];
                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading: CircleAvatar(
                      backgroundColor: _accent.withValues(alpha: 0.12),
                      child: Text(p.initial,
                          style: TextStyle(
                              color: _accent, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${p.purpose} • ${p.validLabel}'),
                    trailing: p.checkedIn
                        ? _CheckedInChip(accent: _accent)
                        : null,
                  ),
                );
              },
            );
      }),
    );
  }
}

class _CheckedInChip extends StatelessWidget {
  const _CheckedInChip({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('Arrived',
          style: TextStyle(
              color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
