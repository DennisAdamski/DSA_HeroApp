import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';

/// Hält fest, was [anwendung] am Zustand [vorher] tatsächlich verändert hat.
///
/// Die Deltas sind die echten Differenzen, nicht die gebuchten Beträge: Bei
/// TP(A) mit nur 3 AuP ist `auDelta` −3, nicht −SP(A); Wunden zählen nur,
/// soweit die Zone Platz hatte.
ZustandsBuchung schadensBuchungAus({
  required HeroState vorher,
  required SchadensAnwendung anwendung,
  required SchadensBuchung buchung,
  required String id,
  required DateTime zeitpunkt,
}) {
  final nachher = anwendung.zustand;
  final wunden = anwendung.hinzugefuegteWunden;
  return ZustandsBuchung(
    id: id,
    art: ZustandsBuchungsArt.schaden,
    zeitpunkt: zeitpunkt.toUtc(),
    lepDelta: nachher.currentLep - vorher.currentLep,
    auDelta: nachher.currentAu - vorher.currentAu,
    zone: wunden > 0 ? buchung.zone : null,
    wundenDelta: wunden,
    kopfIniMalusDelta:
        nachher.wpiZustand.kopfIniMalus - vorher.wpiZustand.kopfIniMalus,
  );
}

/// Wo eine Schadensbuchung im Protokoll steht.
enum SchadensBuchungsStatus {
  /// Kein Bezug zu einer zurücknehmbaren Schadensbuchung.
  keine,

  /// Die Buchung liegt vor und lässt sich zurücknehmen.
  ruecknehmbar,

  /// Eine Gegenbuchung hat sie bereits zurückgenommen.
  zurueckgenommen,

  /// Die Buchung ist nicht mehr gespeichert (verdrängt oder von einer
  /// älteren App-Version verworfen).
  nichtMehrVerfuegbar,
}

/// Warum eine Rücknahme nicht möglich ist.
enum RuecknahmeHindernis {
  /// Keine Buchung mit dieser ID gespeichert.
  nichtGefunden,

  /// Die Buchung ist kein Treffer (etwa selbst eine Rücknahme).
  keineSchadensbuchung,

  /// Die Buchung wurde bereits zurückgenommen.
  bereitsZurueckgenommen,
}

/// Deutscher Text zu einem [RuecknahmeHindernis].
String ruecknahmeHindernisText(RuecknahmeHindernis hindernis) {
  return switch (hindernis) {
    RuecknahmeHindernis.nichtGefunden =>
      'Diese Buchung ist nicht mehr gespeichert.',
    RuecknahmeHindernis.keineSchadensbuchung =>
      'Nur ein erhaltener Schaden lässt sich zurücknehmen.',
    RuecknahmeHindernis.bereitsZurueckgenommen =>
      'Diese Buchung wurde bereits zurückgenommen.',
  };
}

/// Status der Buchung [buchungId] im Zustand [zustand] für die Anzeige.
SchadensBuchungsStatus schadensBuchungsStatus(
  HeroState zustand,
  String? buchungId,
) {
  if (buchungId == null) {
    return SchadensBuchungsStatus.keine;
  }
  if (zustand.buchungen.any((b) => b.ruecknahmeVon == buchungId)) {
    return SchadensBuchungsStatus.zurueckgenommen;
  }
  final original = zustand.buchungen.where((b) => b.id == buchungId);
  if (original.isEmpty) {
    return SchadensBuchungsStatus.nichtMehrVerfuegbar;
  }
  return original.first.art == ZustandsBuchungsArt.schaden
      ? SchadensBuchungsStatus.ruecknehmbar
      : SchadensBuchungsStatus.keine;
}

/// Was eine Rücknahme am aktuellen Zustand ändert.
class SchadensRuecknahmePlan {
  /// Erzeugt den Plan.
  const SchadensRuecknahmePlan({
    required this.original,
    required this.lepPlus,
    required this.auPlus,
    required this.zone,
    required this.wundenEntfernt,
    required this.wundenNichtMehrVorhanden,
    required this.unterdrueckungEntfernt,
    required this.kopfIniMalusMinus,
    required this.zoneUnbekannt,
  });

