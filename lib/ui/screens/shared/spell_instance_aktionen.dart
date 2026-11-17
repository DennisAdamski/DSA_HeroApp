import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_event_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_protection_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/attributo_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/spell_duration_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/spell_effect_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/spell_shield_actions.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/schaden/schaden_dialog.dart';

/// Bedienwege für Zauberwirkungen (Instanzen) am Helden.
///
/// Gemeinsam genutzt vom Dialog „Zauber aktivieren“ und von der Kachel im
/// Gefecht, damit beide dieselben Eingaben, Vorschläge und Schreibregeln
/// verwenden. Geschrieben wird nie ein beim Rendern erfasster Stand: [aendere]
/// bekommt den frisch gespeicherten Zustand und ersetzt nur eigene Felder.
class SpellInstanceAktionen {
  /// Erstellt die Aktionen für einen Helden.
  const SpellInstanceAktionen({
    required this.context,
    required this.ref,
    required this.heroId,
    required this.aendere,
  });

  /// Kontext für Dialoge; nach jedem `await` per `context.mounted` geprüft.
  final BuildContext context;

  /// Zugriff auf Provider.
  final WidgetRef ref;

  /// Held, dessen Wirkungen bedient werden.
  final String heroId;

  /// Schreibt eine Änderung frisch auf den gespeicherten Zustand.
  final Future<void> Function(HeroState Function(HeroState aktuell)) aendere;

  RulesCatalog? get _katalog =>
      ref.read(heroRulesCatalogProvider(heroId)).asData?.value;

  /// Legt einen weiteren Attributo als eigene Quelle an.
  Future<void> attributoQuelleHinzufuegen() async {
    final bonuses = await showAttributoInputDialog(context: context);
    if (bonuses == null || !context.mounted) {
      return;
    }
    final instanz = SpellEffectInstance(
      id: const Uuid().v4(),
      effectId: activeSpellEffectAttributo,
      vorgangsId: const Uuid().v4(),
      attributeMods: const AttributeModifiers().uebernimmWerte(bonuses),
    );
    await aendere((aktuell) => aktiviereEffektInstanz(aktuell, instanz));
  }

  /// Legt eine Zauberwirkung mit belegtem Profil als weitere Quelle an.
  Future<void> zauberwirkungHinzufuegen(RulesCatalog katalog) async {
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
    if (eingabe == null || !context.mounted) {
      return;
    }
    final instanz = SpellEffectInstance(
      id: const Uuid().v4(),
      effectId: eingabe.zauberId,
      vorgangsId: const Uuid().v4(),
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
    await aendere((aktuell) => aktiviereEffektInstanz(aktuell, instanz));
  }

  /// Legt die Wirkungsdauer einer Quelle fest.
  Future<void> dauerDerQuelle(SpellEffectInstance instanz) async {
    final ergebnis = await showSpellDurationDialog(
      context: context,
      spellLabel: effektName(instanz.effectId, _katalog),
      initialDuration: instanz.duration,
      defaultUnit: SpellDurationUnit.kampfrunden,
    );
    if (ergebnis == null || !context.mounted) {
      return;
    }
    await aendere(
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
  Future<void> aengsteEinsetzen(SpellEffectInstance instanz) async {
    final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
    if (snapshot == null) {
      return;
    }
    final mu = snapshot.probenEigenschaften.mu;
    var verbraucht = false;
    await showLoggedProbeDialog(
      context: context,
      ref: ref,
      heroId: heroId,
      request: aengsteLindernProbe(mu: mu, instanz: instanz),
      zaubereffekteAnwenden: false,
      onResolved: (_) {
        // Sofort nach der Auswertung, nicht erst beim Schließen des Blatts;
        // das Beenden ist über die Instanz-ID idempotent.
        if (verbraucht) return;
        verbraucht = true;
        unawaited(
          aendere((aktuell) => beendeEffektInstanz(aktuell, instanz.id)),
        );
      },
    );
  }

  /// Lässt einen Zauberschild einen direkten magischen Treffer auffangen und
  /// bietet den Durchschlag anschließend als Schaden an.
  Future<void> schildAuffangen(SpellEffectInstance instanz) async {
    final ergebnis = await fangeTrefferMitSchildAuf(
      context: context,
      ref: ref,
      heroId: heroId,
      instanz: instanz,
      schildName: effektName(instanz.effectId, _katalog),
    );
    if (ergebnis == null || !context.mounted) {
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
    if (schadenBuchen != true || !context.mounted) {
      return;
    }
    await showSchadenDialog(
      context: context,
      ref: ref,
      heroId: heroId,
      anfangsTp: ergebnis.durchschlag,
    );
  }

  /// Korrigiert den Schutzvorrat eines Zauberschilds.
  Future<void> schutzRestAnpassen(SpellEffectInstance instanz) async {
    final rest = await fragePasseSchutzRestAn(
      context: context,
      instanz: instanz,
    );
    if (rest == null || !context.mounted) {
      return;
    }
    await aendere((aktuell) => setzeSchutzRest(aktuell, instanz.id, rest));
  }
}
