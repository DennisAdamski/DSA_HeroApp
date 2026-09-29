// Regeln für den Ablauf „Schaden erhalten“ (ARCH-05), nach Wege des Schwerts
// S. 56–58 (Schaden, TP(A), Wunden) und S. 109 (Trefferzonen).
//
// Die Rechnung ist bewusst ein Vorschlag: Welche Wundschwelle ein Angriff
// tatsächlich hat, hängt auch vom Angriff ab (Armbrustbolzen senken sie etwa
// um 2, waffenlose Angriffe und TP(A) heben sie um 2). Die Wundzahl
// entscheidet deshalb der Nutzer; die Regeln liefern Vorschlag, Zusatzwürfe
// und die Anwendung auf den gespeicherten Zustand.

import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/trefferzonen.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/trefferzonen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';

/// Worauf ein erhaltener Schaden wirkt.
enum SchadensArt {
  /// Trefferpunkte gegen die Lebensenergie; kann Wunden verursachen.
  lebensenergie,

  /// Trefferpunkte (Ausdauer), etwa waffenlos: Die SP(A) senken die AuP,
  /// die Hälfte davon trifft als echte SP die Lebensenergie und kann Wunden
  /// verursachen (WdS S. 57).
  ausdauer,
}

/// Schadenspunkte aus Trefferpunkten [tp] abzüglich Rüstungsschutz [rs].
///
/// Nie negativ: Ein RS über den TP fängt den Treffer vollständig ab.
int berechneSchadenspunkte({required int tp, required int rs}) {
  return math.max(0, tp - rs);
}

/// Echte SP gegen die Lebensenergie aus [sp] Schadenspunkten der [art].
///
/// Bei TP(A) die Hälfte der SP(A), kaufmännisch gerundet (WdS S. 57,
/// Rundung nach WdZ S. 7); sonst die SP selbst. Sie entscheiden über Wunden.
int echteSchadenspunkte({required SchadensArt art, required int sp}) {
  return switch (art) {
    SchadensArt.lebensenergie => sp,
    SchadensArt.ausdauer => (sp / 2).round(),
  };
}

/// Vorgeschlagene Wundzahl samt den dafür verwendeten Schwellen.
class WundVorschlag {
  /// Erstellt einen Vorschlag.
  const WundVorschlag({required this.wunden, required this.schwellen});

  /// Anzahl überschrittener Schwellen (0 bis 3).
  final int wunden;

  /// Die drei Schwellen nach Angriffsmodifikator, aufsteigend
  /// (0,5 KO, KO, 1,5 KO).
  final List<int> schwellen;
}

/// Schlägt vor, wie viele Wunden [sp] (echte) Schadenspunkte verursachen.
///
/// Jede der drei [stufen] zählt, wenn die SP sie **echt überschreiten**
/// (WdS S. 58). [angriffsModifikator] verschiebt alle Stufen, etwa `-2` für
/// Armbrustbolzen oder `+2` für TP(A). Das Ergebnis ist ein Vorschlag, die
/// Entscheidung trifft der Nutzer.
WundVorschlag schlageWundenVor({
  required int sp,
  required WundschwellenStufen stufen,
  int angriffsModifikator = 0,
}) {
  final schwellen = <int>[
    stufen.halbKo + angriffsModifikator,
    stufen.ko + angriffsModifikator,
    stufen.einhalbKo + angriffsModifikator,
  ];
  final wunden = schwellen.where((schwelle) => sp > schwelle).length;
  return WundVorschlag(wunden: wunden, schwellen: List.unmodifiable(schwellen));
}

/// Anzahl Wunden, die [zone] in [zustand] noch aufnehmen kann.
int freieWundplaetze(WundZustand zustand, WundZone zone) {
  return math.max(0, maxWundenProZone - zustand.wundenInZone(zone));
}

/// Ein Zusatzwurf, der mit neuen Wunden in einer Zone fällig wird.
class SchadensZusatzwurf {
  /// Erstellt einen Zusatzwurf.
  const SchadensZusatzwurf({
    required this.label,
    required this.diceSpec,
    required this.wirkung,
  });

  /// Anzeigename, z. B. `Extraschaden` oder `3. Wunde: Extraschaden`.
  final String label;

  /// Zu würfelnde Würfel für alle neuen Wunden zusammen.
  final DiceSpec diceSpec;

  /// Worauf das Ergebnis wirkt.
  final TrefferzonenZusatzwirkung wirkung;
}

/// Zusatzwürfe für [neueWunden] Wunden in [zone] bei [bisherigeWunden].
///
/// Grundlage ist die Standard-Trefferzonentabelle: Kopfwunden bringen je
/// Wunde 2W6 INI-Malus, Brust- und Bauchwunden je Wunde 1W6 zusätzliche SP.
/// Erreicht die Zone mit diesem Treffer ihre dritte Wunde, kommen die Würfe
/// der dritten Wunde hinzu (Kopf: 2W6 SP). Zonen ohne Tabellenwürfe liefern
/// eine leere Liste.
List<SchadensZusatzwurf> schadensZusatzwuerfe({
  required WundZone zone,
  required int bisherigeWunden,
  required int neueWunden,
}) {
  if (neueWunden <= 0) {
    return const <SchadensZusatzwurf>[];
  }
  TrefferzonenEintrag? eintrag;
  for (final kandidat in humanoidTrefferzonenTabelle.eintraege) {
    if (kandidat.zone == zone) {
      eintrag = kandidat;
      break;
    }
  }
  if (eintrag == null) {
    return const <SchadensZusatzwurf>[];
  }
  final ergebnisse = <SchadensZusatzwurf>[];
  for (final wurf in eintrag.zusatzwuerfeErsteBisDritteWunde) {
    final faktor = wurf.multipliziertMitWunden ? neueWunden : 1;
    ergebnisse.add(
      SchadensZusatzwurf(
        label: wurf.label,
        diceSpec: DiceSpec(
          count: wurf.diceCount * faktor,
          sides: wurf.diceSides,
          modifier: wurf.modifier * faktor,
        ),
        wirkung: wurf.wirkung,
      ),
    );
  }
  final erreichtDritte =
      bisherigeWunden < maxWundenProZone &&
      bisherigeWunden + neueWunden >= maxWundenProZone;
  if (erreichtDritte) {
    for (final wurf in eintrag.zusatzwuerfeDritteWunde) {
      ergebnisse.add(
        SchadensZusatzwurf(
          label: '3. Wunde: ${wurf.label}',
          diceSpec: DiceSpec(
            count: wurf.diceCount,
            sides: wurf.diceSides,
            modifier: wurf.modifier,
          ),
          wirkung: wurf.wirkung,
        ),
      );
    }
  }
  return ergebnisse;
}

