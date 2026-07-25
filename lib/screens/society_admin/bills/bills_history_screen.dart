import 'package:flutter/material.dart';

import '../../../data/bills_repository.dart';
import '../../../models/maintenance_bill.dart';
import '../../../models/user_role.dart';
import '../../bill_kind_tag.dart';

/// Paid bills across the society — where a bill lands once it's marked paid, so
/// the Bills tab only ever shows what's still due. An admin can mark one unpaid
/// here to send it back.
class BillsHistoryScreen extends StatefulWidget {
  const BillsHistoryScreen({super.key});

  @override
  State<BillsHistoryScreen> createState() => _BillsHistoryScreenState();
}

class _BillsHistoryScreenState extends State<BillsHistoryScreen> {
  final _repo = BillsRepository.instance;
  Color get _accent => UserRole.societyAdmin.color;
  bool _busy = false;

  String _money(double v) => '₹${v.toStringAsFixed(0)}';

  List<MaintenanceBill> get _paid {
    final list = _repo.all.where((b) => b.paid).toList();
    list.sort((a, b) => (b.paidAt ?? DateTime(2000))
        .compareTo(a.paidAt ?? DateTime(2000)));
    return list;
  }

  Future<void> _markUnpaid(MaintenanceBill b) async {
    setState(() => _busy = true);
    try {
      await _repo.setPaid(b, false);
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmDelete(MaintenanceBill b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.error),
        title: const Text('Delete bill?'),
        content: Text(
            'The ${b.kindLabel.toLowerCase()} bill for Flat ${b.flatNumber} '
            '(${b.period}) will be removed.'),
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
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _repo.delete(b);
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paid = _paid;
    final total = paid.fold<double>(0, (s, b) => s + b.amount);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: paid.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history,
                        size: 64, color: _accent.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text('No payments yet.\nPaid bills show up here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Collected',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF2E7D32))),
                      const SizedBox(height: 6),
                      Text(_money(total),
                          style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 30,
                              fontWeight: FontWeight.bold)),
                      Text('${paid.length} paid bill${paid.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: paid.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final b = paid[i];
                      return Material(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.12),
                                child: const Icon(Icons.check_circle,
                                    color: Color(0xFF2E7D32)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text('Flat ${b.flatNumber}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ),
                                        const SizedBox(width: 8),
                                        BillKindTag(bill: b, accent: _accent),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text('${b.dueLabel} • ${_money(b.amount)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'More',
                                enabled: !_busy,
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (v) {
                                  if (v == 'unpaid') {
                                    _markUnpaid(b);
                                  } else if (v == 'delete') {
                                    _confirmDelete(b);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'unpaid',
                                    child: Row(
                                      children: [
                                        Icon(Icons.undo, size: 20,
                                            color: _accent),
                                        const SizedBox(width: 10),
                                        const Text('Unpaid'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline,
                                            size: 20, color: Colors.red),
                                        SizedBox(width: 10),
                                        Text('Delete bill'),
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
                  ),
                ),
              ],
            ),
    );
  }
}
