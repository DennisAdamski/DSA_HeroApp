import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';

/// Displaynamen fuer Stat-Modifikator-Felder.
const Map<String, String> kStatFieldLabels = {
  'gs': 'Geschwindigkeit (GS)',
  'lep': 'Lebenspunkte (LeP)',
  'au': 'Ausdauer (Au)',
  'asp': 'Astralenergie (AsP)',
  'kap': 'Karmaenergie (KaP)',
  'mr': 'Magieresistenz (MR)',
  'iniBase': 'Initiative (INI)',
  'at': 'Attacke (AT)',
  'pa': 'Parade (PA)',
  'fk': 'Fernkampf (FK)',
  'ausweichen': 'Ausweichen',
  'rs': 'Rüstungsschutz (RS)',
};

/// Displaynamen fuer Attribut-Modifikator-Felder.
const Map<String, String> kAttributeFieldLabels = {
  'mu': 'Mut (MU)',
  'kl': 'Klugheit (KL)',
  'inn': 'Intuition (IN)',
  'ch': 'Charisma (CH)',
  'ff': 'Fingerfertigkeit (FF)',
  'ge': 'Gewandtheit (GE)',
  'ko': 'Konstitution (KO)',
  'kk': 'Körperkraft (KK)',
};

/// Editor fuer die Modifikator-Liste eines Inventar-Items.
///
/// Zeigt jede [InventoryItemModifier] als bearbeitbare Zeile:
/// Typ-Dropdown → Ziel-Dropdown → Wert-Feld → Loeschen.
class InventoryModifierEditor extends StatefulWidget {
  const InventoryModifierEditor({
    super.key,
    required this.modifiers,
    required this.onChanged,
  });

  final List<InventoryItemModifier> modifiers;
  final ValueChanged<List<InventoryItemModifier>> onChanged;

  @override
  State<InventoryModifierEditor> createState() =>
      _InventoryModifierEditorState();
}

class _InventoryModifierEditorState extends State<InventoryModifierEditor> {
  late List<InventoryItemModifier> _mods;

  @override
  void initState() {
    super.initState();
    _mods = List<InventoryItemModifier>.from(widget.modifiers);
  }

