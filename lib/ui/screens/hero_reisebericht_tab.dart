import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/reisebericht_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisebericht_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_tab_header.dart';

part 'hero_reisebericht/reisebericht_category_view.dart';
part 'hero_reisebericht/reisebericht_entry_tile.dart';
part 'hero_reisebericht/reisebericht_dialogs.dart';

/// Reisebericht-Tab: Tracker fuer Abenteuererfahrungen mit Belohnungen.
class HeroReiseberichtTab extends ConsumerStatefulWidget {
  const HeroReiseberichtTab({
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
  ConsumerState<HeroReiseberichtTab> createState() =>
      _HeroReiseberichtTabState();
}

class _HeroReiseberichtTabState extends ConsumerState<HeroReiseberichtTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final WorkspaceTabEditController _editController;
  late final TabController _innerTabController;

  HeroSheet? _latestHero;
  HeroReisebericht _draft = const HeroReisebericht();

  static const _kategorieKeys = [
    'kampferfahrungen',
    'koerperliche_erprobungen',
    'gesellschaftliche_erfahrungen',
    'naturerfahrungen',
    'spirituelle_erfahrungen',
    'magische_erfahrungen',
  ];

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(
      length: _kategorieKeys.length,
      vsync: this,
    );
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
    if (!_editController.shouldSync(hero, force: force)) return;
    _draft = hero.reisebericht;
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

    final catalog = ref.read(rulesCatalogProvider).valueOrNull;
    if (catalog == null) return;

    final rewards = computePendingRewards(
      catalog: catalog.reisebericht,
      state: _draft,
    );

    final updatedHero = applyReiseberichtRewards(
      hero: hero,
      rewards: rewards,
      updatedState: _draft,
    );

    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) return;

    _editController.markSaved();

    if (!rewards.isEmpty) {
      final parts = <String>[];
      if (rewards.ap > 0) parts.add('+${rewards.ap} AP');
      if (rewards.seRewards.isNotEmpty) {
        parts.add('${rewards.seRewards.length}x SE');
      }
      if (rewards.talentBoni.isNotEmpty) {
        parts.add('${rewards.talentBoni.length}x Talentbonus');
      }
      if (rewards.eigenschaftsBoni.isNotEmpty) {
        parts.add('${rewards.eigenschaftsBoni.length}x Eigenschaftsbonus');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reisebericht gespeichert: ${parts.join(', ')}'),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reisebericht gespeichert')));
    }
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

  void _toggleChecked(String id) {
    final next = Set<String>.of(_draft.checkedIds);
    if (next.contains(id)) {
      // Ruecknahme-Pruefung
      if (_draft.appliedRewardIds.contains(id)) {
        _showRevokeConfirmation(id);
        return;
      }
      next.remove(id);
    } else {
      next.add(id);
    }
    setState(() {
      _draft = _draft.copyWith(checkedIds: next);
    });
    _editController.markFieldChanged();
  }

  void _showRevokeConfirmation(String id) {
    final catalog = ref.read(rulesCatalogProvider).valueOrNull;
    if (catalog == null) return;
    final def = catalog.reisebericht.where((d) => d.id == id).firstOrNull;
    if (def == null) return;

    final revoke = computeRevocationRewards(
      def: def,
      catalog: catalog.reisebericht,
      state: _draft,
    );

    showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _RevokeConfirmDialog(rewards: revoke, entryName: def.name),
    ).then((confirmed) {
      if (confirmed == true) {
        final hero = _latestHero;
        if (hero == null) return;

        final next = Set<String>.of(_draft.checkedIds)..remove(id);
        final cleaned = Set<String>.of(_draft.appliedRewardIds)
          ..removeAll(revoke.newAppliedIds);
        setState(() {
          _draft = _draft.copyWith(checkedIds: next, appliedRewardIds: cleaned);
        });
        _editController.markFieldChanged();
      }
    });
  }

  void _updateDraft(HeroReisebericht newDraft) {
    setState(() {
      _draft = newDraft;
    });
    _editController.markFieldChanged();
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

    final catalogAsync = ref.watch(rulesCatalogProvider);
    final catalog = catalogAsync.valueOrNull;
    if (catalog == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const CodexTabHeader(
          title: 'Abenteuer-Chronik',
          subtitle:
              'Erfahrungen, Meilensteine und Belohnungen als fortlaufender Reisebericht.',
          assetPath: 'assets/ui/codex/hero_banner_crest.png',
        ),
        TabBar(
          controller: _innerTabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _kategorieKeys
              .map((key) {
                final label = reiseberichtKategorien[key] ?? key;
                // Kurzlabel ohne "Meine "
                final short = label.replaceFirst('Meine ', '');
                return Tab(text: short);
              })
              .toList(growable: false),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTabController,
            children: _kategorieKeys
                .map((kategorie) {
                  final entries = catalog.reisebericht
                      .where((d) => d.kategorie == kategorie)
                      .toList(growable: false);
                  return _ReiseberichtCategoryView(
                    entries: entries,
                    allDefs: catalog.reisebericht,
                    draft: _draft,
                    isEditing: _editController.isEditing,
                    onToggleChecked: _toggleChecked,
                    onUpdateDraft: _updateDraft,
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
