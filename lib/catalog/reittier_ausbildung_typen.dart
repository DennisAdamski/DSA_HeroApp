/// Typen des Reittier-Ausbildungskatalogs (ZBA S. 32–40).
///
/// Die Tabellen selbst stehen in `reittier_ausbildung_katalog.dart`. Alle
/// Typen sind unveränderlich und `const`-fähig, damit der Katalog ohne
/// Laden auskommt und Regeln ihn ohne `RulesCatalog` erreichen.
library;

import 'package:dsa_heldenverwaltung/domain/hero_companion/reittier_ausbildungsstufe.dart';

/// Grobe Einordnung einer Ausbildungsvariante.
///
/// Rittmeister (Epische Stufen S. 9) wirkt je nach Kategorie verschieden:
/// Schlachtrösser, Rennpferde und Magierpferde bekommen eigene Boni.
enum ReittierVariantenKategorie {
  schlachtross,
  rennpferd,
  magierpferd,
  reitpferd,
  zugpferd,
  lasttier,
  schaupferd;

  /// Anzeigename der Kategorie.
  String get label => switch (this) {
    ReittierVariantenKategorie.schlachtross => 'Schlachtross',
    ReittierVariantenKategorie.rennpferd => 'Rennpferd',
    ReittierVariantenKategorie.magierpferd => 'Magierpferd',
    ReittierVariantenKategorie.reitpferd => 'Reitpferd',
    ReittierVariantenKategorie.zugpferd => 'Zugpferd',
    ReittierVariantenKategorie.lasttier => 'Lasttier',
    ReittierVariantenKategorie.schaupferd => 'Schaupferd',
  };
}

/// Lernweg einer Pferde-Sonderfertigkeit (ZBA S. 36).
enum PferdeSfTyp {
  /// Jederzeit nachträglich per Abrichten-Probe erlernbar.
  allgemein,

  /// Nur über eine Ausbildungsvariante oder bestimmte Tierarten.
  speziell;

  /// Anzeigename des Lernwegs.
  String get label => switch (this) {
    PferdeSfTyp.allgemein => 'allgemein',
    PferdeSfTyp.speziell => 'speziell',
  };
}

/// Werteänderungen durch einen Ausbildungsschritt, eine Variante oder eine
/// Unart.
///
/// Geschwindigkeit und Ausdauer gelten getrennt für Trab und Galopp; Trag-
/// und Zugkraft ändern den Faktor auf die KK („TK +1×KK“).
class ReittierModifikationen {
  /// Erstellt Modifikationen; nicht genannte Werte bleiben 0.
  const ReittierModifikationen({
    this.lo = 0,
    this.kk = 0,
    this.at = 0,
    this.tpTritt = 0,
    this.gsTrab = 0,
    this.gsGalopp = 0,
    this.auTrab = 0,
    this.auGalopp = 0,
    this.tkFaktor = 0,
    this.zkFaktor = 0,
  });

  /// Keine Änderung.
  static const ReittierModifikationen keine = ReittierModifikationen();

  /// Loyalität.
  final int lo;

  /// Körperkraft.
  final int kk;

  /// Attacke aller Pferdeangriffe.
  final int at;

  /// Trefferpunkte des Tritts.
  final int tpTritt;

  /// Geschwindigkeit im Trab.
  final int gsTrab;

  /// Geschwindigkeit im Galopp.
  final int gsGalopp;

  /// Ausdauer (Spielrunden) im Trab.
  final int auTrab;

  /// Ausdauer (Spielrunden) im Galopp.
  final int auGalopp;

  /// Zusätzlicher Tragkraftfaktor auf die KK.
  final int tkFaktor;

  /// Zusätzlicher Zugkraftfaktor auf die KK.
  final int zkFaktor;

  /// `true`, wenn keine Änderung enthalten ist.
  bool get istLeer => this == keine;

