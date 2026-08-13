import 'package:flutter/material.dart';

import '../../data/notices_repository.dart';
import '../../models/user_role.dart';
import '../loadable.dart';

/// Announcements Nestora sent to this society. Read-only on purpose — they are
/// the platform's word, not the society's, so there is nothing to pin or
/// delete here. The society's own board lives in Notices.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen>
    with LoadableState<AnnouncementsScreen> {
  final _repo = NoticesRepository.instance;

  Color get _accent => UserRole.societyAdmin.color;

  @override
  Future<void> load() => _repo.loadAnnouncements();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        color: _accent,
        child: buildLoad(() {
          final items = _repo.announcements;
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 64,
                  color: _accent.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nothing from Nestora yet.\nUpdates about the app show up '
                  'here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = items[i];
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border(left: BorderSide(color: _accent, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.campaign, size: 18, color: _accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nestora · ${a.dateLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(a.body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
