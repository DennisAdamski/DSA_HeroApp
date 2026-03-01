import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

const double _pagePadding = 16;
const double _sectionSpacing = 16;
const double _fieldSpacing = 12;
const int _minimumRows = 10;

class HeroInventoryTab extends ConsumerStatefulWidget {
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
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  late final WorkspaceTabEditController _editController;
  HeroSheet? _latestHero;
  int _rowCount = _minimumRows;

  static const List<_InventoryColumn> _columns = <_InventoryColumn>[
    _InventoryColumn('Gegenstand', 'gegenstand', 180),
    _InventoryColumn('Wo getragen', 'wo_getragen', 130),
    _InventoryColumn('Typ', 'typ', 120),
    _InventoryColumn('Welches Abenteuer', 'welches_abenteuer', 170),
    _InventoryColumn('Gewicht', 'gewicht', 110),
    _InventoryColumn('Wert', 'wert', 110),
    _InventoryColumn('Artefakt', 'artefakt', 110),
    _InventoryColumn('Anzahl', 'anzahl', 90),
    _InventoryColumn('am Koerper', 'am_koerper', 110),
    _InventoryColumn('wo dann?', 'wo_dann', 110),
    _InventoryColumn('Gruppe', 'gruppe', 120),
    _InventoryColumn('Beschreibung', 'beschreibung', 280),
  ];

  @override
  void initState() {
    super.initState();
    _editController = WorkspaceTabEditController(
      onDirtyChanged: widget.onDirtyChanged,
      onEditingChanged: widget.onEditingChanged,
      requestRebuild: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _registerWithParent();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _registerWithParent() {
    _editController.emitCurrentState();
    widget.onRegisterDiscard(_discardChanges);
    widget.onRegisterEditActions(
      WorkspaceTabEditActions(
        startEdit: _startEdit,
        save: _saveChanges,
        cancel: _cancelChanges,
      ),
    );
  }

  TextEditingController _field(String key) {
    return _controllers.putIfAbsent(key, () => TextEditingController());
  }

  String _rowKey(int rowIndex, String columnKey) =>
      'row_${rowIndex}_$columnKey';

  void _syncControllers(HeroSheet hero, {bool force = false}) {
    if (!_editController.shouldSync(hero, force: force)) {
      return;
    }

    _field('dukaten').text = hero.dukaten;
    _rowCount = hero.inventoryEntries.length > _minimumRows
        ? hero.inventoryEntries.length
        : _minimumRows;

    for (var rowIndex = 0; rowIndex < _rowCount; rowIndex++) {
      final entry = rowIndex < hero.inventoryEntries.length
          ? hero.inventoryEntries[rowIndex]
          : const HeroInventoryEntry();
      _field(_rowKey(rowIndex, 'gegenstand')).text = entry.gegenstand;
      _field(_rowKey(rowIndex, 'wo_getragen')).text = entry.woGetragen;
      _field(_rowKey(rowIndex, 'typ')).text = entry.typ;
      _field(_rowKey(rowIndex, 'welches_abenteuer')).text =
          entry.welchesAbenteuer;
      _field(_rowKey(rowIndex, 'gewicht')).text = entry.gewicht;
      _field(_rowKey(rowIndex, 'wert')).text = entry.wert;
      _field(_rowKey(rowIndex, 'artefakt')).text = entry.artefakt;
      _field(_rowKey(rowIndex, 'anzahl')).text = entry.anzahl;
      _field(_rowKey(rowIndex, 'am_koerper')).text = entry.amKoerper;
      _field(_rowKey(rowIndex, 'wo_dann')).text = entry.woDann;
      _field(_rowKey(rowIndex, 'gruppe')).text = entry.gruppe;
      _field(_rowKey(rowIndex, 'beschreibung')).text = entry.beschreibung;
    }
  }

  Future<void> _startEdit() async {
    _editController.startEdit();
  }

  Future<void> _saveChanges() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }

    final entries = <HeroInventoryEntry>[];
    for (var rowIndex = 0; rowIndex < _rowCount; rowIndex++) {
      final entry = HeroInventoryEntry(
        gegenstand: _field(_rowKey(rowIndex, 'gegenstand')).text.trim(),
        woGetragen: _field(_rowKey(rowIndex, 'wo_getragen')).text.trim(),
        typ: _field(_rowKey(rowIndex, 'typ')).text.trim(),
        welchesAbenteuer: _field(
          _rowKey(rowIndex, 'welches_abenteuer'),
        ).text.trim(),
        gewicht: _field(_rowKey(rowIndex, 'gewicht')).text.trim(),
        wert: _field(_rowKey(rowIndex, 'wert')).text.trim(),
        artefakt: _field(_rowKey(rowIndex, 'artefakt')).text.trim(),
        anzahl: _field(_rowKey(rowIndex, 'anzahl')).text.trim(),
        amKoerper: _field(_rowKey(rowIndex, 'am_koerper')).text.trim(),
        woDann: _field(_rowKey(rowIndex, 'wo_dann')).text.trim(),
        gruppe: _field(_rowKey(rowIndex, 'gruppe')).text.trim(),
        beschreibung: _field(_rowKey(rowIndex, 'beschreibung')).text.trim(),
      );
      if (_isEntryEmpty(entry)) {
        continue;
      }
      entries.add(entry);
    }

    final updatedHero = hero.copyWith(
      dukaten: _field('dukaten').text.trim(),
      inventoryEntries: entries,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }

    _editController.markSaved();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Inventar gespeichert')));
  }