  /// Summe beider Modifikationen.
  ReittierModifikationen plus(ReittierModifikationen o) {
    return ReittierModifikationen(
      lo: lo + o.lo,
      kk: kk + o.kk,
      at: at + o.at,
      tpTritt: tpTritt + o.tpTritt,
      gsTrab: gsTrab + o.gsTrab,
      gsGalopp: gsGalopp + o.gsGalopp,
      auTrab: auTrab + o.auTrab,
      auGalopp: auGalopp + o.auGalopp,
      tkFaktor: tkFaktor + o.tkFaktor,
      zkFaktor: zkFaktor + o.zkFaktor,
    );
  }

  /// Halbe Modifikationen, abgerundet.
  ///
  /// Gilt für ein fundiert begonnenes Tier, das ländlich weitergeführt wird
  /// (ZBA S. 35). Die Werte sind dort stets positiv, `~/` rundet also ab.
  ReittierModifikationen halbiert() {
    return ReittierModifikationen(
      lo: lo ~/ 2,
      kk: kk ~/ 2,
      at: at ~/ 2,
      tpTritt: tpTritt ~/ 2,
      gsTrab: gsTrab ~/ 2,
      gsGalopp: gsGalopp ~/ 2,
      auTrab: auTrab ~/ 2,
      auGalopp: auGalopp ~/ 2,
      tkFaktor: tkFaktor ~/ 2,
      zkFaktor: zkFaktor ~/ 2,
    );
  }

  /// JSON-Abbild; nur Werte ungleich 0.
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (lo != 0) 'lo': lo,
    if (kk != 0) 'kk': kk,
    if (at != 0) 'at': at,
    if (tpTritt != 0) 'tpTritt': tpTritt,
    if (gsTrab != 0) 'gsTrab': gsTrab,
    if (gsGalopp != 0) 'gsGalopp': gsGalopp,
    if (auTrab != 0) 'auTrab': auTrab,
    if (auGalopp != 0) 'auGalopp': auGalopp,
    if (tkFaktor != 0) 'tkFaktor': tkFaktor,
    if (zkFaktor != 0) 'zkFaktor': zkFaktor,
  };

  @override
  bool operator ==(Object other) =>
      other is ReittierModifikationen &&
      other.lo == lo &&
      other.kk == kk &&
      other.at == at &&
      other.tpTritt == tpTritt &&
      other.gsTrab == gsTrab &&
      other.gsGalopp == gsGalopp &&
      other.auTrab == auTrab &&
      other.auGalopp == auGalopp &&
      other.tkFaktor == tkFaktor &&
      other.zkFaktor == zkFaktor;

  @override
  int get hashCode => Object.hash(
    lo,
    kk,
    at,
    tpTritt,
    gsTrab,
    gsGalopp,
    auTrab,
    auGalopp,
    tkFaktor,
    zkFaktor,
  );

  @override
  String toString() => 'ReittierModifikationen(${toJson()})';
}

/// Eine geforderte Talentprobe des Ausbilders.
class ReittierProbeDef {
  /// Erstellt die Probenvorgabe.
  const ReittierProbeDef({
    required this.talentId,
    required this.talentName,
    required this.anzahl,
    this.erschwernis = 0,
    this.alternativeTalentId,
    this.alternativeTalentName,
  });

  /// Talent-ID im Katalog (`tal_abrichten`, `tal_tierkunde`, `tal_reiten`).
  final String talentId;

  /// Anzeigename des Talents.
  final String talentName;

  /// Wie viele Proben dieser Art gefordert sind.
  final int anzahl;

  /// Erschwernis je Probe (positiv heißt erschwert).
  final int erschwernis;

  /// Ersatz bei Zugtieren: Fahrzeug Lenken statt Reiten.
  final String? alternativeTalentId;

  /// Anzeigename des Ersatztalents.
  final String? alternativeTalentName;

