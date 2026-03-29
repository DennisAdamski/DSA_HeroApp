import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';

/// Editor für benutzerdefinierte Katalogeinträge.
class CatalogEntryEditorScreen extends ConsumerStatefulWidget {
  /// Erstellt den Editor für eine einzelne Katalogsektion.
  const CatalogEntryEditorScreen({
    super.key,
    required this.section,
    this.initialEntry,
  });

  /// Bearbeitete Katalogsektion.
  final CatalogSectionId section;

  /// Optional vorhandener Custom-Eintrag für den Bearbeitungsmodus.
  final Map<String, dynamic>? initialEntry;

  @override
  ConsumerState<CatalogEntryEditorScreen> createState() =>
      _CatalogEntryEditorScreenState();
}

class _CatalogEntryEditorScreenState
    extends ConsumerState<CatalogEntryEditorScreen> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final JsonEncoder _jsonEncoder = const JsonEncoder.withIndent('  ');
  late final Map<String, dynamic> _seedEntry;
  late bool _active;
  late bool _schriftlos;
  String _errorText = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final rawEntry =
        widget.initialEntry ?? defaultCatalogEntryTemplate(widget.section);
    _seedEntry = canonicalizeCatalogEntry(widget.section, rawEntry);
    _active = (_seedEntry['active'] as bool?) ?? true;
    _schriftlos = (_seedEntry['schriftlos'] as bool?) ?? false;
    _initializeControllers();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initialEntry == null
        ? '${widget.section.singularLabel} hinzufügen'
        : '${widget.section.singularLabel} bearbeiten';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorText.isNotEmpty) ...[
                    _ErrorBox(message: _errorText),
                    const SizedBox(height: 12),
                  ],
                  if (widget.section.usesJsonEditor)
                    _buildJsonEditor()
                  else
                    _buildFormFields(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Speichern'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJsonEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JSON-Editor', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Der Eintrag wird beim Speichern geparst, validiert und in das App-Schema normalisiert.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller('json'),
          minLines: 18,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'JSON',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _formatJson,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Formatieren'),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: switch (widget.section) {
        CatalogSectionId.talents => _buildTalentFields(isCombatTalent: false),
        CatalogSectionId.combatTalents => _buildTalentFields(
          isCombatTalent: true,
        ),
        CatalogSectionId.weapons => _buildWeaponFields(),
        CatalogSectionId.spells => _buildSpellFields(),
        CatalogSectionId.maneuvers => _buildManeuverFields(),
        CatalogSectionId.sprachen => _buildSpracheFields(),
        CatalogSectionId.schriften => _buildSchriftFields(),
        CatalogSectionId.combatSpecialAbilities => const <Widget>[],
      },
    );
  }

  List<Widget> _buildTalentFields({required bool isCombatTalent}) {
    return <Widget>[
      _buildIdField(),
      const SizedBox(height: 12),
      _buildTextField(label: 'Name', fieldKey: 'name'),
      const SizedBox(height: 12),
      _buildTextField(
        label: 'Gruppe',
        fieldKey: 'group',
        readOnly: isCombatTalent,
      ),
      const SizedBox(height: 12),
      _buildTextField(label: 'Steigerung', fieldKey: 'steigerung'),
      const SizedBox(height: 12),
      _buildTextField(
        label: 'Eigenschaften',
        fieldKey: 'attributes',
        helper:
            'Kommasepariert oder eine Eigenschaft pro Zeile, z. B. MU, IN, FF',
      ),
      const SizedBox(height: 12),
      _buildTextField(label: 'Typ', fieldKey: 'type'),
      const SizedBox(height: 12),
      _buildTextField(label: 'BE', fieldKey: 'be'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Waffenkategorie', fieldKey: 'weaponCategory'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Alternativen', fieldKey: 'alternatives'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Quelle', fieldKey: 'source'),
      const SizedBox(height: 12),
      _buildTextField(
        label: 'Beschreibung',
        fieldKey: 'description',
        minLines: 4,
      ),
      const SizedBox(height: 12),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Aktiv'),
        value: _active,
        onChanged: (value) => setState(() => _active = value),
      ),
    ];
  }

  List<Widget> _buildWeaponFields() {
    return <Widget>[
      _buildIdField(),
      const SizedBox(height: 12),
      _buildTextField(label: 'Name', fieldKey: 'name'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Typ', fieldKey: 'type'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Kampftalent', fieldKey: 'combatSkill'),
      const SizedBox(height: 12),
      _buildTextField(label: 'TP', fieldKey: 'tp'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Komplexität', fieldKey: 'complexity'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Waffenkategorie', fieldKey: 'weaponCategory'),
      const SizedBox(height: 12),
      _buildTextField(
        label: 'Mögliche Manöver',
        fieldKey: 'possibleManeuvers',
        minLines: 3,
        helper: 'Ein Manöver pro Zeile oder kommasepariert.',
      ),
      const SizedBox(height: 12),
      _buildTextField(
        label: 'Aktive Standard-Manöver',
        fieldKey: 'activeManeuvers',
        minLines: 3,
        helper: 'Ein Manöver pro Zeile oder kommasepariert.',
      ),
      const SizedBox(height: 12),
      _buildTextField(label: 'TP/KK', fieldKey: 'tpkk'),
      const SizedBox(height: 12),
      _buildTextField(label: 'INI-Mod', fieldKey: 'iniMod', number: true),
      const SizedBox(height: 12),
      _buildTextField(label: 'AT-Mod', fieldKey: 'atMod', number: true),
      const SizedBox(height: 12),
      _buildTextField(label: 'PA-Mod', fieldKey: 'paMod', number: true),
      const SizedBox(height: 12),
      _buildTextField(label: 'Gewicht', fieldKey: 'weight'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Länge', fieldKey: 'length'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Bruchfaktor', fieldKey: 'breakFactor'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Preis', fieldKey: 'price'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Bemerkungen', fieldKey: 'remarks'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Ladezeit', fieldKey: 'reloadTime', number: true),
      const SizedBox(height: 12),
      _buildTextField(label: 'Ladezeit-Text', fieldKey: 'reloadTimeText'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Reichweite / DK', fieldKey: 'reach'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Quelle', fieldKey: 'source'),
      const SizedBox(height: 12),
      _buildTextField(
        label: 'Distanzbänder',
        fieldKey: 'rangedDistanceBands',
        minLines: 4,
        helper: 'Eine Zeile pro Band: Label|TP-Mod, z. B. nah|1',
      ),
      const SizedBox(height: 12),
      _buildTextField(
        label: 'Geschossvorlagen',
        fieldKey: 'rangedProjectiles',
        minLines: 5,
        helper:
            'Eine Zeile pro Geschoss: Name|Anzahl|TP-Mod|INI-Mod|AT-Mod|Beschreibung',
      ),
      const SizedBox(height: 12),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Aktiv'),
        value: _active,
        onChanged: (value) => setState(() => _active = value),
      ),
    ];
  }

  List<Widget> _buildSpellFields() {
    return <Widget>[
      _buildIdField(),
      const SizedBox(height: 12),
      _buildTextField(label: 'Name', fieldKey: 'name'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Tradition', fieldKey: 'tradition'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Steigerung', fieldKey: 'steigerung'),
      const SizedBox(height: 12),
      _buildTextField(
        label: 'Eigenschaften',
        fieldKey: 'attributes',
        helper:
            'Kommasepariert oder eine Eigenschaft pro Zeile, z. B. KL, IN, CH',
      ),
      const SizedBox(height: 12),
      _buildTextField(label: 'Verfügbarkeit', fieldKey: 'availability'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Merkmale', fieldKey: 'traits'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Modifikator', fieldKey: 'modifier'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Zauberdauer', fieldKey: 'castingTime'),
      const SizedBox(height: 12),
      _buildTextField(label: 'AsP-Kosten', fieldKey: 'aspCost'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Zielobjekt', fieldKey: 'targetObject'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Reichweite', fieldKey: 'range'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Wirkungsdauer', fieldKey: 'duration'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Modifikationen', fieldKey: 'modifications'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Kategorie', fieldKey: 'category'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Quelle', fieldKey: 'source'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Wirkung', fieldKey: 'wirkung', minLines: 5),
      const SizedBox(height: 12),
      _buildTextField(
        label: 'Varianten',
        fieldKey: 'variants',
        minLines: 4,
        helper: 'Eine Variante pro Zeile oder kommasepariert.',
      ),
      const SizedBox(height: 12),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Aktiv'),
        value: _active,
        onChanged: (value) => setState(() => _active = value),
      ),
    ];
  }

  List<Widget> _buildManeuverFields() {
    return <Widget>[
      _buildIdField(),
      const SizedBox(height: 12),
      _buildTextField(label: 'Name', fieldKey: 'name'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Gruppe', fieldKey: 'gruppe'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Typ', fieldKey: 'typ'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Erschwernis', fieldKey: 'erschwernis'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Seite', fieldKey: 'seite'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Kurzbeschreibung', fieldKey: 'erklarung'),
      const SizedBox(height: 12),
      _buildTextField(
        label: 'Lange Erklärung',
        fieldKey: 'erklarung_lang',
        minLines: 4,
      ),
      const SizedBox(height: 12),
      _buildTextField(label: 'Voraussetzungen', fieldKey: 'voraussetzungen'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Verbreitung', fieldKey: 'verbreitung'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Kosten', fieldKey: 'kosten'),
    ];
  }

  List<Widget> _buildSpracheFields() {
    return <Widget>[
      _buildIdField(),
      const SizedBox(height: 12),
      _buildTextField(label: 'Name', fieldKey: 'name'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Familie', fieldKey: 'familie'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Maximalwert', fieldKey: 'maxWert', number: true),
      const SizedBox(height: 12),
      _buildTextField(label: 'Steigerung', fieldKey: 'steigerung'),
      const SizedBox(height: 12),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Schriftlos'),
        subtitle: const Text(
          'Aktivieren, wenn diese Sprache keine zugeordneten Schrift-IDs hat.',
        ),
        value: _schriftlos,
        onChanged: (value) => setState(() => _schriftlos = value),
      ),
      const SizedBox(height: 12),
      _buildTextField(
        label: 'Schrift-IDs',
        fieldKey: 'schriftIds',
        minLines: 3,
        helper: 'Eine Schrift-ID pro Zeile oder kommasepariert.',
        readOnly: _schriftlos,
      ),
      const SizedBox(height: 12),
      _buildTextField(label: 'Hinweise', fieldKey: 'hinweise', minLines: 4),
    ];
  }

  List<Widget> _buildSchriftFields() {
    return <Widget>[
      _buildIdField(),
      const SizedBox(height: 12),
      _buildTextField(label: 'Name', fieldKey: 'name'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Maximalwert', fieldKey: 'maxWert', number: true),
      const SizedBox(height: 12),
      _buildTextField(label: 'Beschreibung', fieldKey: 'beschreibung'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Steigerung', fieldKey: 'steigerung'),
      const SizedBox(height: 12),
      _buildTextField(label: 'Hinweise', fieldKey: 'hinweise', minLines: 4),
    ];
  }

  Widget _buildIdField() {
    return TextField(
      controller: _controller('id'),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'ID',
        helperText: 'Muss innerhalb der Sektion eindeutig sein.',
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String fieldKey,
    String? helper,
    int minLines = 1,
    bool number = false,
    bool readOnly = false,
  }) {
    return TextField(
      controller: _controller(fieldKey),
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : null,
      keyboardType: number
          ? const TextInputType.numberWithOptions(signed: true)
          : (minLines == 1 ? TextInputType.text : TextInputType.multiline),
      readOnly: readOnly,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        helperText: helper,
        alignLabelWithHint: minLines > 1,
      ),
    );
  }

  void _initializeControllers() {
    if (widget.section.usesJsonEditor) {
      _controller('json').text = _jsonEncoder.convert(_seedEntry);
      return;
    }

    switch (widget.section) {
      case CatalogSectionId.talents:
      case CatalogSectionId.combatTalents:
        _setControllerText('id', _stringValue('id'));
        _setControllerText('name', _stringValue('name'));
        _setControllerText('group', _stringValue('group'));
        _setControllerText('steigerung', _stringValue('steigerung'));
        _setControllerText('attributes', _stringListValue('attributes'));
        _setControllerText('type', _stringValue('type'));
        _setControllerText('be', _stringValue('be'));
        _setControllerText('weaponCategory', _stringValue('weaponCategory'));
        _setControllerText('alternatives', _stringValue('alternatives'));
        _setControllerText('source', _stringValue('source'));
        _setControllerText('description', _stringValue('description'));
        break;
      case CatalogSectionId.weapons:
        _setControllerText('id', _stringValue('id'));
        _setControllerText('name', _stringValue('name'));
        _setControllerText('type', _stringValue('type'));
        _setControllerText('combatSkill', _stringValue('combatSkill'));
        _setControllerText('tp', _stringValue('tp'));
        _setControllerText('complexity', _stringValue('complexity'));
        _setControllerText('weaponCategory', _stringValue('weaponCategory'));
        _setControllerText(
          'possibleManeuvers',
          _stringListValue('possibleManeuvers'),
        );
        _setControllerText(
          'activeManeuvers',
          _stringListValue('activeManeuvers'),
        );
        _setControllerText('tpkk', _stringValue('tpkk'));
        _setControllerText('iniMod', _numberValue('iniMod'));
        _setControllerText('atMod', _numberValue('atMod'));
        _setControllerText('paMod', _numberValue('paMod'));
        _setControllerText('weight', _stringValue('weight'));
        _setControllerText('length', _stringValue('length'));
        _setControllerText('breakFactor', _stringValue('breakFactor'));
        _setControllerText('price', _stringValue('price'));
        _setControllerText('remarks', _stringValue('remarks'));
        _setControllerText('reloadTime', _numberValue('reloadTime'));
        _setControllerText('reloadTimeText', _stringValue('reloadTimeText'));
        _setControllerText('reach', _stringValue('reach'));
        _setControllerText('source', _stringValue('source'));
        _setControllerText(
          'rangedDistanceBands',
          _distanceBandsValue('rangedDistanceBands'),
        );
        _setControllerText(
          'rangedProjectiles',
          _projectilesValue('rangedProjectiles'),
        );
        break;
      case CatalogSectionId.spells:
        _setControllerText('id', _stringValue('id'));
        _setControllerText('name', _stringValue('name'));
        _setControllerText('tradition', _stringValue('tradition'));
        _setControllerText('steigerung', _stringValue('steigerung'));
        _setControllerText('attributes', _stringListValue('attributes'));
        _setControllerText('availability', _stringValue('availability'));
        _setControllerText('traits', _stringValue('traits'));
        _setControllerText('modifier', _stringValue('modifier'));
        _setControllerText('castingTime', _stringValue('castingTime'));
        _setControllerText('aspCost', _stringValue('aspCost'));
        _setControllerText('targetObject', _stringValue('targetObject'));
        _setControllerText('range', _stringValue('range'));
        _setControllerText('duration', _stringValue('duration'));
        _setControllerText('modifications', _stringValue('modifications'));
        _setControllerText('category', _stringValue('category'));
        _setControllerText('source', _stringValue('source'));
        _setControllerText('wirkung', _stringValue('wirkung'));
        _setControllerText('variants', _stringListValue('variants'));
        break;
      case CatalogSectionId.maneuvers:
        _setControllerText('id', _stringValue('id'));
        _setControllerText('name', _stringValue('name'));
        _setControllerText('gruppe', _stringValue('gruppe'));
        _setControllerText('typ', _stringValue('typ'));
        _setControllerText('erschwernis', _stringValue('erschwernis'));
        _setControllerText('seite', _stringValue('seite'));
        _setControllerText('erklarung', _stringValue('erklarung'));
        _setControllerText('erklarung_lang', _stringValue('erklarung_lang'));
        _setControllerText('voraussetzungen', _stringValue('voraussetzungen'));
        _setControllerText('verbreitung', _stringValue('verbreitung'));
        _setControllerText('kosten', _stringValue('kosten'));
        break;
      case CatalogSectionId.sprachen:
        _setControllerText('id', _stringValue('id'));
        _setControllerText('name', _stringValue('name'));
        _setControllerText('familie', _stringValue('familie'));
        _setControllerText('maxWert', _numberValue('maxWert'));
        _setControllerText('steigerung', _stringValue('steigerung'));
        _setControllerText('schriftIds', _stringListValue('schriftIds'));
        _setControllerText('hinweise', _stringValue('hinweise'));
        break;
      case CatalogSectionId.schriften:
        _setControllerText('id', _stringValue('id'));
        _setControllerText('name', _stringValue('name'));
        _setControllerText('maxWert', _numberValue('maxWert'));
        _setControllerText('beschreibung', _stringValue('beschreibung'));
        _setControllerText('steigerung', _stringValue('steigerung'));
        _setControllerText('hinweise', _stringValue('hinweise'));
        break;
      case CatalogSectionId.combatSpecialAbilities:
        break;
    }
  }

  TextEditingController _controller(String key) {
    return _controllers.putIfAbsent(key, TextEditingController.new);
  }

  void _setControllerText(String key, String value) {
    _controller(key).text = value;
  }

  String _stringValue(String key) {
    final value = _seedEntry[key];
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  String _numberValue(String key) {
    final value = _seedEntry[key];
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  String _stringListValue(String key) {
    final raw = _seedEntry[key];
    if (raw is! List) {
      return '';
    }
    return raw.map((entry) => entry.toString()).join('\n');
  }

  String _distanceBandsValue(String key) {
    final raw = _seedEntry[key];
    if (raw is! List) {
      return '';
    }
    final lines = <String>[];
    for (final value in raw) {
      if (value is! Map) {
        continue;
      }
      final label = (value['label'] as String? ?? '').trim();
      final tpMod = (value['tpMod'] as num?)?.toInt() ?? 0;
      if (label.isEmpty) {
        continue;
      }
      lines.add('$label|$tpMod');
    }
    return lines.join('\n');
  }

  String _projectilesValue(String key) {
    final raw = _seedEntry[key];
    if (raw is! List) {
      return '';
    }
    final lines = <String>[];
    for (final value in raw) {
      if (value is! Map) {
        continue;
      }
      final name = (value['name'] as String? ?? '').trim();
      if (name.isEmpty) {
        continue;
      }
      final count = (value['count'] as num?)?.toInt() ?? 0;
      final tpMod = (value['tpMod'] as num?)?.toInt() ?? 0;
      final iniMod = (value['iniMod'] as num?)?.toInt() ?? 0;
      final atMod = (value['atMod'] as num?)?.toInt() ?? 0;
      final description = (value['description'] as String? ?? '').trim();
      lines.add('$name|$count|$tpMod|$iniMod|$atMod|$description');
    }
    return lines.join('\n');
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorText = '';
    });

    try {
      final entry = widget.section.usesJsonEditor
          ? _buildEntryFromJson()
          : _buildEntryFromForm();
      await ref
          .read(catalogActionsProvider)
          .saveCustomEntry(
            section: widget.section,
            entry: entry,
            previousId: (widget.initialEntry?['id'] as String? ?? '').trim(),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on FormatException catch (error) {
      setState(() {
        _errorText = error.message;
      });
    } on Exception catch (error) {
      setState(() {
        _errorText = 'Speichern fehlgeschlagen: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _formatJson() {
    try {
      final parsed = _buildEntryFromJson();
      final canonical = canonicalizeCatalogEntry(widget.section, parsed);
      _controller('json').text = _jsonEncoder.convert(canonical);
      setState(() => _errorText = '');
    } on FormatException catch (error) {
      setState(() => _errorText = error.message);
    }
  }

  Map<String, dynamic> _buildEntryFromJson() {
    final rawText = _controller('json').text.trim();
    if (rawText.isEmpty) {
      throw const FormatException('Das JSON-Feld darf nicht leer sein.');
    }
    final decoded = jsonDecode(rawText);
    if (decoded is! Map) {
      throw const FormatException('Der JSON-Editor erwartet ein Objekt.');
    }
    return decoded.cast<String, dynamic>();
  }

  Map<String, dynamic> _buildEntryFromForm() {
    return switch (widget.section) {
      CatalogSectionId.talents => <String, dynamic>{
        'id': _readText('id'),
        'name': _readText('name'),
        'group': _readText('group'),
        'steigerung': _readText('steigerung'),
        'attributes': _readStringList('attributes'),
        'type': _readText('type'),
        'be': _readText('be'),
        'weaponCategory': _readText('weaponCategory'),
        'alternatives': _readText('alternatives'),
        'source': _readText('source'),
        'description': _readText('description'),
        'active': _active,
      },
      CatalogSectionId.combatTalents => <String, dynamic>{
        'id': _readText('id'),
        'name': _readText('name'),
        'group': 'Kampftalent',
        'steigerung': _readText('steigerung'),
        'attributes': _readStringList('attributes'),
        'type': _readText('type'),
        'be': _readText('be'),
        'weaponCategory': _readText('weaponCategory'),
        'alternatives': _readText('alternatives'),
        'source': _readText('source'),
        'description': _readText('description'),
        'active': _active,
      },
      CatalogSectionId.weapons => <String, dynamic>{
        'id': _readText('id'),
        'name': _readText('name'),
        'type': _readText('type'),
        'combatSkill': _readText('combatSkill'),
        'tp': _readText('tp'),
        'complexity': _readText('complexity'),
        'weaponCategory': _readText('weaponCategory'),
        'possibleManeuvers': _readStringList('possibleManeuvers'),
        'activeManeuvers': _readStringList('activeManeuvers'),
        'tpkk': _readText('tpkk'),
        'iniMod': _readInt('iniMod'),
        'atMod': _readInt('atMod'),
        'paMod': _readInt('paMod'),
        'weight': _readText('weight'),
        'length': _readText('length'),
        'breakFactor': _readText('breakFactor'),
        'price': _readText('price'),
        'remarks': _readText('remarks'),
        'reloadTime': _readInt('reloadTime'),
        'reloadTimeText': _readText('reloadTimeText'),
        'rangedDistanceBands': _parseDistanceBands(
          _controller('rangedDistanceBands').text,
        ),
        'rangedProjectiles': _parseProjectiles(
          _controller('rangedProjectiles').text,
        ),
        'reach': _readText('reach'),
        'source': _readText('source'),
        'active': _active,
      },
      CatalogSectionId.spells => <String, dynamic>{
        'id': _readText('id'),
        'name': _readText('name'),
        'tradition': _readText('tradition'),
        'steigerung': _readText('steigerung'),
        'attributes': _readStringList('attributes'),
        'availability': _readText('availability'),
        'traits': _readText('traits'),
        'modifier': _readText('modifier'),
        'castingTime': _readText('castingTime'),
        'aspCost': _readText('aspCost'),
        'targetObject': _readText('targetObject'),
        'range': _readText('range'),
        'duration': _readText('duration'),
        'modifications': _readText('modifications'),
        'wirkung': _readText('wirkung'),
        'variants': _readStringList('variants'),
        'category': _readText('category'),
        'source': _readText('source'),
        'active': _active,
      },
      CatalogSectionId.maneuvers => <String, dynamic>{
        'id': _readText('id'),
        'name': _readText('name'),
        'gruppe': _readText('gruppe'),
        'typ': _readText('typ'),
        'erschwernis': _readText('erschwernis'),
        'seite': _readText('seite'),
        'erklarung': _readText('erklarung'),
        'erklarung_lang': _readText('erklarung_lang'),
        'voraussetzungen': _readText('voraussetzungen'),
        'verbreitung': _readText('verbreitung'),
        'kosten': _readText('kosten'),
      },
      CatalogSectionId.combatSpecialAbilities => _buildEntryFromJson(),
      CatalogSectionId.sprachen => <String, dynamic>{
        'id': _readText('id'),
        'name': _readText('name'),
        'familie': _readText('familie'),
        'maxWert': _readInt('maxWert', fallback: 18),
        'steigerung': _readText('steigerung'),
        'schriftIds': _schriftlos
            ? const <String>[]
            : _readStringList('schriftIds'),
        'schriftlos': _schriftlos,
        'hinweise': _readText('hinweise'),
      },
      CatalogSectionId.schriften => <String, dynamic>{
        'id': _readText('id'),
        'name': _readText('name'),
        'maxWert': _readInt('maxWert', fallback: 10),
        'beschreibung': _readText('beschreibung'),
        'steigerung': _readText('steigerung'),
        'hinweise': _readText('hinweise'),
      },
    };
  }

  String _readText(String key) {
    return _controller(key).text.trim();
  }

  int _readInt(String key, {int fallback = 0}) {
    final value = _controller(key).text.trim();
    if (value.isEmpty) {
      return fallback;
    }
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw FormatException('Feld "$key" erwartet eine Ganzzahl.');
    }
    return parsed;
  }

  List<String> _readStringList(String key) {
    final raw = _controller(key).text;
    final tokens = raw.split(RegExp(r'[\n,;]+'));
    final normalized = <String>[];
    final seen = <String>{};
    for (final token in tokens) {
      final trimmed = token.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }

  List<Map<String, dynamic>> _parseDistanceBands(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    final result = <Map<String, dynamic>>[];
    for (final line in lines) {
      final parts = line.split('|');
      final label = parts.first.trim();
      if (label.isEmpty) {
        throw const FormatException(
          'Jedes Distanzband benötigt ein Label vor dem Trennzeichen "|".',
        );
      }
      final tpModText = parts.length > 1 ? parts[1].trim() : '0';
      final tpMod = int.tryParse(tpModText);
      if (tpMod == null) {
        throw FormatException(
          'Ungültiger TP-Modifikator im Distanzband "$line".',
        );
      }
      result.add(<String, dynamic>{'label': label, 'tpMod': tpMod});
    }
    return result;
  }

  List<Map<String, dynamic>> _parseProjectiles(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    final result = <Map<String, dynamic>>[];
    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length < 5) {
        throw const FormatException(
          'Geschosszeilen brauchen mindestens 5 Teile: Name|Anzahl|TP-Mod|INI-Mod|AT-Mod.',
        );
      }
      final name = parts[0].trim();
      if (name.isEmpty) {
        throw const FormatException('Jedes Geschoss benötigt einen Namen.');
      }
      final count = int.tryParse(parts[1].trim());
      final tpMod = int.tryParse(parts[2].trim());
      final iniMod = int.tryParse(parts[3].trim());
      final atMod = int.tryParse(parts[4].trim());
      if (count == null || tpMod == null || iniMod == null || atMod == null) {
        throw FormatException('Ungültige Zahl in Geschosszeile "$line".');
      }
      final description = parts.length > 5
          ? parts.sublist(5).join('|').trim()
          : '';
      result.add(<String, dynamic>{
        'name': name,
        'count': count,
        'tpMod': tpMod,
        'iniMod': iniMod,
        'atMod': atMod,
        'description': description,
      });
    }
    return result;
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
