import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../data/deliveries_repository.dart';
import '../../data/pre_approved_repository.dart';
import '../../data/society_repository.dart';
import '../../data/visitors_repository.dart';
import '../../models/pre_approved_visitor.dart';
import '../../models/society.dart';
import '../../models/user_role.dart';
import '../society_admin/admin_widgets.dart';
import '../user_profile_tab.dart';

/// Home for the Security Guard — the gate console.
class SecurityGuardHome extends StatefulWidget {
  const SecurityGuardHome({super.key});

  @override
  State<SecurityGuardHome> createState() => _SecurityGuardHomeState();
}

class _SecurityGuardHomeState extends State<SecurityGuardHome> {
  final _visitors = VisitorsRepository.instance;
  final _deliveries = DeliveriesRepository.instance;
  final _preApproved = PreApprovedRepository.instance;

  int _index = 0;
  bool _loading = true;

  /// Visitors tab filter set by tapping a stat card: 'all' | 'inside' | 'today'.
  String _visitorFilter = 'all';

  Color get _accent => UserRole.securityGuard.color;

  static const _purposes = ['Guest', 'Delivery', 'Cab', 'Service', 'Other'];

  static const _couriers = [
    'Amazon',
    'Flipkart',
    'Swiggy',
    'Zomato',
    'Blue Dart',
    'Delhivery',
    'DTDC',
    'India Post',
    'Meesho',
    'BigBasket',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await SocietyRepository.instance.load();
      await _visitors.load();
      await _preApproved.load();
      await _deliveries.load();
    } catch (_) {
      // Leave lists empty on failure.
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

  Future<void> _newVisitor({PreApprovedVisitor? from}) async {
    final flats = SocietyRepository.instance.society?.allFlats ?? const <Flat>[];
    final nameController = TextEditingController(text: from?.name ?? '');
    final phoneController = TextEditingController();
    final flatController = TextEditingController(text: from?.flatNumber ?? '');
    final vehicleController = TextEditingController();
    // Pre-select the flat (by id) only if it exists in the society's flats.
    String? selectedFlat;
    if (from != null) {
      for (final f in flats) {
        if (f.number == from.flatNumber) {
          selectedFlat = f.id;
          break;
        }
      }
    }
    String purpose = from?.purpose ?? _purposes.first;
    if (!_purposes.contains(purpose)) purpose = _purposes.first;

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
                  Text('New Visitor Entry',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
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
                  Row(
                    children: [
                      Expanded(
                        // Flat dropdown when the society is configured, else text.
                        child: flats.isNotEmpty
                            ? DropdownButtonFormField<String>(
                                initialValue: selectedFlat,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Visiting flat',
                                  prefixIcon: Icon(Icons.home_outlined),
                                ),
                                items: [
                                  for (final f in flats)
                                    DropdownMenuItem(
                                        value: f.id, child: Text(f.number)),
                                ],
                                onChanged: (v) =>
                                    setModalState(() => selectedFlat = v),
                              )
                            : TextField(
                                controller: flatController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Visiting flat',
                                  prefixIcon: Icon(Icons.home_outlined),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: purpose,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Purpose'),
                          items: [
                            for (final p in _purposes)
                              DropdownMenuItem(value: p, child: Text(p)),
                          ],
                          onChanged: (v) =>
                              setModalState(() => purpose = v ?? purpose),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: vehicleController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle no. (optional)',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    icon: const Icon(Icons.login),
                    label: const Text('Check In'),
                    onPressed: () {
                      final name = nameController.text.trim();
                      final flatId = flats.isNotEmpty ? selectedFlat : null;
                      if (name.isEmpty ||
                          (flats.isNotEmpty && flatId == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Enter name and select flat')),
                        );
                        return;
                      }
                      Navigator.of(context).pop(true);
                      _mutate(() async {
                        if (from != null) {
                          // Backend creates the Visitor and marks it checked-in.
                          await _preApproved.markCheckedIn(from);
                          await _visitors.load();
                        } else {
                          await _visitors.add(
                            name: name,
                            phone: phoneController.text.trim(),
                            flatId: flatId,
                            purpose: purpose,
                            vehicleNo:
                                vehicleController.text.trim().isEmpty
                                    ? null
                                    : vehicleController.text
                                        .trim()
                                        .toUpperCase(),
                          );
                        }
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Controllers not disposed here — disposing while the sheet animates out
    // crashes (addListener on a disposed ChangeNotifier); GC'd with the route.
    if (added == true && mounted) setState(() {});
  }

  Future<void> _newDelivery() async {
    final flats = SocietyRepository.instance.society?.allFlats ?? const <Flat>[];
    final otherCourierController = TextEditingController();
    String courier = _couriers.first;
    String? selectedFlat;

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
                  Text('Log Delivery',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: courier,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Courier / company',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                    items: [
                      for (final c in _couriers)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) =>
                        setModalState(() => courier = v ?? courier),
                  ),
                  // Custom name field only when "Other" is picked.
                  if (courier == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: otherCourierController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Courier name',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedFlat,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'For flat',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                    items: [
                      for (final f in flats)
                        DropdownMenuItem(value: f.id, child: Text(f.number)),
                    ],
                    onChanged: (v) => setModalState(() => selectedFlat = v),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    onPressed: () {
                      final courierName = courier == 'Other'
                          ? otherCourierController.text.trim()
                          : courier;
                      final flatId = selectedFlat;
                      if (courierName.isEmpty || flatId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Select courier and flat')),
                        );
                        return;
                      }
                      Navigator.of(context).pop(true);
                      _mutate(() => _deliveries.add(
                          courier: courierName, flatId: flatId));
                    },
                    child: const Text('Add Parcel'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Controllers not disposed here — see note in _newVisitor.
    if (added == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    // The Profile tab is a full screen with its own app bar, so the gate's
    // app bar, stat strip and FAB all step aside for it.
    const profileIndex = 3;
    final onProfile = index == profileIndex;
    return Scaffold(
      appBar: onProfile
          ? null
          : AppBar(
              title: const Text('Security · Main Gate'),
              backgroundColor: _accent,
              foregroundColor: Colors.white,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visitorFilter = 'all';
        }),
        indicatorColor: _accent.withValues(alpha: 0.16),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Visitors',
          ),
          NavigationDestination(
            // The count used to live in the tab label; a badge says it without
            // stretching the destination.
            icon: Badge.count(
              count: _preApproved.pendingCount,
              isLabelVisible: _preApproved.pendingCount > 0,
              child: const Icon(Icons.event_available_outlined),
            ),
            selectedIcon: Badge.count(
              count: _preApproved.pendingCount,
              isLabelVisible: _preApproved.pendingCount > 0,
              child: const Icon(Icons.event_available),
            ),
            label: 'Expected',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: _deliveries.pendingCount,
              isLabelVisible: _deliveries.pendingCount > 0,
              child: const Icon(Icons.local_shipping_outlined),
            ),
            selectedIcon: Badge.count(
              count: _deliveries.pendingCount,
              isLabelVisible: _deliveries.pendingCount > 0,
              child: const Icon(Icons.local_shipping),
            ),
            label: 'Parcels',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: (index == 1 || onProfile)
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              onPressed: index == 0 ? () => _newVisitor() : _newDelivery,
              icon: Icon(index == 0 ? Icons.person_add_alt : Icons.add),
              label: Text(index == 0 ? 'New Entry' : 'Add Parcel'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : onProfile
              ? const UserProfileTab()
              : Column(
                  children: [
                    _StatStrip(
                      inside: _visitors.insideCount,
                      today: _visitors.todayCount,
                      accent: _accent,
                      onTap: (filter) => setState(() {
                        _visitorFilter = filter;
                        _index = 0;
                      }),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _index,
                        children: [
                          _VisitorsTab(
                              accent: _accent,
                              repo: _visitors,
                              filter: _visitorFilter,
                              onClearFilter: () =>
                                  setState(() => _visitorFilter = 'all'),
                              onAction: _mutate),
                          _ExpectedTab(
                              accent: _accent,
                              repo: _preApproved,
                              onCheckIn: (p) => _newVisitor(from: p)),
                          _DeliveriesTab(
                              accent: _accent,
                              repo: _deliveries,
                              onAction: _mutate),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.inside,
    required this.today,
    required this.accent,
    required this.onTap,
  });

  final int inside;
  final int today;
  final Color accent;

  /// Filters the visitor list: 'inside' or 'today'.
  final void Function(String filter) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _stat('Inside now', '$inside', Icons.people_alt_outlined,
              () => onTap('inside')),
          const SizedBox(width: 12),
          _stat("Today's visitors", '$today', Icons.today_outlined,
              () => onTap('today')),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        return Material(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                children: [
                  Icon(icon, color: accent, size: 22),
                  const SizedBox(height: 6),
                  Text(value,
                      style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold, color: accent)),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _VisitorsTab extends StatelessWidget {
  const _VisitorsTab({
    required this.accent,
    required this.repo,
    required this.onAction,
    this.filter = 'all',
    this.onClearFilter,
  });

  final Color accent;
  final VisitorsRepository repo;
  final Future<void> Function(Future<void> Function()) onAction;

  /// 'all' | 'inside' | 'today' — set by tapping a stat card.
  final String filter;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final all = repo.all;
    if (all.isEmpty) {
      return const EmptyMessage(
          icon: Icons.how_to_reg_outlined,
          text: 'No visitors yet.\nTap New Entry to log one.');
    }
    final visitors = switch (filter) {
      'inside' => all.where((v) => v.inside).toList(),
      'today' => all.where((v) => v.isToday).toList(),
      _ => all,
    };
    final banner = filter == 'all' ? null : _filterBanner(context);
    if (visitors.isEmpty) {
      return Column(
        children: [
          ?banner,
          Expanded(
            child: EmptyMessage(
                icon: Icons.filter_alt_off_outlined,
                text: filter == 'inside'
                    ? 'No visitors inside right now.'
                    : 'No visitors today yet.'),
          ),
        ],
      );
    }
    final list = ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: visitors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final v = visitors[index];
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child: Text(v.initial,
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Flat ${v.flatNumber} • ${v.purpose}',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text(
                        v.inside
                            ? 'In: ${v.inTime}'
                            : 'In: ${v.inTime}  •  Out: ${v.outTime}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (v.inside)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent.withValues(alpha: 0.14),
                      foregroundColor: accent,
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => onAction(() => repo.checkout(v)),
                    child: const Text('Check out'),
                  )
                else
                  const _ExitedChip(),
              ],
            ),
          ),
        );
      },
    );
    if (banner == null) return list;
    return Column(children: [banner, Expanded(child: list)]);
  }

  Widget _filterBanner(BuildContext context) {
    final theme = Theme.of(context);
    final label = filter == 'inside' ? 'Inside now' : "Today's visitors";
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_outlined, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Showing: $label',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: accent, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: onClearFilter,
            child: const Text('Show all'),
          ),
        ],
      ),
    );
  }
}

class _ExitedChip extends StatelessWidget {
  const _ExitedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text('Exited',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
    );
  }
}

class _ExpectedTab extends StatelessWidget {
  const _ExpectedTab({
    required this.accent,
    required this.repo,
    required this.onCheckIn,
  });

