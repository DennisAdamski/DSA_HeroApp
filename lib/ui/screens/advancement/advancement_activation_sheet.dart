import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_catalog_filter_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_option_card.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Auswahlblatt für Katalogeinträge, die der Held noch nicht führt.
///
/// Liefert das gewählte Ziel zurück und schließt sich dabei selbst; geplant
/// wird erst danach beim Aufrufer. So liegt der Planungsdialog nie über einem
/// Blatt derselben Root-Navigator-Ebene, und die Sitzung wird weiterhin nur an
/// einer Stelle verändert.
Future<AdvancementOption?> showAdvancementActivationSheet({
  required BuildContext context,
  required String heroId,
  required String title,
  required List<AdvancementKind> kinds,
  bool Function(AdvancementOption option)? filter,
  String initialQuery = '',
}) {
  return showAdaptiveDetailSheet<AdvancementOption>(
    context: context,
    builder: (_) => _AdvancementActivationSheet(
      heroId: heroId,
      title: title,
      kinds: kinds,
      filter: filter,
      initialQuery: initialQuery,
    ),
  );
}

/// Unterteilung innerhalb eines Blatts.
///
/// Bewusst als Prädikat und nicht als [AdvancementKind]-Liste: „Kampftalent“
/// ist keine eigene Art, sondern eine Eigenschaft der Talentoption.
enum _ActivationFilter {
  all('Alle', 'alle'),
  talents('Talente', 'talente'),
  combatTalents('Kampftalente', 'kampftalente'),
  languages('Sprachen', 'sprachen'),
  scripts('Schriften', 'schriften'),
  generalAbilities('Allgemein', 'allgemein'),
  magicAbilities('Magisch', 'magisch'),
  karmalAbilities('Karmal', 'karmal'),
  combatAbilities('Kampf', 'kampf');

  const _ActivationFilter(this.label, this.slug);
  final String label;
  final String slug;

  bool matches(AdvancementOption option) => switch (this) {
    all => true,
    talents => option.kind == AdvancementKind.talent && !option.isCombatTalent,
    combatTalents =>
      option.kind == AdvancementKind.talent && option.isCombatTalent,
    languages => option.kind == AdvancementKind.language,
    scripts => option.kind == AdvancementKind.script,
    generalAbilities => option.kind == AdvancementKind.generalAbility,
    magicAbilities => option.kind == AdvancementKind.magicAbility,
    karmalAbilities => option.kind == AdvancementKind.karmalAbility,
    combatAbilities => option.kind == AdvancementKind.combatAbility,
  };
}

class _AdvancementActivationSheet extends ConsumerStatefulWidget {
  const _AdvancementActivationSheet({
    required this.heroId,
    required this.title,
    required this.kinds,
    required this.initialQuery,
    this.filter,
  });

  final String heroId;
  final String title;
  final List<AdvancementKind> kinds;
  final String initialQuery;

  /// Engt die Arten weiter ein, etwa auf Kampftalente oder auf
  /// Sonderfertigkeiten, die zur Tradition des Helden passen.
  final bool Function(AdvancementOption option)? filter;

  @override
  ConsumerState<_AdvancementActivationSheet> createState() =>
      _AdvancementActivationSheetState();
}

