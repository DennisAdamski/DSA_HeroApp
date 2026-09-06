import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
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
  String initialQuery = '',
}) {
  return showAdaptiveDetailSheet<AdvancementOption>(
    context: context,
    builder: (_) => _AdvancementActivationSheet(
      heroId: heroId,
      title: title,
      kinds: kinds,
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
  });

  final String heroId;
  final String title;
  final List<AdvancementKind> kinds;
  final String initialQuery;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.sizeOf(context);
    final options = ref
        .watch(
          advancementOptionsProvider((
            heroId: widget.heroId,
            scope: AdvancementScope.inactive,
          )),
        )
        .where((option) => widget.kinds.contains(option.kind))
        .toList();
    final filters = _availableFilters(options);
    // Ohne sichtbare Chips gilt immer der volle Umfang.
    final filter = filters.contains(_filter) ? _filter : _ActivationFilter.all;
    final query = _searchController.text.trim().toLowerCase();
    final filtered =
        options.where((option) {
          if (_onlyAvailable && option.unavailableReason != null) return false;
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
                          onSelected: (_) => setState(() => _filter = choice),
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
                  key: const ValueKey('advancement-activate-only-available'),
                  label: const Text('Nur erwerbbare'),
                  selected: _onlyAvailable,
                  onSelected: (value) => setState(() => _onlyAvailable = value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      key: ValueKey('advancement-activate-empty'),
                      child: Text('Keine passenden Einträge.'),
                    )
                  : ListView.builder(
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
