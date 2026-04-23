import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/state/house_rule_pack_admin_providers.dart';

part 'house_rule_pack_editor/house_rule_pack_editor_support.dart';
part 'house_rule_pack_editor/house_rule_pack_patch_draft.dart';

/// Editor fuer importierte Hausregel-Pakete mit Struktur- und JSON-Ansicht.
class HouseRulePackEditorScreen extends ConsumerStatefulWidget {
  /// Erstellt den Editor fuer ein Hausregel-Paket.
  const HouseRulePackEditorScreen({
    super.key,
    required this.initialManifestJson,
    required this.screenTitle,
    this.previousPackId = '',
  });

  /// Startwert des zu bearbeitenden Manifest-Entwurfs.
  final Map<String, dynamic> initialManifestJson;

  /// Anzeigename der aktuellen Editor-Route.
  final String screenTitle;

  /// Vorherige Paket-ID beim Bearbeiten eines importierten Pakets.
  final String previousPackId;

  @override
  ConsumerState<HouseRulePackEditorScreen> createState() =>
      _HouseRulePackEditorScreenState();
}

class _HouseRulePackEditorScreenState
    extends ConsumerState<HouseRulePackEditorScreen>
    with SingleTickerProviderStateMixin {
  final JsonEncoder _jsonEncoder = const JsonEncoder.withIndent('  ');
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _parentPackIdController = TextEditingController();
  final TextEditingController _priorityController = TextEditingController();
  final TextEditingController _jsonController = TextEditingController();
  final List<_PatchDraftControllers> _patches = <_PatchDraftControllers>[];

  late final TabController _tabController;

  String _errorText = '';
  bool _isSaving = false;
  bool _isValidating = false;
  bool _validationIsStale = true;
  int _previousTabIndex = 0;
  bool _isHandlingTabChange = false;
  List<HouseRulePackIssue> _validationIssues = const <HouseRulePackIssue>[];

  @override
  void initState() {
    super.initState();
    _loadStructuredState(widget.initialManifestJson);
    _syncStructuredToJson();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _idController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _parentPackIdController.dispose();
    _priorityController.dispose();
    _jsonController.dispose();
    for (final patch in _patches) {
      patch.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.screenTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Strukturiert'),
            Tab(text: 'JSON'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving || _isValidating ? null : _runValidation,
            icon: _isValidating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rule_folder_outlined),
            label: const Text('Validieren'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_errorText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _EditorMessageCard(
                  color: theme.colorScheme.errorContainer,
                  textColor: theme.colorScheme.onErrorContainer,
                  title: 'Fehler',
                  message: _errorText,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _ValidationCard(
                issues: _validationIssues,
                isStale: _validationIsStale,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStructuredTab(),
                  _JsonTab(
                    controller: _jsonController,
                    onChanged: _markValidationStale,
                    onFormat: _formatJson,
                  ),
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

  Widget _buildStructuredTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paket-Metadaten',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _EditorTextField(
                  fieldKey: const ValueKey<String>('house-rule-pack-id'),
                  controller: _idController,
                  onChanged: _markValidationStale,
                  label: 'ID',
                  helper:
                      'Muss unter allen eingebauten und importierten Paketen eindeutig sein.',
                ),
                const SizedBox(height: 12),
                _EditorTextField(
                  fieldKey: const ValueKey<String>('house-rule-pack-title'),
                  controller: _titleController,
                  onChanged: _markValidationStale,
                  label: 'Titel',
                ),
                const SizedBox(height: 12),
                _EditorTextField(
                  fieldKey: const ValueKey<String>(
                    'house-rule-pack-description',
                  ),
                  controller: _descriptionController,
                  onChanged: _markValidationStale,
                  label: 'Beschreibung',
                  minLines: 3,
                ),
                const SizedBox(height: 12),
                _EditorTextField(
                  fieldKey: const ValueKey<String>('house-rule-pack-parent'),
                  controller: _parentPackIdController,
                  onChanged: _markValidationStale,
                  label: 'Parent-Paket-ID',
                  helper: 'Optional. Leer lassen, wenn das Paket ein Root ist.',
                ),
                const SizedBox(height: 12),
                _EditorTextField(
                  fieldKey: const ValueKey<String>('house-rule-pack-priority'),
                  controller: _priorityController,
                  onChanged: _markValidationStale,
                  label: 'Standard-Priorität',
                  helper: 'Leer oder 0 für Standard.',
                  number: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Patches',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    FilledButton.icon(
                      onPressed: _addPatch,
                      icon: const Icon(Icons.add),
                      label: const Text('+ Patch'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_patches.isEmpty)
                  Text(
                    'Noch keine Patches definiert. Ein Paket ohne Patches ist '
                    'gueltig, wirkt aber nicht auf den Katalog.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Column(
                    children: _patches
                        .asMap()
                        .entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildPatchCard(
                              patch: entry.value,
                              index: entry.key,
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
    );
  }

  Widget _buildPatchCard({
    required _PatchDraftControllers patch,
    required int index,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Patch ${index + 1}', style: theme.textTheme.titleSmall),
                IconButton(
                  tooltip: 'Patch duplizieren',
                  onPressed: () => _duplicatePatch(index),
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: 'Nach oben',
                  onPressed: index == 0 ? null : () => _movePatch(index, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Nach unten',
                  onPressed: index == _patches.length - 1
                      ? null
                      : () => _movePatch(index, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'Patch entfernen',
                  onPressed: () => _removePatch(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CatalogSectionId>(
              initialValue: patch.section,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Sektion',
              ),
              items: editableCatalogSections
                  .map(
                    (section) => DropdownMenuItem(
                      value: section,
                      child: Text(section.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  patch.section = value;
                  _markValidationStale();
                });
              },
            ),
            const SizedBox(height: 12),
            _EditorTextField(
              controller: patch.priorityController,
              onChanged: _markValidationStale,
              label: 'Patch-Priorität',
              helper: 'Optional. Leer = Paket-Priorität verwenden.',
              number: true,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Einträge deaktivieren'),
              subtitle: const Text(
                'Entfernt alle durch den Selektor getroffenen Einträge.',
              ),
              value: patch.deactivateEntries,
              onChanged: (value) {
                setState(() {
                  patch.deactivateEntries = value;
                  _markValidationStale();
                });
              },
            ),
            const SizedBox(height: 12),
            _EditorTextField(
              controller: patch.entryIdController,
              onChanged: _markValidationStale,
              label: 'Selektor: entryId',
              helper: 'Optional. Exakte Eintrags-ID.',
            ),
            const SizedBox(height: 12),
            _EditorTextField(
              controller: patch.hasTagsController,
              onChanged: _markValidationStale,
              label: 'Selektor: Tags',
              helper: 'Ein Tag pro Zeile oder kommasepariert.',
              minLines: 2,
            ),
            const SizedBox(height: 12),
            _EditorTextField(
              controller: patch.fieldEqualsController,
              onChanged: _markValidationStale,
              label: 'Selektor: fieldEquals (JSON-Objekt)',
              helper: 'Leer oder ein JSON-Objekt, z. B. {"group":"Körperlich"}',
              minLines: 4,
            ),
            const SizedBox(height: 12),
            _EditorTextField(
              controller: patch.setFieldsController,
              onChanged: _markValidationStale,
              label: 'setFields (JSON-Objekt)',
              helper: 'Leer oder ein JSON-Objekt mit Feldpfaden und Werten.',
              minLines: 5,
            ),
            const SizedBox(height: 12),
            _EditorTextField(
              controller: patch.addEntriesController,
              onChanged: _markValidationStale,
              label: 'addEntries (JSON-Liste)',
              helper: 'Leer oder eine JSON-Liste aus Katalogeinträgen.',
              minLines: 6,
            ),
          ],
        ),
      ),
    );
  }

  void _handleTabChange() {
    if (_isHandlingTabChange || !_tabController.indexIsChanging) {
      return;
    }
    final nextIndex = _tabController.index;
    if (_previousTabIndex == nextIndex) {
      return;
    }

    if (_previousTabIndex == 0 && nextIndex == 1) {
      try {
        _syncStructuredToJson();
        _previousTabIndex = nextIndex;
      } on FormatException catch (error) {
        setState(() => _errorText = error.message);
        _restorePreviousTab();
      }
      return;
    }

    if (_previousTabIndex == 1 && nextIndex == 0) {
      try {
        _applyJsonToStructured();
        _previousTabIndex = nextIndex;
      } on FormatException catch (error) {
        setState(() => _errorText = error.message);
        _restorePreviousTab();
      }
    }
  }

  void _restorePreviousTab() {
    _isHandlingTabChange = true;
    _tabController.index = _previousTabIndex;
    _isHandlingTabChange = false;
  }

  void _loadStructuredState(Map<String, dynamic> manifestJson) {
    final manifest = HouseRulePackManifest.fromJson(manifestJson);
    _idController.text = manifest.id;
    _titleController.text = manifest.title;
    _descriptionController.text = manifest.description;
    _parentPackIdController.text = manifest.parentPackId;
    _priorityController.text = manifest.priority == 0
        ? ''
        : manifest.priority.toString();

    for (final patch in _patches) {
      patch.dispose();
    }
    _patches
      ..clear()
      ..addAll(
        manifest.patches.map(
          (patch) =>
              _PatchDraftControllers.fromPatch(patch, encoder: _jsonEncoder),
        ),
      );
  }

  void _syncStructuredToJson() {
    final manifestJson = _buildStructuredManifestJson();
    _jsonController.text = _jsonEncoder.convert(manifestJson);
    _errorText = '';
  }

  void _applyJsonToStructured() {
    final decoded = _parseJsonObject(
      _jsonController.text,
      fieldLabel: 'Manifest-JSON',
    );
    _loadStructuredState(decoded);
    _errorText = '';
  }

  Map<String, dynamic> _buildCurrentManifestJson() {
    if (_tabController.index == 1) {
      return _parseJsonObject(
        _jsonController.text,
        fieldLabel: 'Manifest-JSON',
      );
    }
    return _buildStructuredManifestJson();
  }

  Map<String, dynamic> _buildStructuredManifestJson() {
    final manifestJson = <String, dynamic>{
      'id': _idController.text.trim(),
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'patches': _patches
          .map((patch) => patch.buildJson())
          .toList(growable: false),
    };

    final parentPackId = _parentPackIdController.text.trim();
    if (parentPackId.isNotEmpty) {
      manifestJson['parentPackId'] = parentPackId;
    }

    final priorityText = _priorityController.text.trim();
    if (priorityText.isNotEmpty) {
      manifestJson['priority'] = _parseInteger(
        priorityText,
        fieldLabel: 'Standard-Priorität',
      );
    }

    return HouseRulePackManifest.fromJson(manifestJson).toJson();
  }

  Future<void> _runValidation() async {
    setState(() {
      _isValidating = true;
      _errorText = '';
    });

    try {
      final manifestJson = _buildCurrentManifestJson();
      final issues = await ref
          .read(houseRulePackAdminActionsProvider)
          .validateManifest(
            manifestJson: manifestJson,
            previousPackId: widget.previousPackId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _validationIssues = issues;
        _validationIsStale = false;
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = error.message);
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorText = '';
    });

    try {
      final manifestJson = _buildCurrentManifestJson();
      final actions = ref.read(houseRulePackAdminActionsProvider);
      final issues = await actions.validateManifest(
        manifestJson: manifestJson,
        previousPackId: widget.previousPackId,
      );
      await actions.savePack(
        manifestJson: manifestJson,
        previousPackId: widget.previousPackId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _validationIssues = issues;
        _validationIsStale = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            issues.isEmpty
                ? 'Hausregelpaket gespeichert.'
                : 'Hausregelpaket mit ${issues.length} Hinweis(en) gespeichert.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = error.message);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = 'Speichern fehlgeschlagen: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _formatJson() {
    try {
      final manifestJson = _parseJsonObject(
        _jsonController.text,
        fieldLabel: 'Manifest-JSON',
      );
      _jsonController.text = _jsonEncoder.convert(
        HouseRulePackManifest.fromJson(manifestJson).toJson(),
      );
      setState(() => _errorText = '');
    } on FormatException catch (error) {
      setState(() => _errorText = error.message);
    }
  }

  void _addPatch() {
    setState(() {
      _patches.add(_PatchDraftControllers.empty());
      _markValidationStale();
    });
  }

  void _duplicatePatch(int index) {
    setState(() {
      _patches.insert(
        index + 1,
        _patches[index].duplicate(encoder: _jsonEncoder),
      );
      _markValidationStale();
    });
  }

  void _movePatch(int index, int delta) {
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= _patches.length) {
      return;
    }
    setState(() {
      final patch = _patches.removeAt(index);
      _patches.insert(nextIndex, patch);
      _markValidationStale();
    });
  }

  void _removePatch(int index) {
    setState(() {
      final patch = _patches.removeAt(index);
      patch.dispose();
      _markValidationStale();
    });
  }

  void _markValidationStale() {
    _validationIsStale = true;
  }

  Map<String, dynamic> _parseJsonObject(
    String rawText, {
    required String fieldLabel,
  }) {
    final normalizedText = rawText.trim();
    if (normalizedText.isEmpty) {
      throw FormatException('$fieldLabel darf nicht leer sein.');
    }
    final decoded = jsonDecode(normalizedText);
    if (decoded is! Map) {
      throw FormatException('$fieldLabel erwartet ein JSON-Objekt.');
    }
    return decoded.cast<String, dynamic>();
  }

  int _parseInteger(String rawText, {required String fieldLabel}) {
    final value = int.tryParse(rawText.trim());
    if (value == null) {
      throw FormatException('$fieldLabel erwartet eine Ganzzahl.');
    }
    return value;
  }
}
