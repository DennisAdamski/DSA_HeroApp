import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
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
/// Einschalten mit Werteingabe läuft über [aktiviereAttributo] bzw.
/// [aktiviereArmatrutz].
HeroState schalteZaubereffekt(
  HeroState zustand,
  String effectId, {
  required bool aktiv,
}) {
  final effekte = zustand.activeSpellEffects.withToggled(effectId, aktiv);
  final attributoAus = !aktiv && effectId == activeSpellEffectAttributo;
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