/// Eine vom Nutzer bestätigte Schadensbuchung.
class SchadensBuchung {
  /// Erstellt eine Buchung. Wunden verlangen eine [zone].
  SchadensBuchung({
    required this.art,
    required this.tp,
    required this.rs,
    this.zone,
    this.wunden = 0,
    this.zusatzSchaden = 0,
    this.kopfIniWurf = 0,
    this.angriffsModifikator = 0,
  }) {
    if (tp < 0 ||
        rs < 0 ||
        wunden < 0 ||
        zusatzSchaden < 0 ||
        kopfIniWurf < 0) {
      throw ArgumentError('Schadenswerte dürfen nicht negativ sein.');
    }
    if (wunden > 0 && zone == null) {
      throw ArgumentError('Wunden brauchen eine Trefferzone.');
    }
  }

  /// Art des Schadens.
  final SchadensArt art;

  /// Trefferpunkte des Angriffs.
  final int tp;

  /// Abgezogener Rüstungsschutz.
  final int rs;

  /// Getroffene Zone, falls bestimmt.
  final WundZone? zone;

  /// Vom Nutzer gewählte Zahl neuer Wunden.
  final int wunden;

  /// Zusätzliche SP aus Zonenwürfen (Brust, Bauch, dritte Kopfwunde).
  final int zusatzSchaden;

  /// Gewürfelter INI-Malus aller neuen Kopfwunden zusammen.
  final int kopfIniWurf;

  /// Wundschwellen-Modifikator des Angriffs; nur für das Protokoll.
  final int angriffsModifikator;

  /// Schadenspunkte aus TP und RS; bei [SchadensArt.ausdauer] die SP(A).
  int get sp => berechneSchadenspunkte(tp: tp, rs: rs);

  /// Echte SP gegen die Lebensenergie, siehe [echteSchadenspunkte].
  int get echteSp => echteSchadenspunkte(art: art, sp: sp);

  /// LeP-Verlust laut Buchung: echte SP und Zusatzschaden.
  int get verlust => echteSp + zusatzSchaden;
}

/// Ergebnis der Anwendung einer [SchadensBuchung] auf einen Zustand.
class SchadensAnwendung {
  /// Erstellt ein Ergebnis.
  const SchadensAnwendung({
    required this.zustand,
    required this.hinzugefuegteWunden,
    required this.verfalleneWunden,
  });

  /// Neuer Zustand.
  final HeroState zustand;

  /// Tatsächlich eingetragene Wunden.
  final int hinzugefuegteWunden;

  /// Gewählte Wunden, für die die Zone keinen Platz mehr hatte.
  final int verfalleneWunden;
}

/// Wendet [buchung] auf den gespeicherten Zustand [zustand] an.
///
/// LeP sinken um [SchadensBuchung.verlust], ohne Untergrenze (unter −KO ist
/// der Held tot, das entscheidet der Tisch). Wunden kommen bis zur vollen
/// Zone hinzu (höchstens drei je Zone, WdS S. 109), der INI-Wurf zählt zur
/// ersten Kopfwunde. Bei TP(A) sinken zusätzlich die AuP um die SP(A),
/// höchstens bis 0; einen Überlauf auf die LeP gibt es nicht. Alle übrigen
/// Felder bleiben unverändert.
SchadensAnwendung wendeSchadenAn(HeroState zustand, SchadensBuchung buchung) {
  final lep = RessourcenAenderung.schritt(-buchung.verlust)
      .wendeAn(zustand.currentLep);
  final au = buchung.art == SchadensArt.ausdauer
      ? RessourcenAenderung.schritt(
          -buchung.sp,
          untergrenze: 0,
        ).wendeAn(zustand.currentAu)
      : zustand.currentAu;
  var wunden = zustand.wpiZustand;
  var hinzugefuegt = 0;
  final zone = buchung.zone;
  if (zone != null) {
    final moeglich = math.min(buchung.wunden, freieWundplaetze(wunden, zone));
    for (var i = 0; i < moeglich; i++) {
      wunden = wunden.mitWundeHinzu(
        zone,
        iniWuerfelWert: i == 0 ? buchung.kopfIniWurf : 0,
      );
    }
    hinzugefuegt = moeglich;
  }
  return SchadensAnwendung(
    zustand: hinzugefuegt > 0
        ? zustand.copyWith(currentLep: lep, currentAu: au, wpiZustand: wunden)
        : zustand.copyWith(currentLep: lep, currentAu: au),
    hinzugefuegteWunden: hinzugefuegt,
    verfalleneWunden: buchung.wunden - hinzugefuegt,
  );
}