  /// JSON-Abbild für den Katalogspiegel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'talentId': talentId,
    'talentName': talentName,
    'anzahl': anzahl,
    if (erschwernis != 0) 'erschwernis': erschwernis,
    if (alternativeTalentId != null) 'alternativeTalentId': alternativeTalentId,
    if (alternativeTalentName != null)
      'alternativeTalentName': alternativeTalentName,
  };
}

/// Ein Ausbildungsschritt von einer Stufe zur nächsten (ZBA S. 34).
class ReittierStufenschrittDef {
  /// Erstellt den Schritt.
  const ReittierStufenschrittDef({
    required this.von,
    required this.nach,
    required this.art,
    this.modifikationen = ReittierModifikationen.keine,
    this.proben = const <ReittierProbeDef>[],
    required this.hinweis,
  });

  /// Ausgangsstufe.
  final ReittierAusbildungsstufe von;

  /// Zielstufe.
  final ReittierAusbildungsstufe nach;

  /// Ausbildungsart des Schritts.
  final ReittierAusbildungsart art;

  /// Werteänderungen des Schritts (ohne Variante).
  final ReittierModifikationen modifikationen;

  /// Geforderte Proben des Ausbilders.
  final List<ReittierProbeDef> proben;

  /// Kurzer Hinweis zu Dauer, Fehlschlägen und Unarten.
  final String hinweis;

  /// JSON-Abbild für den Katalogspiegel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'von': von.name,
    'nach': nach.name,
    'art': art.name,
    if (!modifikationen.istLeer) 'modifikationen': modifikationen.toJson(),
    if (proben.isNotEmpty)
      'proben': proben.map((p) => p.toJson()).toList(growable: false),
    'hinweis': hinweis,
  };
}

/// Modifikator der Reiten-Probe je Ausbildungsstufe (ZBA S. 35).
///
/// Positive Werte erschweren. Ein geschultes Tier hilft im Kampf nur dann
/// voll, wenn es als Kampfpferd ausgebildet ist.
class ReittierReitenModifikatorDef {
  /// Erstellt den Modifikator.
  const ReittierReitenModifikatorDef({
    required this.stufe,
    required this.normal,
    required this.imKampf,
    required this.imKampfAlsKampfpferd,
  });

  /// Stufe, für die der Modifikator gilt.
  final ReittierAusbildungsstufe stufe;

  /// Modifikator außerhalb des Kampfes.
  final int normal;

  /// Modifikator im Kampf.
  final int imKampf;

  /// Modifikator im Kampf, wenn die Variante ein Kampfpferd ist.
  final int imKampfAlsKampfpferd;

  /// JSON-Abbild für den Katalogspiegel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'stufe': stufe.name,
    'normal': normal,
    'imKampf': imKampf,
    'imKampfAlsKampfpferd': imKampfAlsKampfpferd,
  };
}

/// Eine fundierte Ausbildungsvariante (ZBA S. 32).
class ReittierAusbildungsvarianteDef {
  /// Erstellt die Variante.
  const ReittierAusbildungsvarianteDef({
    required this.id,
    required this.name,
    required this.kategorie,
    this.kampfpferd = false,
    this.modifikationen = ReittierModifikationen.keine,
    this.sfIds = const <String>[],
    this.hinweis = '',
  });

  /// Stabile ID (`pvar_…`).
  final String id;

  /// Anzeigename.
  final String name;

  /// Einordnung für Rittmeister und Anzeige.
  final ReittierVariantenKategorie kategorie;

  /// Gilt im Kampf als Kampfpferd (Reiten-Probe −3 statt −1).
  final bool kampfpferd;

  /// Werteänderungen beim Abschluss der Variante.
  final ReittierModifikationen modifikationen;

  /// Pferde-SF, die die Variante mitbringt.
  final List<String> sfIds;

  /// Voraussetzungen oder Besonderheiten als Hinweis.
  final String hinweis;

