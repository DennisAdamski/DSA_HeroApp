import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

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
/// Typ-Dropdown → Ziel-Dropdown/Feld → Wert-Feld → Loeschen.
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

class _ModifierRow extends StatefulWidget {
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
  State<_ModifierRow> createState() => _ModifierRowState();
}

class _ModifierRowState extends State<_ModifierRow> {
  late TextEditingController _wertController;
  late TextEditingController _talentIdController;
  late TextEditingController _beschreibungController;

  @override
  void initState() {
    super.initState();
    _wertController = TextEditingController(
      text: widget.modifier.wert.toString(),
    );
    _talentIdController = TextEditingController(
      text: widget.modifier.targetId,
    );
    _beschreibungController = TextEditingController(
      text: widget.modifier.beschreibung,
    );
  }

  @override
  void dispose() {
    _wertController.dispose();
    _talentIdController.dispose();
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Art-Dropdown
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<InventoryModifierKind>(
              initialValue: mod.kind,
              decoration: const InputDecoration(
                labelText: 'Art',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: [
                DropdownMenuItem(
                  value: InventoryModifierKind.stat,
                  child: const Text('Stat'),
                ),
                DropdownMenuItem(
                  value: InventoryModifierKind.attribut,
                  child: const Text('Attribut'),
                ),
                DropdownMenuItem(
                  value: InventoryModifierKind.talent,
                  child: const Text('Talent'),
                ),
              ],
              onChanged: (kind) {
                if (kind == null) return;
                final defaultId = switch (kind) {
                  InventoryModifierKind.stat => 'gs',
                  InventoryModifierKind.attribut => 'ge',
                  InventoryModifierKind.talent => '',
                };
                _talentIdController.text = defaultId;
                _emit(kind: kind, targetId: defaultId);
              },
            ),
          ),
          const SizedBox(width: 6),
          // Ziel-Feld
          SizedBox(
            width: mod.kind == InventoryModifierKind.talent ? 150 : 180,
            child: mod.kind == InventoryModifierKind.talent
                ? TextFormField(
                    controller: _talentIdController,
                    decoration: const InputDecoration(
                      labelText: 'Talent-ID',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) => _emit(targetId: v.trim()),
                  )
                : DropdownButtonFormField<String>(
                    key: ValueKey<String>('target-${mod.kind.name}-${mod.targetId}'),
                    initialValue: _resolvedTargetId(mod),
                    decoration: const InputDecoration(
                      labelText: 'Ziel',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    isExpanded: true,
                    items: _targetItems(mod.kind),
                    onChanged: (id) {
                      if (id == null) return;
                      _emit(targetId: id);
                    },
                  ),
          ),
          const SizedBox(width: 6),
          // Wert-Feld
          SizedBox(
            width: 64,
            child: TextFormField(
              controller: _wertController,
              decoration: const InputDecoration(
                labelText: 'Wert',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              onChanged: (v) => _emit(wert: int.tryParse(v) ?? 0),
            ),
          ),
          const SizedBox(width: 6),
          // Beschreibung
          Expanded(
            child: TextFormField(
              controller: _beschreibungController,
              decoration: const InputDecoration(
                labelText: 'Quelle',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              maxLength: 60,
              onChanged: (v) => _emit(beschreibung: v),
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
            ),
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
    );
  }

  String _resolvedTargetId(InventoryItemModifier mod) {
    final labels = mod.kind == InventoryModifierKind.stat
        ? kStatFieldLabels
        : kAttributeFieldLabels;
    return labels.containsKey(mod.targetId) ? mod.targetId : labels.keys.first;
  }

  List<DropdownMenuItem<String>> _targetItems(InventoryModifierKind kind) {
    final labels =
        kind == InventoryModifierKind.stat ? kStatFieldLabels : kAttributeFieldLabels;
    return labels.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList();
  }
}
