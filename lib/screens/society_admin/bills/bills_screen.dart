import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/bills_repository.dart';
import '../../../data/society_repository.dart';
import '../../../models/maintenance_bill.dart';
import '../../../models/user_role.dart';
import '../../../push_notifications.dart';
import '../../bill_kind_tag.dart';
import '../../loadable.dart';
import '../admin_widgets.dart';
import 'bills_history_screen.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen>
    with LoadableState<BillsScreen>, WidgetsBindingObserver {
  final _repo = BillsRepository.instance;

  Color get _accent => UserRole.societyAdmin.color;

  @override
  Future<void> load() => _repo.load();

  // Residents pay from their own phones, so this list can go out of date while
  // it sits open on the admin's screen. Two cheap signals bring it back in
  // line: the "Payment received" push, and the app returning to the front.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushNotifications.instance.refreshSignal.addListener(quietRefresh);
  }

  @override
  void dispose() {
    PushNotifications.instance.refreshSignal.removeListener(quietRefresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) quietRefresh();
  }

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Future<void> _generateBills() async {
    final society = SocietyRepository.instance.society;
    if (society == null) return;
    final flats = society.allFlats;
    final amountController = TextEditingController();
    final titleController = TextEditingController();
    String? flatId;
    String kind = 'RENT'; // 'RENT' | 'MANUAL' (maintenance) | 'OTHER'
    DateTime selectedDate = DateTime.now();
    String dateLabel(DateTime d) =>
        '${d.day} ${_months[d.month - 1]} ${d.year}';
    String amountLabel() => switch (kind) {
          'RENT' => 'Rent amount',
          'MANUAL' => 'Maintenance amount',
          _ => 'Amount',
        };

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
                Text('Generate Bill',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    kind == 'OTHER'
                        ? 'A one-off charge for the chosen month.'
                        : 'Set the amount from the chosen month — it then '
                            'auto-generates each month after.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: flatId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Flat',
                    hintText: 'Choose flat',
                    prefixIcon: Icon(Icons.home_work_outlined),
                  ),
                  items: [
                    for (final f in flats)
                      DropdownMenuItem<String>(
                          value: f.id, child: Text('Flat ${f.number}')),
                  ],
                  onChanged: (v) => setSheet(() => flatId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'RENT', child: Text('Rent')),
                    DropdownMenuItem(
                        value: 'MANUAL', child: Text('Maintenance')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (v) =>
                      setSheet(() => kind = v ?? 'RENT'),
                ),
                if (kind == 'OTHER') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Charge name',
                      hintText: 'e.g. Parking, Water, Event fund',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035, 12),
                      helpText: 'Select start date',
                    );
                    if (picked != null) {
                      setSheet(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start date',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(dateLabel(selectedDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: amountLabel(),
                    hintText: 'Enter amount',
                    prefixIcon: const Icon(Icons.currency_rupee),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  onPressed: () {
                    final amount =
                        double.tryParse(amountController.text.trim());
                    final title = titleController.text.trim();
                    if (flatId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Choose a flat')),
                      );
                      return;
                    }
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter an amount')),
                      );
                      return;
                    }
                    if (kind == 'OTHER' && title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Name the charge')),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                    final messenger = ScaffoldMessenger.of(context);
                    runMutation(() async {
                      final count = await _repo.generate(
                        startDate: selectedDate,
                        flatId: flatId!,
                        kind: kind,
                        amount: amount,
                        title: kind == 'OTHER' ? title : null,
                      );
                      messenger.showSnackBar(
                        SnackBar(
                            content: Text(count > 0
                                ? '$count bill${count == 1 ? '' : 's'} generated'
                                : 'Bill updated for that month')),
                      );
                    });
                  },
                  child: const Text('Generate'),
                ),
              ],
            ),
          );
        });
      },
    );

    // Controllers not disposed here — see note in residents_screen.dart.
    if (done == true && mounted) setState(() {});
  }

  Future<void> _confirmDelete(MaintenanceBill bill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.error),
        title: const Text('Delete bill?'),
        content: Text(
            'The ${bill.kindLabel.toLowerCase()} bill for Flat '
            '${bill.flatNumber} (${bill.period}) will be removed.'),
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
    if (ok == true) runMutation(() => _repo.delete(bill));
  }

  Future<void> _editBill(MaintenanceBill bill) async {
    final amountController =
        TextEditingController(text: bill.amount.toStringAsFixed(0));
    final titleController =
        TextEditingController(text: bill.isOther ? (bill.title ?? '') : '');
    DateTime selectedDate = bill.dueDate ?? DateTime.now();
    String dateLabel(DateTime d) =>
        '${d.day} ${_months[d.month - 1]} ${d.year}';

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
                Text('Edit bill',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Flat ${bill.flatNumber} · ${bill.kindLabel}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                if (bill.isOther) ...[
                  TextField(
                    controller: titleController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Charge name',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035, 12),
                      helpText: 'Select due date',
                    );
                    if (picked != null) {
                      setSheet(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due date',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(dateLabel(selectedDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  onPressed: () {
                    final amount =
                        double.tryParse(amountController.text.trim());
                    final title = titleController.text.trim();
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter an amount')),
                      );
                      return;
                    }
                    if (bill.isOther && title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name the charge')),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                    final messenger = ScaffoldMessenger.of(context);
                    runMutation(() async {
                      await _repo.update(
                        bill,
                        amount: amount,
                        date: selectedDate,
                        title: bill.isOther ? title : null,
                      );
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Bill updated')),
                      );
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        });
      },
    );

    // Controllers not disposed here — see note in residents_screen.dart.
    if (done == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Sibling tabs live in the same IndexedStack, so their FABs
        // coexist and would collide on the default hero tag.
        heroTag: 'admin-bills-fab',
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: _generateBills,
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('Generate'),
      ),
      body: buildLoad(() {
        // Paid bills move to the history screen; here we only show what's due.
        final bills = _repo.all.where((b) => !b.paid).toList();
        return Column(
        children: [
          // Summary row.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _SummaryCard(
                  label: 'Collected',
                  value: _money(_repo.totalCollected),
                  sub: '${_repo.paidCount} paid',
                  color: const Color(0xFF2E7D32),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const BillsHistoryScreen(),
                    ));
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(width: 12),
                _SummaryCard(
                  label: 'Pending',
                  value: _money(_repo.totalPending),
                  sub: '${_repo.pendingCount} unpaid',
                  color: const Color(0xFFD32F2F),
                ),
              ],
            ),
          ),
          Expanded(
            child: bills.isEmpty
                ? const EmptyMessage(
                    icon: Icons.check_circle_outline,
                    text: 'No pending bills.\nAll dues are cleared.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: bills.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final b = bills[index];
                      final theme = Theme.of(context);
                      return Material(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: b.paid
                                    ? const Color(0xFF2E7D32)
                                        .withValues(alpha: 0.12)
                                    : const Color(0xFFD32F2F)
                                        .withValues(alpha: 0.12),
                                child: Icon(
                                  b.paid
                                      ? Icons.check_circle
                                      : Icons.pending_outlined,
                                  color: b.paid
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFD32F2F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text('Flat ${b.flatNumber}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
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
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (v) {
                                  if (v == 'paid') {
                                    runMutation(
                                        () => _repo.setPaid(b, !b.paid));
                                  } else if (v == 'edit') {
                                    _editBill(b);
                                  } else if (v == 'delete') {
                                    _confirmDelete(b);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'paid',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline,
                                            size: 20, color: _accent),
                                        const SizedBox(width: 10),
                                        Text(b.paid ? 'Unpaid' : 'Paid'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined,
                                            size: 20, color: _accent),
                                        const SizedBox(width: 10),
                                        const Text('Edit'),
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
        );
      }),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;

  /// When set, the card is tappable (e.g. Collected opens payment history).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style:
                            theme.textTheme.bodySmall?.copyWith(color: color)),
                    if (onTap != null) ...[
                      const Spacer(),
                      Icon(Icons.chevron_right, size: 18, color: color),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(value,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold, color: color)),
                Text(sub, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
