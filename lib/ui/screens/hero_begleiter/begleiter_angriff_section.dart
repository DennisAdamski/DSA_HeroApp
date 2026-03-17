part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Angriffe
// ---------------------------------------------------------------------------

class _AngriffseSection extends StatelessWidget {
  const _AngriffseSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    final angriffe = companion.angriffe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Angriffe'),
        if (angriffe.isEmpty && !isEditing)
          Text(
            'Keine Angriffe eingetragen.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else if (angriffe.isNotEmpty) ...[
          // Kopfzeile
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Name',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    'DK',
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    'AT',
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    'PA',
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TP',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (isEditing) const SizedBox(width: 64),
              ],
            ),
          ),
          const Divider(height: 1),
          for (int i = 0; i < angriffe.length; i++) ...[
            _AngriffRow(
              angriff: angriffe[i],
              isEditing: isEditing,
              onEdit: () async {
                final ctx = context;
                if (!ctx.mounted) return;
                final result = await showAdaptiveDetailSheet<HeroCompanionAttack>(
                  context: ctx,
                  builder: (_) => _AngriffDialog(initial: angriffe[i]),
                );
                if (result != null) {
                  final next = List<HeroCompanionAttack>.from(angriffe);
                  next[i] = result;
                  onChanged(companion.copyWith(angriffe: next));
                }
              },
              onDelete: () {
                final next = List<HeroCompanionAttack>.from(angriffe)
                  ..removeAt(i);
                onChanged(companion.copyWith(angriffe: next));
              },
            ),
            if (i < angriffe.length - 1) const Divider(height: 1),
          ],
        ],
        if (isEditing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final result = await showAdaptiveDetailSheet<HeroCompanionAttack>(
                context: context,
                builder: (_) => const _AngriffDialog(),
              );
              if (result != null) {
                onChanged(
                  companion.copyWith(
                    angriffe: [...companion.angriffe, result],
                  ),
                );
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Angriff hinzufügen'),
          ),
        ],
      ],
    );
  }
}

class _AngriffRow extends StatelessWidget {
  const _AngriffRow({
    required this.angriff,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
  });

  final HeroCompanionAttack angriff;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  angriff.name.isEmpty ? '–' : angriff.name,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  angriff.dk.isEmpty ? '–' : angriff.dk,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  angriff.at != null ? '${angriff.at}' : '–',
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  angriff.pa != null ? '${angriff.pa}' : '–',
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(angriff.tp.isEmpty ? '–' : angriff.tp),
              ),
              if (isEditing) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Bearbeiten',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                  tooltip: 'Löschen',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
          if (angriff.beschreibung.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                angriff.beschreibung,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AngriffDialog extends StatefulWidget {
  const _AngriffDialog({this.initial});
  final HeroCompanionAttack? initial;

  @override
  State<_AngriffDialog> createState() => _AngriffDialogState();
}

class _AngriffDialogState extends State<_AngriffDialog> {
  late final TextEditingController _name;
  late final TextEditingController _dk;
  late final TextEditingController _at;
  late final TextEditingController _pa;
  late final TextEditingController _tp;
  late final TextEditingController _beschreibung;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _dk = TextEditingController(text: i?.dk ?? '');
    _at = TextEditingController(text: i?.at != null ? '${i!.at}' : '');
    _pa = TextEditingController(text: i?.pa != null ? '${i!.pa}' : '');
    _tp = TextEditingController(text: i?.tp ?? '');
    _beschreibung = TextEditingController(text: i?.beschreibung ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _dk.dispose();
    _at.dispose();
    _pa.dispose();
    _tp.dispose();
    _beschreibung.dispose();
    super.dispose();
  }

  HeroCompanionAttack _build() {
    return HeroCompanionAttack(
      id: widget.initial?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      dk: _dk.text.trim(),
      at: int.tryParse(_at.text.trim()),
      pa: int.tryParse(_pa.text.trim()),
      tp: _tp.text.trim(),
      beschreibung: _beschreibung.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    return AlertDialog(
      title: Text(isNew ? 'Angriff hinzufügen' : 'Angriff bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: _fieldSpacing),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dk,
                    decoration: const InputDecoration(
                      labelText: 'DK',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: _innerFieldSpacing),
                Expanded(
                  child: TextField(
                    controller: _at,
                    decoration: const InputDecoration(
                      labelText: 'AT',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: _innerFieldSpacing),
                Expanded(
                  child: TextField(
                    controller: _pa,
                    decoration: const InputDecoration(
                      labelText: 'PA',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: _fieldSpacing),
            TextField(
              controller: _tp,
              decoration: const InputDecoration(
                labelText: 'TP (z.B. 1W6+3)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: _fieldSpacing),
            TextField(
              controller: _beschreibung,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 3,
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
          onPressed: () => Navigator.of(context).pop(_build()),
          child: Text(isNew ? 'Hinzufügen' : 'Speichern'),
        ),
      ],
    );
  }
}
