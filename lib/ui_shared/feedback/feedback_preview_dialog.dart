import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/feedback/feedback_result.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_submission.dart';

/// Bestätigt den exakt aus den strukturierten Feldern aufgebauten Issue-Inhalt.
class FeedbackPreviewDialog extends StatefulWidget {
  const FeedbackPreviewDialog({
    super.key,
    required this.submission,
    required this.onSend,
  });

  final FeedbackSubmission submission;
  final Future<FeedbackResult> Function() onSend;

  @override
  State<FeedbackPreviewDialog> createState() => _FeedbackPreviewDialogState();
}

class _FeedbackPreviewDialogState extends State<FeedbackPreviewDialog> {
  bool _sending = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Öffentliche Vorschau'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Diese Angaben werden als öffentlich lesbares GitHub-Issue gespeichert.',
              ),
              const SizedBox(height: 16),
              SelectableText(formatFeedbackPreview(widget.submission)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Zurück'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: const Text('Jetzt senden'),
        ),
      ],
    );
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await widget.onSend();
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Feedback konnte nicht gesendet werden. Die Eingaben bleiben erhalten.';
      });
    }
  }
}

/// Formatiert die lokale Vorschau mit denselben Abschnitten wie das Backend.
String formatFeedbackPreview(FeedbackSubmission submission) {
  final sections = <String>[];
  switch (submission) {
    case BugFeedbackSubmission bug:
      sections.addAll([
        '## Tatsächliches Verhalten\n${bug.actualBehavior.trim()}',
        '## Erwartetes Verhalten\n${bug.expectedBehavior.trim()}',
        if (bug.reproductionSteps?.trim().isNotEmpty ?? false)
          '## Schritte zur Reproduktion\n${bug.reproductionSteps!.trim()}',
      ]);
    case FeatureFeedbackSubmission feature:
      sections.addAll([
        '## Zu lösendes Problem\n${feature.problem.trim()}',
        '## Gewünschtes Verhalten\n${feature.desiredBehavior.trim()}',
      ]);
    case RulesFeedbackSubmission rules:
      sections.addAll([
        '## Regelfrage\n${rules.question.trim()}',
        if (rules.source?.trim().isNotEmpty ?? false)
          '## Regelwerk/Fundstelle\n${rules.source!.trim()}',
        if (rules.interpretation?.trim().isNotEmpty ?? false)
          '## Eigene Auslegung\n${rules.interpretation!.trim()}',
      ]);
  }
  final metadata = submission.metadata;
  sections.add(
    '## App-Kontext\n'
    '- Bereich: ${submission.surface.label}\n'
    '- Version: ${metadata.appVersion}+${metadata.buildNumber}\n'
    '- Build: ${metadata.commit.isEmpty ? 'lokal' : metadata.commit}\n'
    '- Bauzeit: ${metadata.builtAt.isEmpty ? 'unbekannt' : metadata.builtAt}\n'
    '- Plattform: ${metadata.platform}',
  );
  if (submission case BugFeedbackSubmission(diagnostics: final diagnostics?)) {
    sections.add(
      '## Diagnose\n'
      '- Betriebssystem: ${diagnostics.operatingSystem} '
      '${diagnostics.operatingSystemVersion}\n'
      '- Sprache: ${diagnostics.locale}\n'
      '- Fenster: ${diagnostics.viewportWidth} × '
      '${diagnostics.viewportHeight} @ ${diagnostics.devicePixelRatio}\n'
      '- Layout: ${diagnostics.layoutClass}\n'
      '- Oberfläche: ${diagnostics.interfaceVariant}, '
      '${diagnostics.brightness}, ${diagnostics.tableMode}\n'
      '- Firebase verfügbar: ${diagnostics.firebaseAvailable ? 'ja' : 'nein'}\n'
      '- Angemeldet: ${diagnostics.authenticated ? 'ja' : 'nein'}',
    );
  }
  final title = _neutralizeMentions(submission.title.trim());
  final body = _neutralizeMentions(sections.join('\n\n'));
  return 'Issue-Titel\n$title\n\nIssue-Text\n$body';
}

// GitHub-Erwähnungen müssen bereits in der Vorschau so neutralisiert sein wie serverseitig.
String _neutralizeMentions(String value) {
  return value.replaceAllMapped(
    RegExp(r'@(?=[\p{L}\p{N}_-])', unicode: true),
    (_) => '@\u200b',
  );
}
