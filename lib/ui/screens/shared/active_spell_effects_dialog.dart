import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_event_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_protection_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/spell_shield_actions.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/heilung/heilung_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/heilung/ruhe_koerper_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/schaden/schaden_dialog.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effect_tile.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/armatrutz_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/attributo_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/spell_duration_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/spell_effect_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/spell_effect_instance_tile.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

/// Oeffnet den gemeinsamen Dialog fuer wichtige aktive Zaubereffekte.
Future<void> showActiveSpellEffectsDialog({
  required BuildContext context,
  required String heroId,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (dialogContext) {
      return ZustandFehlerBereich(
        child: _ActiveSpellEffectsDialog(heroId: heroId),
      );
    },
  );
}

/// Dialog fuer laufend aktivierbare Zaubereffekte wie `Axxeleratus`,
/// `Attributo` und `Armatrutz`.
///
/// Jeder aktive Effekt kann zusaetzlich eine Wirkungsdauer tragen, die am
/// Spieltisch heruntergezaehlt wird.
class _ActiveSpellEffectsDialog extends ConsumerStatefulWidget {
  const _ActiveSpellEffectsDialog({required this.heroId});

  final String heroId;

  @override
  ConsumerState<_ActiveSpellEffectsDialog> createState() =>
      _ActiveSpellEffectsDialogState();
}

