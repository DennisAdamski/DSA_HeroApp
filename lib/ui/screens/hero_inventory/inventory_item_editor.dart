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
  /// Erstellt den Detail-Editor fuer einen Inventar-Eintrag.
  const InventoryItemEditor({
    super.key,
    required this.entry,
    required this.onSaved,
    required this.onCancelled,
    this.showAppBar = true,
    this.isNew = false,
    this.companions = const <HeroCompanion>[],
  });

  final HeroInventoryEntry entry;
  final Future<void> Function(HeroInventoryEntry entry) onSaved;
  final VoidCallback onCancelled;
  final bool showAppBar;
  final bool isNew;

  /// Begleiter des Helden fuer das Traeger-Dropdown.
  final List<HeroCompanion> companions;

  @override
  State<InventoryItemEditor> createState() => _InventoryItemEditorState();
}

class _InventoryItemEditorState extends State<InventoryItemEditor> {
  late HeroInventoryEntry _draft;
  bool _isSaving = false;

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

  String get _editorTitle {
    if (widget.isNew) {
      return 'Gegenstand hinzufügen';
    }
    if (_isLinked) {
      return _draft.gegenstand;
    }
    return 'Gegenstand bearbeiten';
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final updated = _draft.copyWith(
      gegenstand: _nameCtrl.text.trim(),
      anzahl: _anzahlCtrl.text.trim(),
      gewichtGramm: int.tryParse(_gewichtCtrl.text) ?? 0,
      wertSilber: int.tryParse(_wertCtrl.text) ?? 0,
      herkunft: _herkunftCtrl.text.trim(),
      beschreibung: _beschreibungCtrl.text.trim(),
    );

    setState(() => _isSaving = true);
    try {
      await widget.onSaved(updated);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    final useCompactTitle = MediaQuery.sizeOf(context).width < 520;
    final appBarTitle = useCompactTitle
        ? (widget.isNew ? 'Hinzufügen' : 'Bearbeiten')
        : _editorTitle;

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(appBarTitle, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          Tooltip(
            message: 'Abbrechen',
            child: IconButton(
              key: const ValueKey<String>('inventory-editor-cancel'),
              onPressed: _isSaving ? null : widget.onCancelled,
              icon: const Icon(Icons.close),
            ),
          ),
          Tooltip(
            message: 'Speichern',
            child: IconButton(
              key: const ValueKey<String>('inventory-editor-save'),
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.check),
            ),
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
          if (!widget.showAppBar)
            _InlineHeader(
              title: _editorTitle,
              onSave: _save,
              onCancel: widget.onCancelled,
              isSaving: _isSaving,
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
            key: const ValueKey<String>('inventory-editor-name'),
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
                items: const {
                  InventoryItemType.ausruestung: 'Ausrüstung',
                  InventoryItemType.verbrauchsgegenstand:
                      'Verbrauchsgegenstand',
                  InventoryItemType.wertvolles: 'Wertvolles',
                  InventoryItemType.sonstiges: 'Sonstiges',
                },
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _draft = _draft.copyWith(itemType: value));
                },
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            SizedBox(
              width: 100,
              child: TextField(
                key: const ValueKey<String>('inventory-editor-quantity'),
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
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(istAusgeruestet: value),
            ),
            title: const Text('Ausgerüstet'),
            subtitle: const Text(
              'Modifikatoren wirken nur, wenn das Item ausgerüstet ist.',
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ],
        const SizedBox(height: _fieldSpacing),
        TextField(
          key: const ValueKey<String>('inventory-editor-origin'),
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
          key: const ValueKey<String>('inventory-editor-description'),
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
            key: const ValueKey<String>('inventory-editor-weight'),
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
            key: const ValueKey<String>('inventory-editor-value'),
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
      onChanged: (mods) =>
          setState(() => _draft = _draft.copyWith(modifiers: mods)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleSmall;

    return Text(title, style: titleStyle?.copyWith(color: colorScheme.primary));
  }
}

class _InlineHeader extends StatelessWidget {
  const _InlineHeader({
    required this.title,
    required this.onSave,
    required this.onCancel,
    required this.isSaving,
  });

  final String title;
  final Future<void> Function() onSave;
  final VoidCallback onCancel;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        TextButton(
          key: const ValueKey<String>('inventory-editor-cancel'),
          onPressed: isSaving ? null : onCancel,
          child: const Text('Abbrechen'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const ValueKey<String>('inventory-editor-save'),
          onPressed: isSaving ? null : onSave,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _LinkedHint extends StatelessWidget {
  const _LinkedHint({required this.gegenstand});

  final String gegenstand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$gegenstand (verknüpft – bearbeite im Kampf-Tab)',
              style: bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown zur Auswahl des Traegers Held oder Begleiter.
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
      for (final companion in companions)
        DropdownMenuItem(
          value: 'begleiter:${companion.id}',
          child: Text(
            companion.name.isEmpty ? 'Unbenannter Begleiter' : companion.name,
          ),
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
      onChanged: (value) {
        if (value == null) {
          return;
        }
        if (value == 'held') {
          onChanged(InventoryTraeger.held, null);
          return;
        }
        final id = value.substring('begleiter:'.length);
        onChanged(InventoryTraeger.begleiter, id);
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
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: items.entries
          .map(
            (entry) =>
                DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
          )
          .toList(growable: false),
      onChanged: enabled ? onChanged : null,
    );
  }
}
