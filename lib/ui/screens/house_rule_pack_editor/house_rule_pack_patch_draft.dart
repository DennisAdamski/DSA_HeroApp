part of '../house_rule_pack_editor_screen.dart';

/// Hält die Formular-Controller eines einzelnen Patch-Entwurfs zusammen.
class _PatchDraftControllers {
  _PatchDraftControllers({
    required this.section,
    required this.priorityController,
    required this.entryIdController,
    required this.hasTagsController,
    required this.fieldEqualsController,
    required this.setFieldsController,
    required this.addEntriesController,
    required this.deactivateEntries,
  });

  CatalogSectionId section;
  final TextEditingController priorityController;
  final TextEditingController entryIdController;
  final TextEditingController hasTagsController;
  final TextEditingController fieldEqualsController;
  final TextEditingController setFieldsController;
  final TextEditingController addEntriesController;
  bool deactivateEntries;

  factory _PatchDraftControllers.empty() {
    return _PatchDraftControllers(
      section: CatalogSectionId.talents,
      priorityController: TextEditingController(),
      entryIdController: TextEditingController(),
      hasTagsController: TextEditingController(),
      fieldEqualsController: TextEditingController(text: '{}'),
      setFieldsController: TextEditingController(text: '{}'),
      addEntriesController: TextEditingController(text: '[]'),
      deactivateEntries: false,
    );
  }

  factory _PatchDraftControllers.fromDraftJson(
    Map<String, dynamic> json, {
    required JsonEncoder encoder,
  }) {
    final sectionName = (json['section'] as String? ?? '').trim();
    final section = houseRuleSectionIdFromString(sectionName);
    if (section == null) {
      throw FormatException(
        'Patch erwartet eine gültige section, erhielt "$sectionName".',
      );
    }

    final selectorJson = json['selector'];
    if (selectorJson != null && selectorJson is! Map) {
      throw const FormatException('Patch selector erwartet ein JSON-Objekt.');
    }
    final selector = selectorJson is Map
        ? HouseRuleSelector.fromJson(selectorJson.cast<String, dynamic>())
        : null;
    final setFields = _coerceDraftJsonObject(
      json['setFields'],
      fieldLabel: 'setFields',
    );
    final addEntries = _coerceDraftJsonObjectList(
      json['addEntries'],
      fieldLabel: 'addEntries',
    );

    return _PatchDraftControllers(
      section: section,
      priorityController: TextEditingController(
        text: _coerceDraftText(json['priority']),
      ),
      entryIdController: TextEditingController(text: selector?.entryId ?? ''),
      hasTagsController: TextEditingController(
        text: selector?.hasTags.join('\n') ?? '',
      ),
      fieldEqualsController: TextEditingController(
        text: encoder.convert(
          selector?.fieldEquals ?? const <String, dynamic>{},
        ),
      ),
      setFieldsController: TextEditingController(
        text: encoder.convert(setFields),
      ),
      addEntriesController: TextEditingController(
        text: encoder.convert(addEntries),
      ),
      deactivateEntries: json['deactivateEntries'] == true,
    );
  }

  _PatchDraftControllers duplicate({required JsonEncoder encoder}) {
    return _PatchDraftControllers(
      section: section,
      priorityController: TextEditingController(text: priorityController.text),
      entryIdController: TextEditingController(text: entryIdController.text),
      hasTagsController: TextEditingController(text: hasTagsController.text),
      fieldEqualsController: TextEditingController(
        text: fieldEqualsController.text,
      ),
      setFieldsController: TextEditingController(
        text: setFieldsController.text,
      ),
      addEntriesController: TextEditingController(
        text: addEntriesController.text,
      ),
      deactivateEntries: deactivateEntries,
    );
  }

  void overwriteFrom(_PatchDraftControllers other) {
    section = other.section;
    priorityController.text = other.priorityController.text;
    entryIdController.text = other.entryIdController.text;
    hasTagsController.text = other.hasTagsController.text;
    fieldEqualsController.text = other.fieldEqualsController.text;
    setFieldsController.text = other.setFieldsController.text;
    addEntriesController.text = other.addEntriesController.text;
    deactivateEntries = other.deactivateEntries;
  }

