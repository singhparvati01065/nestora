import 'package:flutter/material.dart';

import '../../data/amenities_repository.dart';
import '../../models/amenity.dart';
import '../../models/user_role.dart';
import '../loadable.dart';

/// Lets a resident browse amenities and book a slot for [flat].
class AmenitiesScreen extends StatefulWidget {
  const AmenitiesScreen({super.key, required this.flat});

  final String flat;

  @override
  State<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends State<AmenitiesScreen>
    with LoadableState<AmenitiesScreen> {
  final _repo = AmenitiesRepository.instance;

  Color get _accent => UserRole.resident.color;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
  String _iso(DateTime d) => d.toIso8601String().split('T').first;

  @override
  Future<void> load() async {
    await AmenitiesRepository.instance.load();
  }

  Future<void> _book(Amenity amenity) async {
    DateTime date = DateTime.now();
    String? slot;
    Set<String> taken = {};
    bool loadingSlots = true;
    bool started = false;

    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> refreshTaken() async {
              setModalState(() => loadingSlots = true);
              try {
                final t = await _repo.bookedSlots(
                    amenityId: amenity.id, day: _iso(date));
                taken = t.toSet();
                if (slot != null && taken.contains(slot)) slot = null;
              } catch (_) {}
              setModalState(() => loadingSlots = false);
            }

            if (!started) {
              started = true;
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => refreshTaken());
            }

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
                  Row(
                    children: [
                      Icon(amenity.icon, color: _accent),
                      const SizedBox(width: 10),
                      Text('Book ${amenity.name}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked != null) {
                        date = picked;
                        refreshTaken();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      child: Text(_fmtDate(date)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Time slot',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(width: 8),
                      if (loadingSlots)
                        const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final s in AmenitiesRepository.slots)
                        ChoiceChip(
                          label: Text(taken.contains(s) ? '$s · Booked' : s),
                          selected: slot == s,
                          selectedColor: _accent.withValues(alpha: 0.18),
                          onSelected: taken.contains(s)
                              ? null
                              : (v) =>
                                  setModalState(() => slot = v ? s : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    onPressed: slot == null
                        ? null
                        : () {
                            final chosen = slot!;
                            Navigator.of(context).pop(true);
                            runMutation(() => _repo.book(
                                  amenityId: amenity.id,
                                  day: _iso(date),
                                  slot: chosen,
                                ));
                          },
                    child: const Text('Confirm Booking'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (booked == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${amenity.name} booking requested')),
      );
    }
  }

  Color _statusColor(AmenityBooking b) => b.isApproved
      ? const Color(0xFF2E7D32)
      : b.isRejected
          ? const Color(0xFFD32F2F)
          : const Color(0xFFF57C00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amenities'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: buildLoad(() {
        final bookings = _repo.bookings;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (bookings.isNotEmpty) ...[
              Text('My bookings',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              for (final b in bookings)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_available, color: _accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(b.amenity,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 8),
                                _StatusChip(
                                    label: b.statusLabel,
                                    color: _statusColor(b)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('${b.dateLabel} • ${b.slot}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel',
                        icon: const Icon(Icons.close, size: 20),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        onPressed: () => runMutation(() => _repo.cancel(b.id)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
            Text('Book an amenity',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_repo.amenities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No amenities yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              )
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  for (final a in _repo.amenities)
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _book(a),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(a.icon, color: _accent),
                              ),
                              const SizedBox(height: 10),
                              Text(a.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        );
      }),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
