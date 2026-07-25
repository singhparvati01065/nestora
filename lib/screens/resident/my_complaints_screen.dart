import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../data/complaints_repository.dart';
import '../../models/complaint.dart';
import '../../models/user_role.dart';
import '../loadable.dart';
import '../society_admin/admin_widgets.dart';

/// A resident's own complaints for [flat] — view and raise new ones.
class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key, required this.flat});

  final String flat;

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen>
    with LoadableState<MyComplaintsScreen> {
  final _repo = ComplaintsRepository.instance;

  Color get _accent => UserRole.resident.color;

  // Shared with maintenance trades — see [kComplaintCategories].
  static const _categories = kComplaintCategories;

  @override
  Future<void> load() => _repo.load();

  Future<void> _raise() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String category = _categories.first;

    final added = await showModalBottomSheet<bool>(
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
                  Text('Raise Complaint',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('For Flat ${widget.flat}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final c in _categories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) =>
                        setModalState(() => category = v ?? category),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    onPressed: () {
                      if (titleController.text.trim().isEmpty ||
                          descController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Enter title and description')),
                        );
                        return;
                      }
                      Navigator.of(context).pop(true);
                      runMutation(() => _repo.add(
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            flatId: Session.instance.user!.flatId!,
                            category: category,
                          ));
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Controllers not disposed here — see note in pre_approve_screen.dart.
    if (added == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Complaints'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Sibling tabs live in the same IndexedStack, so their FABs
        // coexist and would collide on the default hero tag.
        heroTag: 'resident-complaints-fab',
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: _raise,
        icon: const Icon(Icons.add),
        label: const Text('Raise'),
      ),
      body: buildLoad(() {
        final complaints = _repo.forFlat(widget.flat);
        return complaints.isEmpty
          ? const EmptyMessage(
              icon: Icons.check_circle_outline,
              text: 'No complaints.\nTap Raise to report an issue.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: complaints.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final c = complaints[index];
                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(c.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ),
                            _StatusChip(status: c.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(c.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('${c.category} • ${c.dateLabel}',
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                            if (c.assignedTo != null) ...[
                              const Spacer(),
                              Icon(Icons.engineering_outlined,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(c.assignedTo!,
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
      }),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(
              color: status.color,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}
