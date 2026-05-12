import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/dukaten_field.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_filter_bar.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_item_editor.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_tab_header.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';

part 'hero_inventory/inventory_display.dart';
part 'hero_inventory/inventory_editor_routing.dart';
part 'hero_inventory/inventory_mutations.dart';
part 'hero_inventory/inventory_table.dart';

const double _widthBreakpoint = 1280;
const double _pagePadding = 12;

/// Inventar-Tab mit direkter Bearbeitung ohne globalen Workspace-Edit-Modus.
class HeroInventoryTab extends ConsumerStatefulWidget {
  /// Erstellt den Inventar-Tab fuer einen einzelnen Helden.
  const HeroInventoryTab({
    super.key,
    required this.heroId,
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  final String heroId;
  final void Function(bool isDirty) onDirtyChanged;
  final void Function(bool isEditing) onEditingChanged;
  final void Function(WorkspaceAsyncAction discardAction) onRegisterDiscard;
  final void Function(WorkspaceTabEditActions actions) onRegisterEditActions;

  @override
  ConsumerState<HeroInventoryTab> createState() => _HeroInventoryTabState();
}

class _HeroInventoryTabState extends ConsumerState<HeroInventoryTab>
    with AutomaticKeepAliveClientMixin {
  HeroSheet? _latestHero;
  InventoryFilter _filter = InventoryFilter.alle;
  int? _selectedIndex;
  HeroInventoryEntry? _pendingNewEntry;
  int _editorRevision = 0;

  bool get _isDetailPanelVisible =>
      _selectedIndex != null || _pendingNewEntry != null;

  static const List<AdaptiveTableColumnSpec>
  _columnSpecs = <AdaptiveTableColumnSpec>[
    AdaptiveTableColumnSpec(
      minWidth: 180,
      maxWidth: 280,
      flex: 2,
    ), // Gegenstand
    AdaptiveTableColumnSpec(minWidth: 130, maxWidth: 180, flex: 1), // Typ
    AdaptiveTableColumnSpec(minWidth: 110, maxWidth: 150, flex: 1), // Quelle
    AdaptiveTableColumnSpec(minWidth: 140, maxWidth: 220, flex: 1), // Träger
    AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 92), // Anzahl
    AdaptiveTableColumnSpec(minWidth: 88, maxWidth: 120), // Gewicht
    AdaptiveTableColumnSpec(minWidth: 88, maxWidth: 120), // Wert
    AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 280, flex: 2), // Status
    AdaptiveTableColumnSpec(minWidth: 160, maxWidth: 280, flex: 2), // Herkunft
    AdaptiveTableColumnSpec.fixed(88), // Aktion
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _registerWithParent();
      }
    });
  }

  List<HeroInventoryEntry> get _entries =>
      _latestHero?.inventoryEntries ?? const <HeroInventoryEntry>[];

  List<HeroCompanion> get _companions =>
      _latestHero?.companions ?? const <HeroCompanion>[];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    _latestHero = hero;

    final isWide = MediaQuery.sizeOf(context).width >= _widthBreakpoint;
    final totalWeight = hero.inventoryEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.gewichtGramm,
    );
    final totalValue = hero.inventoryEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.wertSilber,
    );

    final filterBar = InventoryFilterBar(
      activeFilter: _filter,
      onFilterChanged: (filter) => setState(() => _filter = filter),
      totalWeightGramm: totalWeight,
      totalValueSilber: totalValue,
    );
    final table = _buildTable(context);

    if (isWide) {
      final listColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CodexTabHeader(
            title: 'Ausrüstungs-Ledger',
            subtitle:
                'Traglast, Herkunft und Ausrüstungsstatus in einer direkten Inventartabelle.',
            assetPath: 'assets/ui/codex/compass_mark.png',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _pagePadding,
              _pagePadding,
              _pagePadding,
              0,
            ),
            child: DukatenField(
              key: const ValueKey<String>('inventory-dukaten-field'),
              value: hero.dukaten,
              onCommit: _saveDukaten,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _pagePadding - 4,
            ),
            child: filterBar,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _pagePadding,
              ),
              child: table,
            ),
          ),
        ],
      );

      if (!_isDetailPanelVisible) {
        return listColumn;
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: listColumn),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: Container(
              key: const ValueKey<String>('inventory-editor-panel'),
              color: Theme.of(context).colorScheme.surface,
              child: _buildEditorPanel(),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CodexTabHeader(
          title: 'Ausrüstungs-Ledger',
          subtitle:
              'Traglast, Wert und Ausrüstungsstatus in einer kompakten Inventartabelle.',
          assetPath: 'assets/ui/codex/compass_mark.png',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _pagePadding,
            _pagePadding,
            _pagePadding,
            0,
          ),
          child: DukatenField(
            key: const ValueKey<String>('inventory-dukaten-field'),
            value: hero.dukaten,
            onCommit: _saveDukaten,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _pagePadding - 4),
          child: filterBar,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
            child: table,
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
