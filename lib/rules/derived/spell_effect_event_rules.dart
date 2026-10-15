import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_request_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_profile_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_protection_rules.dart';

// Einmalige, zielgebundene Zauberwirkungen und ihr Verbrauch (MAG-EFF-04).
//
// Falkenauge und Ängste lindern wirken nicht dauerhaft, sondern auf genau
// eine Probe. Dieses Modul entscheidet, ob eine Wirkung zu einer Probe passt;
// verbraucht wird sie erst, wenn die Probe bestätigt abgeschlossen ist
// (`beendeEffektInstanz` in `active_spell_state_rules.dart`, idempotent über
// die Instanz-ID). Blattartig: Domäne, Profile und Probenbau.
//
// Belege: Liber Cantiones S. 84 (Falkenauge), S. 23 (Ängste lindern).

/// Zauber-ID des Falkenauge Meisterschuss.
const String kFalkenaugeZauberId = 'spell_falkenauge_meisterschuss';

/// Zauber-ID von Ängste lindern.
const String kAengsteLindernZauberId = 'spell_aengste_lindern';

/// Einmalige Zauber, deren Instanz nach der passenden Probe verbraucht wird.
const Set<String> kEinmaligeZauberIds = <String>{
  kFalkenaugeZauberId,
  kAengsteLindernZauberId,
};

bool _profilAutomatisiert(RulesCatalog? katalog, String zauberId) {
  if (katalog == null) {
    return false;
  }
  return profileFuerZauber(katalog, zauberId).any(istAutomatisiert);
}

String _norm(String text) => text.trim().toLowerCase();

/// Ob [ziel] das Gegenüber des aktuellen Kontakts ist.
///
/// Verglichen wird der Name des Kontakts (ohne Groß-/Kleinschreibung) oder
/// die Kennung `gegner:<ID>`. Ohne erfassten Kontakt passt nichts: Die
/// Zielbindung wird nie geraten.
bool zielPasstZumKontakt(String? ziel, Gefechtskontext kontext) {
  final gesucht = _norm(ziel ?? '');
  if (gesucht.isEmpty) {
    return false;
  }
  return gesucht == _norm(kontext.kontakt) ||
      gesucht == _norm(kontext.zielkennung);
}

/// Die Falkenauge-Wirkung, die für einen Schuss auf [kontext] gilt.
///
/// Voraussetzungen: automatisierbares Profil, nicht unterdrückt, ZfP* und
/// Ziel angegeben, Ziel passt zum Kontakt. Mehrere passende Quellen: die mit
/// dem größten ZfP* (Tischregel: nur die stärkste zählt). Die Variante
/// „bleibendes Band“ ist nicht umgesetzt.
SpellEffectInstance? passendeFalkenauge(
  HeroState zustand,
  Gefechtskontext kontext,
  RulesCatalog? katalog,
) {
  if (!_profilAutomatisiert(katalog, kFalkenaugeZauberId)) {
    return null;
  }
  SpellEffectInstance? beste;
  for (final instanz in zustand.activeSpellEffects.instanzen) {
    if (instanz.effectId != kFalkenaugeZauberId ||
        instanz.unterdrueckt ||
        instanz.zfpStern == null ||
        !zielPasstZumKontakt(instanz.ziel, kontext)) {
      continue;
    }
    if (beste == null || instanz.zfpStern! > beste.zfpStern!) {
      beste = instanz;
    }
  }
  return beste;
}

/// Erleichterung des Fernkampfangriffs durch Falkenauge als benannter Anteil
/// (negativ = erleichtert, wie die übrigen Anteile der Gefechtsprüfung).
///
/// `null`, wenn keine Wirkung zum Ziel passt.
Gefechtsmodifikator? falkenaugeAnteil(
  HeroState zustand,
  Gefechtskontext kontext,
  RulesCatalog? katalog,
) {
  final instanz = passendeFalkenauge(zustand, kontext, katalog);
  final zfp = instanz?.zfpStern ?? 0;
  if (instanz == null || zfp <= 0) {
    return null;
  }
  return Gefechtsmodifikator('Falkenauge (Zaubereffekt)', -zfp);
}

