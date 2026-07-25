import 'package:flutter/material.dart';

import '../../../data/complaints_repository.dart';
import '../../../data/society_repository.dart';
import '../../../models/complaint.dart';
import '../../../models/user_role.dart';
import '../../loadable.dart';
import '../admin_widgets.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen>
    with LoadableState<ComplaintsScreen> {
  final _repo = ComplaintsRepository.instance;

  /// null = All, otherwise the selected status filter.
  ComplaintStatus? _filter;

  Color get _accent => UserRole.societyAdmin.color;

  static const _categories = kComplaintCategories;

  /// The society's real maintenance staff, for the assign dropdown. Loaded
  /// alongside complaints.
  List<StaffMember> _staff = [];

  @override
  Future<void> load() async {
    await _repo.load();
    _staff = await _repo.fetchStaff();
  }

  List<Complaint> get _visible {
    final all = _repo.all;
    if (_filter == null) return all;
    return all.where((c) => c.status == _filter).toList();
  }

  Future<void> _addComplaint() async {
    final society = SocietyRepository.instance.society;
    if (society == null) return;
    final flats = society.allFlats;

    final titleController = TextEditingController();
    final descController = TextEditingController();
    String? selectedFlat;
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
                  Text('New Complaint',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
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
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedFlat,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Flat',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                          items: [
                            for (final f in flats)
                              DropdownMenuItem(
                                  value: f.id, child: Text(f.number)),
                          ],
                          onChanged: (v) =>
                              setModalState(() => selectedFlat = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: [
                            for (final c in _categories)
                              DropdownMenuItem(value: c, child: Text(c)),
                          ],
                          onChanged: (v) =>
                              setModalState(() => category = v ?? category),
                        ),
                      ),
                    ],
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
                      if (selectedFlat == null ||
                          titleController.text.trim().isEmpty ||
                          descController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please fill all fields')),
                        );
                        return;
                      }
                      Navigator.of(context).pop(true);
                      runMutation(() => _repo.add(
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            flatId: selectedFlat!,
                            category: category,
                          ));
                    },
                    child: const Text('Submit Complaint'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Controllers not disposed here — see note in residents_screen.dart.
    if (added == true && mounted) setState(() {});
  }

  void _openComplaint(Complaint complaint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(complaint.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      _StatusChip(status: complaint.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Flat ${complaint.flatNumber} • ${complaint.category} • '
                    '${complaint.dateLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(complaint.description,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  Text('Status',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in ComplaintStatus.values)
                        ChoiceChip(
                          label: Text(s.label),
                          selected: complaint.status == s,
                          selectedColor: s.color.withValues(alpha: 0.18),
                          onSelected: (_) {
                            runMutation(() => _repo.updateStatus(complaint, s));
                            setModalState(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Assign to',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final names = _staff.map((s) => s.name).toSet();
                    // A complaint assigned to someone no longer in the staff
                    // list (a legacy label) still needs a matching item, or the
                    // dropdown asserts.
                    final assignee = complaint.assignedTo;
                    final legacy =
                        assignee != null && !names.contains(assignee);
                    return DropdownButtonFormField<String>(
                      initialValue: assignee,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.engineering_outlined),
                        hintText: 'Unassigned',
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Unassigned')),
                        for (final s in _staff)
                          DropdownMenuItem(
                            value: s.name,
                            // Show trades so the admin knows who covers what.
                            child: Text(s.trades.isEmpty
                                ? s.name
                                : '${s.name} · ${s.trades.join(", ")}'),
                          ),
                        if (legacy)
                          DropdownMenuItem(
                              value: assignee, child: Text('$assignee (former)')),
                      ],
                      onChanged: (v) {
                        runMutation(() => _repo.assign(complaint, v));
                        setModalState(() {});
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Sibling tabs live in the same IndexedStack, so their FABs
        // coexist and would collide on the default hero tag.
        heroTag: 'admin-complaints-fab',
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: _addComplaint,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: buildLoad(() {
        final visible = _visible;
        return Column(
        children: [
          // Filter chips.
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _filterChip('All', null),
                for (final s in ComplaintStatus.values)
                  _filterChip('${s.label} (${_repo.countByStatus(s)})', s),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const EmptyMessage(
                    icon: Icons.check_circle_outline,
                    text: 'Nothing here.\nNo complaints for this filter.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final c = visible[index];
                      return Material(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openComplaint(c),
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
                                    Icon(Icons.home_outlined,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text('Flat ${c.flatNumber} • ${c.category}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    if (c.assignedTo != null) ...[
                                      const SizedBox(width: 10),
                                      Icon(Icons.engineering_outlined,
                                          size: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(c.assignedTo!,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
      }),
    );
  }

  Widget _filterChip(String label, ComplaintStatus? status) {
    final selected = _filter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: _accent.withValues(alpha: 0.18),
        onSelected: (_) => setState(() => _filter = status),
      ),
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