  bool _isEntryEmpty(HeroInventoryEntry entry) {
    return entry.gegenstand.isEmpty &&
        entry.woGetragen.isEmpty &&
        entry.typ.isEmpty &&
        entry.welchesAbenteuer.isEmpty &&
        entry.gewicht.isEmpty &&
        entry.wert.isEmpty &&
        entry.artefakt.isEmpty &&
        entry.anzahl.isEmpty &&
        entry.amKoerper.isEmpty &&
        entry.woDann.isEmpty &&
        entry.gruppe.isEmpty &&
        entry.beschreibung.isEmpty;
  }

  Future<void> _cancelChanges() async {
    await _discardChanges();
  }

  Future<void> _discardChanges() async {
    final hero = _latestHero;
    if (hero != null) {
      _editController.clearSyncSignature();
      _syncControllers(hero, force: true);
    }
    _editController.markDiscarded();
  }

  void _onFieldChanged(String _) {
    _editController.markFieldChanged();
  }

  void _addRow() {
    setState(() {
      _rowCount++;
    });
    _editController.markFieldChanged();
  }

  void _removeLastRow() {
    if (_rowCount <= _minimumRows) {
      return;
    }
    setState(() {
      _rowCount--;
    });
    _editController.markFieldChanged();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    _latestHero = hero;
    _syncControllers(hero);
    final isReadOnly = !_editController.isEditing;

    return ListView(
      padding: const EdgeInsets.all(_pagePadding),
      children: [
        _SectionCard(
          title: 'Inventar',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  key: const ValueKey<String>('inventory-field-dukaten'),
                  controller: _field('dukaten'),
                  readOnly: isReadOnly,
                  decoration: const InputDecoration(
                    labelText: 'Dukaten',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: isReadOnly ? null : _onFieldChanged,
                ),
              ),
              const SizedBox(height: _fieldSpacing),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: isReadOnly ? null : _addRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Zeile'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: isReadOnly ? null : _removeLastRow,
                    icon: const Icon(Icons.remove),
                    label: const Text('Zeile'),
                  ),
                ],
              ),
              const SizedBox(height: _fieldSpacing),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _columns.fold<double>(
                    0,
                    (sum, column) => sum + column.width,
                  ),
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: <int, TableColumnWidth>{
                      for (var i = 0; i < _columns.length; i++)
                        i: FixedColumnWidth(_columns[i].width),
                    },
                    children: [
                      TableRow(
                        children: _columns
                            .map(
                              (column) => Padding(
                                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                                child: Text(
                                  column.label,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      for (var rowIndex = 0; rowIndex < _rowCount; rowIndex++)
                        TableRow(
                          children: _columns
                              .map(
                                (column) => Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: TextField(
                                    key: ValueKey<String>(
                                      'inventory-field-${_rowKey(rowIndex, column.key)}',
                                    ),
                                    controller: _field(
                                      _rowKey(rowIndex, column.key),
                                    ),
                                    readOnly: isReadOnly,
                                    maxLines: 1,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: isReadOnly
                                        ? null
                                        : _onFieldChanged,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _sectionSpacing),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _InventoryColumn {
  const _InventoryColumn(this.label, this.key, this.width);

  final String label;
  final String key;
  final double width;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: _fieldSpacing),
            child,
          ],
        ),
      ),
    );
  }
}
