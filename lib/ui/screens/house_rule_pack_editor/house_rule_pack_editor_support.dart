part of '../house_rule_pack_editor_screen.dart';

/// Gemeinsame Textfeldeingabe für den Hausregel-Editor.
class _EditorTextField extends StatelessWidget {
  const _EditorTextField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.fieldKey,
    this.helper,
    this.minLines = 1,
    this.number = false,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String? helper;
  final int minLines;
  final bool number;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : null,
      keyboardType: number
          ? const TextInputType.numberWithOptions(signed: true)
          : (minLines == 1 ? TextInputType.text : TextInputType.multiline),
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        helperText: helper,
        alignLabelWithHint: minLines > 1,
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

/// JSON-Ansicht für das vollständige Hausregel-Manifest.
class _JsonTab extends StatelessWidget {
  const _JsonTab({
    required this.controller,
    required this.onChanged,
    required this.onFormat,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onFormat;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manifest-JSON',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Diese Ansicht zeigt das gesamte Paket-Manifest. Beim '
                  'Wechsel zurück in die strukturierte Ansicht wird das JSON '
                  'geparst und in die Formularfelder übernommen.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey<String>('house-rule-pack-json'),
                  controller: controller,
                  minLines: 22,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'JSON',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onFormat,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Formatieren'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sichtbarer Fehlerhinweis im Editor.
class _EditorMessageCard extends StatelessWidget {
  const _EditorMessageCard({
    required this.color,
    required this.textColor,
    required this.title,
    required this.message,
  });

  final Color color;
  final Color textColor;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zeigt den Status der letzten Manifest-Validierung an.
class _ValidationCard extends StatelessWidget {
  const _ValidationCard({required this.issues, required this.isStale});

  final List<HouseRulePackIssue> issues;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasIssues = issues.isNotEmpty;
    final backgroundColor = hasIssues
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final foregroundColor = hasIssues
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Validierung',
              style: theme.textTheme.titleMedium?.copyWith(
                color: foregroundColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isStale
                  ? 'Der Entwurf wurde seit der letzten Validierung geändert.'
                  : hasIssues
                  ? '${issues.length} Hinweis(e) gefunden.'
                  : 'Keine Hinweise aus der letzten Validierung.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
              ),
            ),
            if (issues.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final issue in issues.take(8)) ...[
                Text(
                  _formatIssue(issue),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (issues.length > 8)
                Text(
                  '… und ${issues.length - 8} weitere Hinweise.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foregroundColor,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatIssue(HouseRulePackIssue issue) {
    final parts = <String>[
      if (issue.packTitle.isNotEmpty) issue.packTitle,
      issue.message,
      if (issue.entryId.isNotEmpty) 'Eintrag: ${issue.entryId}',
    ];
    return parts.join(' · ');
  }
}
