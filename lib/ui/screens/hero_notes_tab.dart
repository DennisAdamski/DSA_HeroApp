import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

part 'hero_notes/hero_notes_sections.dart';

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
