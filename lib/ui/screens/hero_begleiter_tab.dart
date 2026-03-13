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

  /// ID des aktuell in der Detailansicht gezeigten Begleiters.
  /// null = Auswahl-Seite wird angezeigt.
  String? _activeCompanionId;

  /// Wird true, wenn der Nutzer explizit den Zurueck-Button gedrueckt hat.
  /// Verhindert Auto-Select bei genau einem Begleiter nach Navigation zurueck.
  bool _userNavigatedBack = false;

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
    // Aktiven Begleiter pruefen – wurde er geloescht?
    if (_activeCompanionId != null &&
        !_draftCompanions.any((c) => c.id == _activeCompanionId)) {
      _activeCompanionId = null;
    }
    // Auto-Select: genau 1 Begleiter und Nutzer hat nicht explizit zuruecknavigiert.
    if (_activeCompanionId == null &&
        !_userNavigatedBack &&
        _draftCompanions.length == 1) {
      _activeCompanionId = _draftCompanions.first.id;
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
      _activeCompanionId = newCompanion.id;
      _userNavigatedBack = false;
    });
    _markFieldChanged();
  }

  Future<void> _deleteCompanion(String companionId) async {
    final index = _draftCompanions.indexWhere((c) => c.id == companionId);
    if (index < 0) return;
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
      if (_activeCompanionId == companionId) {
        _activeCompanionId = null;
      }
    });
    _markFieldChanged();
  }

  void _updateCompanion(HeroCompanion updated) {
    setState(() {
      _draftCompanions = _draftCompanions
          .map((c) => c.id == updated.id ? updated : c)
          .toList();
    });
    _markFieldChanged();
  }

  void _navigateBack() {
    setState(() {
      _activeCompanionId = null;
      _userNavigatedBack = true;
    });
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
    final activeCompanion = _activeCompanionId != null
        ? _draftCompanions.cast<HeroCompanion?>().firstWhere(
            (c) => c!.id == _activeCompanionId,
            orElse: () => null,
          )
        : null;

    if (activeCompanion != null) {
      return _BegleiterDetailView(
        companion: activeCompanion,
        isEditing: isEditing,
        onBack: _navigateBack,
        onChanged: _updateCompanion,
        onDelete: () => _deleteCompanion(activeCompanion.id),
      );
    }

    return _BegleiterAuswahlView(
      companions: _draftCompanions,
      isEditing: isEditing,
      onSelect: (id) => setState(() {
        _activeCompanionId = id;
        _userNavigatedBack = false;
      }),
      onAdd: _addCompanion,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
