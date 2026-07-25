import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../data/amenities_repository.dart';
import '../../models/amenity.dart';
import '../../models/user_role.dart';

/// Admin: manage the society's amenities and approve/reject residents' bookings.
class AmenitiesAdminScreen extends StatefulWidget {
  const AmenitiesAdminScreen({super.key});

  @override
  State<AmenitiesAdminScreen> createState() => _AmenitiesAdminScreenState();
}

class _AmenitiesAdminScreenState extends State<AmenitiesAdminScreen> {
  final _repo = AmenitiesRepository.instance;
  Color get _accent => UserRole.societyAdmin.color;

  bool _loading = true;
  bool _busy = false;
  late Future<List<AmenityBooking>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _repo.allBookings();
    _reloadAmenities();
  }

  Future<void> _reloadAmenities() async {
    setState(() => _loading = true);
    try {
      await _repo.loadAmenities();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _reloadBookings() {
    setState(() => _bookingsFuture = _repo.allBookings());
  }

  Future<void> _setStatus(AmenityBooking b, String status) => _run(() async {
        await _repo.setBookingStatus(b.id, status);
        _reloadBookings();
      });

  /// Opens the actions sheet for a decided (approved / rejected) booking, from
  /// where the admin can change their mind.
  Future<void> _bookingActions(AmenityBooking b) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${b.amenity} • Flat ${b.flatNumber}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('${b.dateLabel} • ${b.slot} • ${b.statusLabel}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Approve — shown unless already approved.
              if (!b.isApproved)
                ListTile(
                  leading: const Icon(Icons.check, color: Color(0xFF2E7D32)),
                  title: const Text('Approve'),
                  onTap: () => Navigator.of(context).pop('APPROVED'),
                ),
              // Reject — shown unless already rejected.
              if (!b.isRejected)
                ListTile(
                  leading: const Icon(Icons.close, color: Color(0xFFD32F2F)),
                  title: const Text('Reject'),
                  onTap: () => Navigator.of(context).pop('REJECTED'),
                ),
              // Back to pending — only when it's already been decided.
              if (!b.isPending)
                ListTile(
                  leading: Icon(Icons.undo, color: _accent),
                  title: const Text('Move to pending'),
                  onTap: () => Navigator.of(context).pop('PENDING'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (action != null) _setStatus(b, action);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.messageFor(e))));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _amenitySheet({Amenity? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String iconKey = existing?.iconKey ?? kAmenityIconKeys.first;

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
                Text(existing == null ? 'Add amenity' : 'Edit amenity',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Badminton Court',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Icon',
                      style: Theme.of(context).textTheme.labelLarge),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final k in kAmenityIconKeys)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setSheet(() => iconKey = k),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: iconKey == k
                                ? _accent.withValues(alpha: 0.18)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: iconKey == k
                                    ? _accent
                                    : Colors.transparent,
                                width: 2),
                          ),
                          child: Icon(amenityIcon(k),
                              color: iconKey == k
                                  ? _accent
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a name')),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                    _run(() => existing == null
                        ? _repo.createAmenity(name: name, icon: iconKey)
                        : _repo.updateAmenity(existing.id,
                            name: name, icon: iconKey));
                  },
                  child: Text(existing == null ? 'Add' : 'Save'),
                ),
              ],
            ),
          );
        });
      },
    );
    if (done == true) _reloadAmenities();
  }

  Future<void> _confirmDelete(Amenity a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.error),
        title: const Text('Delete amenity?'),
        content: Text(
            '${a.name} and all its bookings will be removed.'),
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
    if (ok == true) {
      await _run(() => _repo.deleteAmenity(a.id));
      _reloadBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Amenities'),
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Amenities'),
              Tab(text: 'Bookings'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          onPressed: () => _amenitySheet(),
          icon: const Icon(Icons.add),
          label: const Text('Add amenity'),
        ),
        body: TabBarView(
          children: [
            _amenitiesTab(),
            _bookingsTab(),
          ],
        ),
      ),
    );
  }

  Widget _amenitiesTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final amenities = _repo.amenities;
    if (amenities.isEmpty) {
      return _empty(Icons.deck_outlined,
          'No amenities yet.\nTap "Add amenity" to create one.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: amenities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = amenities[i];
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _accent.withValues(alpha: 0.12),
                  child: Icon(a.icon, color: _accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(a.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  enabled: !_busy,
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (v) {
                    if (v == 'edit') {
                      _amenitySheet(existing: a);
                    } else if (v == 'delete') {
                      _confirmDelete(a);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20, color: _accent),
                          const SizedBox(width: 10),
                          const Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bookingsTab() {
    return RefreshIndicator(
      onRefresh: () async => _reloadBookings(),
      color: _accent,
      child: FutureBuilder<List<AmenityBooking>>(
        future: _bookingsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final bookings = snap.data ?? const [];
          if (bookings.isEmpty) {
            return _empty(Icons.event_note_outlined,
                'No bookings yet.\nResidents\' requests show up here.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: bookings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _bookingCard(bookings[i]),
          );
        },
      ),
    );
  }

  Widget _bookingCard(AmenityBooking b) {
    final theme = Theme.of(context);
    final color = b.isApproved
        ? const Color(0xFF2E7D32)
        : b.isRejected
            ? const Color(0xFFD32F2F)
            : const Color(0xFFF57C00);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        // Tap opens the actions sheet to set / change the decision.
        onTap: _busy ? null : () => _bookingActions(b),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${b.amenity} • Flat ${b.flatNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(b.statusLabel,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: color, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text('${b.dateLabel} • ${b.slot}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _empty(IconData icon, String text) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
      children: [
        Icon(icon, size: 64, color: _accent.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
