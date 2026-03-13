import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_modifier_editor.dart';

const double _fieldSpacing = 12;

/// Detail-Editor fuer einen einzelnen Inventar-Eintrag.
///
/// Kann als Inline-Panel (breite Screens) oder als eigenstaendige Seite
/// (schmale Screens) eingesetzt werden.
///
/// Ruft [onSaved] mit dem aktualisierten Eintrag auf, [onCancelled] bei Abbruch.
class InventoryItemEditor extends StatefulWidget {
  const InventoryItemEditor({
    super.key,
    required this.entry,
    required this.onSaved,
    required this.onCancelled,
    this.showAppBar = true,
    this.companions = const <HeroCompanion>[],
  });

  final HeroInventoryEntry entry;
  final ValueChanged<HeroInventoryEntry> onSaved;
  final VoidCallback onCancelled;
  final bool showAppBar;

  /// Begleiter des Helden – fuer das Träger-Dropdown.
  final List<HeroCompanion> companions;

  @override
  State<InventoryItemEditor> createState() => _InventoryItemEditorState();
}

class _InventoryItemEditorState extends State<InventoryItemEditor> {
  late HeroInventoryEntry _draft;

  late TextEditingController _nameCtrl;
  late TextEditingController _anzahlCtrl;
  late TextEditingController _gewichtCtrl;
  late TextEditingController _wertCtrl;
  late TextEditingController _herkunftCtrl;
  late TextEditingController _beschreibungCtrl;

  @override
  void initState() {
    super.initState();
    _draft = widget.entry;
    _nameCtrl = TextEditingController(text: _draft.gegenstand);
    _anzahlCtrl = TextEditingController(text: _draft.anzahl);
    _gewichtCtrl = TextEditingController(
      text: _draft.gewichtGramm > 0 ? _draft.gewichtGramm.toString() : '',
    );
    _wertCtrl = TextEditingController(
      text: _draft.wertSilber > 0 ? _draft.wertSilber.toString() : '',
    );
    _herkunftCtrl = TextEditingController(text: _draft.herkunft);
    _beschreibungCtrl = TextEditingController(text: _draft.beschreibung);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _anzahlCtrl.dispose();
    _gewichtCtrl.dispose();
    _wertCtrl.dispose();
    _herkunftCtrl.dispose();
    _beschreibungCtrl.dispose();
    super.dispose();
  }

  bool get _isLinked => _draft.sourceRef != null;