/// Die Ängste-lindern-Wirkungen, die der Held einsetzen kann (mit ZfP*).
List<SpellEffectInstance> einsetzbareAengsteLindern(
  HeroState zustand,
  RulesCatalog? katalog,
) {
  if (!_profilAutomatisiert(katalog, kAengsteLindernZauberId)) {
    return const <SpellEffectInstance>[];
  }
  return List<SpellEffectInstance>.unmodifiable([
    for (final instanz in zustand.activeSpellEffects.instanzen)
      if (instanz.effectId == kAengsteLindernZauberId &&
          !instanz.unterdrueckt &&
          instanz.zfpStern != null)
        instanz,
  ]);
}

/// Wiederholte Mut-Probe mit Ängste lindern (LC S. 23).
///
/// Der MU-Wert gilt für die Wiederholung um ZfP* erhöht; das ist für die
/// Eigenschaftsprobe dieselbe Wirkung wie eine um ZfP* erleichterte Probe und
/// steht als Startwert des situativen Modifikators im Dialog. Gilt nur für
/// Angst-/Mut-Proben (kein pauschales MU-Plus); ob die Probe wirklich eine
/// Angstprobe ist, entscheidet der Nutzer, indem er die Wirkung einsetzt.
ResolvedProbeRequest aengsteLindernProbe({
  required int mu,
  required SpellEffectInstance instanz,
}) {
  final zfp = instanz.zfpStern ?? 0;
  return buildAttributeProbeRequest(label: 'MU', effectiveValue: mu).copyWith(
    initialSituationalModifier: zfp,
    ruleHint:
        'Wiederholung einer Angst- oder Mut-Probe mit Ängste lindern: '
        'MU +$zfp (ZfP*); die Wirkung ist danach verbraucht.',
  );
}

/// Wirkungsdauer, die das Regelwerk **eindeutig** festlegt, als Vorschlag.
///
/// - Plumbumbarum: 5 Kampfrunden (LC S. 211)
/// - Adlerauge: 1 Spielrunde (LC S. 15)
/// - Falkenauge: ZfW Kampfrunden (LC S. 84) – ohne ZfW kein Vorschlag
/// - Karnifilo: ZfP* × 5 Kampfrunden (LC S. 136)
/// - Seidenzunge: ZfP* Spielrunden (LC S. 237)
/// - Gardianum: höchstens 1 Spielrunde (LC S. 92); der Schild löst sich
///   früher auf, wenn der Vorrat verbraucht ist
///
/// Blitz dauert ZfW/2 Aktionen; die Rundung eines ungeraden ZfW steht nicht im
/// Regelwerk, deshalb gibt es dort keinen Vorschlag. Psychostabilis dauert
/// „nach AsP“ und wird vom Nutzer festgelegt. `null` = kein Vorschlag.
SpellDuration? dauerVorschlag(String zauberId, {int? zfw, int? zfpStern}) {
  switch (zauberId) {
    case kKarnifiloZauberId:
      if (zfpStern == null || zfpStern <= 0) {
        return null;
      }
      return SpellDuration(
        amount: zfpStern * 5,
        unit: SpellDurationUnit.kampfrunden,
      );
    case kSeidenzungeZauberId:
      if (zfpStern == null || zfpStern <= 0) {
        return null;
      }
      return SpellDuration(
        amount: zfpStern,
        unit: SpellDurationUnit.spielrunden,
      );
    case kPlumbumbarumZauberId:
      return SpellDuration(amount: 5, unit: SpellDurationUnit.kampfrunden);
    case kAdlerAugeZauberId:
      return SpellDuration(amount: 1, unit: SpellDurationUnit.spielrunden);
    case kGardianumZauberId:
      return SpellDuration(amount: 1, unit: SpellDurationUnit.spielrunden);
    case kFalkenaugeZauberId:
      if (zfw == null || zfw <= 0) {
        return null;
      }
      return SpellDuration(amount: zfw, unit: SpellDurationUnit.kampfrunden);
  }
  return null;
}
