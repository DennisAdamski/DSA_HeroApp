import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_zonen_rules.dart';

/// Aggregierte Wundauswirkungen nach Gesamt- **und** Zonensystem.
///
/// Die Hausregel „Erweiterung und Überarbeitung des Regelwerks“ (S. 3) lässt
/// jede Wunde kombiniert wirken: die allgemeinen Abzüge (WdS S. 58) plus die
/// der Zone (WdS S. 108 f.), siehe `wund_zonen_rules.dart`. Nur effektive,
/// also nicht unterdrückte Wunden wirken.
///
/// Zuständigkeiten: [atMalus] bis [gsMalus] gehen über
/// [wundEffekteToStatModifiers] in die Basiswerte. Die armgebundenen Abzüge
/// ([schwertarmAtPaMalus], [schildarmAtPaMalus]) rechnet erst die
/// Kampfvorschau der Waffe im jeweiligen Arm an. [eigenschaftsVerluste]
/// gelten ausschließlich für Proben ([wendeWundVerlusteAn]), nie für
/// abgeleitete Werte (WdS S. 111).
class WundEffekte {
  /// Erstellt ein Ergebnis; ohne Angaben wirkt nichts.
  const WundEffekte({
    this.atMalus = 0,
    this.paMalus = 0,
    this.fkMalus = 0,
    this.iniBasisMalus = 0,
    this.gsMalus = 0,
    this.schwertarmAtPaMalus = 0,
    this.schildarmAtPaMalus = 0,
    this.eigenschaftsVerluste = const AttributeModifiers(),
    this.aktuellerIniMalus = 0,
    this.hinweise = const <String>[],
    this.kampfunfaehig = false,
    this.zonenMitDritterWunde = const <WundZone>[],
    this.unterdrueckteGesamt = 0,
    this.unterdrueckungHalbiert = false,
    this.linkshaender = false,
  });

  /// AT-Abzug, der unabhängig vom Arm gilt (≤ 0).
  final int atMalus;

  /// PA-Abzug, der unabhängig vom Arm gilt (≤ 0).
  final int paMalus;

  /// FK-Abzug (≤ 0). Armwunden erhöhen ihn nicht.
  final int fkMalus;

  /// Abzug auf den INI-Basiswert (≤ 0).
  final int iniBasisMalus;

  /// GS-Abzug (≤ 0); die GS sinkt dadurch nie unter 1 ([begrenzeWundGs]).
  final int gsMalus;

  /// AT- und PA-Abzug der Waffe im Schwertarm (≤ 0).
  final int schwertarmAtPaMalus;

  /// AT- und PA-Abzug von Schild, Parier- oder Nebenhandwaffe im
  /// Schildarm (≤ 0).
  final int schildarmAtPaMalus;

  /// Eigenschaftsverluste für Proben (GE je Wunde, dazu die Zonen).
  final AttributeModifiers eigenschaftsVerluste;

  /// Gewürfelter Verlust der **aktuellen** INI durch Kopfwunden (≥ 0).
  ///
  /// Gilt laut WdS S. 109 nur im laufenden Kampf und senkt deshalb keinen
  /// gespeicherten Wert; die App zeigt ihn als Hinweis.
  final int aktuellerIniMalus;

  /// Informationstexte (Zusatzschaden, dritte Wunden, Unterdrückung).
  final List<String> hinweise;

  /// Eine dritte Wunde an Kopf, Brust, Rücken oder Bauch.
  final bool kampfunfaehig;

  /// Alle Zonen mit drei Wunden, auch Arme und Beine.
  final List<WundZone> zonenMitDritterWunde;

  /// Anzahl insgesamt unterdrückter Wunden (für die Anzeige).
  final int unterdrueckteGesamt;

  /// Epische KO-Haupteigenschaft: Unterdrücken ist halb so schwer und
  /// erschöpft halb so sehr („Epische Stufen“ S. 4).
  final bool unterdrueckungHalbiert;

  /// Der linke Arm ist der Schwertarm (Vorteil Linkshänder).
  final bool linkshaender;

  /// Ob überhaupt ein Abzug wirkt (Hinweise zählen nicht mit).
  bool get hatAbzuege =>
      atMalus != 0 ||
      paMalus != 0 ||
      fkMalus != 0 ||
      iniBasisMalus != 0 ||
      gsMalus != 0 ||
      schwertarmAtPaMalus != 0 ||
      schildarmAtPaMalus != 0 ||
      !_istLeer(eigenschaftsVerluste);
}

// Ob keine Eigenschaft verändert wird.
bool _istLeer(AttributeModifiers mods) =>
    mods.mu == 0 &&
    mods.kl == 0 &&
    mods.inn == 0 &&
    mods.ch == 0 &&
    mods.ff == 0 &&
    mods.ge == 0 &&
    mods.ko == 0 &&
    mods.kk == 0;

