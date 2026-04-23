import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';

/// Beschreibt ein Problem beim Laden oder Anwenden eines Hausregel-Pakets.
class HouseRulePackIssue {
  /// Erstellt einen strukturierten Hinweis zu einem Hausregel-Paket.
  const HouseRulePackIssue({
    required this.message,
    this.packId = '',
    this.packTitle = '',
    this.filePath = '',
    this.section,
    this.entryId = '',
    this.fieldPath = '',
  });

  /// Menschlich lesbare Fehlermeldung.
  final String message;

  /// Betroffenes Paket oder leer fuer globale Probleme.
  final String packId;

  /// Optionaler Anzeigename des Pakets.
  final String packTitle;

  /// Optionaler Dateipfad der Quelle.
  final String filePath;

  /// Optional betroffene Katalogsektion.
  final CatalogSectionId? section;

  /// Optional betroffene Eintrags-ID.
  final String entryId;

  /// Optional betroffener Feldpfad.
  final String fieldPath;
}

/// Geladene Hausregel-Pakete samt Problemen aus einer Quelle.
class HouseRulePackSourceSnapshot {
  /// Erstellt einen Snapshot fuer geladene Paket-Manifeste.
  const HouseRulePackSourceSnapshot({
    this.packs = const <HouseRulePackManifest>[],
    this.issues = const <HouseRulePackIssue>[],
  });

  /// Erfolgreich geladene Pakete.
  final List<HouseRulePackManifest> packs;

  /// Probleme beim Laden oder Validieren.
  final List<HouseRulePackIssue> issues;
}

/// Selektor fuer Bulk-Patches auf Katalogeintraege.
class HouseRuleSelector {
  /// Erstellt einen Selektor fuer Hausregel-Patches.
  const HouseRuleSelector({
    this.entryId = '',
    this.fieldEquals = const <String, dynamic>{},
    this.hasTags = const <String>[],
  });

  /// Exakte Eintrags-ID.
  final String entryId;

  /// Zu vergleichende Feldpfade und Sollwerte.
  final Map<String, dynamic> fieldEquals;

  /// Benoetigte Regel-Tags.
  final List<String> hasTags;

  /// Deserialisiert den Selektor tolerant aus JSON.
  factory HouseRuleSelector.fromJson(Map<String, dynamic> json) {
    final fieldEqualsRaw =
        readCatalogObject(json, 'fieldEquals') ?? const <String, dynamic>{};
    final hasTagRaw = json['hasTag'];
    final hasTags = <String>[];
    if (hasTagRaw is String && hasTagRaw.trim().isNotEmpty) {
      hasTags.add(hasTagRaw.trim());
    } else if (hasTagRaw is List) {
      for (final entry in hasTagRaw) {
        if (entry is String && entry.trim().isNotEmpty) {
          hasTags.add(entry.trim());
        }
      }
    }

    return HouseRuleSelector(
      entryId: readCatalogString(json, 'entryId', fallback: ''),
      fieldEquals: fieldEqualsRaw,
      hasTags: List<String>.unmodifiable(hasTags),
    );
  }

  /// Gibt an, ob der Selektor keinerlei Einschraenkung enthaelt.
  bool get isEmpty =>
      entryId.trim().isEmpty && fieldEquals.isEmpty && hasTags.isEmpty;

  /// Serialisiert den Selektor zurueck in das JSON-Format.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (entryId.trim().isNotEmpty) {
      json['entryId'] = entryId.trim();
    }
    if (fieldEquals.isNotEmpty) {
      json['fieldEquals'] = _cloneJsonMap(fieldEquals);
    }
    if (hasTags.isNotEmpty) {
      json['hasTag'] = List<String>.unmodifiable(hasTags);
    }
    return json;
  }

  /// Prueft, ob ein Eintrag vom Selektor erfasst wird.
  bool matches({
    required CatalogSectionId section,
    required Map<String, dynamic> entry,
  }) {
    if (entryId.trim().isNotEmpty) {
      final currentId = (entry['id'] as String? ?? '').trim();
      if (currentId != entryId.trim()) {
        return false;
      }
    }

    for (final condition in fieldEquals.entries) {
      final currentValue = readHouseRuleFieldValue(entry, condition.key);
      if (!_valuesMatch(currentValue, condition.value)) {
        return false;
      }
    }

    if (hasTags.isNotEmpty) {
      final availableTags = collectRuleTagsForEntry(
        section: section,
        entry: entry,
      );
      for (final requiredTag in hasTags) {
        if (!availableTags.contains(requiredTag)) {
          return false;
        }
      }
    }

    return true;
  }
}

/// Beschreibt einen einzelnen Patch innerhalb eines Hausregel-Pakets.
class HouseRulePatch {
  /// Erstellt einen strukturierten Patch.
  const HouseRulePatch({
    required this.section,
    required this.setFields,
    required this.addEntries,
    required this.deactivateEntries,
    this.selector,
    this.priority,
  });

