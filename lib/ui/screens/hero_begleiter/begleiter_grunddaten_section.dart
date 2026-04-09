part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Begleiter-Auswahl (Startseite des Tabs)
// ---------------------------------------------------------------------------

class _BegleiterAuswahlView extends StatelessWidget {
  const _BegleiterAuswahlView({
    required this.companions,
    required this.onSelect,
    required this.onAdd,
  });

  final List<HeroCompanion> companions;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (companions.isEmpty) {
      return _EmptyBegleiterHint(onAdd: onAdd);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Begleiter',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Begleiter'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final companion in companions)
                ActionChip(
                  avatar: const Icon(Icons.pets_outlined, size: 18),
                  label: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        companion.name.isEmpty ? 'Unbenannt' : companion.name,
                      ),
                      Text(
                        companion.typ.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => onSelect(companion.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leerzustand
// ---------------------------------------------------------------------------

class _EmptyBegleiterHint extends StatelessWidget {
  const _EmptyBegleiterHint({
    required this.onAdd,
  });

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.pets_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine Begleiter vorhanden.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Begleiter hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Begleiter-Detailansicht (mit Zurueck-Navigation)
// ---------------------------------------------------------------------------

class _BegleiterDetailView extends StatelessWidget {
  const _BegleiterDetailView({
    required this.companion,
    required this.isEditing,
    required this.canRaise,
    required this.onBack,
    required this.onChanged,
    required this.onDelete,
    required this.onSaveImmediate,
    this.onRaiseRegular,
    this.onRaisePool,
    this.onRaiseAngriffAt,
    this.onRaiseAngriffPa,
    this.onRaiseRk,
    this.vertrautenmagieKategorie,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final bool canRaise;
  final VoidCallback onBack;
  final ValueChanged<HeroCompanion> onChanged;
  final VoidCallback onDelete;
  final ValueChanged<HeroCompanion> onSaveImmediate;
  final void Function(String key, String label)? onRaiseRegular;
  final void Function(String key, String label)? onRaisePool;
  final void Function(String attackId)? onRaiseAngriffAt;
  final void Function(String attackId)? onRaiseAngriffPa;
  final VoidCallback? onRaiseRk;
  final HeroRitualCategory? vertrautenmagieKategorie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Navigationsleiste mit Zurueck-Button
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Zurück zur Übersicht',
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  companion.name.isEmpty ? 'Unbenannt' : companion.name,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Begleiter löschen',
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GrunddatenSection(
                  companion: companion,
                  isEditing: isEditing,
                  onChanged: onChanged,
                ),
                const SizedBox(height: _sectionSpacing),
                _EigenschaftenSection(
                  companion: companion,
                  isEditing: isEditing,
                  onChanged: onChanged,
                  onRaiseRegular: onRaiseRegular,
                ),
                const SizedBox(height: _sectionSpacing),
                _KampfWerteSection(
                  companion: companion,
                  isEditing: isEditing,
                  onChanged: onChanged,
                  onRaiseRegular: onRaiseRegular,
                  onRaisePool: onRaisePool,
                ),
                const SizedBox(height: _sectionSpacing),
                _AngriffseSection(
                  companion: companion,
                  isEditing: isEditing,
                  onChanged: onChanged,
                  onRaiseAngriffAt: onRaiseAngriffAt,
                  onRaiseAngriffPa: onRaiseAngriffPa,
                ),
                const SizedBox(height: _sectionSpacing),
                _LepSection(
                  companion: companion,
                  isEditing: isEditing,
                  onChanged: onChanged,
                  onRaisePool: onRaisePool,
                ),
                const SizedBox(height: _sectionSpacing),
                _WeiteresSection(
                  companion: companion,
                  isEditing: isEditing,
                  onChanged: onChanged,
                ),
                const SizedBox(height: _sectionSpacing),
                _VorNachteileSection(
                  companion: companion,
                  isEditing: isEditing,
                  onChanged: onChanged,
                ),
                const SizedBox(height: _sectionSpacing),
                _SonderfertigkeitenSection(
                  companion: companion,
                  isEditing: isEditing,
                  onChanged: onChanged,
                ),
                const SizedBox(height: _sectionSpacing),
                _MerkmaleSection(
                  companion: companion,
                  isEditing: isEditing,
                  onChanged: onChanged,
                ),
                if (companion.typ == BegleiterTyp.vertrauter &&
                    vertrautenmagieKategorie != null) ...[
                  const SizedBox(height: _sectionSpacing),
                  _VertrautenmagieSection(
                    kategorie: vertrautenmagieKategorie!,
                    isEditing: isEditing,
                    onRaiseRk: onRaiseRk,
                    rkSteigerung: companionSteigerung(companion, 'rk'),
                    onChanged: (updatedKat) => onChanged(
                      companion.copyWith(
                        ritualCategories: companion.ritualCategories
                            .map(
                              (c) =>
                                  c.id == updatedKat.id ? updatedKat : c,
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: _sectionSpacing),
                _RuestungSection(
                  companion: companion,
                  isEditing: isEditing,
                  onChanged: onChanged,
                ),
                const SizedBox(height: _sectionSpacing),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Grunddaten
// ---------------------------------------------------------------------------

class _GrunddatenSection extends StatelessWidget {
  const _GrunddatenSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Grunddaten'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: EditAwareField(
                label: 'Name',
                value: companion.name,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(name: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: EditAwareField(
                label: 'Gattung',
                value: companion.gattung,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(gattung: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: EditAwareField(
                label: 'Familie',
                value: companion.familie,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(familie: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: isEditing
                  ? InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Typ',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: DropdownButton<BegleiterTyp>(
                        value: companion.typ,
                        isExpanded: true,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: BegleiterTyp.values
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (t) {
                          if (t != null) {
                            onChanged(companion.copyWith(typ: t));
                          }
                        },
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Typ',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(companion.typ.label),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: _innerFieldSpacing),
        EditAwareField(
          label: 'Aussehen',
          value: companion.aussehen,
          isEditing: isEditing,
          maxLines: 3,
          onChanged: (v) => onChanged(companion.copyWith(aussehen: v)),
        ),
        const SizedBox(height: _innerFieldSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EditAwareField(
                label: 'Gewicht',
                value: companion.gewicht,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(gewicht: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: EditAwareField(
                label: 'Größe',
                value: companion.groesse,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(groesse: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: EditAwareField(
                label: 'Alter / Geburtsjahr',
                value: companion.alter,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(alter: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
