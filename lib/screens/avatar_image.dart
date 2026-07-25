import 'package:flutter/material.dart';

import '../api/api_client.dart';

/// A circular or rounded avatar that shows an uploaded image when there is one,
/// and a placeholder when there isn't.
///
/// Used for both people (user photo) and societies (logo), so it takes colours
/// and a placeholder rather than assuming a role.
class AvatarImage extends StatelessWidget {
  const AvatarImage({
    super.key,
    required this.path,
    required this.name,
    required this.size,
    this.background,
    this.foreground,
    this.borderColor,
    this.borderWidth = 0,
    this.radius,
    this.fallbackIcon,
  });

  /// Stored path (`/uploads/x.jpg`) or null. Resolved via [ApiClient.imageUrl].
  final String? path;

  /// Supplies the fallback initial when [fallbackIcon] is null.
  final String name;

  final double size;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final double borderWidth;

  /// Null makes it a circle; a value makes it a rounded square.
  final double? radius;

  /// Shown instead of the initial when there is no image — a building for a
  /// society, a person for a user. Null keeps the initial.
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = ApiClient.imageUrl(path);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final shape = radius == null ? BoxShape.circle : BoxShape.rectangle;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.surfaceContainerHighest,
        shape: shape,
        borderRadius: radius == null ? null : BorderRadius.circular(radius!),
        border: borderWidth > 0 && borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      alignment: Alignment.center,
      child: url == null
          ? _placeholder(theme, initial)
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              // A deleted file or an unreachable backend must not blow up the
              // screen — fall back to what we'd show without an image.
              errorBuilder: (_, _, _) => _placeholder(theme, initial),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _placeholder(theme, initial),
            ),
    );
  }

  Widget _placeholder(ThemeData theme, String initial) {
    final color = foreground ?? theme.colorScheme.onSurfaceVariant;
    if (fallbackIcon != null) {
      return Icon(fallbackIcon, color: color, size: size * 0.5);
    }
    return Text(
      initial,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        // Roughly proportional, so one widget covers 38px tiles and 84px
        // profile banners without a size argument per caller.
        fontSize: size * 0.42,
      ),
    );
  }
}
