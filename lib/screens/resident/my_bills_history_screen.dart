import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../api/session.dart';
import '../../data/bills_repository.dart';
import '../../data/society_repository.dart';
import '../../models/maintenance_bill.dart';
import '../../models/user_role.dart';
import '../../util/receipt_pdf.dart';
import '../bill_kind_tag.dart';
import '../loadable.dart';
import '../society_admin/admin_widgets.dart';

/// Read-only history of a resident's payments. Bills paid together (in one tap)
/// share a timestamp, so each payment is shown as ONE card — the combined
/// amount up top, with a Rent / Maintenance line-item breakdown below.
class MyBillsHistoryScreen extends StatefulWidget {
  const MyBillsHistoryScreen({super.key, required this.flat, this.onBack});

  final String flat;

  /// Optional: shown as a back arrow (this screen lives as a home tab, so there
  /// is nothing to pop — instead we hand control back to the home).
  final VoidCallback? onBack;

  @override
  State<MyBillsHistoryScreen> createState() => _MyBillsHistoryScreenState();
}

class _MyBillsHistoryScreenState extends State<MyBillsHistoryScreen>
    with LoadableState<MyBillsHistoryScreen> {
  final _repo = BillsRepository.instance;

  Color get _accent => UserRole.resident.color;

  @override
  Future<void> load() => _repo.load(flatId: Session.instance.user?.flatId);

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  /// Groups paid bills into payments by their (shared) paidAt, newest first.
  List<List<MaintenanceBill>> _payments() {
    final paid = _repo.paidForFlat(widget.flat);
    final groups = <String, List<MaintenanceBill>>{};
    for (final b in paid) {
      final key = b.paidAt?.toIso8601String() ?? 'unknown-${b.id}';
      groups.putIfAbsent(key, () => []).add(b);
    }
    final list = groups.values.toList();
    list.sort((a, b) {
      final da = a.first.paidAt, db = b.first.paidAt;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: buildLoad(() {
        final payments = _payments();
        final totalPaid = _repo
            .paidForFlat(widget.flat)
            .fold<double>(0, (s, b) => s + b.amount);
        if (payments.isEmpty) {
          return const EmptyMessage(
            icon: Icons.receipt_long_outlined,
            text: 'No payments yet.\nPaid bills will show up here.',
          );
        }
        return Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total paid • Flat ${widget.flat}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: _accent),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _money(totalPaid),
                    style: TextStyle(
                      color: _accent,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${payments.length} payment${payments.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: payments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _PaymentCard(
                  bills: payments[index],
                  accent: _accent,
                  flat: widget.flat,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// One payment: the combined amount and when it was paid, with each bill listed
/// underneath so rent vs maintenance stays clear.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.bills,
    required this.accent,
    required this.flat,
  });

  final List<MaintenanceBill> bills;
  final Color accent;
  final String flat;

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = Session.instance.user;
      final path = await BillReceipt.download(
        bills: bills,
        flat: flat,
        residentName: user?.name ?? 'Resident',
        phone: user?.phone ?? '',
        societyName: SocietyRepository.instance.society?.name,
      );
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Receipt saved to Downloads.'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFilex.open(path),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the receipt.')),
      );
    }
  }

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

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  String _when() {
    final d = bills.first.paidAt;
    if (d == null) return 'Date not recorded';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} ${d.year} • $h:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = bills.fold<double>(0, (s, b) => s + b.amount);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: date + paid badge, and the combined amount.
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: const Color(0xFF2E7D32),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _when(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _money(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ],
            ),
            if (bills.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 28),
                child: Text(
                  'Paid together • ${bills.length} bills',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Divider(height: 20),
            // Line items — one row per bill so rent vs maintenance is clear.
            ...bills.map(
              (b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    BillKindTag(bill: b, accent: accent),
                    const SizedBox(width: 8),
                    Text(b.period, style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text(
                      _money(b.amount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 15),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _download(context),
                icon: const Icon(Icons.download_outlined, size: 18),
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                label: const Text('Download'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
