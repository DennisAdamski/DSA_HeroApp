// ignore_for_file: invalid_use_of_protected_member

part of '../catalog_entry_editor_screen.dart';

extension _CatalogEntryFormFieldBuilders on _CatalogEntryEditorScreenState {
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
        CatalogSectionId.combatSpecialAbilities ||
        CatalogSectionId.generalSpecialAbilities ||
        CatalogSectionId.magicSpecialAbilities ||
        CatalogSectionId.karmalSpecialAbilities ||
        CatalogSectionId.advantages ||
        CatalogSectionId.disadvantages => const <Widget>[],
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
}
