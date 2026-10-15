import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_duration_rules.dart';

// Zustandsänderungen der laufenden Zaubereffekte (ARCH-05).
//
// Jede Funktion bekommt den **gespeicherten** Laufzeitzustand und ändert nur
// die Felder ihres Effekts. Der Dialog wendet sie über
// `HeroActions.updateHeroState` auf den frisch geladenen Stand an, damit
// zwischenzeitlich gespeicherte Würfe, Wunden oder Ressourcen erhalten
// bleiben. Eigene Datei, weil `active_spell_rules.dart` von `combat_rules`
// und `magic_rules` importiert wird und keine Schreiblogik tragen soll.

/// Schaltet den Effekt [effectId] ein oder aus.
///
/// Beim Ausschalten des Attributo fallen auch seine Eigenschaftsboni weg:
/// Sie liegen in `HeroState.tempAttributeMods` und wirken sonst weiter. Nur
/// die Werte werden zurückgesetzt, unbekannte Felder bleiben erhalten.
/// Mit [attributoBoniBehalten] bleiben sie stehen (Boni stammen dann aus einer
/// anderen Quelle, etwa manuell oder Corpofesso): der Dialog fragt, weil die
/// Herkunft der alten Werte nicht erkennbar ist. Einschalten mit Werteingabe läuft über [aktiviereAttributo] bzw.
/// [aktiviereArmatrutz].
HeroState schalteZaubereffekt(
  HeroState zustand,
  String effectId, {
  required bool aktiv,
  bool attributoBoniBehalten = false,
}) {
  final effekte = zustand.activeSpellEffects.withToggled(effectId, aktiv);
  final attributoAus =
      !aktiv &&
      effectId == activeSpellEffectAttributo &&
      !attributoBoniBehalten;
  if (!attributoAus) {
    return zustand.copyWith(activeSpellEffects: effekte);
  }
  return zustand.copyWith(
    activeSpellEffects: effekte,
    tempAttributeMods: zustand.tempAttributeMods.uebernimmWerte(
      const AttributeModifiers(),
    ),
  );
}

/// Aktiviert den Attributo mit den eingegebenen Eigenschaftsboni [boni].
///
/// Auch für ein erneutes Bearbeiten der Boni bei bereits aktivem Effekt.
HeroState aktiviereAttributo(HeroState zustand, AttributeModifiers boni) {
  return zustand.copyWith(
    tempAttributeMods: zustand.tempAttributeMods.uebernimmWerte(boni),
    activeSpellEffects: zustand.activeSpellEffects.withToggled(
      activeSpellEffectAttributo,
      true,
    ),
  );
}

/// Aktiviert den Armatrutz mit RS und Wirkungsdauer aus [detail].
///
/// Erst einschalten, dann Zusatzdaten setzen: Zusatzdaten inaktiver Effekte
/// verwirft `ActiveSpellEffectsState` beim Normalisieren.
HeroState aktiviereArmatrutz(
  HeroState zustand,
  ActiveSpellEffectDetail detail,
) {
  final effekte = zustand.activeSpellEffects
      .withToggled(activeSpellEffectArmatrutz, true)
      .withDetail(activeSpellEffectArmatrutz, detail);
  return zustand.copyWith(activeSpellEffects: effekte);
}

/// Setzt die Wirkungsdauer des Effekts [effectId]; `null` entfernt sie.
///
/// Die übrigen Zusatzdaten (etwa der RS des Armatrutz) kommen aus
/// [zustand], nicht aus dem Stand beim Öffnen des Dialogs.
HeroState setzeZaubereffektDauer(
  HeroState zustand,
  String effectId,
  SpellDuration? dauer,
) {
  final detail = zustand.activeSpellEffects.detailFor(effectId);
  final geaendert = dauer == null
      ? detail.copyWith(clearDuration: true)
      : detail.copyWith(duration: dauer);
  final effekte = zustand.activeSpellEffects.withDetail(effectId, geaendert);
  return zustand.copyWith(activeSpellEffects: effekte);
}

/// Zählt die Restdauer des Effekts [effectId] um eine Einheit herunter oder
/// setzt sie mit [zuruecksetzen] auf die Gesamtdauer zurück.
///
/// Gezählt wird ab der **gespeicherten** Restdauer, zwei schnelle Klicks
/// zählen also zweimal. Ohne Wirkungsdauer bleibt [zustand] unverändert.
HeroState zaehleZaubereffektDauer(
  HeroState zustand,
  String effectId, {
  required bool zuruecksetzen,
}) {
  final detail = zustand.activeSpellEffects.detailFor(effectId);
  final dauer = detail.duration;
  if (dauer == null) {
    return zustand;
  }
  final naechste = zuruecksetzen
      ? resetSpellDuration(dauer)
      : advanceSpellDuration(dauer);
  final effekte = zustand.activeSpellEffects.withDetail(
    effectId,
    detail.copyWith(duration: naechste),
  );
  return zustand.copyWith(activeSpellEffects: effekte);
}

