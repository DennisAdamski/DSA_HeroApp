import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/combat_config.dart' show ArmorPiece;
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/companion_steigerung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/editor_entwurf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/catalog/vertrautenmagie_preset.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/editor_entwurf_speichern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/protected_content_helpers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/edit_aware_field.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_tab_header.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/erwerb_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/steigerungs_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

part 'hero_begleiter/begleiter_helpers.dart';
part 'hero_begleiter/begleiter_grunddaten_section.dart';
part 'hero_begleiter/begleiter_eigenschaften_section.dart';
part 'hero_begleiter/begleiter_kampfwerte_section.dart';
part 'hero_begleiter/begleiter_ruestung_section.dart';
part 'hero_begleiter/begleiter_angriff_section.dart';
part 'hero_begleiter/begleiter_sonderfertigkeiten_section.dart';
part 'hero_begleiter/vertrautenmagie_section.dart';

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

  /// Held, aus dem der Entwurf gefüllt wurde; Ausgang des Abgleichs beim
  /// Speichern (ARCH-05).
  HeroSheet? _entwurfBasis;

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
    _entwurfBasis = hero;
    // Migration: Vertrautenmagie von HeroSheet.ritualCategories zum Companion.
    final altVertrautenmagie = hero.ritualCategories
        .where((c) => c.id == 'vertrautenmagie')
        .firstOrNull;
    _draftCompanions = hero.companions.map((companion) {
      if (companion.typ == BegleiterTyp.vertrauter &&
          companion.ritualCategories.isEmpty &&
          altVertrautenmagie != null) {
        return companion.copyWith(ritualCategories: [altVertrautenmagie]);
      }
      return companion;
    }).toList();
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
    final basis = _entwurfBasis;
    if (basis == null) return;
    // Startwerte fuer Vertraute initialisieren.
    final finalized = _draftCompanions
        .map(
          (c) =>
              c.typ == BegleiterTyp.vertrauter ? mitBegleiterStartwerten(c) : c,
        )
        .toList();
    _draftCompanions = finalized;
    // Vertrautenmagie aus Hero-Ritualkategorien entfernen (lebt jetzt im Companion).
    final heroRituals = basis.ritualCategories
        .where((c) => c.id != 'vertrautenmagie')
        .toList();
    final entwurf = basis.copyWith(
      companions: List.unmodifiable(finalized),
      ritualCategories: List.unmodifiable(heroRituals),
    );
    final gespeichert = await speichereEditorEntwurf(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      abgleich: (aktuell, erzwungen) => uebernimmEditorEntwurf(
        basis: basis,
        entwurf: entwurf,
        aktuell: aktuell,
        erzwungen: erzwungen,
        neueId: neueEditorSlotId,
      ),
    );
    if (!gespeichert || !mounted) return;
    _editController.markSaved();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Begleiter gespeichert')));
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

  /// Bucht eine Vertrauten-Steigerung sofort, ohne den Editor zu speichern.
  ///
  /// Gebucht wird auf den gespeicherten Begleiter (ARCH-05): Hat ihn ein
  /// anderer Weg inzwischen gesteigert, passen die Kosten nicht mehr, und die
  /// Buchung wird mit Meldung abgewiesen. Danach übernimmt der Entwurf den
  /// gespeicherten Stand; gesteigert wird nur ohne offene Änderungen, und
  /// der gespeicherte Held wird die neue Basis des Abgleichs.
  Future<void> _bucheSteigerung(
    HeroCompanion angezeigt, {
    required BegleiterSteigerungsziel ziel,
    required int erwarteterStand,
    required int neuerStand,
    required int apKosten,
  }) async {
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Steigerung',
      aenderung: (held) => bucheBegleiterSteigerung(
        held,
        begleiterId: angezeigt.id,
        ziel: ziel,
        erwarteterStand: erwarteterStand,
        neuerStand: neuerStand,
        apKosten: apKosten,
      ),
    );
    if (gespeichert == null || !mounted) return;
    setState(() => _syncDraftFromHero(gespeichert, force: true));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Steigerung gespeichert')));
  }

  Future<void> _addCompanion() async {
    if (!_editController.isEditing) {
      await _startEdit();
    }
    if (!mounted) return;
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
    final result = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Begleiter löschen',
      content:
          'Möchtest du "${_draftCompanions[index].name}" wirklich löschen?',
      confirmLabel: 'Löschen',
      isDestructive: true,
    );
    if (result != AdaptiveConfirmResult.confirm || !mounted) return;
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
    final old = _draftCompanions.firstWhere(
      (c) => c.id == updated.id,
      orElse: () => updated,
    );
    // Seiteneffekt: Typ wechselt zu Vertrauter.
    var effective = updated;
    if (old.typ != BegleiterTyp.vertrauter &&
        updated.typ == BegleiterTyp.vertrauter) {
      // Loyalitaet vorbelegen, falls noch nicht gesetzt.
      if (effective.loyalitaet == null) {
        effective = effective.copyWith(loyalitaet: 15);
      }
      // Vertrautenmagie-Kategorie im Companion anlegen, falls fehlend.
      final hatVertrautenmagie = effective.ritualCategories.any(
        (cat) => cat.id == 'vertrautenmagie',
      );
      if (!hatVertrautenmagie) {
        effective = effective.copyWith(
          ritualCategories: [
            ...effective.ritualCategories,
            const HeroRitualCategory(
              id: 'vertrautenmagie',
              name: 'Vertrautenmagie',
              knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
              ownKnowledge: HeroRitualKnowledge(
                name: 'Vertrautenmagie',
                value: 3,
                learningComplexity: 'E',
              ),
            ),
          ],
        );
      }
    }
    setState(() {
      _draftCompanions = _draftCompanions
          .map((c) => c.id == effective.id ? effective : c)
          .toList();
    });
    _markFieldChanged();
  }

  // ---------------------------------------------------------------------------
  // Steigerung (inline, nur Vertraute)
  // ---------------------------------------------------------------------------

  bool get _canRaise => _editController.isEditing && !_editController.isDirty;

  HeroCompanion? get _activeCompanion => _activeCompanionId != null
      ? _draftCompanions.cast<HeroCompanion?>().firstWhere(
          (c) => c!.id == _activeCompanionId,
          orElse: () => null,
        )
      : null;

  bool _canRaiseFor(HeroCompanion c) =>
      _canRaise && c.typ == BegleiterTyp.vertrauter;

  Future<void> _raiseRegular(String key, String label) async {
    final c = _activeCompanion;
    if (c == null || !_canRaiseFor(c)) return;
    final basis = companionBasiswert(c, key);
    if (basis == null) return;
    final stg = companionSteigerung(c, key);
    final effWert = basis + stg;
    final apVerf = companionApVerfuegbar(c);
    final maxWert = regMaxSteigerung(
      aktuellerSteigerungswert: effWert,
      verfuegbareAp: apVerf,
    );
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: '$label (Vertrauter)',
      aktuellerWert: effWert,
      maxWert: maxWert,
      effektiveKomplexitaet: kVertrauterKomplexitaet,
      verfuegbareAp: apVerf,
    );
    if (result == null) return;
    await _bucheSteigerung(
      c,
      ziel: BegleiterSteigerungsziel.wert(key),
      erwarteterStand: stg,
      neuerStand: result.neuerWert - basis,
      apKosten: result.apKosten,
    );
  }

  Future<void> _raisePool(String key, String label) async {
    final c = _activeCompanion;
    if (c == null || !_canRaiseFor(c)) return;
    final startwert =
        companionPoolStartwert(c, key) ?? companionPoolBasiswert(c, key);
    if (startwert == null) return;
    final stg = companionSteigerung(c, key);
    final maxStg = poolMaxSteigerung(startwert);
    if (stg >= maxStg) return;
    final apVerf = companionApVerfuegbar(c);
    final effektivMax = math.min(
      maxStg,
      regMaxSteigerung(aktuellerSteigerungswert: stg, verfuegbareAp: apVerf),
    );
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: '$label (Vertrauter)',
      aktuellerWert: stg,
      maxWert: effektivMax,
      effektiveKomplexitaet: kVertrauterKomplexitaet,
      verfuegbareAp: apVerf,
    );
    if (result == null) return;
    await _bucheSteigerung(
      c,
      ziel: BegleiterSteigerungsziel.wert(key),
      erwarteterStand: stg,
      neuerStand: result.neuerWert,
      apKosten: result.apKosten,
    );
  }

  Future<void> _raiseAngriffAt(String attackId) async {
    final c = _activeCompanion;
    if (c == null || !_canRaiseFor(c)) return;
    final angriff = c.angriffe.where((a) => a.id == attackId).firstOrNull;
    if (angriff == null || angriff.at == null) return;
    final basisAt = angriff.at!;
    final effAt = basisAt + angriff.steigerungAt;
    final apVerf = companionApVerfuegbar(c);
    final maxWert = regMaxSteigerung(
      aktuellerSteigerungswert: effAt,
      verfuegbareAp: apVerf,
    );
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: '${angriff.name} AT (Vertrauter)',
      aktuellerWert: effAt,
      maxWert: maxWert,
      effektiveKomplexitaet: kVertrauterKomplexitaet,
      verfuegbareAp: apVerf,
    );
    if (result == null) return;
    await _bucheSteigerung(
      c,
      ziel: BegleiterSteigerungsziel.angriff(attackId, parade: false),
      erwarteterStand: angriff.steigerungAt,
      neuerStand: result.neuerWert - basisAt,
      apKosten: result.apKosten,
    );
  }

  Future<void> _raiseAngriffPa(String attackId) async {
    final c = _activeCompanion;
    if (c == null || !_canRaiseFor(c)) return;
    final angriff = c.angriffe.where((a) => a.id == attackId).firstOrNull;
    if (angriff == null || angriff.pa == null) return;
    final basisPa = angriff.pa!;
    final effPa = basisPa + angriff.steigerungPa;
    final apVerf = companionApVerfuegbar(c);
    final maxWert = regMaxSteigerung(
      aktuellerSteigerungswert: effPa,
      verfuegbareAp: apVerf,
    );
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: '${angriff.name} PA (Vertrauter)',
      aktuellerWert: effPa,
      maxWert: maxWert,
      effektiveKomplexitaet: kVertrauterKomplexitaet,
      verfuegbareAp: apVerf,
    );
    if (result == null) return;
    await _bucheSteigerung(
      c,
      ziel: BegleiterSteigerungsziel.angriff(attackId, parade: true),
      erwarteterStand: angriff.steigerungPa,
      neuerStand: result.neuerWert - basisPa,
      apKosten: result.apKosten,
    );
  }

  Future<void> _raiseRk() async {
    final c = _activeCompanion;
    if (c == null || !_canRaiseFor(c)) return;
    final basisRk =
        c.ritualCategories
            .where((k) => k.id == 'vertrautenmagie')
            .firstOrNull
            ?.ownKnowledge
            ?.value ??
        0;
    final stg = companionSteigerung(c, 'rk');
    final effRk = basisRk + stg;
    final apVerf = companionApVerfuegbar(c);
    final maxWert = regMaxSteigerung(
      aktuellerSteigerungswert: effRk,
      verfuegbareAp: apVerf,
    );
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: 'Ritualkenntnis (Vertrauter)',
      aktuellerWert: effRk,
      maxWert: maxWert,
      effektiveKomplexitaet: kVertrauterKomplexitaet,
      verfuegbareAp: apVerf,
    );
    if (result == null) return;
    await _bucheSteigerung(
      c,
      ziel: const BegleiterSteigerungsziel.wert('rk'),
      erwarteterStand: stg,
      neuerStand: result.neuerWert - basisRk,
      apKosten: result.apKosten,
    );
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
      final vertrautenmagieKat = activeCompanion.ritualCategories
          .where((c) => c.id == 'vertrautenmagie')
          .firstOrNull;
      final canRaise = _canRaiseFor(activeCompanion);
      return Column(
        children: [
          const CodexTabHeader(
            title: 'Begleiter-Dossier',
            subtitle: 'Vertraute und Begleiter mit Grunddaten, Kampfwerten und Sonderfertigkeiten.',
            assetPath: 'assets/ui/codex/hero_banner_crest.png',
          ),
          Expanded(
            child: _BegleiterDetailView(
              companion: activeCompanion,
              isEditing: isEditing,
              canRaise: canRaise,
              onBack: _navigateBack,
              onChanged: _updateCompanion,
              onDelete: () => _deleteCompanion(activeCompanion.id),
              onRaiseRegular: canRaise ? _raiseRegular : null,
              onRaisePool: canRaise ? _raisePool : null,
              onRaiseAngriffAt: canRaise ? _raiseAngriffAt : null,
              onRaiseAngriffPa: canRaise ? _raiseAngriffPa : null,
              onRaiseRk: canRaise ? _raiseRk : null,
              vertrautenmagieKategorie: vertrautenmagieKat,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const CodexTabHeader(
          title: 'Begleiter-Dossier',
          subtitle: 'Vertraute und Begleiter mit Grunddaten, Kampfwerten und Sonderfertigkeiten.',
          assetPath: 'assets/ui/codex/hero_banner_crest.png',
        ),
        Expanded(
          child: _BegleiterAuswahlView(
            companions: _draftCompanions,
            onSelect: (id) => setState(() {
              _activeCompanionId = id;
              _userNavigatedBack = false;
            }),
            onAdd: _addCompanion,
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
