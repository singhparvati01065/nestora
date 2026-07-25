import 'package:flutter/material.dart';

import '../../data/residents_repository.dart';
import '../../models/society.dart';
import '../../models/user_role.dart';
import 'residents/resident_detail_screen.dart';

/// Shows all flats in a tower, grouped by floor. Tapping a flat opens the
/// resident living there (or says it's empty).
class TowerDetailScreen extends StatefulWidget {
  const TowerDetailScreen({super.key, required this.tower});

  final Tower tower;

  @override
  State<TowerDetailScreen> createState() => _TowerDetailScreenState();
}

class _TowerDetailScreenState extends State<TowerDetailScreen> {
  Color get _accent => UserRole.societyAdmin.color;

  @override
  void initState() {
    super.initState();
    // Make sure occupancy is known even if the Residents tab wasn't opened yet.
    if (ResidentsRepository.instance.all.isEmpty) {
      ResidentsRepository.instance.load().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tower = widget.tower;
    final byFloor = tower.flatsByFloor;
    final floors = byFloor.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text(tower.name),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: floors.length,
          itemBuilder: (context, index) {
            final floor = floors[index];
            final flats = byFloor[floor]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Floor $floor',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final flat in flats)
                      _FlatChip(
                        flat: flat,
                        accent: _accent,
                        // A remove archives the resident, so refresh occupancy.
                        onChanged: () {
                          if (mounted) setState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FlatChip extends StatelessWidget {
  const _FlatChip({
    required this.flat,
    required this.accent,
    required this.onChanged,
  });

  final Flat flat;
  final Color accent;

  /// Called after a resident is removed so the tower can refresh occupancy.
  final VoidCallback onChanged;

  Future<void> _open(BuildContext context) async {
    final repo = ResidentsRepository.instance;
    var resident = repo.byFlatId(flat.id);
    // If the residents list hasn't loaded yet, fetch it once and re-check.
    if (resident == null && repo.all.isEmpty) {
      try {
        await repo.load();
      } catch (_) {}
      resident = repo.byFlatId(flat.id);
    }
    if (!context.mounted) return;
    if (resident != null) {
      final removed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ResidentDetailScreen(resident: resident!),
      ));
      if (removed == true) onChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No resident in Flat ${flat.number}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resident = ResidentsRepository.instance.byFlatId(flat.id);
    final occupied = resident != null;
    return Material(
      color: occupied
          ? accent.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Container(
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: accent.withValues(alpha: occupied ? 0.5 : 0.25)),
          ),
          child: Column(
            children: [
              Icon(occupied ? Icons.person : Icons.home_outlined,
                  color: accent, size: 22),
              const SizedBox(height: 6),
              Text(flat.number,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(occupied ? resident.name : 'Empty',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
