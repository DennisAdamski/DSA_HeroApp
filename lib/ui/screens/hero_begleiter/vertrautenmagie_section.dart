part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Vertrautenmagie-Sektion (nur fuer Vertrauten-Typ)
// ---------------------------------------------------------------------------

/// Liest den Ritualprobe-Text aus den additionalFieldValues eines Rituals.
String _ritualProbeText(HeroRitualEntry ritual) {
  final probe = ritual.additionalFieldValues
      .where((f) => f.fieldDefId == 'ritualprobe')
      .firstOrNull;
  if (probe == null || probe.attributeCodes.isEmpty) return '';
  return probe.attributeCodes.join('/');
}

class _VertrautenmagieSection extends StatelessWidget {
  const _VertrautenmagieSection({
    required this.kategorie,
    required this.isEditing,
    required this.onChanged,
    this.onRaiseRk,
    this.rkSteigerung = 0,
  });

  final HeroRitualCategory kategorie;
  final bool isEditing;
  final ValueChanged<HeroRitualCategory> onChanged;
  final VoidCallback? onRaiseRk;
  final int rkSteigerung;

  void _removeRitual(int index) {
    final updated = List<HeroRitualEntry>.from(kategorie.rituals)
      ..removeAt(index);
    onChanged(kategorie.copyWith(rituals: updated));
  }

  Future<void> _addRitual(BuildContext context) async {
    final aktiviert = kategorie.rituals.map((r) => r.name).toSet();
    final selected = await showAdaptiveDetailSheet<HeroRitualEntry>(
      context: context,
      builder: (_) =>
          _VertrautenmagiePickerDialog(aktiviert: aktiviert),
    );
    if (selected == null) return;
    onChanged(
      kategorie.copyWith(rituals: [...kategorie.rituals, selected]),
    );
  }

  void _showDetail(BuildContext context, HeroRitualEntry ritual) {
    showAdaptiveDetailSheet<void>(
      context: context,
      builder: (_) => _VertrautenmagieDetailDialog(ritual: ritual),
    );
  }

  @override
  Widget build(BuildContext context) {
    final basisRk = kategorie.ownKnowledge?.value ?? 0;
    final effRk = basisRk + rkSteigerung;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Vertrautenmagie'),
        isEditing
            ? Row(
                children: [
                  Expanded(
                    child: EditAwareIntField(
                      label: 'Ritualkenntnis (RK)',
                      value: basisRk,
                      isEditing: true,
                      onChanged: (v) => onChanged(
                        kategorie.copyWith(
                          ownKnowledge: (kategorie.ownKnowledge ??
                                  const HeroRitualKnowledge(
                                    name: 'Vertrautenmagie',
                                    value: 0,
                                    learningComplexity: 'E',
                                  ))
                              .copyWith(value: v ?? 0),
                        ),
                      ),
                    ),
                  ),
                  if (onRaiseRk != null)
                    _RaiseIconButton(
                      tooltip: 'RK steigern',
                      onPressed: onRaiseRk!,
                    ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(
                      'RK: $effRk',
                      style: rkSteigerung > 0
                          ? TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                  ),
                  if (onRaiseRk != null)
                    _RaiseIconButton(
                      tooltip: 'RK steigern',
                      onPressed: onRaiseRk!,
                    ),
                ],
              ),
        const SizedBox(height: 8),
        ...kategorie.rituals.asMap().entries.map(
          (entry) => _RitualListTile(
            ritual: entry.value,
            isEditing: isEditing,
            onTap: isEditing
                ? null
                : () => _showDetail(context, entry.value),
            onDelete:
                isEditing ? () => _removeRitual(entry.key) : null,
          ),
        ),
        if (isEditing) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => _addRitual(context),
            icon: const Icon(Icons.add),
            label: const Text('Ritual hinzufügen'),
          ),
        ],
      ],
    );
  }
}

class _RitualListTile extends StatelessWidget {
  const _RitualListTile({
    required this.ritual,
    required this.isEditing,
    this.onTap,
    this.onDelete,
  });

  final HeroRitualEntry ritual;
  final bool isEditing;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final probe = _ritualProbeText(ritual);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(ritual.name),
      subtitle: probe.isNotEmpty ? Text(probe) : null,
      trailing: isEditing
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// Picker-Dialog: zeigt verfuegbare Rituale aus dem Preset.
class _VertrautenmagiePickerDialog extends StatelessWidget {
  const _VertrautenmagiePickerDialog({required this.aktiviert});

  final Set<String> aktiviert;

  @override
  Widget build(BuildContext context) {
    final verfuegbar = kVertrautenmagiePresetCategory.rituals;
    return AlertDialog(
      title: const Text('Ritual hinzufügen'),
      content: SizedBox(
        width: kDialogWidthSmall,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: verfuegbar.length,
          itemBuilder: (ctx, i) {
            final ritual = verfuegbar[i];
            final istAktiv = aktiviert.contains(ritual.name);
            return ListTile(
              dense: true,
              title: Text(
                ritual.name,
                style: istAktiv
                    ? TextStyle(
                        color:
                            Theme.of(ctx).colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              subtitle: Text(_ritualProbeText(ritual)),
              enabled: !istAktiv,
              onTap: istAktiv
                  ? null
                  : () => Navigator.of(ctx).pop(ritual),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}

// Detail-Dialog: zeigt alle Felder eines Rituals.
class _VertrautenmagieDetailDialog extends StatelessWidget {
  const _VertrautenmagieDetailDialog({required this.ritual});

  final HeroRitualEntry ritual;

  String _fieldValue(String fieldDefId) =>
      ritual.additionalFieldValues
          .where((f) => f.fieldDefId == fieldDefId)
          .firstOrNull
          ?.textValue ??
      '';

  @override
  Widget build(BuildContext context) {
    final probe = _ritualProbeText(ritual);
    final rows = <(String, String)>[
      if (probe.isNotEmpty) ('Ritualprobe', probe),
      if (ritual.technik.isNotEmpty) ('Technik', ritual.technik),
      if (ritual.zauberdauer.isNotEmpty)
        ('Zauberdauer', ritual.zauberdauer),
      if (ritual.kosten.isNotEmpty) ('Ritualkosten', ritual.kosten),
      if (ritual.zielobjekt.isNotEmpty)
        ('Zielobjekt', ritual.zielobjekt),
      if (ritual.reichweite.isNotEmpty)
        ('Reichweite', ritual.reichweite),
      if (ritual.wirkungsdauer.isNotEmpty)
        ('Wirkungsdauer', ritual.wirkungsdauer),
      if (ritual.merkmale.isNotEmpty) ('Merkmale', ritual.merkmale),
      if (_fieldValue('erschwernis').isNotEmpty)
        ('Erschwernis', _fieldValue('erschwernis')),
    ];
    return AlertDialog(
      title: Text(ritual.name),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ritual.wirkung.isNotEmpty) ...[
                Text(ritual.wirkung),
                const SizedBox(height: 12),
              ],
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          '${row.$1}:',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: Text(row.$2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
