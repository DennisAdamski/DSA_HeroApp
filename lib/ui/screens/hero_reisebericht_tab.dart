import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ui/screens/shared/planung_bearbeiten_guard.dart';
import 'package:dsa_heldenverwaltung/catalog/reisebericht_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/editor_entwurf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisebericht_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/editor_entwurf_speichern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_tab_header.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';

part 'hero_reisebericht/reisebericht_category_view.dart';
part 'hero_reisebericht/reisebericht_entry_tile.dart';
part 'hero_reisebericht/reisebericht_dialogs.dart';
part 'hero_reisebericht/reisebericht_farben.dart';

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

  /// Held, aus dem der Entwurf gefüllt wurde; Ausgang des Abgleichs beim
  /// Speichern (ARCH-05).
  HeroSheet? _entwurfBasis;

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
    _entwurfBasis = hero;
    _draft = hero.reisebericht;
  }

  Future<void> _startEdit() async {
    final darfBearbeiten = await bestaetigeBearbeitungBeiPlanung(
      context: context,
      heroId: widget.heroId,
    );
    if (!darfBearbeiten || !mounted) {
      return;
    }
    final hero = _latestHero;
    if (hero == null) return;
    _editController.clearSyncSignature();
    _syncDraftFromHero(hero, force: true);
    _editController.startEdit();
  }

  Future<void> _saveChanges() async {
    final basis = _entwurfBasis;
    if (basis == null) return;

    final catalog = ref.read(rulesCatalogProvider).valueOrNull;
    if (catalog == null) return;

    // Gebucht und zurückgenommen wird auf dem gespeicherten Helden, nie
    // doppelt; die Vorschau dient nur der Meldung.
    final entwurf = _draft;
    final vorschau = berechneReiseberichtBuchung(
      catalog: catalog.reisebericht,
      gebucht: basis.reisebericht,
      entwurf: entwurf,
    );
    final gespeichert = await speichereEditorEntwurf(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      abgleich: (aktuell, erzwungen) => bucheReiseberichtEntwurf(
        basis: basis,
        aktuell: aktuell,
        entwurf: entwurf,
        katalog: catalog.reisebericht,
        erzwingen: erzwungen.contains('reisebericht'),
      ),
    );
    if (!gespeichert || !mounted) return;

    _editController.markSaved();

    final parts = <String>[
      ..._buchungsteile(vorschau.neu, zurueck: false),
      ..._buchungsteile(vorschau.zurueck, zurueck: true),
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          parts.isEmpty
              ? 'Reisebericht gespeichert'
              : 'Reisebericht gespeichert: ${parts.join(', ')}',
        ),
      ),
    );
  }

  List<String> _buchungsteile(
    ReiseberichtRewards rewards, {
    required bool zurueck,
  }) {
    final zusatz = zurueck ? ' zurückgenommen' : '';
    return <String>[
      if (rewards.ap > 0) '${zurueck ? '−' : '+'}${rewards.ap} AP',
      if (rewards.seRewards.isNotEmpty)
        '${rewards.seRewards.length}x SE$zusatz',
      if (rewards.talentBoni.isNotEmpty)
        '${rewards.talentBoni.length}x Talentbonus$zusatz',
      if (rewards.eigenschaftsBoni.isNotEmpty)
        '${rewards.eigenschaftsBoni.length}x Eigenschaftsbonus$zusatz',
    ];
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
    if (!next.remove(id)) {
      next.add(id);
    }
    _aendereEntwurf(_draft.copyWith(checkedIds: next));
  }

  void _updateDraft(HeroReisebericht newDraft) => _aendereEntwurf(newDraft);

  /// Übernimmt [nachher] in den Entwurf.
  ///
  /// Nimmt die Änderung bereits gebuchte Belohnungen zurück (ein entfernter
  /// Haken, ein gelöschter offener Eintrag, eine dadurch unterschrittene
  /// Schwelle), fragt der Tab vorher nach. Gebucht und zurückgenommen wird
  /// erst beim Speichern; bis dahin zeigt der Entwurf die zurückgenommenen
  /// Belohnungen schon als offen an.
  Future<void> _aendereEntwurf(HeroReisebericht nachher) async {
    final basis = _entwurfBasis;
    final catalog = ref.read(rulesCatalogProvider).valueOrNull;
    var neu = nachher;
    if (basis != null && catalog != null) {
      final aenderung = reiseberichtBuchungsaenderung(
        catalog: catalog.reisebericht,
        gebucht: basis.reisebericht,
        vorher: _draft,
        nachher: nachher,
      );
      if (!aenderung.zurueck.isEmpty) {
        final bestaetigt = await showDialog<bool>(
          context: context,
          builder: (ctx) => _RevokeConfirmDialog(buchung: aenderung),
        );
        if (bestaetigt != true || !mounted) return;
      }
      final buchung = berechneReiseberichtBuchung(
        catalog: catalog.reisebericht,
        gebucht: basis.reisebericht,
        entwurf: nachher,
      );
      final entfaellt = buchung.zurueck.newAppliedIds.difference(
        buchung.neu.newAppliedIds,
      );
      neu = nachher.copyWith(
        appliedRewardIds: basis.reisebericht.appliedRewardIds.difference(
          entfaellt,
        ),
      );
    }
    setState(() {
      _draft = neu;
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
          subtitle: 'Erfahrungen, Meilensteine und Belohnungen als fortlaufender Reisebericht.',
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