  Map<String, dynamic> buildJson() {
    final patchJson = <String, dynamic>{'section': section.name};
    final selectorJson = <String, dynamic>{};
    final entryId = entryIdController.text.trim();
    if (entryId.isNotEmpty) {
      selectorJson['entryId'] = entryId;
    }

    final hasTags = _parseTags(hasTagsController.text);
    if (hasTags.isNotEmpty) {
      selectorJson['hasTag'] = hasTags;
    }

    final fieldEquals = _parseOptionalJsonObject(
      fieldEqualsController.text,
      fieldLabel: 'Selektor: fieldEquals',
    );
    if (fieldEquals.isNotEmpty) {
      selectorJson['fieldEquals'] = fieldEquals;
    }
    if (selectorJson.isNotEmpty) {
      patchJson['selector'] = selectorJson;
    }

    final setFields = _parseOptionalJsonObject(
      setFieldsController.text,
      fieldLabel: 'setFields',
    );
    if (setFields.isNotEmpty) {
      patchJson['setFields'] = setFields;
    }

    final addEntries = _parseOptionalJsonObjectList(
      addEntriesController.text,
      fieldLabel: 'addEntries',
    );
    if (addEntries.isNotEmpty) {
      patchJson['addEntries'] = addEntries;
    }

    if (deactivateEntries) {
      patchJson['deactivateEntries'] = true;
    }

    final priorityText = priorityController.text.trim();
    if (priorityText.isNotEmpty) {
      final priority = int.tryParse(priorityText);
      if (priority == null) {
        throw const FormatException('Patch-Priorität erwartet eine Ganzzahl.');
      }
      patchJson['priority'] = priority;
    }

    return patchJson;
  }

  void dispose() {
    priorityController.dispose();
    entryIdController.dispose();
    hasTagsController.dispose();
    fieldEqualsController.dispose();
    setFieldsController.dispose();
    addEntriesController.dispose();
  }

  static List<String> _parseTags(String rawText) {
    final tags = rawText
        .split(RegExp(r'[\n,;]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    return tags.toSet().toList(growable: false);
  }

  static Map<String, dynamic> _parseOptionalJsonObject(
    String rawText, {
    required String fieldLabel,
  }) {
    final normalizedText = rawText.trim();
    if (normalizedText.isEmpty || normalizedText == '{}') {
      return const <String, dynamic>{};
    }
    final decoded = jsonDecode(normalizedText);
    if (decoded is! Map) {
      throw FormatException('$fieldLabel erwartet ein JSON-Objekt.');
    }
    return decoded.cast<String, dynamic>();
  }

  static List<Map<String, dynamic>> _parseOptionalJsonObjectList(
    String rawText, {
    required String fieldLabel,
  }) {
    final normalizedText = rawText.trim();
    if (normalizedText.isEmpty || normalizedText == '[]') {
      return const <Map<String, dynamic>>[];
    }
    final decoded = jsonDecode(normalizedText);
    if (decoded is! List) {
      throw FormatException('$fieldLabel erwartet eine JSON-Liste.');
    }
    final result = <Map<String, dynamic>>[];
    for (final entry in decoded) {
      if (entry is Map<String, dynamic>) {
        result.add(entry);
        continue;
      }
      if (entry is Map) {
        result.add(entry.cast<String, dynamic>());
        continue;
      }
      throw FormatException('$fieldLabel darf nur JSON-Objekte enthalten.');
    }
    return result;
  }

  static String _coerceDraftText(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  static Map<String, dynamic> _coerceDraftJsonObject(
    Object? value, {
    required String fieldLabel,
  }) {
    if (value == null) {
      return const <String, dynamic>{};
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw FormatException('$fieldLabel erwartet ein JSON-Objekt.');
  }

  static List<Map<String, dynamic>> _coerceDraftJsonObjectList(
    Object? value, {
    required String fieldLabel,
  }) {
    if (value == null) {
      return const <Map<String, dynamic>>[];
    }
    if (value is! List) {
      throw FormatException('$fieldLabel erwartet eine JSON-Liste.');
    }
    final result = <Map<String, dynamic>>[];
    for (final entry in value) {
      if (entry is Map<String, dynamic>) {
        result.add(entry);
        continue;
      }
      if (entry is Map) {
        result.add(entry.cast<String, dynamic>());
        continue;
      }
      throw FormatException('$fieldLabel darf nur JSON-Objekte enthalten.');
    }
    return result;
  }
}