  /// Zielsektion des Patches.
  final CatalogSectionId section;

  /// Optionaler Selektor fuer bestehende Eintraege.
  final HouseRuleSelector? selector;

  /// Zu setzende Feldwerte fuer alle gematchten Eintraege.
  final Map<String, dynamic> setFields;

  /// Neu hinzuzufuegende Eintraege.
  final List<Map<String, dynamic>> addEntries;

  /// Entfernt alle gematchten Eintraege aus dem wirksamen Katalog.
  final bool deactivateEntries;

  /// Optionale Patch-Prioritaet, sonst greift die Paket-Prioritaet.
  final int? priority;

  /// Deserialisiert einen Patch aus JSON.
  factory HouseRulePatch.fromJson(Map<String, dynamic> json) {
    final sectionName = readCatalogString(json, 'section', fallback: '');
    final section = houseRuleSectionIdFromString(sectionName);
    if (section == null) {
      throw FormatException('Unbekannte Hausregel-Sektion "$sectionName".');
    }

    final selectorJson = readCatalogObject(json, 'selector');
    final selector = selectorJson == null
        ? null
        : HouseRuleSelector.fromJson(selectorJson);
    final setFields =
        readCatalogObject(json, 'setFields') ?? const <String, dynamic>{};
    final addEntries = readCatalogObjectList(json, 'addEntries');
    final deactivateEntries = readCatalogBool(
      json,
      'deactivateEntries',
      fallback: false,
    );
    final priority = json['priority'] is int ? json['priority'] as int : null;

    if (setFields.isEmpty && addEntries.isEmpty && !deactivateEntries) {
      throw const FormatException(
        'Hausregel-Patch benoetigt setFields, addEntries oder deactivateEntries.',
      );
    }
    if ((setFields.isNotEmpty || deactivateEntries) &&
        (selector == null || selector.isEmpty)) {
      throw const FormatException(
        'setFields/deactivateEntries benoetigen einen nicht-leeren selector.',
      );
    }

    return HouseRulePatch(
      section: section,
      selector: selector,
      setFields: setFields,
      addEntries: addEntries,
      deactivateEntries: deactivateEntries,
      priority: priority,
    );
  }

  /// Liefert die wirksame Prioritaet dieses Patches.
  int effectivePriority(int packPriority) => priority ?? packPriority;

  /// Serialisiert den Patch zurueck in das JSON-Format.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'section': section.name};
    final selectorJson = selector?.toJson() ?? const <String, dynamic>{};
    if (selectorJson.isNotEmpty) {
      json['selector'] = selectorJson;
    }
    if (setFields.isNotEmpty) {
      json['setFields'] = _cloneJsonMap(setFields);
    }
    if (addEntries.isNotEmpty) {
      json['addEntries'] = addEntries
          .map((entry) => _cloneJsonMap(entry))
          .toList(growable: false);
    }
    if (deactivateEntries) {
      json['deactivateEntries'] = true;
    }
    if (priority != null) {
      json['priority'] = priority;
    }
    return json;
  }
}

/// Manifest eines aktivierbaren Hausregel-Pakets.
class HouseRulePackManifest {
  /// Erstellt ein Hausregel-Paket mit allen Laufzeitdaten.
  const HouseRulePackManifest({
    required this.id,
    required this.title,
    required this.description,
    required this.patches,
    this.parentPackId = '',
    this.priority = 0,
    this.filePath = '',
    this.isBuiltIn = false,
  });

  /// Stabile Paket-ID.
  final String id;

  /// Anzeigename.
  final String title;

  /// Beschreibung fuer Settings und Tooltips.
  final String description;

  /// Optionale Parent-ID fuer hierarchische Aktivierung.
  final String parentPackId;

  /// Standard-Prioritaet aller Patches des Pakets.
  final int priority;

  /// Enthaltene Patches.
  final List<HouseRulePatch> patches;

  /// Herkunftsdatei fuer Diagnose und UI.
  final String filePath;

  /// Ob das Paket aus App-Assets stammt.
  final bool isBuiltIn;

  /// Ob das Paket keinen Parent besitzt.
  bool get isRoot => parentPackId.trim().isEmpty;

