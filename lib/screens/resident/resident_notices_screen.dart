import 'package:flutter/material.dart';

import '../../data/notices_repository.dart';
import '../../models/notice.dart';
import '../../models/user_role.dart';
import '../loadable.dart';
import '../notice_card.dart';
import '../society_admin/admin_widgets.dart';

/// Read-only notices feed for residents.
class ResidentNoticesScreen extends StatefulWidget {
  const ResidentNoticesScreen({super.key});

  @override
  State<ResidentNoticesScreen> createState() => _ResidentNoticesScreenState();
}

class _ResidentNoticesScreenState extends State<ResidentNoticesScreen>
    with LoadableState<ResidentNoticesScreen> {
  final _repo = NoticesRepository.instance;

  Color get _accent => UserRole.resident.color;

  @override
  Future<void> load() async {
    await NoticesRepository.instance.load();
  }

  void _open(Notice notice) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
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
                      notice.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (notice.pinned)
                    Icon(Icons.push_pin, size: 18, color: _accent),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                notice.dateLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(notice.body, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: buildLoad(() {
        final notices = _repo.all;
        return notices.isEmpty
            ? const EmptyMessage(
                icon: Icons.campaign_outlined,
                text: 'No notices yet.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final n = notices[index];
                  return NoticeCard(
                    notice: n,
                    accent: _accent,
                    onTap: () => _open(n),
                  );
                },
              );
      }),
    );
  }
}
