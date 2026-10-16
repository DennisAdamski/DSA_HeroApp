import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/feedback/feedback_result.dart';

/// Zeigt bestätigte und noch unklare Versandzustände ohne falsche Erfolgsmeldung.
class FeedbackResultView extends StatelessWidget {
  const FeedbackResultView({
    super.key,
    required this.result,
    this.onRefresh,
    this.refreshing = false,
  });

  final FeedbackResult result;
  final Future<void> Function()? onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    if (result.status == FeedbackResultStatus.created) {
      final reference = '#${result.issueNumber ?? '?'}';
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedback eingegangen: $reference',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (result.issueUrl != null) ...[
                const SizedBox(height: 8),
                SelectableText(result.issueUrl.toString()),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: result.issueUrl.toString()),
                  ),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Link kopieren'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (result.status == FeedbackResultStatus.failed) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Feedback konnte nicht gesendet werden. Die Meldung wurde nicht als Erfolg bestätigt.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }
    final processing = result.status == FeedbackResultStatus.processing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              processing
                  ? 'Feedback wird verarbeitet'
                  : 'Versandstatus noch unklar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText('Referenz: ${result.requestId}'),
            if (onRefresh != null)
              TextButton.icon(
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Status prüfen'),
              ),
          ],
        ),
      ),
    );
  }
}
