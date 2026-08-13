import 'package:flutter/material.dart';

import '../models/complaint.dart';

/// The icon that stands for a complaint category. Falls back to a generic one
/// so a category added later still renders.
IconData complaintCategoryIcon(String category) {
  switch (category) {
    case 'Plumbing':
      return Icons.plumbing;
    case 'Electrical':
      return Icons.bolt;
    case 'Elevator':
      return Icons.elevator_outlined;
    case 'Cleaning':
      return Icons.cleaning_services_outlined;
    case 'Security':
      return Icons.shield_outlined;
    default:
      return Icons.report_problem_outlined;
  }
}

/// Open / In progress / Resolved, in the status's own colour.
class ComplaintStatusChip extends StatelessWidget {
  const ComplaintStatusChip({super.key, required this.status});

  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One complaint, the same everywhere it is listed — the resident's own list,
/// the admin's queue and the maintenance staff's tasks. Each screen only
/// chooses which of the trailing details are worth showing.
class ComplaintCard extends StatelessWidget {
  const ComplaintCard({
    super.key,
    required this.complaint,
    this.onTap,
    this.showFlat = true,
    this.showAssignee = true,
  });

  final Complaint complaint;
  final VoidCallback? onTap;

  /// The resident already knows the flat — it is their own.
  final bool showFlat;
  final bool showAssignee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final c = complaint;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Small tinted square: the category at a glance, in the colour of
              // the status, without taking a whole column of height.
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: c.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  complaintCategoryIcon(c.category),
                  size: 17,
                  color: c.status.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ComplaintStatusChip(status: c.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              c.category,
                              if (showFlat) 'Flat ${c.flatNumber}',
                              c.dateLabel,
                              if (showAssignee && c.assignedTo != null)
                                c.assignedTo!,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
