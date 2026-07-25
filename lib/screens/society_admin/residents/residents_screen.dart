import 'package:flutter/material.dart';

import '../../../data/residents_repository.dart';
import '../../../models/resident.dart';
import '../../../models/user_role.dart';
import '../../loadable.dart';
import 'add_resident_screen.dart';
import 'resident_detail_screen.dart';
import 'resident_history_screen.dart';

class ResidentsScreen extends StatefulWidget {
  const ResidentsScreen({super.key});

  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends State<ResidentsScreen>
    with LoadableState<ResidentsScreen> {
  final _repo = ResidentsRepository.instance;

  Color get _accent => UserRole.societyAdmin.color;

  @override
  void initState() {
    super.initState();
    // Rebuild whenever the roster changes anywhere (e.g. removed from a tower).
    _repo.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  @override
  Future<void> load() => _repo.load();

  Future<void> _addResident() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddResidentScreen()),
    );
    if (added == true && mounted) refresh();
  }

  Future<void> _openResident(Resident resident) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ResidentDetailScreen(resident: resident),
      ),
    );
    if (removed == true && mounted) refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Residents'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Resident history',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ResidentHistoryScreen(),
            )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Sibling tabs live in the same IndexedStack, so their FABs
        // coexist and would collide on the default hero tag.
        heroTag: 'admin-residents-fab',
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: _addResident,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add'),
      ),
      body: buildLoad(() {
        final residents = _repo.all;
        return residents.isEmpty
          ? const _EmptyMessage(
              icon: Icons.people_outline,
              text: 'No residents yet.\nTap Add to assign residents to flats.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: residents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final r = residents[index];
                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading: CircleAvatar(
                      backgroundColor: _accent.withValues(alpha: 0.12),
                      child: Text(r.initial,
                          style: TextStyle(
                              color: _accent, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(r.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Flat ${r.flatNumber} • ${r.phone}'),
                    trailing: _TypeChip(type: r.type),
                    onTap: () => _openResident(r),
                  ),
                );
              },
            );
      }),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final ResidentType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(type.label,
          style: TextStyle(
              color: type.color,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