  final Color accent;
  final PreApprovedRepository repo;
  final void Function(PreApprovedVisitor) onCheckIn;

  @override
  Widget build(BuildContext context) {
    final list = repo.all;
    if (list.isEmpty) {
      return const EmptyMessage(
          icon: Icons.verified_user_outlined,
          text: 'No expected visitors.\nResidents can pre-approve guests.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = list[index];
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child: Text(p.initial,
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Flat ${p.flatNumber} • ${p.purpose}',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(p.validLabel,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                if (p.checkedIn)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Checked in',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32))),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => onCheckIn(p),
                    child: const Text('Check In'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeliveriesTab extends StatelessWidget {
  const _DeliveriesTab({
    required this.accent,
    required this.repo,
    required this.onAction,
  });

  final Color accent;
  final DeliveriesRepository repo;
  final Future<void> Function(Future<void> Function()) onAction;

  @override
  Widget build(BuildContext context) {
    final list = repo.all;
    if (list.isEmpty) {
      return const EmptyMessage(
          icon: Icons.inventory_2_outlined,
          text: 'No parcels held.\nTap Add Parcel to log one.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final d = list[index];
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            leading: CircleAvatar(
              backgroundColor: d.collected
                  ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                  : accent.withValues(alpha: 0.12),
              child: Icon(
                d.collected ? Icons.check_circle : Icons.inventory_2_outlined,
                color: d.collected ? const Color(0xFF2E7D32) : accent,
              ),
            ),
            title: Text('${d.courier} → Flat ${d.flatNumber}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Received ${d.inTime}'),
            trailing: TextButton(
              onPressed: () => onAction(() => repo.toggleCollected(d)),
              child: Text(d.collected ? 'Undo' : 'Collected'),
            ),
          ),
        );
      },
    );
  }
}
