part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Hinweise zu Voraussetzungen der Vertrautenbindung
// ---------------------------------------------------------------------------

/// Bestätigt den Aurapanzer des Vertrauten (WdZ S. 125).
///
/// Zeigt Kosten und offene Voraussetzungen (AE 20, freie AP); diese gehen nur
/// per Meisterentscheid. Liefert, ob der Meisterentscheid gesetzt wurde.
class _VertrautenAurapanzerDialog extends StatefulWidget {
  const _VertrautenAurapanzerDialog({required this.companion});

  final HeroCompanion companion;

  @override
  State<_VertrautenAurapanzerDialog> createState() =>
      _VertrautenAurapanzerDialogState();
}

class _VertrautenAurapanzerDialogState
    extends State<_VertrautenAurapanzerDialog> {
  bool _meisterentscheid = false;

  @override
  Widget build(BuildContext context) {
    final offen = vertrautenAurapanzerVoraussetzungen(widget.companion);
    final theme = Theme.of(context);
    return AdaptiveInputDialog(
      title: 'Aurapanzer',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kostet $kVertrautenAurapanzerKosten AP des Vertrauten; '
            'Voraussetzung ist AE $kVertrautenAurapanzerMindestAsp '
            '(WdZ S. 125).',
          ),
          for (final hinweis in offen)
            Text(
              hinweis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          if (offen.isNotEmpty)
            CheckboxListTile(
              key: const ValueKey<String>('vertrauten-aurapanzer-meister'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _meisterentscheid,
              title: const Text('Trotzdem erwerben (Meisterentscheid)'),
              onChanged: (v) => setState(() => _meisterentscheid = v ?? false),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('vertrauten-aurapanzer-bestaetigen'),
          onPressed: offen.isEmpty || _meisterentscheid
              ? () => Navigator.of(context).pop<bool>(_meisterentscheid)
              : null,
          child: const Text('Erwerben'),
        ),
      ],
    );
  }
}

/// Zeigt fehlende Voraussetzungen der Bindung und die Freigabe per
/// Meisterentscheid.
///
/// Sperrt nie selbst: ohne Hinweise bleibt das Widget leer, sonst gibt der
/// Dialog „Binden“ erst nach dem Häkchen frei.
class _BindungHinweise extends StatelessWidget {
  const _BindungHinweise({
    required this.hinweise,
    required this.meisterentscheid,
    required this.onChanged,
  });

  final List<String> hinweise;
  final bool meisterentscheid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (hinweise.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey<String>('vertrauten-bindung-hinweise'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final hinweis in hinweise)
          Text(
            hinweis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        CheckboxListTile(
          key: const ValueKey<String>('vertrauten-bindung-meisterentscheid'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: meisterentscheid,
          title: const Text('Trotzdem binden (Meisterentscheid)'),
          onChanged: (v) => onChanged(v ?? false),
        ),
      ],
    );
  }
}
