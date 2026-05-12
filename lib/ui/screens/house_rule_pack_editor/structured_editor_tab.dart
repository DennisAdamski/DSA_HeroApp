// ignore_for_file: invalid_use_of_protected_member

part of '../house_rule_pack_editor_screen.dart';

extension _HouseRulePackStructuredEditor on _HouseRulePackEditorScreenState {
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
}
