part of '../hero_magic_tab.dart';

/// Sektion für magische Sonderfertigkeiten mit Beschreibungstext.
class _MagicSpecialAbilitiesSection extends StatelessWidget {
  const _MagicSpecialAbilitiesSection({
    required this.abilities,
    required this.isEditing,
    required this.onChanged,
    this.onEnsureEditing,
    this.catalogAbilities = const <SpecialAbilityDef>[],
    this.verfuegbareAp = 0,
    this.episch = false,
    this.onApKostenBestaetigt,
  });

  final List<MagicSpecialAbility> abilities;
  final bool isEditing;
  final void Function(List<MagicSpecialAbility>) onChanged;
  final Future<void> Function()? onEnsureEditing;

  /// Katalog magischer Sonderfertigkeiten fuer den Kosten-Abgleich beim
  /// Neuanlegen (Name-Match, best effort).
  final List<SpecialAbilityDef> catalogAbilities;
  final int verfuegbareAp;
  final bool episch;

  /// Wird aufgerufen, wenn beim Neuanlegen ein Erwerbs-Dialog bestaetigt
  /// wurde — der Aufrufer erhoeht damit `hero.apSpent`.
  final ValueChanged<int>? onApKostenBestaetigt;

  Future<void> _editAbility(BuildContext context, int index) async {
    final result = await showAdaptiveInputDialog<_MagicSpecialAbilityErwerb>(
      context: context,
      builder: (_) => _MagicSpecialAbilityDialog(initial: abilities[index]),
    );
    if (result == null) {
      return;
    }
    final updated = List<MagicSpecialAbility>.from(abilities);
    updated[index] = result.ability;
    onChanged(updated);
  }

  void _removeAbility(int index) {
    final updated = List<MagicSpecialAbility>.from(abilities);
    updated.removeAt(index);
    onChanged(updated);
  }

  Future<void> _addAbility(BuildContext context) async {
    await onEnsureEditing?.call();
    if (!context.mounted) {
      return;
    }
    final result = await showAdaptiveInputDialog<_MagicSpecialAbilityErwerb>(
      context: context,
      builder: (_) => _MagicSpecialAbilityDialog(
        catalogAbilities: catalogAbilities,
        verfuegbareAp: verfuegbareAp,
        episch: episch,
      ),
    );
    if (result == null) {
      return;
    }
    final updated = List<MagicSpecialAbility>.from(abilities)
      ..add(result.ability);
    onChanged(updated);
    if (result.apKosten > 0) {
      onApKostenBestaetigt?.call(result.apKosten);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: CodexSectionCard(
        title: 'Sonderfertigkeiten',
        subtitle:
            '${abilities.length} Einträge mit Beschreibung und Zusatzangaben.',
        trailing: FilledButton(
          key: const ValueKey<String>('magic-sf-add'),
          onPressed: () => _addAbility(context),
          child: const Text('+ Sonderfertigkeit'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (abilities.isEmpty)
              Text(
                'Keine Sonderfertigkeiten eingetragen.',
                style: theme.textTheme.bodySmall,
              ),
            ...abilities.asMap().entries.map((entry) {
              final index = entry.key;
              final ability = entry.value;
              final isLast = index == abilities.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ability.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (ability.beschreibung.isNotEmpty)
                            Text(
                              ability.beschreibung,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isEditing)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _editAbility(context, index),
                            tooltip: 'Bearbeiten',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _removeAbility(index),
                            tooltip: 'Löschen',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Ergebnis des Sonderfertigkeiten-Dialogs: die Eingabe plus AP-Kosten,
/// falls beim Neuanlegen ein Erwerbs-Dialog bestaetigt wurde (sonst `0`).
class _MagicSpecialAbilityErwerb {
  const _MagicSpecialAbilityErwerb({required this.ability, this.apKosten = 0});

  final MagicSpecialAbility ability;
  final int apKosten;
}

/// Dialog zum Anlegen und Bearbeiten einer magischen Sonderfertigkeit.
///
/// Beim Neuanlegen wird der eingegebene Name gegen den Katalog abgeglichen
/// und — falls ein Treffer gefunden wird — ein Erwerbs-Dialog mit den
/// bekannten AP-Kosten angeboten (vgl. `showErwerbDialog`).
class _MagicSpecialAbilityDialog extends StatefulWidget {
  const _MagicSpecialAbilityDialog({
    this.initial,
    this.catalogAbilities = const <SpecialAbilityDef>[],
    this.verfuegbareAp = 0,
    this.episch = false,
  });

  final MagicSpecialAbility? initial;
  final List<SpecialAbilityDef> catalogAbilities;
  final int verfuegbareAp;
  final bool episch;

  @override
  State<_MagicSpecialAbilityDialog> createState() =>
      _MagicSpecialAbilityDialogState();
}

class _MagicSpecialAbilityDialogState
    extends State<_MagicSpecialAbilityDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _beschreibungController;

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _beschreibungController = TextEditingController(
      text: widget.initial?.beschreibung ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _beschreibungController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    var apKosten = 0;
    if (_isNew) {
      final match = matchCatalogSpecialAbility(
        widget.catalogAbilities,
        name,
      );
      final erwerb = await showErwerbDialog(
        context: context,
        bezeichnung: name,
        kostenHinweis: match?.kosten,
        vorgeschlageneApKosten: match == null
            ? null
            : parseLeadingApAmount(match.kosten),
        verfuegbareAp: widget.verfuegbareAp,
        episch: widget.episch,
        epischerInhalt: match?.nurEpisch ?? false,
      );
      if (erwerb == null) {
        return;
      }
      apKosten = erwerb.apKosten;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(
      _MagicSpecialAbilityErwerb(
        ability: MagicSpecialAbility(
          name: name,
          beschreibung: _beschreibungController.text.trim(),
        ),
        apKosten: apKosten,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveInputDialog(
      title: _isNew
          ? 'Sonderfertigkeit hinzufügen'
          : 'Sonderfertigkeit bearbeiten',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'z. B. Kraftlinienmagie',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _beschreibungController,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 4,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}
