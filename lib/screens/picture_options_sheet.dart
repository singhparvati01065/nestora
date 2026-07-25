import 'package:flutter/material.dart';

/// What the user chose in [showPictureOptions].
enum PictureAction { camera, gallery, remove }

/// Asks where a picture should come from — and offers to drop it.
///
/// Both the profile header and Society details put this behind their camera
/// badge, so the picture is changed the same way wherever you are.
///
/// Removing is confirmed here rather than by each caller, so the confirmation
/// can never be forgotten at one of the call sites. Returns null if the user
/// backs out at either step.
Future<PictureAction?> showPictureOptions(
  BuildContext context, {
  required Color accent,
  /// Hides Remove when there is no picture to remove.
  required bool canRemove,
  String title = 'Change picture',
}) async {
  final action = await _showSheet(context,
      accent: accent, canRemove: canRemove, title: title);
  if (action != PictureAction.remove || !context.mounted) return action;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
      title: const Text('Remove picture?'),
      content: const Text(
          'The picture goes back to the default icon. You can upload a new one '
          'any time.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  return confirmed == true ? PictureAction.remove : null;
}

Future<PictureAction?> _showSheet(
  BuildContext context, {
  required Color accent,
  required bool canRemove,
  required String title,
}) {
  return showModalBottomSheet<PictureAction>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            _Option(
              icon: Icons.photo_camera_outlined,
              label: 'Take a photo',
              accent: accent,
              onTap: () => Navigator.of(context).pop(PictureAction.camera),
            ),
            _Option(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              accent: accent,
              onTap: () => Navigator.of(context).pop(PictureAction.gallery),
            ),
            if (canRemove) ...[
              const Divider(height: 8),
              _Option(
                icon: Icons.delete_outline,
                label: 'Remove picture',
                accent: theme.colorScheme.error,
                danger: true,
                onTap: () => Navigator.of(context).pop(PictureAction.remove),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: accent, size: 21),
      ),
      title: Text(label,
          style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: danger ? accent : null)),
    );
  }
}
