part of 'package:dsa_heldenverwaltung/ui/screens/hero_reisebericht_tab.dart';

/// Einzelner Reisebericht-Eintrag mit typ-spezifischer Darstellung.
class _ReiseberichtEntryTile extends StatelessWidget {
  const _ReiseberichtEntryTile({
    required this.def,
    required this.allDefs,
    required this.draft,
    required this.isEditing,
    required this.onToggleChecked,
    required this.onUpdateDraft,
  });

  final ReiseberichtDef def;
  final List<ReiseberichtDef> allDefs;
  final HeroReisebericht draft;
  final bool isEditing;
  final void Function(String id) onToggleChecked;
  final void Function(HeroReisebericht) onUpdateDraft;

  @override
  Widget build(BuildContext context) {
    return switch (def.typ) {
      'checkpoint' => _CheckpointTile(
        def: def,
        draft: draft,
        isEditing: isEditing,
        onToggleChecked: onToggleChecked,
      ),
      'multi_requirement' => _MultiRequirementTile(
        def: def,
        draft: draft,
        isEditing: isEditing,
        onToggleChecked: onToggleChecked,
      ),
      'collection_fixed' => _CollectionFixedTile(
        def: def,
        draft: draft,
        isEditing: isEditing,
        onToggleChecked: onToggleChecked,
      ),
      'collection_open' => _CollectionOpenTile(
        def: def,
        draft: draft,
        isEditing: isEditing,
        onUpdateDraft: onUpdateDraft,
      ),
      'grouped_progression' => _GroupedProgressionTile(
        def: def,
        draft: draft,
        isEditing: isEditing,
        onToggleChecked: onToggleChecked,
      ),
      'grouped_progression_bonus' => _GroupedProgressionBonusTile(
        def: def,
        allDefs: allDefs,
        draft: draft,
      ),
      'meta' => _MetaTile(
        def: def,
        allDefs: allDefs,
        draft: draft,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ---------------------------------------------------------------------------
// Belohnungs-Chips (gemeinsam verwendet)
// ---------------------------------------------------------------------------

/// Zeigt AP-Badge und SE-Chips fuer einen Eintrag.
class _RewardChips extends StatelessWidget {
  const _RewardChips({this.ap = 0, this.seDefs = const [], this.talentBoni = const []});

  final int ap;
  final List<ReiseberichtSeDef> seDefs;
  final List<ReiseberichtTalentBonusDef> talentBoni;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (ap > 0) {
      chips.add(_SmallChip(label: '+$ap AP', color: Colors.amber));
    }
    for (final se in seDefs) {
      final label = se.ziel == 'wahl'
          ? 'SE: ${se.name}'
          : 'SE ${se.name}';
      chips.add(_SmallChip(label: label, color: Colors.blue));
    }
    for (final tb in talentBoni) {
      chips.add(_SmallChip(
        label: '+${tb.wert} ${tb.talentName}',
        color: Colors.green,
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(spacing: 4, runSpacing: 4, children: chips),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Fortschrittsanzeige (z. B. "3/5").
class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final done = current >= total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: done
            ? Colors.green.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$current/$total',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: done ? Colors.green : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Checkpoint
// ---------------------------------------------------------------------------

class _CheckpointTile extends StatelessWidget {
  const _CheckpointTile({
    required this.def,
    required this.draft,
    required this.isEditing,
    required this.onToggleChecked,
  });

  final ReiseberichtDef def;
  final HeroReisebericht draft;
  final bool isEditing;
  final void Function(String id) onToggleChecked;

  @override
  Widget build(BuildContext context) {
    final checked = draft.checkedIds.contains(def.id);
    final applied = draft.appliedRewardIds.contains(def.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: isEditing
            ? Checkbox(
                value: checked,
                onChanged: (_) => onToggleChecked(def.id),
              )
            : Icon(
                checked ? Icons.check_circle : Icons.circle_outlined,
                color: checked ? Colors.green : null,
              ),
        title: Text(
          def.name,
          style: TextStyle(
            decoration: applied ? TextDecoration.lineThrough : null,
            color: applied
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (def.beschreibung.isNotEmpty)
              Text(def.beschreibung, style: Theme.of(context).textTheme.bodySmall),
            _RewardChips(ap: def.ap, seDefs: def.se),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-Requirement
// ---------------------------------------------------------------------------

class _MultiRequirementTile extends StatelessWidget {
  const _MultiRequirementTile({
    required this.def,
    required this.draft,
    required this.isEditing,
    required this.onToggleChecked,
  });

  final ReiseberichtDef def;
  final HeroReisebericht draft;
  final bool isEditing;
  final void Function(String id) onToggleChecked;

  @override
  Widget build(BuildContext context) {
    final doneCount =
        def.anforderungen.where((r) => draft.checkedIds.contains(r.id)).length;
    final totalCount = def.anforderungen.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ExpansionTile(
        leading: Icon(
          doneCount >= totalCount ? Icons.check_circle : Icons.circle_outlined,
          color: doneCount >= totalCount ? Colors.green : null,
        ),
        title: Row(
          children: [
            Expanded(child: Text(def.name)),
            _ProgressIndicator(current: doneCount, total: totalCount),
          ],
        ),
        subtitle: def.beschreibung.isNotEmpty
            ? Text(def.beschreibung, style: Theme.of(context).textTheme.bodySmall)
            : null,
        children: [
          for (final req in def.anforderungen)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              leading: isEditing
                  ? Checkbox(
                      value: draft.checkedIds.contains(req.id),
                      onChanged: (_) => onToggleChecked(req.id),
                    )
                  : Icon(
                      draft.checkedIds.contains(req.id)
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: draft.checkedIds.contains(req.id)
                          ? Colors.green
                          : null,
                    ),
              title: Text(req.name),
              subtitle: _RewardChips(ap: req.ap, seDefs: req.se),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collection Fixed
// ---------------------------------------------------------------------------

class _CollectionFixedTile extends StatelessWidget {
  const _CollectionFixedTile({
    required this.def,
    required this.draft,
    required this.isEditing,
    required this.onToggleChecked,
  });

  final ReiseberichtDef def;
  final HeroReisebericht draft;
  final bool isEditing;
  final void Function(String id) onToggleChecked;

  @override
  Widget build(BuildContext context) {
    final checkedCount = countFixedCollectionChecked(def, draft);
    final totalCount = def.festeEintraege.length;
    final thresholdMet = isFixedCollectionThresholdMet(def, draft);
    final bonusMet = isFixedCollectionBonusMet(def, draft);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ExpansionTile(
        leading: Icon(
          checkedCount >= totalCount ? Icons.check_circle : Icons.circle_outlined,
          color: checkedCount >= totalCount ? Colors.green : null,
        ),
        title: Row(
          children: [
            Expanded(child: Text(def.name)),
            _ProgressIndicator(current: checkedCount, total: totalCount),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (def.beschreibung.isNotEmpty)
              Text(def.beschreibung, style: Theme.of(context).textTheme.bodySmall),
            if (def.apProEintrag > 0)
              _RewardChips(ap: def.apProEintrag, seDefs: const []),
            if (def.schwelle > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  thresholdMet
                      ? 'Schwelle $checkedCount/${def.schwelle} erreicht!'
                      : 'Schwelle: ${def.schwelle} für Bonus',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: thresholdMet ? Colors.green : null,
                    fontWeight: thresholdMet ? FontWeight.bold : null,
                  ),
                ),
              ),
            if (def.schwelleBelohnung != null)
              _RewardChips(
                ap: def.schwelleBelohnung!.ap,
                seDefs: def.schwelleBelohnung!.se,
                talentBoni: def.schwelleBelohnung!.talentBoni,
              ),
            if (def.bonus != null && bonusMet)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _SmallChip(
                  label: '${def.bonus!.name}: +${def.bonus!.ap} AP',
                  color: Colors.orange,
                ),
              ),
          ],
        ),
        children: [
          for (final eintrag in def.festeEintraege)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              leading: isEditing
                  ? Checkbox(
                      value: draft.checkedIds.contains(eintrag.id),
                      onChanged: (_) => onToggleChecked(eintrag.id),
                    )
                  : Icon(
                      draft.checkedIds.contains(eintrag.id)
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: draft.checkedIds.contains(eintrag.id)
                          ? Colors.green
                          : null,
                    ),
              title: Text(eintrag.name),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collection Open
// ---------------------------------------------------------------------------

class _CollectionOpenTile extends StatelessWidget {
  const _CollectionOpenTile({
    required this.def,
    required this.draft,
    required this.isEditing,
    required this.onUpdateDraft,
  });

  final ReiseberichtDef def;
  final HeroReisebericht draft;
  final bool isEditing;
  final void Function(HeroReisebericht) onUpdateDraft;

  @override
  Widget build(BuildContext context) {
    final items = draft.openEntries[def.id] ?? const [];
    final itemCount = items.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ExpansionTile(
        leading: Icon(
          def.schwelle > 0 && itemCount >= def.schwelle
              ? Icons.check_circle
              : Icons.circle_outlined,
          color: def.schwelle > 0 && itemCount >= def.schwelle
              ? Colors.green
              : null,
        ),
        title: Row(
          children: [
            Expanded(child: Text(def.name)),
            if (def.schwelle > 0)
              _ProgressIndicator(current: itemCount, total: def.schwelle)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$itemCount',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (def.beschreibung.isNotEmpty)
              Text(def.beschreibung, style: Theme.of(context).textTheme.bodySmall),
            _RewardChips(ap: def.apProEintrag, seDefs: const []),
            if (def.seIntervall > 0 && def.se.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'SE alle ${def.seIntervall} Eintraege: ${def.se.map((s) => s.name).join(", ")}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
        children: [
          for (var i = 0; i < items.length; i++)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              leading: const Icon(Icons.check_box, size: 20, color: Colors.green),
              title: Text(items[i].name),
              subtitle: items[i].klassifikation.isNotEmpty
                  ? Text(
                      _klassifikationLabel(items[i].klassifikation) +
                          (items[i].ap > 0 ? ' (+${items[i].ap} AP)' : ''),
                    )
                  : items[i].ap > 0
                      ? Text('+${items[i].ap} AP')
                      : null,
              trailing: isEditing
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _removeItem(i),
                    )
                  : null,
            ),
          if (isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Hinzufuegen'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _klassifikationLabel(String id) {
    for (final k in def.klassifikationen) {
      if (k.id == id) return k.name;
    }
    return id;
  }

  void _removeItem(int index) {
    final items = List<ReiseberichtOpenItem>.of(
      draft.openEntries[def.id] ?? const [],
    );
    items.removeAt(index);
    final updated = Map<String, List<ReiseberichtOpenItem>>.of(draft.openEntries);
    updated[def.id] = items;
    onUpdateDraft(draft.copyWith(openEntries: updated));
  }

  void _showAddDialog(BuildContext context) {
    showAdaptiveInputDialog<ReiseberichtOpenItem>(
      context: context,
      builder: (ctx) => _OpenItemAddDialog(def: def),
    ).then((item) {
      if (item != null) {
        final items = List<ReiseberichtOpenItem>.of(
          draft.openEntries[def.id] ?? const [],
        )..add(item);
        final updated = Map<String, List<ReiseberichtOpenItem>>.of(
          draft.openEntries,
        );
        updated[def.id] = items;
        onUpdateDraft(draft.copyWith(openEntries: updated));
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Grouped Progression
// ---------------------------------------------------------------------------

class _GroupedProgressionTile extends StatelessWidget {
  const _GroupedProgressionTile({
    required this.def,
    required this.draft,
    required this.isEditing,
    required this.onToggleChecked,
  });

  final ReiseberichtDef def;
  final HeroReisebericht draft;
  final bool isEditing;
  final void Function(String id) onToggleChecked;

  @override
  Widget build(BuildContext context) {
    final checked = draft.checkedIds.contains(def.id);
    final applied = draft.appliedRewardIds.contains(def.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: isEditing
            ? Checkbox(
                value: checked,
                onChanged: (_) => onToggleChecked(def.id),
              )
            : Icon(
                checked ? Icons.check_circle : Icons.circle_outlined,
                color: checked ? Colors.green : null,
              ),
        title: Text(
          def.name,
          style: TextStyle(
            decoration: applied ? TextDecoration.lineThrough : null,
            color: applied
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (def.beschreibung.isNotEmpty)
              Text(def.beschreibung, style: Theme.of(context).textTheme.bodySmall),
            _RewardChips(ap: def.ap, seDefs: def.se),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped Progression Bonus (Auto-Completion bei voller Gruppe)
// ---------------------------------------------------------------------------

class _GroupedProgressionBonusTile extends StatelessWidget {
  const _GroupedProgressionBonusTile({
    required this.def,
    required this.allDefs,
    required this.draft,
  });

  final ReiseberichtDef def;
  final List<ReiseberichtDef> allDefs;
  final HeroReisebericht draft;

  @override
  Widget build(BuildContext context) {
    final complete = isReiseberichtEntryComplete(def, draft, allDefs);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: complete
          ? Colors.green.withValues(alpha: 0.08)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Icon(
          complete ? Icons.star : Icons.star_outline,
          color: complete ? Colors.amber : Colors.grey,
        ),
        title: Text(
          def.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: complete ? Colors.green : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              complete
                  ? 'Gruppe vollständig - Bonus freigeschaltet!'
                  : 'Alle Stufen der Gruppe abschließen für Bonus',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            _RewardChips(seDefs: def.se),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meta (Auto-Completion wenn gesamte Kategorie fertig)
// ---------------------------------------------------------------------------

class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.def,
    required this.allDefs,
    required this.draft,
  });

  final ReiseberichtDef def;
  final List<ReiseberichtDef> allDefs;
  final HeroReisebericht draft;

  @override
  Widget build(BuildContext context) {
    final complete = isReiseberichtEntryComplete(def, draft, allDefs);

    // Fortschritt berechnen
    final sameCategory = allDefs.where(
      (d) => d.kategorie == def.kategorie && d.id != def.id && d.typ != 'meta',
    ).toList(growable: false);
    final doneCount = sameCategory
        .where((d) => isReiseberichtEntryComplete(d, draft, allDefs))
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: complete
          ? Colors.amber.withValues(alpha: 0.1)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Icon(
          complete ? Icons.emoji_events : Icons.emoji_events_outlined,
          color: complete ? Colors.amber : Colors.grey,
          size: 28,
        ),
        title: Text(
          def.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: complete ? Colors.amber.shade800 : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (def.beschreibung.isNotEmpty)
              Text(def.beschreibung, style: Theme.of(context).textTheme.bodySmall),
            if (!complete)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Fortschritt: $doneCount/${sameCategory.length}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            if (complete)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: _SmallChip(
                  label: 'Meta-Erfolg freigeschaltet!',
                  color: Colors.amber,
                ),
              ),
            _RewardChips(
              ap: def.ap,
              seDefs: def.se,
            ),
            if (def.eigenschaftsBonus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final eb in def.eigenschaftsBonus)
                      _SmallChip(
                        label: eb.eigenschaft == 'wahl'
                            ? '+${eb.wert} Eigenschaft (Wahl: ${eb.optionen.join("/")})'
                            : '+${eb.wert} ${eb.eigenschaft.toUpperCase()}',
                        color: Colors.purple,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
