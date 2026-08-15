import 'package:flutter/material.dart';

import 'avatar_image.dart';

/// The left side of a role's home app bar: their photo, their name and one
/// line of context (their flat, their post). Tapping it opens the Profile tab.
///
/// Home is the first screen of the app for every role, so its bar has no back
/// arrow to make room for — set `automaticallyImplyLeading: false` and
/// `centerTitle: false` on the [AppBar] that uses this, since the app-wide
/// theme centres titles.
class AppBarIdentity extends StatelessWidget {
  const AppBarIdentity({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.subtitle,
    required this.onTap,
  });

  final String name;
  final String? photoUrl;

  /// "Flat A101", "Main Gate" — null leaves the name on its own.
  final String? subtitle;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarImage(
              path: photoUrl,
              name: name,
              size: 36,
              background: Colors.white.withValues(alpha: 0.22),
              foreground: Colors.white,
              borderColor: Colors.white.withValues(alpha: 0.6),
              borderWidth: 1,
              fallbackIcon: Icons.person,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
