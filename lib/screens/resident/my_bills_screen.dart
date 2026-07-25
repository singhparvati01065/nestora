import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../data/bills_repository.dart';
import '../../models/maintenance_bill.dart';
import '../../models/user_role.dart';
import '../bill_kind_tag.dart';
import '../loadable.dart';
import '../society_admin/admin_widgets.dart';
import 'payment_screen.dart';

/// A resident's own bills for [flat]. Shows only *unpaid* bills, which can be
/// picked in bulk (rent + maintenance together) and paid in one tap. Paid bills
/// move to the History screen.
class MyBillsScreen extends StatefulWidget {
  const MyBillsScreen({super.key, required this.flat});

  final String flat;

  @override
  State<MyBillsScreen> createState() => _MyBillsScreenState();
}

class _MyBillsScreenState extends State<MyBillsScreen>
    with LoadableState<MyBillsScreen> {
  final _repo = BillsRepository.instance;

  /// Bill ids the resident has ticked to pay together.
  final Set<String> _selected = {};

  Color get _accent => UserRole.resident.color;

  @override
  Future<void> load() => _repo.load(flatId: Session.instance.user?.flatId);

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  void _toggle(MaintenanceBill bill) {
    setState(() {
      if (!_selected.remove(bill.id)) _selected.add(bill.id);
    });
  }

  void _toggleAll(List<MaintenanceBill> unpaid) {
    setState(() {
      if (_selected.length == unpaid.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(unpaid.map((b) => b.id));
      }
    });
  }

  Future<void> _paySelected(List<MaintenanceBill> unpaid) async {
    final chosen = unpaid.where((b) => _selected.contains(b.id)).toList();
    if (chosen.isEmpty) return;
    // The payment screen runs the actual payment and pops true on success.
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PaymentScreen(bills: chosen)),
    );
    if (!mounted) return;
    if (paid == true) {
      setState(() => _selected.clear());
      await refresh(); // reflect the now-paid bills
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bills'),
        // A tab of ResidentHome, not a pushed route — a back arrow here would
        // pop the whole home.
        automaticallyImplyLeading: false,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: buildLoad(() {
        final unpaid = _repo.unpaidForFlat(widget.flat);
        // Drop any stale selections (e.g. a bill just paid).
        _selected.retainWhere((id) => unpaid.any((b) => b.id == id));
        final pending =
            unpaid.fold<double>(0, (s, b) => s + b.amount);
        // Money owed reads as red; a cleared balance stays on the calm accent.
        final dueColor =
            pending > 0 ? const Color(0xFFD32F2F) : _accent;
        return Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [dueColor, dueColor.withValues(alpha: 0.75)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      pending > 0
                          ? 'Total due • Flat ${widget.flat}'
                          : 'All clear • Flat ${widget.flat}',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text(_money(pending),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (unpaid.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                child: Row(
                  children: [
                    Text('${unpaid.length} pending',
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _toggleAll(unpaid),
                      child: Text(_selected.length == unpaid.length
                          ? 'Clear all'
                          : 'Select all'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: unpaid.isEmpty
                  ? EmptyMessage(
                      icon: Icons.check_circle_outline,
                      text: 'You\'re all caught up.\nNo pending bills.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: unpaid.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final b = unpaid[index];
                        final checked = _selected.contains(b.id);
                        final theme = Theme.of(context);
                        return Material(
                          color: checked
                              ? _accent.withValues(alpha: 0.08)
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _toggle(b),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: checked
                                      ? _accent
                                      : theme.colorScheme.outlineVariant,
                                  width: checked ? 1.5 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              child: Row(
                                children: [
                                  _SelectCircle(checked: checked, accent: _accent),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(b.period,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            const SizedBox(width: 8),
                                            BillKindTag(
                                                bill: b, accent: _accent),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(_money(b.amount),
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () =>
                      _paySelected(_repo.unpaidForFlat(widget.flat)),
                  child: Builder(builder: (context) {
                    final chosen = _repo
                        .unpaidForFlat(widget.flat)
                        .where((b) => _selected.contains(b.id))
                        .toList();
                    final total =
                        chosen.fold<double>(0, (s, b) => s + b.amount);
                    return Text(
                        'Pay ${_money(total)} • ${chosen.length} selected',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600));
                  }),
                ),
              ),
            ),
    );
  }
}

/// A soft round selector for a bill row — an outlined circle when off, a filled
/// accent circle with a tick when on. Nicer than a stock square checkbox.
class _SelectCircle extends StatelessWidget {
  const _SelectCircle({required this.checked, required this.accent});

  final bool checked;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? accent : Colors.transparent,
        border: Border.all(
          color: checked ? accent : Theme.of(context).colorScheme.outline,
          width: 2,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
