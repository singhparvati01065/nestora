import 'package:flutter/material.dart';

import '../api/api_client.dart';

/// Shows an app content page (FAQ / Terms / Privacy / About / Contact) fetched
/// live from the backend, so the super-admin can edit it without an app update.
class ContentScreen extends StatefulWidget {
  const ContentScreen({
    super.key,
    required this.contentKey,
    required this.title,
    required this.accent,
  });

  final String contentKey;
  final String title;
  final Color accent;

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  bool _loading = true;
  String _title = '';
  String _body = '';

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.instance.get('/content/${widget.contentKey}')
          as Map<String, dynamic>;
      _title = (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : widget.title;
      _body = (data['body'] as String?) ?? '';
    } catch (_) {
      // leave empty; UI shows a fallback
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: widget.accent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _body.trim().isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Nothing here yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    Text(_body,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                  ],
                ),
    );
  }
}

/// The content pages the app links to, in display order.
const List<({String key, String title})> kContentPages = [
  (key: 'faq', title: 'FAQ'),
  (key: 'terms', title: 'Terms & Conditions'),
  (key: 'privacy', title: 'Privacy Policy'),
  (key: 'about', title: 'About Us'),
  (key: 'contact', title: 'Contact Us'),
];