/// Legt [instanz] als weitere Quelle an.
///
/// Idempotent: Existiert bereits eine Instanz mit derselben `id` oder
/// derselben `vorgangsId`, bleibt [zustand] unverändert (Doppelklick, Retry,
/// Neustart). Die Legacy-Felder (`tempAttributeMods`, Legacy-IDs) bleiben
/// unberührt.
HeroState aktiviereEffektInstanz(
  HeroState zustand,
  SpellEffectInstance instanz,
) {
  final bisher = zustand.activeSpellEffects.instanzen;
  final doppelt = bisher.any(
    (i) =>
        i.id == instanz.id ||
        (instanz.vorgangsId != null && i.vorgangsId == instanz.vorgangsId),
  );
  if (doppelt) {
    return zustand;
  }
  return zustand.copyWith(
    activeSpellEffects: zustand.activeSpellEffects.copyWith(
      instanzen: <SpellEffectInstance>[...bisher, instanz],
    ),
  );
}

/// Ändert die Instanz [instanzId] mit [aenderung]; unbekannte ID lässt
/// [zustand] unverändert.
///
/// [aenderung] bekommt die **gespeicherte** Instanz (per `copyWith` ändern,
/// damit unbekannte Felder bleiben).
HeroState bearbeiteEffektInstanz(
  HeroState zustand,
  String instanzId,
  SpellEffectInstance Function(SpellEffectInstance aktuell) aenderung,
) {
  final bisher = zustand.activeSpellEffects.instanzen;
  if (!bisher.any((i) => i.id == instanzId)) {
    return zustand;
  }
  return zustand.copyWith(
    activeSpellEffects: zustand.activeSpellEffects.copyWith(
      instanzen: [for (final i in bisher) i.id == instanzId ? aenderung(i) : i],
    ),
  );
}

/// Unterdrückt die Instanz [instanzId] oder hebt die Unterdrückung auf.
HeroState unterdrueckeEffektInstanz(
  HeroState zustand,
  String instanzId, {
  required bool unterdrueckt,
}) {
  return bearbeiteEffektInstanz(
    zustand,
    instanzId,
    (aktuell) => aktuell.copyWith(unterdrueckt: unterdrueckt),
  );
}

/// Beendet die Instanz [instanzId]; nur ihr Beitrag fällt weg.
///
/// Weder andere Instanzen noch `tempAttributeMods` werden angefasst.
HeroState beendeEffektInstanz(HeroState zustand, String instanzId) {
  final bisher = zustand.activeSpellEffects.instanzen;
  if (!bisher.any((i) => i.id == instanzId)) {
    return zustand;
  }
  return zustand.copyWith(
    activeSpellEffects: zustand.activeSpellEffects.copyWith(
      instanzen: [
        for (final i in bisher)
          if (i.id != instanzId) i,
      ],
    ),
  );
}

/// Zählt die Restdauer der Instanz [instanzId] herunter oder setzt sie zurück
/// (wie [zaehleZaubereffektDauer], ab dem gespeicherten Wert).
HeroState zaehleEffektInstanzDauer(
  HeroState zustand,
  String instanzId, {
  required bool zuruecksetzen,
}) {
  return bearbeiteEffektInstanz(zustand, instanzId, (aktuell) {
    final dauer = aktuell.duration;
    if (dauer == null) {
      return aktuell;
    }
    return aktuell.copyWith(
      duration: zuruecksetzen
          ? resetSpellDuration(dauer)
          : advanceSpellDuration(dauer),
    );
  });
}

/// Überführt die Boni eines Legacy-Attributo in eine eigene Instanz
/// ([instanzId]).
///
/// Nur auf ausdrückliche Bestätigung des Nutzers: Ob die Werte in
/// `tempAttributeMods` wirklich vom Attributo stammen, ist nicht erkennbar.
/// Die Boni wandern in die Instanz, `tempAttributeMods` wird zurückgesetzt,
/// das Legacy-Flag samt Dauer entfällt (die Dauer geht in die Instanz).
/// Ohne aktives Legacy-Attributo bleibt [zustand] unverändert.
HeroState uebernimmLegacyAttributoAlsInstanz(
  HeroState zustand,
  String instanzId,
) {
  final effekte = zustand.activeSpellEffects;
  if (!effekte.isActive(activeSpellEffectAttributo) ||
      effekte.instanzFor(instanzId) != null) {
    return zustand;
  }
  final instanz = SpellEffectInstance(
    id: instanzId,
    effectId: activeSpellEffectAttributo,
    attributeMods: const AttributeModifiers().uebernimmWerte(
      zustand.tempAttributeMods,
    ),
    duration: effekte.detailFor(activeSpellEffectAttributo).duration,
  );
  return zustand.copyWith(
    activeSpellEffects: effekte
        .withToggled(activeSpellEffectAttributo, false)
        .copyWith(
          instanzen: <SpellEffectInstance>[...effekte.instanzen, instanz],
        ),
    tempAttributeMods: zustand.tempAttributeMods.uebernimmWerte(
      const AttributeModifiers(),
    ),
  );
}