  @override
  void didUpdateWidget(InventoryModifierEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modifiers != widget.modifiers) {
      _mods = List<InventoryItemModifier>.from(widget.modifiers);
    }
  }

  void _update() {
    widget.onChanged(List<InventoryItemModifier>.unmodifiable(_mods));
  }

  void _add() {
    setState(() {
      _mods.add(
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'gs',
          wert: 0,
        ),
      );
    });
    _update();
  }

  void _remove(int index) {
    setState(() {
      _mods.removeAt(index);
    });
    _update();
  }

  void _updateAt(int index, InventoryItemModifier mod) {
    setState(() {
      _mods[index] = mod;
    });
    _update();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _mods.length; i++)
          _ModifierRow(
            key: ValueKey<int>(i),
            modifier: _mods[i],
            onChanged: (mod) => _updateAt(i, mod),
            onDelete: () => _remove(i),
          ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Modifikator hinzufügen'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

class _ModifierRow extends ConsumerStatefulWidget {
  const _ModifierRow({
    super.key,
    required this.modifier,
    required this.onChanged,
    required this.onDelete,
  });

  final InventoryItemModifier modifier;
  final ValueChanged<InventoryItemModifier> onChanged;
  final VoidCallback onDelete;

  @override
  ConsumerState<_ModifierRow> createState() => _ModifierRowState();
}

class _ModifierRowState extends ConsumerState<_ModifierRow> {
  late TextEditingController _wertController;
  late TextEditingController _beschreibungController;

  @override
  void initState() {
    super.initState();
    _wertController = TextEditingController(
      text: widget.modifier.wert.toString(),
    );
    _beschreibungController = TextEditingController(
      text: widget.modifier.beschreibung,
    );
  }

  @override
  void dispose() {
    _wertController.dispose();
    _beschreibungController.dispose();
    super.dispose();
  }

  void _emit({
    InventoryModifierKind? kind,
    String? targetId,
    int? wert,
    String? beschreibung,
  }) {
    widget.onChanged(
      widget.modifier.copyWith(
        kind: kind,
        targetId: targetId,
        wert: wert,
        beschreibung: beschreibung,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mod = widget.modifier;
    final catalog = ref.watch(rulesCatalogProvider).asData?.value;

    // Talente aus dem Katalog sortiert nach Name
    final talents = catalog == null
        ? const <TalentDef>[]
        : (List<TalentDef>.of(catalog.talents)
          ..sort((a, b) => a.name.compareTo(b.name)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zeile 1: Art + Ziel + Löschen
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Art-Dropdown
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<InventoryModifierKind>(
                  isExpanded: true,
                  initialValue: mod.kind,
                  decoration: const InputDecoration(
                    labelText: 'Art',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: InventoryModifierKind.stat,
                      child: Text('Stat'),
                    ),
                    DropdownMenuItem(
                      value: InventoryModifierKind.attribut,
                      child: Text('Attribut'),
                    ),
                    DropdownMenuItem(
                      value: InventoryModifierKind.talent,
                      child: Text('Talent'),
                    ),
                  ],
                  onChanged: (kind) {
                    if (kind == null) return;
                    final defaultId = switch (kind) {
                      InventoryModifierKind.stat => 'gs',
                      InventoryModifierKind.attribut => 'ge',
                      InventoryModifierKind.talent =>
                        talents.isNotEmpty ? talents.first.id : '',
                    };
                    _emit(kind: kind, targetId: defaultId);
                  },
                ),
              ),
              const SizedBox(width: 6),
              // Ziel-Dropdown
              Expanded(
                child: _buildTargetField(mod, talents),
              ),
              // Loeschen
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: widget.onDelete,
                tooltip: 'Entfernen',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Zeile 2: Wert + Quelle
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _wertController,
                  decoration: const InputDecoration(
                    labelText: 'Wert',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  onChanged: (v) => _emit(wert: int.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  controller: _beschreibungController,
                  decoration: const InputDecoration(
                    labelText: 'Quelle (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  maxLength: 60,
                  onChanged: (v) => _emit(beschreibung: v),
                  buildCounter: (
                    _,  {required currentLength, required isFocused, maxLength}
                  ) =>
                      null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetField(InventoryItemModifier mod, List<TalentDef> talents) {
    switch (mod.kind) {
      case InventoryModifierKind.stat:
      case InventoryModifierKind.attribut:
        final labels = mod.kind == InventoryModifierKind.stat
            ? kStatFieldLabels
            : kAttributeFieldLabels;
        final resolved =
            labels.containsKey(mod.targetId) ? mod.targetId : labels.keys.first;
        return DropdownButtonFormField<String>(
          key: ValueKey<String>('target-${mod.kind.name}-${mod.targetId}'),
          isExpanded: true,
          initialValue: resolved,
          decoration: const InputDecoration(
            labelText: 'Ziel',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          items: labels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (id) {
            if (id != null) _emit(targetId: id);
          },
        );

      case InventoryModifierKind.talent:
        final initialName = talents.isEmpty
            ? mod.targetId
            : (talents.where((t) => t.id == mod.targetId).firstOrNull?.name ??
                mod.targetId);
        return Autocomplete<TalentDef>(
          key: ValueKey<String>('talent-auto-${mod.targetId}'),
          initialValue: TextEditingValue(text: initialName),
          displayStringForOption: (t) => t.name,
          optionsBuilder: (value) {
            if (value.text.isEmpty) return talents;
            final query = value.text.toLowerCase();
            return talents.where((t) => t.name.toLowerCase().contains(query));
          },
          onSelected: (t) => _emit(targetId: t.id),
          fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
            return TextField(
              controller: ctrl,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Talent suchen',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final t = options.elementAt(i);
                      return ListTile(
                        dense: true,
                        title: Text(t.name),
                        subtitle:
                            t.group.isNotEmpty ? Text(t.group) : null,
                        onTap: () => onSelected(t),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
    }
  }
}
