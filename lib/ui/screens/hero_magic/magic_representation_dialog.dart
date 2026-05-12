part of '../hero_magic_tab.dart';

class _MerkmaleLine extends StatelessWidget {
  const _MerkmaleLine({
    super.key,
    required this.zauberMerkmale,
    required this.heldMerkmalskenntnisse,
  });

  final List<String> zauberMerkmale;
  final List<String> heldMerkmalskenntnisse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (zauberMerkmale.isEmpty) {
      return Text(
        'Merkmale: -',
        style: theme.textTheme.bodyMedium,
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Merkmale:', style: theme.textTheme.bodyMedium),
        for (final merkmal in zauberMerkmale)
          _MerkmalChip(
            merkmal: merkmal,
            matches: heldMerkmalskenntnisse.contains(merkmal),
          ),
      ],
    );
  }
}

class _MerkmalChip extends StatelessWidget {
  const _MerkmalChip({required this.merkmal, required this.matches});

  final String merkmal;
  final bool matches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium;
    if (matches) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          merkmal,
          style: base?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }
    return Text(merkmal, style: base);
  }
}

Future<SpellAvailabilityEntry?> _showSpellRepresentationDialog({
  required BuildContext context,
  required String spellName,
  required List<SpellAvailabilityEntry> entries,
  required String baseLernkomplexitaet,
  required List<String> zauberMerkmale,
  required List<String> heldMerkmalskenntnisse,
}) {
  return showAdaptiveDetailSheet<SpellAvailabilityEntry>(
    context: context,
    builder: (dialogContext) {
      return _SpellRepresentationDialog(
        spellName: spellName,
        entries: entries,
        baseLernkomplexitaet: baseLernkomplexitaet,
        zauberMerkmale: zauberMerkmale,
        heldMerkmalskenntnisse: heldMerkmalskenntnisse,
      );
    },
  );
}

class _SpellRepresentationDialog extends StatefulWidget {
  const _SpellRepresentationDialog({
    required this.spellName,
    required this.entries,
    required this.baseLernkomplexitaet,
    required this.zauberMerkmale,
    required this.heldMerkmalskenntnisse,
  });

  final String spellName;
  final List<SpellAvailabilityEntry> entries;
  final String baseLernkomplexitaet;
  final List<String> zauberMerkmale;
  final List<String> heldMerkmalskenntnisse;

  @override
  State<_SpellRepresentationDialog> createState() =>
      _SpellRepresentationDialogState();
}

class _SpellRepresentationDialogState
    extends State<_SpellRepresentationDialog> {
  SpellAvailabilityEntry? _selectedEntry;

  @override
  void initState() {
    super.initState();
    if (widget.entries.isNotEmpty) {
      _selectedEntry = widget.entries.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchingMerkmale = widget.zauberMerkmale
        .where(widget.heldMerkmalskenntnisse.contains)
        .toList(growable: false);
    final effLernkomplexitaet = effectiveSpellLernkomplexitaet(
      basisKomplexitaet: widget.baseLernkomplexitaet,
      istHauszauber: false,
      zauberMerkmale: widget.zauberMerkmale,
      heldMerkmalskenntnisse: widget.heldMerkmalskenntnisse,
      gifted: false,
    );
    final reduced = effLernkomplexitaet != widget.baseLernkomplexitaet;
    final lernkomplexitaetText = reduced
        ? 'Lernkomplexität: $effLernkomplexitaet '
              '(Basis ${widget.baseLernkomplexitaet}, '
              '-1 durch Merkmal "${matchingMerkmale.join(', ')}")'
        : 'Lernkomplexität: ${widget.baseLernkomplexitaet}';

    return AlertDialog(
      key: const ValueKey<String>('magic-spell-representation-dialog'),
      title: const Text('Zauber-Repräsentation wählen'),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.spellName,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _MerkmaleLine(
              key: const ValueKey<String>(
                'magic-spell-representation-merkmale',
              ),
              zauberMerkmale: widget.zauberMerkmale,
              heldMerkmalskenntnisse: widget.heldMerkmalskenntnisse,
            ),
            const SizedBox(height: 4),
            Text(
              lernkomplexitaetText,
              key: const ValueKey<String>(
                'magic-spell-representation-lernkomplexitaet',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final entry in widget.entries)
              ListTile(
                key: ValueKey<String>(
                  'magic-spell-representation-option-${entry.storageKey}',
                ),
                contentPadding: EdgeInsets.zero,
                title: Text(entry.displayLabel),
                subtitle: entry.isForeignRepresentation
                    ? const Text('Fremdrepr. (+2 Komplexitaet)')
                    : const Text('Eigenrepr.'),
                leading: Icon(
                  _selectedEntry?.storageKey == entry.storageKey
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                onTap: () {
                  setState(() {
                    _selectedEntry = entry;
                  });
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('magic-spell-representation-save'),
          onPressed: _selectedEntry == null
              ? null
              : () => Navigator.of(context).pop(_selectedEntry),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
