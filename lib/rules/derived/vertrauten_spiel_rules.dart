// Spieltischregeln der Vertrauten (WdZ S. 124 f.): Regeneration, Vereinigung
// bei Vollmond und Loyalität.
//
// Regeneration: ein aufgerundetes Zehntel der maximalen LE bzw. AE je
// Regenerationsphase, bei Körperkontakt zusätzlich ein LeP **oder** ein AsP.
// Vereinigung: Hexe und Tier verlieren je 1W6 AsP; ein versäumtes Treffen
// kostet den Vertrauten 1 LeP und 1 LO, nach einem Jahr ohne Versäumnis darf
// eine CH-Probe die LO um 1 heben (höchstens 25). Alles rechnet auf dem
// gespeicherten Zustand bzw. Bogen; ein Maximum kommt aus dem Begleiter.

import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/catalog/vertrauten_katalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';

/// Was der Körperkontakt bei der Regeneration zusätzlich bringt.
enum KontaktBonus {
  /// Ein zusätzlicher Lebenspunkt.
  lep,

  /// Ein zusätzlicher Astralpunkt.
  asp,
}

/// Regeneration je Phase: ein aufgerundetes Zehntel von [maximum].
int vertrautenRegenerationJePhase(int maximum) =>
    maximum <= 0 ? 0 : (maximum + 9) ~/ 10;

/// Zuwachs von [c] durch [phasen] Regenerationsphasen.
///
/// Mit [koerperkontakt] kommt je Phase der gewählte [wahl]-Punkt dazu; ein
/// AsP-Bonus entfällt, wenn der Vertraute keine Astralenergie hat.
({int lep, int asp}) vertrautenRegeneration(
  HeroCompanion c, {
  int phasen = 1,
  bool koerperkontakt = false,
  KontaktBonus wahl = KontaktBonus.lep,
}) {
  final maxLep = begleiterPoolMaximum(c, BegleiterPool.lep);
  final maxAsp = begleiterPoolMaximum(c, BegleiterPool.asp);
  final kontaktLep = koerperkontakt && wahl == KontaktBonus.lep ? 1 : 0;
  final kontaktAsp = koerperkontakt && wahl == KontaktBonus.asp && maxAsp > 0
      ? 1
      : 0;
  final n = math.max(0, phasen);
  return (
    lep: n * (vertrautenRegenerationJePhase(maxLep) + kontaktLep),
    asp: n * (vertrautenRegenerationJePhase(maxAsp) + kontaktAsp),
  );
}

/// Wendet die Regeneration von [c] auf [state] an.
///
/// Heilt höchstens bis zum Maximum; ein Wert darüber bleibt unverändert, ein
/// voller Begleiter bekommt keinen Eintrag. Liefert [state] selbst, wenn sich
/// nichts ändert.
HeroState mitVertrautenRegeneration(
  HeroState state,
  HeroCompanion c, {
  int phasen = 1,
  bool koerperkontakt = false,
  KontaktBonus wahl = KontaktBonus.lep,
}) {
  final zuwachs = vertrautenRegeneration(
    c,
    phasen: phasen,
    koerperkontakt: koerperkontakt,
    wahl: wahl,
  );
  var neu = state;
  for (final (pool, plus) in <(BegleiterPool, int)>[
    (BegleiterPool.lep, zuwachs.lep),
    (BegleiterPool.asp, zuwachs.asp),
  ]) {
    if (plus <= 0) continue;
    final maximum = begleiterPoolMaximum(c, pool);
    final alt = begleiterAktuellerPool(c, neu, pool);
    if (alt >= maximum) continue;
    neu = mitBegleiterPool(
      neu,
      c,
      pool,
      RessourcenAenderung.setzen(math.min(maximum, alt + plus)),
    );
  }
  return neu;
}

/// AsP, die jemand mit [aktuell] AsP bei der Vereinigung tatsächlich verliert:
/// der Wurf, höchstens der vorhandene Vorrat.
int vertrautenVereinigungsVerlust({required int aktuell, required int wurf}) =>
    math.min(math.max(aktuell, 0), math.max(wurf, 0));

