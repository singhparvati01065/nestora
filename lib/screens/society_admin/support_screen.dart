import 'package:flutter/material.dart';

import '../../data/support_repository.dart';
import '../../models/support_ticket.dart';
import '../../models/user_role.dart';
import '../loadable.dart';

/// Society admin: raise support tickets and see their status.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with LoadableState<SupportScreen> {
  final _repo = SupportRepository.instance;
  Color get _accent => UserRole.societyAdmin.color;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String _fmt(DateTime? d) =>
      d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Future<void> load() => _repo.load();

  Color _statusColor(String status) {
    switch (status) {
      case 'CLOSED':
        return const Color(0xFF2E7D32);
      case 'PENDING':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFF1565C0);
    }
  }

  Future<void> _raise() async {
    final subject = TextEditingController();
    final message = TextEditingController();
    String category = kTicketCategories.first;

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
                Text('Raise a ticket',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final c in kTicketCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setSheet(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subject,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: message,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Describe the issue',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  onPressed: () {
                    final s = subject.text.trim();
                    final m = message.text.trim();
                    if (s.isEmpty || m.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Fill subject and description')),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                    runMutation(() => _repo.create(
                          category: category,
                          subject: s,
                          message: m,
                        ));
                  },
                  child: const Text('Submit ticket'),
                ),
              ],
            ),
          );
        });
      },
    );
    if (done == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: _raise,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New ticket'),
      ),
      body: buildLoad(() {
        final tickets = _repo.all;
        if (tickets.isEmpty) {
          final theme = Theme.of(context);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.support_agent_outlined,
                      size: 64, color: _accent.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No tickets yet.\nTap "New ticket" to raise one.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: tickets.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final t = tickets[i];
            final theme = Theme.of(context);
            final color = _statusColor(t.status);
            return Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(t.subject,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(t.statusLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: color, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${t.category} • ${_fmt(t.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(t.message, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