class _ActiveSpellEffectsDialogState
    extends ConsumerState<_ActiveSpellEffectsDialog> {
  /// Wendet [aenderung] auf den frisch gespeicherten Zustand an.
  ///
  /// Nie den Stand beim Rendern zurückschreiben: sonst gingen Würfe, Wunden
  /// oder Ressourcen verloren, die seit dem Öffnen gespeichert wurden.
  Future<void> _aendere(HeroState Function(HeroState aktuell) aenderung) {
    return aendereZustandMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Zaubereffekt',
      aenderung: aenderung,
    );
  }

  /// Liest den aktuellen Laufzeitzustand; `null`, solange er nicht geladen ist.
  HeroState? get _state =>
      ref.read(heroStateProvider(widget.heroId)).valueOrNull;

  Future<void> _toggleEffect(String effectId, bool value) async {
    await _aendere(
      (aktuell) => schalteZaubereffekt(aktuell, effectId, aktiv: value),
    );
  }

  /// Aktiviert den Attributo erst nach Eingabe der Eigenschaftsboni.
  Future<void> _toggleAttributo(bool value) async {
    if (!value) {
      await _beendeLegacyAttributo();
      return;
    }
    final bonuses = await showAttributoInputDialog(context: context);
    if (bonuses == null || !mounted) {
      return;
    }
    await _aendere((aktuell) => aktiviereAttributo(aktuell, bonuses));
  }

  /// Schaltet den bisherigen Attributo aus.
  ///
  /// Ob die gespeicherten Eigenschaftsboni vom Attributo stammen oder
  /// manuell bzw. aus einem anderen Zauber, ist nicht erkennbar: Der Nutzer
  /// entscheidet, statt dass die App sie still löscht.
  Future<void> _beendeLegacyAttributo() async {
    final boni = _state?.tempAttributeMods;
    final hatBoni = boni != null && describeAttributeModifiers(boni).isNotEmpty;
    var behalten = false;
    if (hatBoni) {
      final antwort = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey<String>('attributo-boni-fragen'),
          title: const Text('Eigenschaftsboni beibehalten?'),
          content: Text(
            'Gespeicherte Boni: ${describeAttributeModifiers(boni)}. '
            'Sie können vom Attributo stammen oder manuell bzw. aus einem '
            'anderen Zauber eingetragen sein.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              key: const ValueKey<String>('attributo-boni-behalten'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Boni behalten'),
            ),
            FilledButton(
              key: const ValueKey<String>('attributo-boni-entfernen'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Boni entfernen'),
            ),
          ],
        ),
      );
      if (antwort == null || !mounted) {
        return;
      }
      behalten = antwort;
    }
    await _aendere(
      (aktuell) => schalteZaubereffekt(
        aktuell,
        activeSpellEffectAttributo,
        aktiv: false,
        attributoBoniBehalten: behalten,
      ),
    );
  }

  /// Legt einen weiteren Attributo als eigene Quelle an.
  Future<void> _fuegeAttributoQuelleHinzu() async {
    final bonuses = await showAttributoInputDialog(context: context);
    if (bonuses == null || !mounted) {
      return;
    }
    final vorgang = const Uuid().v4();
    final instanz = SpellEffectInstance(
      id: const Uuid().v4(),
      effectId: activeSpellEffectAttributo,
      vorgangsId: vorgang,
      attributeMods: const AttributeModifiers().uebernimmWerte(bonuses),
    );
    await _aendere((aktuell) => aktiviereEffektInstanz(aktuell, instanz));
  }

  /// Legt eine Zauberwirkung mit belegtem Profil als weitere Quelle an.
  Future<void> _fuegeZauberwirkungHinzu(RulesCatalog katalog) async {
    final auswahl = spellEffectAuswahl(katalog);
    if (auswahl.isEmpty) {
      return;
    }
    final eingabe = await showSpellEffectInputDialog(
      context: context,
      auswahl: [
        for (final eintrag in auswahl)
          SpellEffectAuswahl(
            zauberId: eintrag.zauberId,
            name: eintrag.name,
            benoetigtZfw: eintrag.benoetigtZfw,
            benoetigtZiel: eintrag.benoetigtZiel,
            benoetigtSchutzvorrat: eintrag.benoetigtSchutzvorrat,
            benoetigtDauerAsp: eintrag.benoetigtDauerAsp,
            hinweis: eintrag.hinweis,
          ),
      ],
      gegnerNamen: [
        for (final g in ref.read(gefechtBegegnungProvider).gegner.values)
          g.name,
      ],
    );
    if (eingabe == null || !mounted) {
      return;
    }
    final vorgang = const Uuid().v4();
    final instanz = SpellEffectInstance(
      id: const Uuid().v4(),
      effectId: eingabe.zauberId,
      vorgangsId: vorgang,
      quelle: eingabe.quelle,
      ziel: eingabe.ziel,
      zfpStern: eingabe.zfpStern,
      zfw: eingabe.zfw,
      // Kapazität eines Schutzschilds bzw. (Psychostabilis) die vorausbezahlten
      // Zusatz-AsP, aus denen die Dauer vorgeschlagen wird.
      amount: eingabe.kapazitaet ?? eingabe.dauerAsp ?? 0,
      // Nur eine eindeutig belegte Dauer wird vorgeschlagen; sonst bleibt sie
      // leer und lässt sich an der Quelle festlegen.
      duration: dauerVorschlag(
        eingabe.zauberId,
        zfw: eingabe.zfw,
        zfpStern: eingabe.zfpStern,
        zusaetzlicheAsp: eingabe.dauerAsp,
      ),
    );
    await _aendere((aktuell) => aktiviereEffektInstanz(aktuell, instanz));
  }

  /// Legt die Wirkungsdauer einer Quelle fest.
  Future<void> _dauerDerQuelle(SpellEffectInstance instanz) async {
    final ergebnis = await showSpellDurationDialog(
      context: context,
      spellLabel: effektName(
        instanz.effectId,
        ref.read(heroRulesCatalogProvider(widget.heroId)).asData?.value,
      ),
      initialDuration: instanz.duration,
      defaultUnit: SpellDurationUnit.kampfrunden,
    );
    if (ergebnis == null || !mounted) {
      return;
    }
    await _aendere(
      (aktuell) => bearbeiteEffektInstanz(
        aktuell,
        instanz.id,
        (gespeichert) => ergebnis.duration == null
            ? gespeichert.copyWith(clearDuration: true)
            : gespeichert.copyWith(duration: ergebnis.duration),
      ),
    );
  }

  /// Setzt Ängste lindern in einer wiederholten Mut-Probe ein.
  ///
  /// Verbraucht wird die Wirkung erst, wenn die Probe tatsächlich
  /// ausgewertet wurde; schließt der Nutzer den Dialog vorher, bleibt sie.
  Future<void> _aengsteEinsetzen(SpellEffectInstance instanz) async {
    final snapshot = ref
        .read(heroComputedProvider(widget.heroId))
        .asData
        ?.value;
    if (snapshot == null) {
      return;
    }
    final mu = snapshot.probenEigenschaften.mu;
    var verbraucht = false;
    await showLoggedProbeDialog(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      request: aengsteLindernProbe(mu: mu, instanz: instanz),
      zaubereffekteAnwenden: false,
      onResolved: (_) {
        // Sofort nach der Auswertung, nicht erst beim Schließen des Blatts;
        // das Beenden ist über die Instanz-ID idempotent.
        if (verbraucht) return;
        verbraucht = true;
        unawaited(
          _aendere((aktuell) => beendeEffektInstanz(aktuell, instanz.id)),
        );
      },
    );
  }

  /// Lässt einen Zauberschild einen direkten magischen Treffer auffangen und
  /// bietet den Durchschlag anschließend als Schaden an.
  Future<void> _schildAuffangen(SpellEffectInstance instanz) async {
    final ergebnis = await fangeTrefferMitSchildAuf(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      instanz: instanz,
      schildName: effektName(
        instanz.effectId,
        ref.read(heroRulesCatalogProvider(widget.heroId)).asData?.value,
      ),
    );
    if (ergebnis == null || !mounted) {
      return;
    }
    final schadenBuchen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey<String>('schild-auffang-ergebnis'),
        title: const Text('Treffer aufgefangen'),
        content: Text(
          'Der Schild nimmt ${ergebnis.aufgefangen} TP auf. '
          '${ergebnis.durchschlag > 0 ? 'Durchschlag: ${ergebnis.durchschlag} TP.' : 'Kein Durchschlag.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Schließen'),
          ),
          if (ergebnis.durchschlag > 0)
            FilledButton(
              key: const ValueKey<String>('schild-durchschlag-buchen'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Durchschlag als Schaden buchen'),
            ),
        ],
      ),
    );
    if (schadenBuchen != true || !mounted) {
      return;
    }
    await showSchadenDialog(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      anfangsTp: ergebnis.durchschlag,
    );
  }

  /// Korrigiert den Schutzvorrat eines Zauberschilds.
  Future<void> _schutzRestAnpassen(SpellEffectInstance instanz) async {
    final rest = await fragePasseSchutzRestAn(
      context: context,
      instanz: instanz,
    );
    if (rest == null || !mounted) {
      return;
    }
    await _aendere((aktuell) => setzeSchutzRest(aktuell, instanz.id, rest));
  }

  /// Führt die alten Attributo-Boni auf ausdrücklichen Wunsch als Quelle.
  Future<void> _uebernimmLegacyAttributo() {
    final id = const Uuid().v4();
    return _aendere(
      (aktuell) => uebernimmLegacyAttributoAlsInstanz(aktuell, id),
    );
  }

  /// Aktiviert den Armatrutz erst nach Eingabe von RS und Wirkungsdauer.
  Future<void> _toggleArmatrutz(bool value) async {
    if (!value) {
      await _toggleEffect(activeSpellEffectArmatrutz, false);
      return;
    }
    await _editArmatrutzValues(activateFirst: true);
  }

  /// Fragt RS und Wirkungsdauer des Armatrutz ab und schreibt sie zurueck.
  Future<void> _editArmatrutzValues({bool activateFirst = false}) async {
    final state = _state;
    if (state == null) {
      return;
    }
    final current = state.activeSpellEffects.detailFor(
      activeSpellEffectArmatrutz,
    );
    final detail = await showArmatrutzInputDialog(
      context: context,
      initialDetail: activateFirst ? null : current,
    );
    if (detail == null || !mounted) {
      return;
    }
    await _aendere((aktuell) => aktiviereArmatrutz(aktuell, detail));
  }

  /// Fragt die Wirkungsdauer eines beliebigen Effekts ab.
  Future<void> _editDuration(ActiveSpellEffectDefinition effect) async {
    final state = _state;
    if (state == null) {
      return;
    }
    final current = state.activeSpellEffects.detailFor(effect.id);
    final result = await showSpellDurationDialog(
      context: context,
      spellLabel: effect.label,
      initialDuration: current.duration,
      defaultUnit: effect.defaultDurationUnit,
    );
    if (result == null || !mounted) {
      return;
    }
    await _aendere(
      (aktuell) => setzeZaubereffektDauer(aktuell, effect.id, result.duration),
    );
  }

  /// Zieht eine Zeiteinheit von der Restlaufzeit ab bzw. setzt sie zurueck.
  Future<void> _changeRemainingDuration(
    ActiveSpellEffectDefinition effect, {
    required bool reset,
  }) async {
    await _aendere(
      (aktuell) =>
          zaehleZaubereffektDauer(aktuell, effect.id, zuruecksetzen: reset),
    );
  }

  /// Ordnet jedem Effekt seine Umschaltlogik zu.
  ValueChanged<bool> _toggleHandlerFor(ActiveSpellEffectDefinition effect) {
    switch (effect.id) {
      case activeSpellEffectAttributo:
        return _toggleAttributo;
      case activeSpellEffectArmatrutz:
        return _toggleArmatrutz;
      default:
        return (value) => _toggleEffect(effect.id, value);
    }
  }

  /// Liefert die effektspezifische Werteingabe, sofern der Effekt eine hat.
  VoidCallback? _valueEditorFor(ActiveSpellEffectDefinition effect) {
    switch (effect.id) {
      case activeSpellEffectArmatrutz:
        return _editArmatrutzValues;
      case activeSpellEffectAttributo:
        return () => _toggleAttributo(true);
      default:
        return null;
    }
  }

  /// Weitere Quellen desselben Zaubers, jede mit eigenem Ende.
  List<Widget> _instanzBereich(
    HeroState state,
    HeroSheet hero,
    RulesCatalog? catalog,
  ) {
    final kampf = berechneSpellEffectBeitraegeFuerHeld(
      held: hero,
      zustand: state,
      katalog: catalog,
    );
    final instanzen = state.activeSpellEffects.instanzen;
    final legacyBoni =
        state.activeSpellEffects.isActive(activeSpellEffectAttributo) &&
        describeAttributeModifiers(state.tempAttributeMods).isNotEmpty;
    return [
      for (var i = 0; i < instanzen.length; i++)
        SpellEffectInstanceTile(
          key: ValueKey<String>('spell-instance-${instanzen[i].id}'),
          instanz: instanzen[i],
          ueberlagert: ueberlagerteEigenschaften(state, instanzen[i].id),
          mussAufrechterhaltenWerden: effektVerlangtAufrechterhaltung(
            instanzen[i].effectId,
            catalog,
          ),
          titel:
              '${effektName(instanzen[i].effectId, catalog)} · Quelle ${i + 1}',
          onWirktChanged: (wirkt) => _aendere(
            (aktuell) => unterdrueckeEffektInstanz(
              aktuell,
              instanzen[i].id,
              unterdrueckt: !wirkt,
            ),
          ),
          onEditDuration: () => _dauerDerQuelle(instanzen[i]),
          onEinsetzen: instanzen[i].effectId == kAengsteLindernZauberId
              ? () => _aengsteEinsetzen(instanzen[i])
              : kSchutzZauberIds.contains(instanzen[i].effectId) &&
                    !instanzen[i].unterdrueckt &&
                    schutzRestVon(instanzen[i]) > 0
              ? () => _schildAuffangen(instanzen[i])
              : null,
          einsetzenLabel: kSchutzZauberIds.contains(instanzen[i].effectId)
              ? 'Magischen Treffer auffangen'
              : 'In Mut-Probe einsetzen',
          onEditSchutz: kSchutzZauberIds.contains(instanzen[i].effectId)
              ? () => _schutzRestAnpassen(instanzen[i])
              : null,
          onBeenden: () => _aendere(
            (aktuell) => beendeEffektInstanz(aktuell, instanzen[i].id),
          ),
          onAdvanceDuration: () => _aendere(
            (aktuell) => zaehleEffektInstanzDauer(
              aktuell,
              instanzen[i].id,
              zuruecksetzen: false,
            ),
          ),
        ),
      if (kampf.orientierenGesperrt)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Blitz: Die Aktion „Orientieren“ ist während der Wirkung nicht '
            'möglich.',
            key: ValueKey<String>('spell-effect-orientieren-hinweis'),
          ),
        ),
      for (final hinweis in kampf.hinweise)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(hinweis),
        ),
      Wrap(
        spacing: kDialogInlineSpacing,
        runSpacing: kDialogInlineSpacing,
        children: [
          OutlinedButton.icon(
            key: const ValueKey<String>('spell-instance-attributo-hinzu'),
            onPressed: _fuegeAttributoQuelleHinzu,
            icon: const Icon(Icons.add),
            label: const Text('Weiteren Attributo als Quelle'),
          ),
          if (catalog != null && spellEffectAuswahl(catalog).isNotEmpty)
            OutlinedButton.icon(
              key: const ValueKey<String>('spell-instance-zauber-hinzu'),
              onPressed: () => _fuegeZauberwirkungHinzu(catalog),
              icon: const Icon(Icons.add),
              label: const Text('Zauberwirkung hinzufügen'),
            ),
          OutlinedButton.icon(
            key: const ValueKey<String>('spell-heilung-erhalten'),
            onPressed: () =>
                showHeilungDialog(context: context, heroId: widget.heroId),
            icon: const Icon(Icons.healing_outlined),
            label: const Text('Heilzauber erhalten'),
          ),
          OutlinedButton.icon(
            key: const ValueKey<String>('spell-ruhe-koerper'),
            onPressed: () =>
                showRuheKoerperDialog(context: context, heroId: widget.heroId),
            icon: const Icon(Icons.bedtime_outlined),
            label: const Text('Ruhe Körper (Schlaf)'),
          ),
          if (legacyBoni)
            OutlinedButton(
              key: const ValueKey<String>('spell-instance-legacy-uebernehmen'),
              onPressed: _uebernimmLegacyAttributo,
              child: const Text('Alte Boni als eigene Quelle führen'),
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final state = ref.watch(heroStateProvider(widget.heroId)).valueOrNull;
    final isLoaded = hero != null && state != null;
    final catalog = ref
        .watch(heroRulesCatalogProvider(widget.heroId))
        .asData
        ?.value;

    return AlertDialog(
      key: const ValueKey<String>('active-spell-effects-dialog'),
      scrollable: true,
      title: const Text('Zauber aktivieren'),
      content: SizedBox(
        width: kDialogWidthSmall,
        child: !isLoaded
            ? const Text(
                'Held oder Laufzeitzustand konnte nicht geladen werden.',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Wichtige laufende Zaubereffekte werden sofort gespeichert '
                    'und auf die aktuellen Kampf- und Statuswerte angewendet. '
                    'Die Wirkungsdauer ist optional und läuft nie automatisch ab.',
                  ),
                  const SizedBox(height: kDialogFieldSpacing),
                  for (final effect in importantActiveSpellEffects)
                    ActiveSpellEffectTile(
                      effect: effect,
                      isActive: isActiveSpellEffectEnabled(
                        sheet: hero,
                        state: state,
                        effectId: effect.id,
                      ),
                      duration: state.activeSpellEffects
                          .detailFor(effect.id)
                          .duration,
                      valueText: describeActiveSpellEffectValue(
                        effectId: effect.id,
                        state: state,
                      ),
                      mussAufrechterhaltenWerden:
                          effektVerlangtAufrechterhaltung(effect.id, catalog),
                      onToggled: _toggleHandlerFor(effect),
                      onEditValue: _valueEditorFor(effect),
                      onEditDuration: () => _editDuration(effect),
                      onAdvanceDuration: () =>
                          _changeRemainingDuration(effect, reset: false),
                      onResetDuration: () =>
                          _changeRemainingDuration(effect, reset: true),
                    ),
                  ..._instanzBereich(state, hero, catalog),
                  const ZustandFehlerAnzeige(),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