  /// Die zurückgenommene Buchung.
  final ZustandsBuchung original;

  /// LeP, die zurückkommen (ohne Obergrenze).
  final int lepPlus;

  /// AuP, die zurückkommen (ohne Obergrenze).
  final int auPlus;

  /// Zone der Wunden des Treffers.
  final WundZone? zone;

  /// Wunden, die entfernt werden.
  final int wundenEntfernt;

  /// Wunden des Treffers, die schon nicht mehr eingetragen sind.
  final int wundenNichtMehrVorhanden;

  /// Unterdrückungen, die mit den Wunden entfallen.
  final int unterdrueckungEntfernt;

  /// Abzug am Kopf-INI-Malus.
  final int kopfIniMalusMinus;

  /// Die Zone stammt aus einer neueren App-Version; ihre Wunden bleiben.
  final bool zoneUnbekannt;
}

/// Ergebnis von [planeSchadensRuecknahme].
sealed class SchadensRuecknahmePruefung {
  const SchadensRuecknahmePruefung();
}

/// Die Rücknahme ist möglich.
class RuecknahmeMoeglich extends SchadensRuecknahmePruefung {
  /// Erzeugt das Ergebnis.
  const RuecknahmeMoeglich(this.plan);

  /// Was sie ändert.
  final SchadensRuecknahmePlan plan;
}

/// Die Rücknahme ist nicht möglich.
class RuecknahmeUnmoeglich extends SchadensRuecknahmePruefung {
  /// Erzeugt das Ergebnis.
  const RuecknahmeUnmoeglich(this.hindernis);

  /// Der Grund.
  final RuecknahmeHindernis hindernis;
}

/// Plant die Gegenbuchung zur Schadensbuchung [buchungId] auf [zustand].
///
/// LeP und AuP kommen um den tatsächlich abgezogenen Betrag zurück, auch
/// über das Maximum (Entscheidung ARCH-06). Wunden des Treffers werden
/// entfernt, soweit die Zone noch so viele trägt; zuerst die unterdrückten,
/// die zu diesem Treffer gehören. Der Kopf-INI-Malus sinkt um den Wurf des
/// Treffers und entfällt mit der letzten Kopfwunde.
SchadensRuecknahmePruefung planeSchadensRuecknahme(
  HeroState zustand,
  String buchungId,
) {
  if (zustand.buchungen.any((b) => b.ruecknahmeVon == buchungId)) {
    return const RuecknahmeUnmoeglich(
      RuecknahmeHindernis.bereitsZurueckgenommen,
    );
  }
  final treffer = zustand.buchungen.where((b) => b.id == buchungId);
  if (treffer.isEmpty) {
    return const RuecknahmeUnmoeglich(RuecknahmeHindernis.nichtGefunden);
  }
  final original = treffer.first;
  if (original.art != ZustandsBuchungsArt.schaden) {
    return const RuecknahmeUnmoeglich(RuecknahmeHindernis.keineSchadensbuchung);
  }

  final zone = original.zone;
  final gebucht = math.max(0, original.wundenDelta);
  var entfernt = 0;
  var unterdrueckungEntfernt = 0;
  var iniMinus = 0;
  if (zone != null && gebucht > 0) {
    final wunden = zustand.wpiZustand;
    final vorhanden = wunden.wundenInZone(zone);
    final unterdrueckt = wunden.unterdrueckteInZone(zone);
    entfernt = math.min(gebucht, vorhanden);
    final eigene = math.min(
      math.min(original.unterdrueckt, unterdrueckt),
      entfernt,
    );
    final ueberzaehlig = unterdrueckt - (vorhanden - entfernt);
    unterdrueckungEntfernt = math.max(eigene, math.max(0, ueberzaehlig));
    if (zone == WundZone.kopf) {
      // Bleiben Kopfwunden übrig, wurden alle Wunden des Treffers entfernt
      // (entfernt = min(gebucht, vorhanden)); dann fällt genau sein Wurf
      // weg. Sonst ist der Kopf frei, und mit ihm entfällt der Malus.
      final malus = wunden.kopfIniMalus;
      final int rest = vorhanden == entfernt
          ? 0
          : math.max(0, malus - math.max(0, original.kopfIniMalusDelta));
      iniMinus = malus - rest;
    }
  }
  return RuecknahmeMoeglich(
    SchadensRuecknahmePlan(
      original: original,
      lepPlus: math.max(0, -original.lepDelta),
      auPlus: math.max(0, -original.auDelta),
      zone: zone,
      wundenEntfernt: entfernt,
      wundenNichtMehrVorhanden: zone == null ? 0 : gebucht - entfernt,
      unterdrueckungEntfernt: unterdrueckungEntfernt,
      kopfIniMalusMinus: iniMinus,
      zoneUnbekannt: zone == null && gebucht > 0,
    ),
  );
}

