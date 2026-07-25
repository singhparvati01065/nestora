import 'package:flutter/material.dart';

import '../models/maintenance_bill.dart';

/// A small "Rent" / "Maintenance" pill so it's clear what a bill is for —
/// now that bills can be either. Shared by the admin and resident bill lists.
class BillKindTag extends StatelessWidget {
  const BillKindTag({super.key, required this.bill, required this.accent});

  final MaintenanceBill bill;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = bill.isRent
        ? accent
        : bill.isOther
            ? const Color(0xFFB26A00) // amber-brown for custom charges
            : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(bill.kindLabel,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