  /// JSON-Abbild für den Katalogspiegel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'kategorie': kategorie.name,
    if (kampfpferd) 'kampfpferd': true,
    if (!modifikationen.istLeer) 'modifikationen': modifikationen.toJson(),
    if (sfIds.isNotEmpty) 'sfIds': sfIds,
    if (hinweis.isNotEmpty) 'hinweis': hinweis,
  };
}

/// Ein vom Reiter abrufbares Kampfmanöver des Pferdes (ZBA S. 39 f.).
///
/// Wird erst im Gefecht (Paket P3) ausgewertet; der Katalog hält die Werte
/// schon jetzt neben der zugehörigen Sonderfertigkeit.
class PferdemanoeverDef {
  /// Erstellt das Manöver.
  const PferdemanoeverDef({
    required this.reitAtErschwernis,
    required this.dk,
    this.aktionen = 1,
    required this.hinweis,
  });

  /// Erschwernis der Reit-AT.
  final int reitAtErschwernis;

  /// Distanzklasse des Angriffs.
  final String dk;

  /// Verbrauchte Aktionen des Reiters.
  final int aktionen;

  /// Kurzwirkung im Kampf.
  final String hinweis;

  /// JSON-Abbild für den Katalogspiegel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'reitAtErschwernis': reitAtErschwernis,
    'dk': dk,
    if (aktionen != 1) 'aktionen': aktionen,
    'hinweis': hinweis,
  };
}

/// Eine Sonderfertigkeit von Pferden und anderen Reittieren (ZBA S. 36).
class PferdeSfDef {
  /// Erstellt die Sonderfertigkeit.
  const PferdeSfDef({
    required this.id,
    required this.name,
    required this.typ,
    this.kampf = false,
    required this.kurzwirkung,
    this.voraussetzungSfIds = const <String>[],
    this.ausgeschlosseneRassen = const <String>[],
    this.nervositaetErschwert = false,
    this.manoever,
  });

  /// Stabile ID (`psf_…`).
  final String id;

  /// Anzeigename.
  final String name;

  /// Lernweg.
  final PferdeSfTyp typ;

  /// Im Kampf einsetzbar.
  final bool kampf;

  /// Kurzwirkung in eigenen Worten.
  final String kurzwirkung;

  /// Sonderfertigkeiten, die das Pferd vorher beherrschen muss.
  final List<String> voraussetzungSfIds;

  /// Rassen, die die Sonderfertigkeit nicht ausführen können.
  final List<String> ausgeschlosseneRassen;

  /// Bei Nervosität nur mit Abrichten +8 erlernbar (ZBA S. 37).
  final bool nervositaetErschwert;

  /// Kampfmanöver, falls der Reiter es abrufen kann.
  final PferdemanoeverDef? manoever;

  /// JSON-Abbild für den Katalogspiegel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'typ': typ.name,
    if (kampf) 'kampf': true,
    'kurzwirkung': kurzwirkung,
    if (voraussetzungSfIds.isNotEmpty) 'voraussetzungSfIds': voraussetzungSfIds,
    if (ausgeschlosseneRassen.isNotEmpty)
      'ausgeschlosseneRassen': ausgeschlosseneRassen,
    if (nervositaetErschwert) 'nervositaetErschwert': true,
    if (manoever != null) 'manoever': manoever!.toJson(),
  };
}

/// Eine Unart von Reit- und Lasttieren (ZBA S. 37 f.).
class PferdeUnartDef {
  /// Erstellt die Unart.
  const PferdeUnartDef({
    required this.id,
    required this.name,
    this.lo = 0,
    required this.kurzwirkung,
  });

  /// Stabile ID (`punart_…`).
  final String id;

  /// Anzeigename.
  final String name;

  /// Änderung der Loyalität (meist negativ).
  final int lo;

  /// Kurzwirkung in eigenen Worten.
  final String kurzwirkung;

  /// JSON-Abbild für den Katalogspiegel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    if (lo != 0) 'lo': lo,
    'kurzwirkung': kurzwirkung,
  };
}