/// Wendet [plan] als Gegenbuchung [gegenbuchungId] auf [zustand] an.
///
/// Alle übrigen Felder bleiben unverändert; die Gegenbuchung verweist über
/// `ruecknahmeVon` auf das Original.
HeroState wendeSchadensRuecknahmeAn(
  HeroState zustand,
  SchadensRuecknahmePlan plan, {
  required String gegenbuchungId,
  required DateTime zeitpunkt,
}) {
  var wunden = zustand.wpiZustand;
  final zone = plan.zone;
  if (zone != null && plan.wundenEntfernt > 0) {
    final zonen = Map<WundZone, int>.of(wunden.wundenProZone);
    final rest = wunden.wundenInZone(zone) - plan.wundenEntfernt;
    if (rest > 0) {
      zonen[zone] = rest;
    } else {
      zonen.remove(zone);
    }
    final unterdrueckte = Map<WundZone, int>.of(
      wunden.unterdrueckteWundenProZone,
    );
    final restUnterdrueckt =
        wunden.unterdrueckteInZone(zone) - plan.unterdrueckungEntfernt;
    if (restUnterdrueckt > 0) {
      unterdrueckte[zone] = restUnterdrueckt;
    } else {
      unterdrueckte.remove(zone);
    }
    wunden = wunden.copyWith(
      wundenProZone: zonen,
      unterdrueckteWundenProZone: unterdrueckte,
      kopfIniMalus: wunden.kopfIniMalus - plan.kopfIniMalusMinus,
    );
  }
  final gegenbuchung = ZustandsBuchung(
    id: gegenbuchungId,
    art: ZustandsBuchungsArt.schadenRuecknahme,
    zeitpunkt: zeitpunkt.toUtc(),
    lepDelta: plan.lepPlus,
    auDelta: plan.auPlus,
    zone: plan.wundenEntfernt > 0 ? zone : null,
    wundenDelta: -plan.wundenEntfernt,
    kopfIniMalusDelta: -plan.kopfIniMalusMinus,
    ruecknahmeVon: plan.original.id,
  );
  return zustand
      .copyWith(
        currentLep: RessourcenAenderung.schritt(plan.lepPlus)
            .wendeAn(zustand.currentLep),
        currentAu: RessourcenAenderung.schritt(plan.auPlus)
            .wendeAn(zustand.currentAu),
        wpiZustand: wunden,
      )
      .withBuchung(gegenbuchung);
}

/// Trägt nach, dass [anzahl] Wunden der Buchung [buchungId] unterdrückt
/// wurden. Ohne passende Buchung bleibt [zustand] unverändert.
HeroState vermerkeUnterdrueckung(
  HeroState zustand,
  String buchungId,
  int anzahl,
) {
  if (anzahl <= 0 || !zustand.buchungen.any((b) => b.id == buchungId)) {
    return zustand;
  }
  return zustand.copyWith(
    buchungen: List<ZustandsBuchung>.unmodifiable(<ZustandsBuchung>[
      for (final buchung in zustand.buchungen)
        if (buchung.id == buchungId)
          buchung.copyWith(
            unterdrueckt: math.min(
              buchung.unterdrueckt + anzahl,
              math.max(0, buchung.wundenDelta),
            ),
          )
        else
          buchung,
    ]),
  );
}