/// Die drei Wundschwellen eines Helden (WdS S. 58).
///
/// Mehr SP als [halbKo] schlagen eine Wunde, mehr als [ko] zwei und mehr als
/// [einhalbKo] drei. Eine vierte Stufe kennt das Regelwerk nicht.
class WundschwellenStufen {
  const WundschwellenStufen({
    required this.halbKo,
    required this.ko,
    required this.einhalbKo,
  });

  /// Wundschwelle bei 0,5 KO; die Wundschwelle im engeren Sinn.
  final int halbKo;

  /// Wundschwelle bei 1,0 KO.
  final int ko;

  /// Wundschwelle bei 1,5 KO.
  final int einhalbKo;
}

/// Berechnet die Wundschwelle des Helden, also die erste der
/// [computeWundschwellenStufen]: KO/2 kaufmaennisch gerundet samt
/// Modifikatoren und Eisern/Glasknochen.
int computeWundschwelle({
  required int ko,
  List<HeroTalentModifier> mods = const [],
  String vorteileText = '',
  String nachteileText = '',
  int merkmalBonus = 0,
}) {
  return computeWundschwellenStufen(
    ko: ko,
    mods: mods,
    vorteileText: vorteileText,
    nachteileText: nachteileText,
    merkmalBonus: merkmalBonus,
  ).halbKo;
}

/// Berechnet die drei Wundschwellenstufen (WdS S. 58).
///
/// Die KO-basierten Faktoren 0,5 und 1,5 werden kaufmaennisch gerundet; das
/// Regelwerk rechnet mit ganzen Zahlen („halbe KO ist gerundet 7“ bei KO 13).
/// Zusatzmodifikatoren aus `mods` wirken auf alle Stufen. Katalogisierte
/// Vor-/Nachteile bringen ihren Bonus als [merkmalBonus] mit (Katalogwirkung
/// `wundschwelle`, ARCH-02); in den frei wirkenden Texten gibt `Eisern`
/// weiterhin pauschal `+2` und `Glasknochen` pauschal `-2`.
WundschwellenStufen computeWundschwellenStufen({
  required int ko,
  List<HeroTalentModifier> mods = const [],
  String vorteileText = '',
  String nachteileText = '',
  int merkmalBonus = 0,
}) {
  final modSumme = _sumWundschwelleMods(mods);
  final namedBonus =
      merkmalBonus +
      (_containsNamedToken(vorteileText, const {'eisern'}) ? 2 : 0) +
      (_containsNamedToken(nachteileText, const {'glasknochen'}) ? -2 : 0);
  final gesamtBonus = modSumme + namedBonus;

  return WundschwellenStufen(
    halbKo: _roundKaufmaennisch(ko * 0.5) + gesamtBonus,
    ko: ko + gesamtBonus,
    einhalbKo: _roundKaufmaennisch(ko * 1.5) + gesamtBonus,
  );
}