  /// Deserialisiert ein Paket-Manifest aus JSON.
  factory HouseRulePackManifest.fromJson(
    Map<String, dynamic> json, {
    String filePath = '',
    bool isBuiltIn = false,
  }) {
    final id = readCatalogString(json, 'id', fallback: '').trim();
    if (id.isEmpty) {
      throw const FormatException(
        'Hausregel-Paket benoetigt eine nicht-leere ID.',
      );
    }
    final title = readCatalogString(json, 'title', fallback: '').trim();
    if (title.isEmpty) {
      throw FormatException(
        'Hausregel-Paket "$id" benoetigt einen nicht-leeren Titel.',
      );
    }

    final rawPatches = (json['patches'] as List?) ?? const [];
    final patches = <HouseRulePatch>[];
    for (final rawPatch in rawPatches) {
      if (rawPatch is Map<String, dynamic>) {
        patches.add(HouseRulePatch.fromJson(rawPatch));
        continue;
      }
      if (rawPatch is Map) {
        patches.add(HouseRulePatch.fromJson(rawPatch.cast<String, dynamic>()));
        continue;
      }
      throw FormatException(
        'Hausregel-Paket "$id" enthaelt einen ungueltigen Patch-Eintrag.',
      );
    }

    return HouseRulePackManifest(
      id: id,
      title: title,
      description: readCatalogString(json, 'description', fallback: ''),
      parentPackId: readCatalogString(json, 'parentPackId', fallback: ''),
      priority: readCatalogInt(json, 'priority', fallback: 0),
      patches: List<HouseRulePatch>.unmodifiable(patches),
      filePath: filePath,
      isBuiltIn: isBuiltIn,
    );
  }

  /// Serialisiert das Manifest zurueck in das JSON-Format.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'patches': patches.map((patch) => patch.toJson()).toList(growable: false),
    };
    if (parentPackId.trim().isNotEmpty) {
      json['parentPackId'] = parentPackId.trim();
    }
    if (priority != 0) {
      json['priority'] = priority;
    }
    return json;
  }
}

/// Zusammengefuehrte Sicht auf alle bekannten Hausregel-Pakete.
class HouseRulePackCatalog {
  /// Erstellt den Laufzeitkatalog aller Hausregel-Pakete.
  const HouseRulePackCatalog({
    this.packs = const <HouseRulePackManifest>[],
    this.issues = const <HouseRulePackIssue>[],
  });

  /// Alle geladenen Pakete.
  final List<HouseRulePackManifest> packs;

  /// Alle bekannten Probleme.
  final List<HouseRulePackIssue> issues;

  /// Fuehrt mehrere Paketquellen zusammen und prueft auf ID-Konflikte.
  factory HouseRulePackCatalog.merge({
    required HouseRulePackSourceSnapshot builtIn,
    required HouseRulePackSourceSnapshot imported,
  }) {
    final issues = <HouseRulePackIssue>[...builtIn.issues, ...imported.issues];
    final packs = <HouseRulePackManifest>[];
    final packsById = <String, HouseRulePackManifest>{};

    void addAll(
      Iterable<HouseRulePackManifest> manifests, {
      required bool preferExisting,
    }) {
      for (final manifest in manifests) {
        final existing = packsById[manifest.id];
        if (existing != null) {
          final ignored = preferExisting ? manifest : existing;
          issues.add(
            HouseRulePackIssue(
              packId: manifest.id,
              packTitle: manifest.title,
              filePath: ignored.filePath,
              message:
                  'Paket-ID kollidiert mit "${existing.title}" und wird ignoriert.',
            ),
          );
          if (!preferExisting) {
            packsById[manifest.id] = manifest;
          }
          continue;
        }
        packsById[manifest.id] = manifest;
        packs.add(manifest);
      }
    }

    addAll(builtIn.packs, preferExisting: true);
    addAll(imported.packs, preferExisting: true);

    for (final pack in packs) {
      final parentId = pack.parentPackId.trim();
      if (parentId.isNotEmpty && !packsById.containsKey(parentId)) {
        issues.add(
          HouseRulePackIssue(
            packId: pack.id,
            packTitle: pack.title,
            filePath: pack.filePath,
            message:
                'Parent-Paket "$parentId" ist unbekannt; das Paket bleibt als Root sichtbar.',
          ),
        );
      }
    }
    return HouseRulePackCatalog(
      packs: List<HouseRulePackManifest>.unmodifiable(packs),
      issues: List<HouseRulePackIssue>.unmodifiable(issues),
    );
  }

  /// Sucht ein Paket per ID.
  HouseRulePackManifest? find(String packId) {
    final normalized = packId.trim();
    for (final pack in packs) {
      if (pack.id == normalized) {
        return pack;
      }
    }
    return null;
  }

  /// Gibt an, ob die Paket-ID bekannt ist.
  bool contains(String packId) => find(packId) != null;

