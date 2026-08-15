import 'package:flutter/material.dart';

import '../api/api_client.dart';

/// Joins the hard line breaks a plain-text editor leaves inside a paragraph,
/// while keeping blank-line paragraph breaks and "- " bullets on their own
/// lines. Without this, text wrapped at 78 columns in the panel reads as a
/// ladder on a phone.
String _unwrap(String text) {
  final out = <String>[];
  for (final block in text.trim().split(RegExp(r'\n\s*\n'))) {
    final lines = block.split('\n').map((l) => l.trimRight()).toList();
    if (lines.any((l) => l.trimLeft().startsWith('- '))) {
      // A list: each bullet is its own line, continuations fold into it.
      final items = <String>[];
      for (final line in lines) {
        if (line.trimLeft().startsWith('- ') || items.isEmpty) {
          items.add(line.trim());
        } else {
          items[items.length - 1] = '${items.last} ${line.trim()}';
        }
      }
      out.add(items.join('\n'));
    } else {
      out.add(lines.map((l) => l.trim()).where((l) => l.isNotEmpty).join(' '));
    }
  }
  return out.join('\n\n');
}

/// One "1. Question" block and the lines under it.
class _QnA {
  _QnA(this.question, this.answer);

  final String question;
  final String answer;
}

/// Splits a body written as numbered questions into blocks. Returns an empty
/// list when the text is not shaped that way, so a page that is plain prose
/// simply falls back to prose.
List<_QnA> _parseQnA(String body) {
  final lines = body.split('\n');
  final items = <_QnA>[];
  final numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');

  String? question;
  final answer = <String>[];
  for (final line in lines) {
    final match = numbered.firstMatch(line);
    if (match != null) {
      if (question != null) {
        items.add(_QnA(question, answer.join('\n').trim()));
        answer.clear();
      }
      question = match.group(2)!.trim();
    } else if (question != null) {
      answer.add(line);
    }
  }
  if (question != null) items.add(_QnA(question, answer.join('\n').trim()));

  // A single block means the numbering was incidental, not a question list.
  return items.length > 1 ? items : const [];
}

/// Shows an app content page (FAQ / Terms / Privacy / About / Contact) fetched
/// live from the backend, so the super-admin can edit it without an app update.
///
/// The body is plain text, so it is laid out here rather than marked up:
/// numbered questions become expandable rows, "- " lines become bullets, and
/// blank lines separate paragraphs.
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
      final data =
          await ApiClient.instance.get('/content/${widget.contentKey}')
              as Map<String, dynamic>;
      _title = (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : widget.title;
      // The panel's textarea posts CRLF. A stray \r is not a line terminator
      // to `.` in a regex, so it silently broke question and heading detection
      // and every page fell back to plain prose.
      _body = ((data['body'] as String?) ?? '')
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
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
                child: Text(
                  'Nothing here yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Only the FAQ folds. Terms numbers its sections the same way, but a legal
    // page is meant to be read straight through, not opened one clause at a
    // time.
    if (widget.contentKey == 'faq') {
      final qna = _parseQnA(_body);
      if (qna.isNotEmpty) return _buildQnA(theme, qna);
    }

    // Prose: first line is the page's own heading, the rest are paragraphs.
    final blocks = _body.trim().split(RegExp(r'\n\s*\n'));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: blocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) => _Block(text: blocks[i], isFirst: i == 0),
    );
  }

  Widget _buildQnA(ThemeData theme, List<_QnA> items) {
    // The intro above the first numbered line, if the page has one.
    final intro = _body.split(RegExp(r'^\s*\d+[.)]\s', multiLine: true)).first;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: items.length + (intro.trim().isEmpty ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (intro.trim().isNotEmpty && i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              _unwrap(intro),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        final item = items[i - (intro.trim().isEmpty ? 0 : 1)];
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: Theme(
            // The default divider lines fight with the card edges.
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              iconColor: widget.accent,
              collapsedIconColor: theme.colorScheme.onSurfaceVariant,
              title: Text(
                item.question,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              children: [
                Text(
                  _unwrap(item.answer),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A paragraph of a prose page: a heading, a bullet list, or plain text.
class _Block extends StatelessWidget {
  const _Block({required this.text, required this.isFirst});

  final String text;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = text.trim().split('\n');
    final first = lines.first.trim();

    // "- " lines are a list.
    if (lines.every((l) => l.trimLeft().startsWith('- '))) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l.trimLeft().substring(2),
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    // A heading is short and unpunctuated. A paragraph that merely happens to
    // be the first one is NOT a heading — that turned the whole of a one
    // paragraph page into a title.
    final looksLikeHeading = first.length < 60 && !first.endsWith('.');

    if (lines.length == 1) {
      if (isFirst && looksLikeHeading) {
        return Text(
          first,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        );
      }
      return Text(
        first,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      );
    }

    if (looksLikeHeading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            first,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _unwrap(lines.sublist(1).join('\n')),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      );
    }

    return Text(
      _unwrap(text),
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
    );
  }
}

/// The content pages the app links to, in display order. The subtitle says
/// what is behind the row, the way every other row in the profile does.
/// Every page carries its own icon: five rows of the same document glyph told
/// the reader nothing about which row was which.
const List<({String key, String title, String subtitle, IconData icon})>
kContentPages = [
  (
    key: 'faq',
    title: 'FAQ',
    subtitle: 'Common questions, answered',
    icon: Icons.help_outline,
  ),
  (
    key: 'terms',
    title: 'Terms & Conditions',
    subtitle: 'The rules for using Nestora',
    icon: Icons.gavel_outlined,
  ),
  (
    key: 'privacy',
    title: 'Privacy Policy',
    subtitle: 'What we collect and why',
    icon: Icons.lock_outline,
  ),
  (
    key: 'about',
    title: 'About Us',
    subtitle: 'What Nestora is and who it is for',
    icon: Icons.business_outlined,
  ),
  (
    key: 'contact',
    title: 'Contact Us',
    subtitle: 'How to reach us',
    icon: Icons.mail_outline,
  ),
];