  void _save() {
    final updated = _draft.copyWith(
      gegenstand: _nameCtrl.text.trim(),
      anzahl: _anzahlCtrl.text.trim(),
      gewichtGramm: int.tryParse(_gewichtCtrl.text) ?? 0,
      wertSilber: int.tryParse(_wertCtrl.text) ?? 0,
      herkunft: _herkunftCtrl.text.trim(),
      beschreibung: _beschreibungCtrl.text.trim(),
    );
    widget.onSaved(updated);
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLinked ? _draft.gegenstand : 'Gegenstand bearbeiten',
        ),
        actions: [
          TextButton(
            onPressed: widget.onCancelled,
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: _save,
            child: const Text('Speichern'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.showAppBar) _InlineHeader(
            title: _isLinked ? _draft.gegenstand : 'Gegenstand bearbeiten',
            onSave: _save,
            onCancel: widget.onCancelled,
          ),
          _SectionTitle('Stammdaten'),
          const SizedBox(height: 8),
          _buildStammdaten(context),
          const SizedBox(height: _fieldSpacing * 2),
          _SectionTitle('Wert & Gewicht'),
          const SizedBox(height: 8),
          _buildWertGewicht(),
          if (_draft.itemType == InventoryItemType.ausruestung) ...[
            const SizedBox(height: _fieldSpacing * 2),
            _SectionTitle('Modifikatoren'),
            const SizedBox(height: 4),
            _buildModifikatoren(),
          ],
        ],
      ),
    );
  }

  Widget _buildStammdaten(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLinked)
          _LinkedHint(gegenstand: _draft.gegenstand)
        else
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        const SizedBox(height: _fieldSpacing),
        Row(
          children: [
            Expanded(
              child: _DropdownField<InventoryItemType>(
                label: 'Typ',
                value: _draft.itemType,
                enabled: !_isLinked,
                items: {
                  InventoryItemType.ausruestung: 'Ausrüstung',
                  InventoryItemType.verbrauchsgegenstand: 'Verbrauchsgegenstand',
                  InventoryItemType.wertvolles: 'Wertvolles',
                  InventoryItemType.sonstiges: 'Sonstiges',
                },
                onChanged: (v) {
                  if (v != null) setState(() => _draft = _draft.copyWith(itemType: v));
                },
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _anzahlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Anzahl',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        if (_draft.itemType == InventoryItemType.ausruestung) ...[
          const SizedBox(height: _fieldSpacing),
          SwitchListTile.adaptive(
            value: _draft.istAusgeruestet,
            onChanged: (v) => setState(() => _draft = _draft.copyWith(istAusgeruestet: v)),
            title: const Text('Ausgerüstet'),
            subtitle: const Text('Modifikatoren wirken nur wenn ausgerüstet'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ],
        const SizedBox(height: _fieldSpacing),
        TextField(
          controller: _herkunftCtrl,
          decoration: const InputDecoration(
            labelText: 'Herkunft',
            hintText: 'z. B. Händler in Ferdok',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (widget.companions.isNotEmpty) ...[
          const SizedBox(height: _fieldSpacing),
          _TraegerDropdown(
            traegerTyp: _draft.traegerTyp,
            traegerId: _draft.traegerId,
            companions: widget.companions,
            onChanged: (typ, id) => setState(() {
              _draft = _draft.copyWith(traegerTyp: typ, traegerId: id);
            }),
          ),
        ],
        const SizedBox(height: _fieldSpacing),
        TextField(
          controller: _beschreibungCtrl,
          decoration: const InputDecoration(
            labelText: 'Beschreibung',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildWertGewicht() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _gewichtCtrl,
            decoration: const InputDecoration(
              labelText: 'Gewicht (g)',
              hintText: '0 = unbekannt',
              border: OutlineInputBorder(),
              isDense: true,
              suffixText: 'g',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: _fieldSpacing),
        Expanded(
          child: TextField(
            controller: _wertCtrl,
            decoration: const InputDecoration(
              labelText: 'Wert (S)',
              hintText: '0 = unbekannt',
              border: OutlineInputBorder(),
              isDense: true,
              suffixText: 'S',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildModifikatoren() {
    return InventoryModifierEditor(
      modifiers: _draft.modifiers,
      onChanged: (mods) => setState(() => _draft = _draft.copyWith(modifiers: mods)),
    );
  }
}

// ---------------------------------------------------------------------------
// Hilfs-Widgets
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

class _InlineHeader extends StatelessWidget {
  const _InlineHeader({
    required this.title,
    required this.onSave,
    required this.onCancel,
  });

  final String title;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        TextButton(onPressed: onCancel, child: const Text('Abbrechen')),
        const SizedBox(width: 8),
        FilledButton(onPressed: onSave, child: const Text('Speichern')),
      ],
    );
  }
}

class _LinkedHint extends StatelessWidget {
  const _LinkedHint({required this.gegenstand});
  final String gegenstand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$gegenstand (verknüpft – bearbeite im Kampf-Tab)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown zur Auswahl des Trägers (Held oder Begleiter).
class _TraegerDropdown extends StatelessWidget {
  const _TraegerDropdown({
    required this.traegerTyp,
    required this.traegerId,
    required this.companions,
    required this.onChanged,
  });

  final InventoryTraeger traegerTyp;
  final String? traegerId;
  final List<HeroCompanion> companions;
  final void Function(InventoryTraeger typ, String? id) onChanged;

  // Zusammengesetzter Auswahlwert: 'held' oder 'begleiter:{id}'
  String get _currentValue {
    if (traegerTyp == InventoryTraeger.begleiter && traegerId != null) {
      return 'begleiter:$traegerId';
    }
    return 'held';
  }

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'held', child: Text('Held')),
      for (final c in companions)
        DropdownMenuItem(
          value: 'begleiter:${c.id}',
          child: Text(c.name.isEmpty ? 'Unbenannter Begleiter' : c.name),
        ),
    ];

    return DropdownButtonFormField<String>(
      initialValue: _currentValue,
      decoration: const InputDecoration(
        labelText: 'Träger',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: items,
      onChanged: (v) {
        if (v == null) return;
        if (v == 'held') {
          onChanged(InventoryTraeger.held, null);
        } else {
          final id = v.substring('begleiter:'.length);
          onChanged(InventoryTraeger.begleiter, id);
        }
      },
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items.entries
          .map((e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}
