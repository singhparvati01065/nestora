import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../data/complaints_repository.dart';
import '../../../data/society_repository.dart';
import '../../../models/complaint.dart';
import '../../../models/user_role.dart';
import '../../../push_notifications.dart';
import '../../loadable.dart';
import '../../complaint_card.dart';
import '../admin_widgets.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen>
    with LoadableState<ComplaintsScreen>, WidgetsBindingObserver {
  final _repo = ComplaintsRepository.instance;

  // Staff resolve tasks and residents raise them while this list sits open, so
  // it reloads on a push and when the app comes back to the front — same rule
  // as the bills screen.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushNotifications.instance.refreshSignal.addListener(quietRefresh);
  }

  @override
  void dispose() {
    PushNotifications.instance.refreshSignal.removeListener(quietRefresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) quietRefresh();
  }

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
                  Text(
                    'New Complaint',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                                value: f.id,
                                child: Text(f.number),
                              ),
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
                            content: Text('Please fill all fields'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).pop(true);
                      runMutation(
                        () => _repo.add(
                          title: titleController.text.trim(),
                          description: descController.text.trim(),
                          flatId: selectedFlat!,
                          category: category,
                        ),
                      );
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
    // The repository replaces its complaints on every reload, so the object
    // handed in goes stale the moment anything is written. [current] is
    // re-read from the cache after each save to keep the sheet honest.
    var current = complaint;
    // Picking a chip or an assignee only marks the choice — nothing is written
    // until Save, so a mis-tap can't move a complaint to Resolved or hand it to
    // the wrong person behind the admin's back. Both edits go through the one
    // Save button, which stays live as long as either differs from what is
    // stored.
    var pendingStatus = current.status;
    var pendingAssignee = current.assignedTo;
    // A snackbar would surface behind the sheet, so a failed save is reported
    // inline instead — otherwise a write that never landed looks like a
    // successful one.
    String? sheetError;
    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            /// Writes, then closes the sheet. A failure keeps it open with the
            /// reason shown inline and the controls snapped back to what the
            /// server actually holds — so a save that never landed can't read
            /// as a successful one.
            Future<void> save(Future<void> Function() action) async {
              setModalState(() {
                saving = true;
                sheetError = null;
              });
              try {
                await action();
                current = _repo.all.firstWhere(
                  (c) => c.id == current.id,
                  orElse: () => current,
                );
                pendingStatus = current.status;
                pendingAssignee = current.assignedTo;
                // Keep the list behind the sheet in step.
                if (mounted) setState(() {});
                if (context.mounted) Navigator.of(context).pop();
                return;
              } catch (e) {
                sheetError = ApiClient.messageFor(e);
              }
              if (context.mounted) setModalState(() => saving = false);
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          current.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ComplaintStatusChip(status: current.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Flat ${current.flatNumber} • ${current.category} • '
                    '${current.dateLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    current.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Status',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // With nobody on it there is no work in progress and nothing
                  // to have resolved it, so an unassigned complaint can only
                  // sit in Open.
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in ComplaintStatus.values)
                        ChoiceChip(
                          label: Text(s.label),
                          selected: pendingStatus == s,
                          selectedColor: s.color.withValues(alpha: 0.18),
                          onSelected:
                              saving ||
                                  (pendingAssignee == null &&
                                      s != ComplaintStatus.open)
                              ? null
                              : (_) => setModalState(() => pendingStatus = s),
                        ),
                    ],
                  ),
                  if (pendingAssignee == null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Assign someone to move this past Open.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Assign to',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final names = _staff.map((s) => s.name).toSet();
                      // A complaint assigned to someone no longer in the staff
                      // list (a legacy label) still needs a matching item, or the
                      // dropdown asserts.
                      final assignee = pendingAssignee;
                      final legacy =
                          assignee != null && !names.contains(assignee);
                      return DropdownButtonFormField<String>(
                        // Driven by the pending choice, which is reset to the
                        // stored value after every save — so a failed write makes
                        // the dropdown spring back rather than show an assignment
                        // that never happened.
                        initialValue: assignee,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.engineering_outlined),
                          hintText: 'Unassigned',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          for (final s in _staff)
                            DropdownMenuItem(
                              value: s.name,
                              // Show trades so the admin knows who covers what.
                              child: Text(
                                s.trades.isEmpty
                                    ? s.name
                                    : '${s.name} · ${s.trades.join(", ")}',
                              ),
                            ),
                          if (legacy)
                            DropdownMenuItem(
                              value: assignee,
                              child: Text('$assignee (former)'),
                            ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => setModalState(() {
                                pendingAssignee = v;
                                // Nobody is on it any more, so it drops back
                                // into the open pool — which is also what puts
                                // it back in the staff's Available tab. Still
                                // only pending: the admin can override the
                                // status before saving.
                                if (v == null) {
                                  pendingStatus = ComplaintStatus.open;
                                }
                              }),
                      );
                    },
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      sheetError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Builder(
                    builder: (context) {
                      final statusChanged = pendingStatus != current.status;
                      final assigneeChanged =
                          pendingAssignee != current.assignedTo;
                      return FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        // Nothing to write until something actually differs.
                        // Status and assignee are committed together, in one tap.
                        onPressed: saving || !(statusChanged || assigneeChanged)
                            ? null
                            : () => save(() async {
                                if (assigneeChanged) {
                                  await _repo.assign(current, pendingAssignee);
                                }
                                if (statusChanged) {
                                  await _repo.updateStatus(
                                    current,
                                    pendingStatus,
                                  );
                                }
                              }),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Save changes'),
                      );
                    },
                  ),
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
                      text: 'Nothing here.\nNo complaints for this filter.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final c = visible[index];
                        // The admin's queue spans every flat and every staff
                        // member, so both are worth showing.
                        return ComplaintCard(
                          complaint: c,
                          onTap: () => _openComplaint(c),
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
