import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/state/house_rule_pack_admin_providers.dart';

part 'house_rule_pack_editor/editor_state_helpers.dart';
part 'house_rule_pack_editor/house_rule_pack_editor_support.dart';
part 'house_rule_pack_editor/house_rule_pack_patch_draft.dart';
part 'house_rule_pack_editor/structured_editor_tab.dart';

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
}