/// Berechnet alle aggregierten Wundeffekte aus dem aktuellen Wundenzustand.
///
/// Unterdrückte Wunden verursachen keine Abzüge, zählen aber weiter für die
/// dritte Wunde einer Zone (die Wunde besteht). [linkshaender] macht den
/// linken Arm zum Schwertarm. [halbierteUnterdrueckung] deckt die epische
/// KO-Haupteigenschaft ab; beide Schalter bleiben auch ohne Wunden gesetzt,
/// damit eine spätere Unterdrückungsprobe sie kennt.
WundEffekte computeWundEffekte(
  WundZustand zustand, {
  bool linkshaender = false,
  bool halbierteUnterdrueckung = false,
}) {
  if (zustand.gesamtWunden == 0) {
    return WundEffekte(
      unterdrueckungHalbiert: halbierteUnterdrueckung,
      linkshaender: linkshaender,
    );
  }

  var at = 0;
  var pa = 0;
  var fk = 0;
  var iniBasis = 0;
  var gs = 0;
  var schwertarm = 0;
  var schildarm = 0;
  var eigenschaften = const AttributeModifiers();
  final zonenMitDritterWunde = <WundZone>[];

  for (final zone in WundZone.values) {
    final effektiv = zustand.effektiveWundenInZone(zone);
    if (effektiv > 0) {
      final zonal = wundZonenWirkung(zone);
      // Armgebundene AT/PA wirken nur auf die Waffe in diesem Arm.
      final zonalAt = zonal.armgebunden ? 0 : zonal.at;
      final zonalPa = zonal.armgebunden ? 0 : zonal.pa;
      at += (kWundAllgemein.at + zonalAt) * effektiv;
      pa += (kWundAllgemein.pa + zonalPa) * effektiv;
      fk += (kWundAllgemein.fk + zonal.fk) * effektiv;
      iniBasis += (kWundAllgemein.iniBasis + zonal.iniBasis) * effektiv;
      gs += (kWundAllgemein.gs + zonal.gs) * effektiv;
      final verluste = kWundAllgemein.eigenschaften + zonal.eigenschaften;
      eigenschaften = eigenschaften + skaliereEigenschaften(verluste, effektiv);
      final rolle = armRolleFuer(zone, linkshaender: linkshaender);
      if (rolle == ArmRolle.schwertarm) {
        schwertarm += zonal.at * effektiv;
      } else if (rolle == ArmRolle.schildarm) {
        schildarm += zonal.at * effektiv;
      }
    }
    // Die dritte Wunde zählt, auch wenn sie unterdrückt ist.
    if (zustand.wundenInZone(zone) >= maxWundenProZone) {
      zonenMitDritterWunde.add(zone);
    }
  }

  final aktuellerIniMalus = _aktuellerKopfIniMalus(zustand);
  return WundEffekte(
    atMalus: at,
    paMalus: pa,
    fkMalus: fk,
    iniBasisMalus: iniBasis,
    gsMalus: gs,
    schwertarmAtPaMalus: schwertarm,
    schildarmAtPaMalus: schildarm,
    eigenschaftsVerluste: eigenschaften,
    aktuellerIniMalus: aktuellerIniMalus,
    hinweise: _wundHinweise(
      zustand,
      linkshaender: linkshaender,
      zonenMitDritterWunde: zonenMitDritterWunde,
      aktuellerIniMalus: aktuellerIniMalus,
      halbierteUnterdrueckung: halbierteUnterdrueckung,
    ),
    kampfunfaehig: zonenMitDritterWunde.any(dritteWundeMachtKampfunfaehig),
    zonenMitDritterWunde: List<WundZone>.unmodifiable(zonenMitDritterWunde),
    unterdrueckteGesamt: zustand.gesamtUnterdrueckt,
    unterdrueckungHalbiert: halbierteUnterdrueckung,
    linkshaender: linkshaender,
  );
}

// Anteil des gespeicherten Kopf-INI-Wurfs, der auf effektive Kopfwunden
// entfällt (aufgerundet); unterdrückte Kopfwunden wirken nicht.
int _aktuellerKopfIniMalus(WundZustand zustand) {
  final kopfTotal = zustand.wundenInZone(WundZone.kopf);
  final kopfEffektiv = zustand.effektiveWundenInZone(WundZone.kopf);
  if (kopfTotal <= 0 || kopfEffektiv <= 0) {
    return 0;
  }
  return (zustand.kopfIniMalus * kopfEffektiv / kopfTotal).ceil();
}

// Hinweise in fester Reihenfolge: Zusatzschaden, aktuelle INI, armgebundene
// Eigenschaften, dritte Wunden, Unterdrückung.
List<String> _wundHinweise(
  WundZustand zustand, {
  required bool linkshaender,
  required List<WundZone> zonenMitDritterWunde,
  required int aktuellerIniMalus,
  required bool halbierteUnterdrueckung,
}) {
  final hinweise = <String>[];
  String anzeige(WundZone zone) =>
      wundZonenAnzeige(zone, linkshaender: linkshaender);

  // Erinnerung: von Hand eingetragene Wunden würfeln keinen Zusatzschaden.
  const rumpf = [WundZone.brust, WundZone.bauch, WundZone.ruecken];
  for (final zone in rumpf) {
    final wunden = zustand.wundenInZone(zone);
    if (wunden > 0) {
      hinweise.add('+${wunden}W6 SP Extraschaden (${anzeige(zone)})');
    }
  }
  if (aktuellerIniMalus > 0) {
    hinweise.add('Kopf: aktuelle INI −$aktuellerIniMalus (laufender Kampf)');
  }
  for (final zone in const [WundZone.rechterArm, WundZone.linkerArm]) {
    final effektiv = zustand.effektiveWundenInZone(zone);
    if (effektiv > 0) {
      final betrag = -wundZonenWirkung(zone).eigenschaften.kk * effektiv;
      hinweise.add(
        '${anzeige(zone)}: KK und FF −$betrag gelten nur für Handlungen '
        'mit diesem Arm',
      );
    }
  }
  for (final zone in zonenMitDritterWunde) {
    hinweise.add('${anzeige(zone)}, 3. Wunde: ${dritteWundeFolge(zone)}');
  }
  final unterdrueckt = zustand.gesamtUnterdrueckt;
  if (unterdrueckt > 0) {
    final plural = unterdrueckt > 1 ? 'n' : '';
    hinweise.add('$unterdrueckt Wunde$plural unterdrückt');
    hinweise.add(wundErschoepfungHinweis(halbiert: halbierteUnterdrueckung));
  }
  return hinweise;
}