  /// Liefert alle Root-Pakete sortiert nach Titel.
  List<HouseRulePackManifest> get roots =>
      packs
          .where((pack) {
            final parentId = pack.parentPackId.trim();
            return parentId.isEmpty || !contains(parentId);
          })
          .toList(growable: false)
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );

  /// Liefert direkte Kinder eines Pakets.
  List<HouseRulePackManifest> childrenOf(String packId) =>
      packs
          .where((pack) => pack.parentPackId.trim() == packId.trim())
          .toList(growable: false)
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );

  /// Berechnet alle wirksamen Paket-IDs unter Beruecksichtigung der Parent-Kette.
  Set<String> resolveActivePackIds(Set<String> disabledPackIds) {
    final active = <String>{};
    for (final pack in packs) {
      if (_isPackActive(pack: pack, disabledPackIds: disabledPackIds)) {
        active.add(pack.id);
      }
    }
    return Set<String>.unmodifiable(active);
  }

  bool _isPackActive({
    required HouseRulePackManifest pack,
    required Set<String> disabledPackIds,
  }) {
    var current = pack;
    while (true) {
      if (disabledPackIds.contains(current.id)) {
        return false;
      }
      final parentId = current.parentPackId.trim();
      if (parentId.isEmpty) {
        return true;
      }
      final parent = find(parentId);
      if (parent == null) {
        return true;
      }
      current = parent;
    }
  }
}

/// Loest String-IDs tolerant zu [CatalogSectionId] auf.
CatalogSectionId? houseRuleSectionIdFromString(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  for (final section in editableCatalogSections) {
    if (section.name == normalized || section.directoryName == normalized) {
      return section;
    }
  }
  return null;
}

/// Liest einen verschachtelten Feldwert aus einem rohen Katalogeintrag.
Object? readHouseRuleFieldValue(Map<String, dynamic> entry, String fieldPath) {
  if (fieldPath.trim().isEmpty) {
    return null;
  }

  Object? current = entry;
  for (final segment in fieldPath.split('.')) {
    if (current is! Map) {
      return null;
    }
    current = current[segment];
  }
  return current;
}

/// Liefert die wirksamen Regel-Tags eines rohen Katalogeintrags.
Set<String> collectRuleTagsForEntry({
  required CatalogSectionId section,
  required Map<String, dynamic> entry,
}) {
  final tags = <String>{};
  final ruleMeta = readCatalogObject(entry, 'ruleMeta');
  if (ruleMeta != null) {
    tags.addAll(readCatalogStringList(ruleMeta, 'ruleTags'));
  }

  switch (section) {
    case CatalogSectionId.talents:
    case CatalogSectionId.combatTalents:
      final group = (entry['group'] as String? ?? '').trim();
      final groupTag = _deriveTalentGroupTag(group);
      if (groupTag != null) {
        tags.add(groupTag);
      }
      final type = (entry['type'] as String? ?? '').trim();
      if (type.isNotEmpty) {
        tags.add('talent.type.${_normalizeRuleToken(type)}');
      }
      break;
    default:
      break;
  }

  return Set<String>.unmodifiable(tags);
}

String? _deriveTalentGroupTag(String group) {
  final normalized = _normalizeRuleToken(group);
  return switch (normalized) {
    'gabe' => 'talent.group.gabe',
    'gesellschaftliche_talente' => 'talent.group.gesellschaft',
    'handwerkliche_talente' => 'talent.group.handwerk',
    'koerperliche_talente' => 'talent.group.koerper',
    'natur_talente' => 'talent.group.natur',
    'wissenstalente' => 'talent.group.wissen',
    'kampftalent' => 'talent.group.kampf',
    _ => null,
  };
}

String _normalizeRuleToken(String value) {
  final lower = value.trim().toLowerCase();
  final replaced = lower
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');
  final buffer = StringBuffer();
  var lastWasSeparator = false;
  for (final codeUnit in replaced.codeUnits) {
    final isAlphaNumeric =
        (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 97 && codeUnit <= 122);
    if (isAlphaNumeric) {
      buffer.writeCharCode(codeUnit);
      lastWasSeparator = false;
      continue;
    }
    if (!lastWasSeparator) {
      buffer.write('_');
      lastWasSeparator = true;
    }
  }
  return buffer.toString().replaceAll(RegExp(r'^_+|_+$'), '');
}

bool _valuesMatch(Object? left, Object? right) {
  if (left == null || right == null) {
    return left == right;
  }
  if (left is num && right is num) {
    return left == right;
  }
  if (left is bool && right is bool) {
    return left == right;
  }
  return left.toString().trim() == right.toString().trim();
}

Map<String, dynamic> _cloneJsonMap(Map<String, dynamic> value) {
  return value.map<String, dynamic>(
    (key, nestedValue) => MapEntry(key, _cloneJsonValue(nestedValue)),
  );
}

dynamic _cloneJsonValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return _cloneJsonMap(value);
  }
  if (value is Map) {
    return _cloneJsonMap(value.cast<String, dynamic>());
  }
  if (value is List) {
    return value.map(_cloneJsonValue).toList(growable: false);
  }
  return value;
}
