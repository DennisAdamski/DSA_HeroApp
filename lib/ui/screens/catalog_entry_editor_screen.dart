import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';

part 'catalog_entry_editor/form_field_builders.dart';
part 'catalog_entry_editor/entry_parser.dart';
part 'catalog_entry_editor/error_box.dart';

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
}