/// Erschöpfung nach einem Kampf mit unterdrückten Wunden (WdS S. 83).
///
/// Die epische KO-Haupteigenschaft halbiert sie („Epische Stufen“ S. 4);
/// gewürfelt wird am Spieltisch.
String wundErschoepfungHinweis({required bool halbiert}) {
  return halbiert
      ? 'Nach dem Kampf: 1W6 Erschöpfung, halbiert (epische KO)'
      : 'Nach dem Kampf: 1W6 Erschöpfung';
}

/// Berechnet die SB-Erschwernis für das Unterdrücken von Wunden (WdS S. 83).
///
/// [gesamtWunden] = alle Wunden inkl. der neuen.
/// [neueWunden] = 1 (normal), 2 oder 3 (Mehrfachwunden aus einem Treffer).
///
/// Bei Einzelwunden: 4 × Gesamtwunden. Bei Mehrfachwunden aus einem Treffer
/// pauschal +8 (2) bzw. +12 (3). [halbiert] (epische KO) halbiert das
/// Ergebnis; alle Werte sind gerade, es entsteht kein Rest.
int computeSbUnterdrueckungErschwernis({
  required int gesamtWunden,
  int neueWunden = 1,
  bool halbiert = false,
}) {
  final voll = switch (neueWunden) {
    2 => 8,
    3 => 12,
    _ => 4 * gesamtWunden,
  };
  return halbiert ? voll ~/ 2 : voll;
}

/// Wendet die wundbedingten Eigenschaftsverluste auf [basis] an.
///
/// Ergebnis sind die **Probenwerte**: Eigenschafts-, Talent- und
/// Zauberproben würfeln gegen sie. Abgeleitete Werte rechnen weiter mit
/// [basis] (WdS S. 111). Die Werte werden nicht begrenzt.
Attributes wendeWundVerlusteAn(Attributes basis, WundEffekte wunden) {
  final mods = wunden.eigenschaftsVerluste;
  return basis.copyWith(
    mu: basis.mu + mods.mu,
    kl: basis.kl + mods.kl,
    inn: basis.inn + mods.inn,
    ch: basis.ch + mods.ch,
    ff: basis.ff + mods.ff,
    ge: basis.ge + mods.ge,
    ko: basis.ko + mods.ko,
    kk: basis.kk + mods.kk,
  );
}

/// Begrenzt die GS so, dass Wunden sie nie unter 1 senken (WdS S. 111).
///
/// [ohneWunden] ist die GS ohne den Wundanteil, [mitWunden] mit ihm. Eine
/// GS, die schon ohne Wunden unter 1 liegt (hohe BE), wird nicht angehoben.
int begrenzeWundGs({required int ohneWunden, required int mitWunden}) {
  if (mitWunden >= ohneWunden || mitWunden >= 1) {
    return mitWunden;
  }
  return ohneWunden < 1 ? ohneWunden : 1;
}

/// Konvertiert aggregierte Wundeffekte in [StatModifiers] für die
/// zentrale Berechnungspipeline.
///
/// Nur die armunabhängigen Abzüge: Armgebundene AT/PA rechnet die
/// Kampfvorschau je Waffe an, Eigenschaftsverluste gelten nur für Proben,
/// und der Kopf-INI-Wurf betrifft nur den laufenden Kampf.
StatModifiers wundEffekteToStatModifiers(WundEffekte effekte) {
  return StatModifiers(
    at: effekte.atMalus,
    pa: effekte.paMalus,
    fk: effekte.fkMalus,
    iniBase: effekte.iniBasisMalus,
    gs: effekte.gsMalus,
  );
}

int _sumWundschwelleMods(List<HeroTalentModifier> mods) {
  var modSumme = 0;
  for (final modifier in mods) {
    modSumme += modifier.modifier;
  }
  return modSumme;
}

int _roundKaufmaennisch(double value) => value.round();

bool _containsNamedToken(String text, Set<String> targets) {
  for (final rawFragment in text.split(RegExp(r'[\n,;]+'))) {
    final fragment = rawFragment.trim();
    if (fragment.isEmpty) {
      continue;
    }
    final normalizedFragment = fragment
        .toLowerCase()
        .replaceAll(String.fromCharCode(228), 'a')
        .replaceAll(String.fromCharCode(246), 'o')
        .replaceAll(String.fromCharCode(252), 'u')
        .replaceAll(String.fromCharCode(223), 'ss');
    final tokens = normalizedFragment
        .split(RegExp(r'[^a-z0-9]+'))
        .where((entry) => entry.isNotEmpty);
    for (final token in tokens) {
      if (targets.contains(token)) {
        return true;
      }
    }
  }
  return false;
}
