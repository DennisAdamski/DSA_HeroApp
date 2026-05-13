part of '../catalog_entry_editor_screen.dart';

extension _CatalogEntryDataAccess on _CatalogEntryEditorScreenState {
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
      case CatalogSectionId.generalSpecialAbilities:
      case CatalogSectionId.magicSpecialAbilities:
      case CatalogSectionId.karmalSpecialAbilities:
      case CatalogSectionId.advantages:
      case CatalogSectionId.disadvantages:
        break;
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
      CatalogSectionId.combatSpecialAbilities ||
      CatalogSectionId.generalSpecialAbilities ||
      CatalogSectionId.magicSpecialAbilities ||
      CatalogSectionId.karmalSpecialAbilities ||
      CatalogSectionId.advantages ||
      CatalogSectionId.disadvantages => _buildEntryFromJson(),
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
