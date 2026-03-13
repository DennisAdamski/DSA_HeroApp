import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart' show ArmorPiece;
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

part 'hero_begleiter/begleiter_sections.dart';

/// Begleiter-Tab mit Auswahl- und Detailansicht fuer Vertraute/Begleiter.
class HeroBegleiterTab extends ConsumerStatefulWidget {
  const HeroBegleiterTab({
    super.key,
    required this.heroId,
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  final String heroId;
  final void Function(bool isDirty) onDirtyChanged;
  final void Function(bool isEditing) onEditingChanged;
  final void Function(WorkspaceAsyncAction discardAction) onRegisterDiscard;
  final void Function(WorkspaceTabEditActions actions) onRegisterEditActions;

  @override
  ConsumerState<HeroBegleiterTab> createState() => _HeroBegleiterTabState();
}

class _HeroBegleiterTabState extends ConsumerState<HeroBegleiterTab>
    with AutomaticKeepAliveClientMixin {
  late final WorkspaceTabEditController _editController;

  HeroSheet? _latestHero;
  List<HeroCompanion> _draftCompanions = <HeroCompanion>[];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _editController = WorkspaceTabEditController(
      onDirtyChanged: widget.onDirtyChanged,
      onEditingChanged: widget.onEditingChanged,
      requestRebuild: () {
        if (mounted) setState(() {});
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _registerWithParent();
    });
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
    if (!_editController.shouldSync(hero, force: force)) return;
    _draftCompanions = List<HeroCompanion>.from(hero.companions);
    if (_selectedIndex >= _draftCompanions.length) {
      _selectedIndex = _draftCompanions.isEmpty ? 0 : _draftCompanions.length - 1;
    }
  }

  Future<void> _startEdit() async {
    final hero = _latestHero;
    if (hero == null) return;
    _editController.clearSyncSignature();
    _syncDraftFromHero(hero, force: true);
    _editController.startEdit();
  }

  Future<void> _saveChanges() async {
    final hero = _latestHero;
    if (hero == null) return;
    await ref.read(heroActionsProvider).saveHero(
      hero.copyWith(companions: List.unmodifiable(_draftCompanions)),
    );
    if (!mounted) return;
    _editController.markSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Begleiter gespeichert')),
    );
  }

  Future<void> _cancelChanges() async => _discardChanges();

  Future<void> _discardChanges() async {
    final hero = _latestHero;
    if (hero != null) {
      _editController.clearSyncSignature();
      _syncDraftFromHero(hero, force: true);
    }
    _editController.markDiscarded();
  }

  void _markFieldChanged() => _editController.markFieldChanged();

  void _addCompanion() {
    final newCompanion = HeroCompanion(
      id: const Uuid().v4(),
      name: 'Neuer Begleiter',
    );
    setState(() {
      _draftCompanions = List<HeroCompanion>.from(_draftCompanions)
        ..add(newCompanion);
      _selectedIndex = _draftCompanions.length - 1;
    });
    _markFieldChanged();
  }

  Future<void> _deleteCompanion(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Begleiter löschen'),
        content: Text(
          'Möchtest du "${_draftCompanions[index].name}" wirklich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _draftCompanions = List<HeroCompanion>.from(_draftCompanions)
        ..removeAt(index);
      if (_selectedIndex >= _draftCompanions.length && _selectedIndex > 0) {
        _selectedIndex = _draftCompanions.length - 1;
      }
    });
    _markFieldChanged();
  }

  void _updateCompanion(HeroCompanion updated) {
    final next = List<HeroCompanion>.from(_draftCompanions);
    next[_selectedIndex] = updated;
    setState(() => _draftCompanions = next);
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

    final isEditing = _editController.isEditing;
    final hasCompanions = _draftCompanions.isNotEmpty;
    final selectedCompanion =
        hasCompanions ? _draftCompanions[_selectedIndex] : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BegleiterSelector(
            companions: _draftCompanions,
            selectedIndex: _selectedIndex,
            isEditing: isEditing,
            onSelect: (i) => setState(() => _selectedIndex = i),
            onAdd: _addCompanion,
            onDelete: _deleteCompanion,
          ),
          if (!hasCompanions)
            _EmptyBegleiterHint(
              isEditing: isEditing,
              onAdd: _addCompanion,
            )
          else if (selectedCompanion != null) ...[
            const SizedBox(height: 16),
            _BegleiterDetail(
              companion: selectedCompanion,
              isEditing: isEditing,
              onChanged: _updateCompanion,
            ),
          ],
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
