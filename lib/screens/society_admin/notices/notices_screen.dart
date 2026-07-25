import 'package:flutter/material.dart';

import '../../../data/notices_repository.dart';
import '../../../models/notice.dart';
import '../../../models/user_role.dart';
import '../../loadable.dart';
import '../admin_widgets.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen>
    with LoadableState<NoticesScreen> {
  final _repo = NoticesRepository.instance;

  Color get _accent => UserRole.societyAdmin.color;

  @override
  Future<void> load() => _repo.load();

  Future<void> _addNotice() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var pinned = false;

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
                  Text('New Notice',
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
                  TextField(
                    controller: bodyController,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: pinned,
                    activeThumbColor: _accent,
                    title: const Text('Pin to top'),
                    onChanged: (v) => setModalState(() => pinned = v),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    onPressed: () {
                      if (titleController.text.trim().isEmpty ||
                          bodyController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Enter a title and message')),
                        );
                        return;
                      }
                      Navigator.of(context).pop(true);
                      runMutation(() => _repo.add(
                            title: titleController.text.trim(),
                            body: bodyController.text.trim(),
                            pinned: pinned,
                          ));
                    },
                    child: const Text('Post Notice'),
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

  void _openNotice(Notice notice) {
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
                    child: Text(notice.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  if (notice.pinned)
                    Icon(Icons.push_pin, size: 18, color: _accent),
                ],
              ),
              const SizedBox(height: 4),
              Text(notice.dateLabel,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Text(notice.body,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(notice.pinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin),
                      label: Text(notice.pinned ? 'Unpin' : 'Pin'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        runMutation(() => _repo.togglePinned(notice));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        runMutation(() => _repo.remove(notice));
                      },
                    ),
                  ),
                ],
              ),
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
      floatingActionButton: FloatingActionButton.extended(
        // Sibling tabs live in the same IndexedStack, so their FABs
        // coexist and would collide on the default hero tag.
        heroTag: 'admin-notices-fab',
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: _addNotice,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Post'),
      ),
      body: buildLoad(() {
        final notices = _repo.all;
        return notices.isEmpty
          ? const EmptyMessage(
              icon: Icons.campaign_outlined,
              text: 'No notices yet.\nTap Post to make an announcement.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: notices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final n = notices[index];
                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openNotice(n),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (n.pinned) ...[
                                Icon(Icons.push_pin, size: 16, color: _accent),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(n.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(n.body,
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
                          Text(n.dateLabel,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
      }),
    );
  }
}
