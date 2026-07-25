import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_api.dart';
import '../../api/session.dart';
import '../../data/complaints_repository.dart';
import '../../models/complaint.dart';
import '../../models/user_role.dart';
import '../society_admin/admin_widgets.dart';
import '../user_profile_tab.dart';

/// Home for Maintenance Staff — the tasks (complaints) assigned to them, plus a
/// pool of unassigned tasks in their trades that they can pick up. First login
/// with no trades set shows the [_TradeSetup] onboarding.
class MaintenanceStaffHome extends StatefulWidget {
  const MaintenanceStaffHome({super.key});

  @override
  State<MaintenanceStaffHome> createState() => _MaintenanceStaffHomeState();
}

class _MaintenanceStaffHomeState extends State<MaintenanceStaffHome> {
  final _repo = ComplaintsRepository.instance;

  int _index = 0;
  bool _loading = true;

  Color get _accent => UserRole.maintenanceStaff.color;

  /// This staff member is the logged-in account — no more switcher.
  String get _staff => Session.instance.user?.name ?? 'Staff';

  /// The categories they handle; the Available pool is filtered to these.
  List<String> get _myTrades => Session.instance.user?.trades ?? const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _repo.load();
    } catch (_) {
      // Leave the list empty on failure; a pull-to-refresh could retry.
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Runs a mutation, surfaces errors, and refreshes.
  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.messageFor(e))),
        );
      }
    }
  }


  /// Opens a task's detail sheet: description + status controls. For an
  /// unassigned task, an "Accept" button assigns it to this staff member.
  void _openTask(Complaint c, {required bool mine}) {
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
                        child: Text(c.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      _StatusChip(status: c.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Flat ${c.flatNumber} • ${c.category} • ${c.dateLabel}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Text(c.description,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  if (mine) ...[
                    Text('Update status',
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
                            selected: c.status == s,
                            selectedColor: s.color.withValues(alpha: 0.18),
                            onSelected: (_) {
                              Navigator.of(context).pop();
                              _mutate(() => _repo.updateStatus(c, s));
                            },
                          ),
                      ],
                    ),
                  ] else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _accent),
                      icon: const Icon(Icons.assignment_turned_in_outlined),
                      label: Text('Accept as $_staff'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _mutate(() async {
                          await _repo.assign(c, _staff);
                          await _repo.updateStatus(
                              c, ComplaintStatus.inProgress);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Task accepted')),
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

  /// First-run: a maintenance account with no trades yet picks them here,
  /// before the task console is usable.
  Future<void> _saveTrades(Set<String> trades) async {
    setState(() => _savingTrades = true);
    try {
      await AuthApi.instance.updateMe(trades: trades.toList());
      if (mounted) setState(() => _savingTrades = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingTrades = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiClient.messageFor(e))));
    }
  }

  bool _savingTrades = false;

  @override
  Widget build(BuildContext context) {
    // No trades yet → onboarding, not the task console.
    if (!_loading && _myTrades.isEmpty) {
      return _TradeSetup(
        accent: _accent,
        name: _staff,
        saving: _savingTrades,
        onSave: _saveTrades,
      );
    }

    final mine = _repo.assignedTo(_staff);
    // My Tasks holds only live work; finished ones move to their own tab.
    final myActive =
        mine.where((c) => c.status != ComplaintStatus.resolved).toList();
    final myResolved =
        mine.where((c) => c.status == ComplaintStatus.resolved).toList();
    // Only complaints in this staff's trades — the trade-based routing.
    final available = _repo.availableFor(_myTrades);

    // The Profile tab is a full screen with its own app bar, so the task
    // console's app bar steps aside for it.
    const profileIndex = 3;
    final onProfile = _index == profileIndex;

    return Scaffold(
      appBar: onProfile
          ? null
          : AppBar(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              title: Text(_staff),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: _accent.withValues(alpha: 0.16),
        destinations: [
          NavigationDestination(
            // Badges count the tabs that need action — active work and the
            // unassigned pool. Resolved is history, so it carries no badge.
            icon: Badge.count(
              count: myActive.length,
              isLabelVisible: myActive.isNotEmpty,
              child: const Icon(Icons.assignment_ind_outlined),
            ),
            selectedIcon: Badge.count(
              count: myActive.length,
              isLabelVisible: myActive.isNotEmpty,
              child: const Icon(Icons.assignment_ind),
            ),
            label: 'My Tasks',
          ),
          const NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Resolved',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: available.length,
              isLabelVisible: available.isNotEmpty,
              child: const Icon(Icons.assignment_outlined),
            ),
            selectedIcon: Badge.count(
              count: available.length,
              isLabelVisible: available.isNotEmpty,
              child: const Icon(Icons.assignment),
            ),
            label: 'Available',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : onProfile
              ? const UserProfileTab()
              : IndexedStack(
                  index: _index,
                  children: [
                    _TaskList(
                      tasks: myActive,
                      accent: _accent,
                      emptyText:
                          'No active tasks.\nCheck the Available tab.',
                      onTap: (c) => _openTask(c, mine: true),
                    ),
                    _TaskList(
                      tasks: myResolved,
                      accent: _accent,
                      emptyText: "Nothing you've resolved yet.",
                      onTap: (c) => _openTask(c, mine: true),
                    ),
                    _TaskList(
                      tasks: available,
                      accent: _accent,
                      emptyText: _myTrades.isEmpty
                          ? 'No trades set on your account yet.\n'
                              'Add them in Profile to receive complaints.'
                          : 'No open complaints in your trades right now.',
                      onTap: (c) => _openTask(c, mine: false),
                    ),
                  ],
                ),
    );
  }

}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.accent,
    required this.emptyText,
    required this.onTap,
  });

  final List<Complaint> tasks;
  final Color accent;
  final String emptyText;
  final void Function(Complaint) onTap;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return EmptyMessage(icon: Icons.task_alt_outlined, text: emptyText);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final c = tasks[index];
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onTap(c),
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
                                fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                      _StatusChip(status: c.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(c.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.home_outlined,
                          size: 14,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('Flat ${c.flatNumber} • ${c.category}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

/// First-run onboarding for a maintenance account with no trades yet.
/// Picking the work they handle is what makes complaints start routing to them.
class _TradeSetup extends StatefulWidget {
  const _TradeSetup({
    required this.accent,
    required this.name,
    required this.saving,
    required this.onSave,
  });

  final Color accent;
  final String name;
  final bool saving;
  final Future<void> Function(Set<String> trades) onSave;

  @override
  State<_TradeSetup> createState() => _TradeSetupState();
}

class _TradeSetupState extends State<_TradeSetup> {
  final Set<String> _trades = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.accent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Set up your work'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.engineering_outlined,
                  color: widget.accent, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Hi ${widget.name} 👋',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'What work do you handle? Complaints in these categories will '
              'come to you.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in kComplaintCategories)
                  FilterChip(
                    label: Text(c),
                    selected: _trades.contains(c),
                    selectedColor: widget.accent.withValues(alpha: 0.18),
                    checkmarkColor: widget.accent,
                    onSelected: (on) => setState(
                        () => on ? _trades.add(c) : _trades.remove(c)),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: (widget.saving || _trades.isEmpty)
                  ? null
                  : () => widget.onSave(_trades),
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: widget.saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