class _AdvancementActivationSheetState
    extends ConsumerState<_AdvancementActivationSheet> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialQuery,
  );
  _ActivationFilter _filter = _ActivationFilter.all;
  bool _onlyAvailable = true;
  String? _spellTrait;
  int _minimumSpellSpread = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.sizeOf(context);
    final session = ref.watch(advancementSessionProvider(widget.heroId));
    final spellSheet = widget.kinds.contains(AdvancementKind.spell);
    final catalogSpells = spellSheet
        ? session?.catalog.spells ?? const <SpellDef>[]
        : const <SpellDef>[];
    final spells = <String, SpellDef>{
      for (final spell in catalogSpells) spell.id: spell,
    };
    final spellTraits = spellCatalogFilterTraits(spells.values);
    final spellSpreads = spellCatalogFilterSpreads(spells.values);
    final options = ref
        .watch(
          advancementOptionsProvider((
            heroId: widget.heroId,
            scope: AdvancementScope.inactive,
          )),
        )
        .where(
          (option) =>
              widget.kinds.contains(option.kind) &&
              (widget.filter?.call(option) ?? true),
        )
        .toList();
    final filters = _availableFilters(options);
    // Ohne sichtbare Chips gilt immer der volle Umfang.
    final filter = filters.contains(_filter) ? _filter : _ActivationFilter.all;
    final query = _searchController.text.trim().toLowerCase();
    final filtered =
        options.where((option) {
          if (option.kind == AdvancementKind.spell) {
            final spell = spells[option.targetId];
            if (spell == null) return false;
            final matches = matchesSpellCatalogFilters(
              spell: spell,
              representations: session?.preview.representationen ?? const [],
              onlyLearnedRepresentations: _onlyAvailable,
              trait: _spellTrait,
              minimumSpread: _minimumSpellSpread,
            );
            if (!matches) return false;
          } else if (_onlyAvailable && option.unavailableReason != null) {
            return false;
          }
          if (!filter.matches(option)) return false;
          return option.label.toLowerCase().contains(query);
        }).toList()..sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );
    return AlertDialog(
      title: Text(widget.title),
      // Der Dialograhmen braucht Platz für Titel und Aktionen; ohne die
      // gekürzte Innenabstände bliebe auf 320 px keine nutzbare Listenhöhe.
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: kDialogWidthLarge,
        height: math.min(520, media.height * 0.6),
        // Filter und Treffer teilen den Scrollbereich auch bei großer Schrift.
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('advancement-activate-search'),
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Suchen…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Die Artfilter laufen waagerecht, damit sie auf schmalen Geräten
                  // nicht die halbe Blatthöhe als Umbruch beanspruchen.
                  if (filters.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final choice in filters)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                key: ValueKey(
                                  'advancement-activate-filter-${choice.slug}',
                                ),
                                label: Text(choice.label),
                                selected: choice == filter,
                                onSelected: (_) =>
                                    setState(() => _filter = choice),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${filtered.length} von ${options.length} Einträgen',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.codexTheme.inkMuted,
                        ),
                      ),
                      FilterChip(
                        key: const ValueKey(
                          'advancement-activate-only-available',
                        ),
                        label: Text(
                          spellSheet
                              ? 'Nur gelernte Repräsentationen'
                              : 'Nur erwerbbare',
                        ),
                        selected: _onlyAvailable,
                        onSelected: (value) =>
                            setState(() => _onlyAvailable = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (spellSheet) ...[
                    // Horizontales Scrollen lässt auf kleinen Geräten Platz für Treffer.
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<String>(
                              key: const ValueKey(
                                'advancement-activate-spell-trait',
                              ),
                              initialValue: _spellTrait ?? '',
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Merkmal',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Alle Merkmale'),
                                ),
                                for (final trait in spellTraits)
                                  DropdownMenuItem(
                                    value: trait,
                                    child: Text(
                                      trait,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) => setState(
                                () => _spellTrait = value == '' ? null : value,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<int>(
                              key: const ValueKey(
                                'advancement-activate-spell-spread',
                              ),
                              initialValue: _minimumSpellSpread,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Verbreitung',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 0,
                                  child: Text('Alle Verbreitungen'),
                                ),
                                for (final spread in spellSpreads)
                                  DropdownMenuItem(
                                    value: spread,
                                    child: Text('Ab $spread'),
                                  ),
                              ],
                              onChanged: (value) => setState(
                                () => _minimumSpellSpread = value ?? 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  key: ValueKey('advancement-activate-empty'),
                  child: Text('Keine passenden Einträge.'),
                ),
              )
            else
              SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final option = filtered[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AdvancementOptionCard(
                      option: option,
                      // Ein vorgemerkter Erwerb macht sein Ziel in der
                      // Vorschau vorhanden; es verlaesst diese Liste
                      // damit sofort und kann hier nie geplant sein.
                      planned: false,
                      onPlan: () => Navigator.of(context).pop(option),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('advancement-activate-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  // Zeigt nur Unterfilter, zu denen es hier auch Einträge gibt.
  List<_ActivationFilter> _availableFilters(List<AdvancementOption> options) {
    final present = _ActivationFilter.values
        .where(
          (filter) =>
              filter != _ActivationFilter.all && options.any(filter.matches),
        )
        .toList();
    if (present.length < 2) return const [];
    return [_ActivationFilter.all, ...present];
  }
}