/// Bucht den LeP-Verlust eines versäumten Treffens (−1 LeP) auf [state].
HeroState mitVersaeumtemTreffenLep(HeroState state, HeroCompanion c) =>
    mitBegleiterPool(
      state,
      c,
      BegleiterPool.lep,
      const RessourcenAenderung.schritt(
        -1,
        untergrenze: kBegleiterLepUntergrenze,
      ),
    );

/// Bucht den LO-Verlust eines versäumten Treffens (−1 LO, nie unter 0).
///
/// [erwarteteLoyalitaet] ist der Stand, den der Dialog gesehen hat; ein
/// inzwischen geänderter Wert bricht ab.
HeroSheet mitVersaeumtemTreffenLo(
  HeroSheet held, {
  required String begleiterId,
  required int erwarteteLoyalitaet,
}) {
  return ersetzeBegleiter(held, begleiterId, (gespeichert) {
    _pruefeVertrauter(gespeichert);
    final lo = gespeichert.loyalitaet ?? 0;
    if (lo != erwarteteLoyalitaet) {
      throw StateError(
        'Die Loyalität wurde inzwischen geändert. Bitte erneut öffnen.',
      );
    }
    return gespeichert.copyWith(loyalitaet: math.max(0, lo - 1));
  });
}

/// Hebt die LO nach gelungener CH-Probe um 1, höchstens auf
/// [kVertrautenMaxLoyalitaet].
///
/// [erwarteteLoyalitaet] ist der Stand, den der Dialog gesehen hat.
HeroSheet mitLoyalitaetPlusEins(
  HeroSheet held, {
  required String begleiterId,
  required int erwarteteLoyalitaet,
}) {
  return ersetzeBegleiter(held, begleiterId, (gespeichert) {
    _pruefeVertrauter(gespeichert);
    final lo = gespeichert.loyalitaet ?? 0;
    if (lo != erwarteteLoyalitaet) {
      throw StateError(
        'Die Loyalität wurde inzwischen geändert. Bitte erneut öffnen.',
      );
    }
    if (lo >= kVertrautenMaxLoyalitaet) {
      throw StateError(
        'Die Loyalität ist bereits am Maximum ($kVertrautenMaxLoyalitaet).',
      );
    }
    return gespeichert.copyWith(loyalitaet: lo + 1);
  });
}

void _pruefeVertrauter(HeroCompanion c) {
  if (c.typ != BegleiterTyp.vertrauter) {
    throw StateError('Nur ein Vertrauter hat diese Loyalitätsregel.');
  }
}

/// Regeneration eines Vertrauten während der Rast der Hexe (WdZ S. 125).
class VertrautenRast {
  /// Erstellt die Angabe für den Vertrauten [begleiterId].
  const VertrautenRast({
    required this.begleiterId,
    this.koerperkontakt = false,
    this.wahl = KontaktBonus.lep,
  });

  /// ID des Vertrauten.
  final String begleiterId;

  /// Die Rast verbringt der Vertraute in Körperkontakt mit der Hexe.
  final bool koerperkontakt;

  /// Was der Körperkontakt zusätzlich bringt.
  final KontaktBonus wahl;
}

/// Wendet die Regeneration aller [vertraute] aus der Rast auf [state] an;
/// [phasen] ist die Zahl der Regenerationsphasen der Rast.
///
/// Begleiter, die [held] nicht mehr führt oder die keine Vertrauten sind,
/// werden übergangen.
HeroState mitVertrautenRast(
  HeroState state,
  HeroSheet held,
  List<VertrautenRast> vertraute, {
  required int phasen,
}) {
  if (phasen <= 0) return state;
  var neu = state;
  for (final angabe in vertraute) {
    final c = held.companions
        .where((b) => b.id == angabe.begleiterId)
        .firstOrNull;
    if (c == null || c.typ != BegleiterTyp.vertrauter) continue;
    neu = mitVertrautenRegeneration(
      neu,
      c,
      phasen: phasen,
      koerperkontakt: angabe.koerperkontakt,
      wahl: angabe.wahl,
    );
  }
  return neu;
}
