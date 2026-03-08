import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

const double _notesPagePadding = 16;
const double _notesSectionSpacing = 16;
const double _notesFieldSpacing = 12;

/// Notizen-Tab mit Unterbereichen fuer freie Notizen und Verbindungen.
class HeroNotesTab extends ConsumerStatefulWidget {
  /// Erzeugt den Notizen-Tab fuer einen einzelnen Helden.
  const HeroNotesTab({
    super.key,
    required this.heroId,
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  /// ID des Helden, dessen Notizen geladen werden.
  final String heroId;

  /// Meldet Dirty-Aenderungen an den Workspace.
  final void Function(bool isDirty) onDirtyChanged;

  /// Meldet den Edit-Status an den Workspace.
  final void Function(bool isEditing) onEditingChanged;

  /// Registriert die Discard-Aktion des Tabs.
  final void Function(WorkspaceAsyncAction discardAction) onRegisterDiscard;

  /// Registriert globale Start-/Save-/Cancel-Aktionen fuer die AppBar.
  final void Function(WorkspaceTabEditActions actions) onRegisterEditActions;

  @override
  ConsumerState<HeroNotesTab> createState() => _HeroNotesTabState();
}

class _HeroNotesTabState extends ConsumerState<HeroNotesTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final WorkspaceTabEditController _editController;
  late final TabController _innerTabController;

  HeroSheet? _latestHero;
  List<HeroNoteEntry> _draftNotes = <HeroNoteEntry>[];
  List<HeroConnectionEntry> _draftConnections = <HeroConnectionEntry>[];

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(length: 2, vsync: this);
    _editController = WorkspaceTabEditController(
      onDirtyChanged: widget.onDirtyChanged,
      onEditingChanged: widget.onEditingChanged,
      requestRebuild: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _registerWithParent();
      }
    });
  }

  @override
  void dispose() {
    _innerTabController.dispose();
    super.dispose();
  }

  void _registerWithParent() {
    _editController.emitCurrentState();
    widget.onRegisterDiscard(_discardChanges);
    widget.onRegisterEditActions(
      WorkspaceTabEditActions(
        startEdit: _startEdit,
        save: _saveChanges,
        cancel: _cancelChanges,
      ),
    );
  }

  void _syncDraftFromHero(HeroSheet hero, {bool force = false}) {
    if (!_editController.shouldSync(hero, force: force)) {
      return;
    }
    _draftNotes = List<HeroNoteEntry>.from(hero.notes);
    _draftConnections = List<HeroConnectionEntry>.from(hero.connections);
  }

  Future<void> _startEdit() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    _editController.clearSyncSignature();
    _syncDraftFromHero(hero, force: true);
    _editController.startEdit();
  }

  Future<void> _saveChanges() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }

    final updatedHero = hero.copyWith(
      notes: _draftNotes.where(_hasNoteContent).toList(growable: false),
      connections: _draftConnections
          .where(_hasConnectionContent)
          .toList(growable: false),
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }

    _editController.markSaved();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Notizen gespeichert')));
  }

  Future<void> _cancelChanges() async {
    await _discardChanges();
  }

  Future<void> _discardChanges() async {
    final hero = _latestHero;
    if (hero != null) {
      _editController.clearSyncSignature();
      _syncDraftFromHero(hero, force: true);
    }
    _editController.markDiscarded();
  }

  bool _hasNoteContent(HeroNoteEntry entry) {
    return entry.title.trim().isNotEmpty || entry.description.trim().isNotEmpty;
  }

  bool _hasConnectionContent(HeroConnectionEntry entry) {
    return entry.name.trim().isNotEmpty ||
        entry.ort.trim().isNotEmpty ||
        entry.sozialstatus.trim().isNotEmpty ||
        entry.loyalitaet.trim().isNotEmpty ||
        entry.beschreibung.trim().isNotEmpty;
  }

  void _markFieldChanged() {
    _editController.markFieldChanged();
  }

  void _addNote() {
    setState(() {
      _draftNotes = List<HeroNoteEntry>.from(_draftNotes)
        ..add(const HeroNoteEntry());
    });
    _markFieldChanged();
  }

  void _removeNote(int index) {
    setState(() {
      _draftNotes = List<HeroNoteEntry>.from(_draftNotes)..removeAt(index);
    });
    _markFieldChanged();
  }

  void _updateNoteTitle(int index, String value) {
    final next = List<HeroNoteEntry>.from(_draftNotes);
    next[index] = next[index].copyWith(title: value);
    setState(() {
      _draftNotes = next;
    });
    _markFieldChanged();
  }

  void _updateNoteDescription(int index, String value) {
    final next = List<HeroNoteEntry>.from(_draftNotes);
    next[index] = next[index].copyWith(description: value);
    setState(() {
      _draftNotes = next;
    });
    _markFieldChanged();
  }

  void _addConnection() {
    setState(() {
      _draftConnections = List<HeroConnectionEntry>.from(_draftConnections)
        ..add(const HeroConnectionEntry());
    });
    _markFieldChanged();
  }

  void _removeConnection(int index) {
    setState(() {
      _draftConnections = List<HeroConnectionEntry>.from(_draftConnections)
        ..removeAt(index);
    });
    _markFieldChanged();
  }

  void _updateConnection(
    int index, {
    String? name,
    String? ort,
    String? sozialstatus,
    String? loyalitaet,
    String? beschreibung,
  }) {
    final next = List<HeroConnectionEntry>.from(_draftConnections);
    next[index] = next[index].copyWith(
      name: name,
      ort: ort,
      sozialstatus: sozialstatus,
      loyalitaet: loyalitaet,
      beschreibung: beschreibung,
    );
    setState(() {
      _draftConnections = next;
    });
    _markFieldChanged();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    _latestHero = hero;
    _syncDraftFromHero(hero);

    return Column(
      children: [
        TabBar(
          controller: _innerTabController,
          tabs: const [
            Tab(text: 'Notizen'),
            Tab(text: 'Verbindungen'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTabController,
            children: [
              _NotesSection(
                entries: _draftNotes,
                isEditing: _editController.isEditing,
                onAdd: _addNote,
                onRemove: _removeNote,
                onTitleChanged: _updateNoteTitle,
                onDescriptionChanged: _updateNoteDescription,
              ),
              _ConnectionsSection(
                entries: _draftConnections,
                isEditing: _editController.isEditing,
                onAdd: _addConnection,
                onRemove: _removeConnection,
                onChanged: _updateConnection,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.entries,
    required this.isEditing,
    required this.onAdd,
    required this.onRemove,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
  });

  final List<HeroNoteEntry> entries;
  final bool isEditing;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index, String value) onTitleChanged;
  final void Function(int index, String value) onDescriptionChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(_notesPagePadding),
      children: [
        _SectionCard(
          title: 'Freie Notizen',
          subtitle: isEditing
              ? 'Lege Eintraege mit Titel und Beschreibung an.'
              : 'Tippe auf einen Titel, um die vollstaendige Beschreibung zu sehen.',
          action: isEditing
              ? FilledButton.icon(
                  key: const ValueKey<String>('notes-add-note'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Notiz'),
                )
              : null,
          child: entries.isEmpty
              ? const _EmptyState(message: 'Noch keine Notizen vorhanden.')
              : Column(
                  children: [
                    for (var index = 0; index < entries.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == entries.length - 1
                              ? 0
                              : _notesFieldSpacing,
                        ),
                        child: isEditing
                            ? _EditableNoteCard(
                                index: index,
                                entry: entries[index],
                                onRemove: onRemove,
                                onTitleChanged: onTitleChanged,
                                onDescriptionChanged: onDescriptionChanged,
                              )
                            : _ReadOnlyNoteTile(
                                index: index,
                                entry: entries[index],
                              ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: _notesSectionSpacing),
      ],
    );
  }
}

class _ConnectionsSection extends StatelessWidget {
  const _ConnectionsSection({
    required this.entries,
    required this.isEditing,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<HeroConnectionEntry> entries;
  final bool isEditing;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(
    int index, {
    String? name,
    String? ort,
    String? sozialstatus,
    String? loyalitaet,
    String? beschreibung,
  })
  onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(_notesPagePadding),
      children: [
        _SectionCard(
          title: 'Verbindungen',
          subtitle: isEditing
              ? 'Pflege Kontakte, Beziehungen und Hintergruende.'
              : 'Oeffne einen Eintrag, um Ort, Sozialstatus, Loyalitaet und Beschreibung zu sehen.',
          action: isEditing
              ? FilledButton.icon(
                  key: const ValueKey<String>('notes-add-connection'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Verbindung'),
                )
              : null,
          child: entries.isEmpty
              ? const _EmptyState(message: 'Noch keine Verbindungen vorhanden.')
              : Column(
                  children: [
                    for (var index = 0; index < entries.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == entries.length - 1
                              ? 0
                              : _notesFieldSpacing,
                        ),
                        child: isEditing
                            ? _EditableConnectionCard(
                                index: index,
                                entry: entries[index],
                                onRemove: onRemove,
                                onChanged: onChanged,
                              )
                            : _ReadOnlyConnectionTile(
                                index: index,
                                entry: entries[index],
                              ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: _notesSectionSpacing),
      ],
    );
  }
}

class _EditableNoteCard extends StatelessWidget {
  const _EditableNoteCard({
    required this.index,
    required this.entry,
    required this.onRemove,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
  });

  final int index;
  final HeroNoteEntry entry;
  final void Function(int index) onRemove;
  final void Function(int index, String value) onTitleChanged;
  final void Function(int index, String value) onDescriptionChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Notiz ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('notes-remove-note-$index'),
                  onPressed: () => onRemove(index),
                  tooltip: 'Notiz entfernen',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>('notes-note-title-$index'),
              initialValue: entry.title,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onTitleChanged(index, value),
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>('notes-note-description-$index'),
              initialValue: entry.description,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onDescriptionChanged(index, value),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyNoteTile extends StatelessWidget {
  const _ReadOnlyNoteTile({required this.index, required this.entry});

  final int index;
  final HeroNoteEntry entry;

  @override
  Widget build(BuildContext context) {
    final title = entry.title.trim().isEmpty ? 'Unbenannte Notiz' : entry.title;
    final description = entry.description.trim().isEmpty
        ? 'Keine Beschreibung hinterlegt.'
        : entry.description;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: ValueKey<String>('notes-note-tile-$index'),
        title: Text(title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(description)),
        ],
      ),
    );
  }
}

class _EditableConnectionCard extends StatelessWidget {
  const _EditableConnectionCard({
    required this.index,
    required this.entry,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final HeroConnectionEntry entry;
  final void Function(int index) onRemove;
  final void Function(
    int index, {
    String? name,
    String? ort,
    String? sozialstatus,
    String? loyalitaet,
    String? beschreibung,
  })
  onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Verbindung ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('notes-remove-connection-$index'),
                  onPressed: () => onRemove(index),
                  tooltip: 'Verbindung entfernen',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>('notes-connection-name-$index'),
              initialValue: entry.name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onChanged(index, name: value),
            ),
            const SizedBox(height: _notesFieldSpacing),
            LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 640;
                final fields = <Widget>[
                  _CompactTextField(
                    fieldKey: ValueKey<String>('notes-connection-ort-$index'),
                    label: 'Ort',
                    initialValue: entry.ort,
                    onChanged: (value) => onChanged(index, ort: value),
                  ),
                  _CompactTextField(
                    fieldKey: ValueKey<String>(
                      'notes-connection-sozialstatus-$index',
                    ),
                    label: 'Sozialstatus',
                    initialValue: entry.sozialstatus,
                    onChanged: (value) => onChanged(index, sozialstatus: value),
                  ),
                  _CompactTextField(
                    fieldKey: ValueKey<String>(
                      'notes-connection-loyalitaet-$index',
                    ),
                    label: 'Loyalitaet',
                    initialValue: entry.loyalitaet,
                    onChanged: (value) => onChanged(index, loyalitaet: value),
                  ),
                ];
                if (!useTwoColumns) {
                  return Column(
                    children: [
                      for (var i = 0; i < fields.length; i++) ...[
                        fields[i],
                        if (i < fields.length - 1)
                          const SizedBox(height: _notesFieldSpacing),
                      ],
                    ],
                  );
                }
                return Wrap(
                  spacing: _notesFieldSpacing,
                  runSpacing: _notesFieldSpacing,
                  children: fields
                      .map(
                        (field) => SizedBox(
                          width:
                              (constraints.maxWidth - _notesFieldSpacing) / 2,
                          child: field,
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>('notes-connection-description-$index'),
              initialValue: entry.beschreibung,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onChanged(index, beschreibung: value),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyConnectionTile extends StatelessWidget {
  const _ReadOnlyConnectionTile({required this.index, required this.entry});

  final int index;
  final HeroConnectionEntry entry;

  @override
  Widget build(BuildContext context) {
    final name = entry.name.trim().isEmpty
        ? 'Unbenannte Verbindung'
        : entry.name;
    final chips = <String>[
      if (entry.ort.trim().isNotEmpty) 'Ort: ${entry.ort}',
      if (entry.sozialstatus.trim().isNotEmpty)
        'Sozialstatus: ${entry.sozialstatus}',
      if (entry.loyalitaet.trim().isNotEmpty) 'Loyalitaet: ${entry.loyalitaet}',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: ValueKey<String>('notes-connection-tile-$index'),
        title: Text(name),
        subtitle: chips.isEmpty ? null : Text(chips.join('  |  ')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (entry.beschreibung.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(entry.beschreibung),
            )
          else
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Keine Beschreibung hinterlegt.'),
            ),
        ],
      ),
    );
  }
}

class _CompactTextField extends StatelessWidget {
  const _CompactTextField({
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final headerChildren = <Widget>[
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    ];
    final trailingAction = action;
    if (trailingAction != null) {
      headerChildren.add(trailingAction);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: headerChildren),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: _notesFieldSpacing),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
