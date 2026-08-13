import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/session.dart';
import '../../data/support_repository.dart';
import '../../models/support_ticket.dart';
import '../../models/user_role.dart';
import '../loadable.dart';

/// One line of the conversation: either a ticket being opened or a reply on it.
class _ChatEntry {
  _ChatEntry({
    required this.at,
    required this.fromSupport,
    required this.author,
    required this.text,
    this.subject,
    this.category,
    this.status,
  });

  final DateTime at;
  final bool fromSupport;
  final String author;
  final String text;

  /// Set only on the message that opened a ticket, so the bubble can show what
  /// the topic was and where it stands.
  final String? subject;
  final String? category;
  final String? status;

  bool get startsTicket => subject != null;
}

/// Society admin's conversation with Nestora support: every ticket and reply in
/// one thread, oldest first, split by day.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with LoadableState<SupportScreen> {
  final _repo = SupportRepository.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  Color get _accent => UserRole.societyAdmin.color;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Future<void> load() async {
    await _repo.load();
    // Land on the newest message, the way any chat opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
  }

  void _jumpToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  /// A day heading: "Today", "Yesterday", or "11 Aug 2026".
  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  String _timeLabel(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${d.hour < 12 ? 'am' : 'pm'}';
  }

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

  String _statusLabel(String status) {
    switch (status) {
      case 'CLOSED':
        return 'Closed';
      case 'PENDING':
        return 'Pending';
      default:
        return 'Open';
    }
  }

  /// Every ticket and every reply, flattened and sorted oldest-first.
  List<_ChatEntry> get _entries {
    final me = Session.instance.user?.name ?? 'You';
    final entries = <_ChatEntry>[];
    for (final t in _repo.all) {
      entries.add(
        _ChatEntry(
          at: t.createdAt ?? DateTime.now(),
          fromSupport: false,
          author: me,
          text: t.message,
          subject: t.subject,
          category: t.category,
          status: t.status,
        ),
      );
      for (final r in t.replies) {
        entries.add(
          _ChatEntry(
            at: r.createdAt ?? DateTime.now(),
            fromSupport: r.fromSupport,
            author: r.fromSupport ? 'Nestora Support' : r.author,
            text: r.body,
          ),
        );
      }
    }
    entries.sort((a, b) => a.at.compareTo(b.at));
    return entries;
  }

  /// Where a typed message goes: the newest ticket, since that is the topic the
  /// conversation is on. With no ticket yet there is nothing to attach to, so
  /// the new-topic sheet opens instead.
  SupportTicket? get _activeTicket {
    final tickets = _repo.all;
    if (tickets.isEmpty) return null;
    final sorted = [...tickets]
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
    return sorted.first;
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final ticket = _activeTicket;
    if (ticket == null) {
      await _newTopic(firstMessage: text);
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.reply(ticket.id, text);
      _input.clear();
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiClient.messageFor(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Starts a new topic. Everything still lands in the same conversation — the
  /// subject and category only label where a topic began.
  Future<void> _newTopic({String? firstMessage}) async {
    final subject = TextEditingController();
    final message = TextEditingController(text: firstMessage ?? '');
    String category = kTicketCategories.first;

    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
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
                  Text(
                    'New topic',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                            content: Text('Fill subject and description'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).pop(true);
                      runMutation(
                        () => _repo.create(
                          category: category,
                          subject: s,
                          message: m,
                        ),
                      );
                    },
                    child: const Text('Send'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Controllers outlive the sheet on purpose — disposing them here crashes on
    // the closing animation.
    if (done == true && mounted) {
      _input.clear();
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'New topic',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _newTopic,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            // Support answers while this screen may be open, so the thread is
            // pullable to fetch what has arrived since.
            child: RefreshIndicator(
              onRefresh: refresh,
              color: _accent,
              child: buildLoad(() => _buildThread()),
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildThread() {
    final theme = Theme.of(context);
    final entries = _entries;
    if (entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
        children: [
          Icon(
            Icons.support_agent_outlined,
            size: 64,
            color: _accent.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet.\nWrite below to start a conversation with '
            'Nestora support.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        // A heading whenever the day changes (and above the first message).
        final newDay =
            i == 0 || _dayLabel(entries[i - 1].at) != _dayLabel(e.at);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newDay) _DayDivider(label: _dayLabel(e.at)),
            _Bubble(
              entry: e,
              accent: _accent,
              time: _timeLabel(e.at),
              statusColor: e.status == null ? null : _statusColor(e.status!),
              statusLabel: e.status == null ? null : _statusLabel(e.status!),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComposer() {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message Nestora support…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: _accent),
              onPressed: _sending || _input.text.trim().isEmpty ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "11 Aug 2026" / "Today" heading between days.
class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// One message. Support sits left in grey, this society right in the accent.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.entry,
    required this.accent,
    required this.time,
    this.statusColor,
    this.statusLabel,
  });

  final _ChatEntry entry;
  final Color accent;
  final String time;
  final Color? statusColor;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = !entry.fromSupport;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine
              ? accent.withValues(alpha: 0.14)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The message that opened a topic carries its subject and status.
            if (entry.startsTicket) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      entry.subject!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (statusLabel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor!.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (entry.category != null)
                Text(
                  entry.category!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 6),
            ],
            Text(entry.text, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                mine ? time : '${entry.author} · $time',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
