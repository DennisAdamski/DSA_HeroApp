import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_impact_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_activation_sheet.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog_actions.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_option_card.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Durchsuchbarer Steigerungskatalog auf Basis der ungespeicherten Vorschau.
class AdvancementCatalog extends ConsumerStatefulWidget {
  /// Bindet den Katalog an die bereits gestartete Steigerungsrunde des Helden.
  const AdvancementCatalog({super.key, required this.heroId});

  /// Held, dessen Vorschau und Katalog in dieser Runde verwendet werden.
  final String heroId;

  /// Hält Suchtext und Kategorie beim Wechsel einzelner Planungsschritte.
  @override
  ConsumerState<AdvancementCatalog> createState() => _AdvancementCatalogState();
}

enum _CatalogCategory {
  attributes('Eigenschaften', [
    AdvancementKind.attribute,
    AdvancementKind.boughtStat,
  ]),
  talents('Talente', [
    AdvancementKind.talent,
    AdvancementKind.language,
    AdvancementKind.script,
  ]),
  spells('Zauber', [AdvancementKind.spell]),
  abilities('Sonderfertigkeiten', [
    AdvancementKind.generalAbility,
    AdvancementKind.magicAbility,
    AdvancementKind.karmalAbility,
    AdvancementKind.combatAbility,
  ]);

  const _CatalogCategory(this.label, this.kinds);
  final String label;

  /// Die Gruppierung dient ausschließlich der Navigation, nicht der Regelprüfung.
  /// Hauptliste und Erwerbsblatt lesen dieselbe Liste, damit kein Eintrag
  /// zwischen beiden verlorengeht.
  final List<AdvancementKind> kinds;

  bool includes(AdvancementKind kind) => kinds.contains(kind);

  /// Eigenschaften und Grundwerte besitzt jeder Held; sie kennen keinen Erwerb.
  bool get supportsActivation => this != attributes;

  String get activationLabel => switch (this) {
    attributes => '',
    talents => 'Talent, Sprache oder Schrift erlernen',
    spells => 'Zauber erlernen',
    abilities => 'Sonderfertigkeit erwerben',
  };

  String get emptyText => switch (this) {
    attributes => '',
    talents =>
      'Noch keine Talente, Sprachen oder Schriften auf dem Heldenbogen.',
    spells => 'Noch keine Zauber auf dem Heldenbogen.',
    abilities => 'Noch keine Sonderfertigkeiten erworben.',
  };
}

class _AdvancementCatalogState extends ConsumerState<AdvancementCatalog> {
  final _searchController = TextEditingController();
  _CatalogCategory _category = _CatalogCategory.attributes;
  bool _dialogOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(advancementSessionProvider(widget.heroId));
    if (session == null) {
      return const Center(child: Text('Keine Steigerungsrunde geöffnet.'));
    }
    final query = _searchController.text.trim().toLowerCase();
    final options = ref.watch(
      advancementOptionsProvider((
        heroId: widget.heroId,
        scope: AdvancementScope.active,
      )),
    );
    final filtered = options.where((option) {
      return _category.includes(option.kind) &&
          option.label.toLowerCase().contains(query);
    }).toList();
    final plannedTargets = <String>{
      for (final entry in session.entries)
        '${entry.kind.name}:${entry.targetId}',
    };
    final showImpact = _category == _CatalogCategory.attributes;
    final showBridge =
        query.isNotEmpty && _category.supportsActivation && !_dialogOpen;
    final headerCount = showImpact ? 1 : 0;
    final optionCount = filtered.isEmpty ? 1 : filtered.length;
    final bridgeCount = showBridge ? 1 : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Steigerungen planen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Werte und Voraussetzungen verwenden die Vorschau. '
                'Vorgemerkte Änderungen werden erst beim Übernehmen gespeichert.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final category in _CatalogCategory.values)
                    ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('advancement-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '${_category.label} durchsuchen',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Suche löschen',
                          onPressed: () => setState(_searchController.clear),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${filtered.length} ${showImpact ? 'Einträge' : 'aktive Einträge'}'
                    ' · ${session.preview.apAvailable} AP verfügbar',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.codexTheme.inkMuted),
                  ),
                  if (_category.supportsActivation)
                    OutlinedButton.icon(
                      key: ValueKey('advancement-activate-${_category.name}'),
                      onPressed: session.isSaving || _dialogOpen
                          ? null
                          : () => _activate(_category),
                      icon: const Icon(Icons.add),
                      label: Text(_category.activationLabel),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: headerCount + optionCount + bridgeCount,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (showImpact && index == 0) {
                return AdvancementImpactPanel(session: session);
              }
              final offset = index - headerCount;
              if (showBridge && offset == optionCount) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: ValueKey(
                      'advancement-activate-hint-${_category.name}',
                    ),
                    onPressed: () => _activate(
                      _category,
                      // Der Suchtext wandert unverändert weiter; `query` ist
                      // für den Vergleich bereits kleingeschrieben.
                      initialQuery: _searchController.text.trim(),
                    ),
                    icon: const Icon(Icons.search),
                    label: const Text('Weitere Treffer im Erwerbsblatt suchen'),
                  ),
                );
              }
              if (filtered.isEmpty) {
                return _buildEmptyState(context, query);
              }
              final option = filtered[offset];
              return AdvancementOptionCard(
                option: option,
                planned: plannedTargets.contains(
                  '${option.kind.name}:${option.targetId}',
                ),
                onPlan: session.isSaving || _dialogOpen
                    ? null
                    : () => _plan(option),
              );
            },
          ),
        ),
      ],
    );
  }

  // Ohne Suchtext ist die Liste nicht gefiltert, sondern schlicht leer.
  Widget _buildEmptyState(BuildContext context, String query) {
    if (query.isNotEmpty || !_category.supportsActivation) {
      return const Center(child: Text('Keine passenden Einträge.'));
    }
    return Column(
      key: ValueKey('advancement-empty-${_category.name}'),
      children: [
        Text(_category.emptyText, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'Über „${_category.activationLabel}" nimmst du Einträge auf.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.codexTheme.inkMuted),
        ),
      ],
    );
  }

  // Das Blatt schließt sich selbst; geplant wird erst danach über _plan.
  Future<void> _activate(
    _CatalogCategory category, {
    String initialQuery = '',
  }) async {
    final session = ref.read(advancementSessionProvider(widget.heroId));
    if (session == null || session.isSaving || _dialogOpen) return;
    setState(() => _dialogOpen = true);
    AdvancementOption? picked;
    try {
      picked = await showAdvancementActivationSheet(
        context: context,
        heroId: widget.heroId,
        title: category.activationLabel,
        kinds: category.kinds,
        initialQuery: initialQuery,
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
    if (picked == null || !mounted) return;
    await _plan(picked);
  }

  // Verhindert doppelte Dialoge und bindet Rückmeldungen an dieselbe Runde.
  Future<void> _plan(AdvancementOption option) async {
    final session = ref.read(advancementSessionProvider(widget.heroId));
    if (session == null || session.isSaving || _dialogOpen) return;
    setState(() => _dialogOpen = true);
    try {
      final entry = await showAdvancementPlanDialog(
        context: context,
        session: session,
        option: option,
      );
      if (entry == null || !mounted) return;
      ref.read(advancementSessionProvider(widget.heroId).notifier).add(entry);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }
}
