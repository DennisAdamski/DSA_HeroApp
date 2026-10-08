/// Typen des Vertrautenkatalogs (WdZ S. 123–128, ZBA S. 19–21).
///
/// Reine Definitionsklassen mit `toJson` für den per Test geprüften
/// JSON-Spiegel; die Werte stehen in `vertrauten_katalog.dart`.
library;

/// Spanne aus Startwert und Maximum einer Eigenschaft (WdZ S. 124).
class VertrautenWertspanne {
  /// Erstellt die Spanne.
  const VertrautenWertspanne(this.start, this.max);

  /// Startwert der Tierart.
  final int start;

  /// Höchstwert, den die Generierung erreichen darf.
  final int max;

  /// JSON-Abbild.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'start': start,
    'max': max,
  };
}

/// Ein Angriff aus der Startwerttabelle; Flieger haben einen Boden- und einen
/// Luftangriff.
class VertrautenAngriffDef {
  /// Erstellt den Angriff.
  const VertrautenAngriffDef({
    required this.name,
    required this.at,
    required this.pa,
    required this.tp,
  });

  /// Bezeichnung des Angriffs.
  final String name;

  /// Attackewert.
  final int at;

  /// Paradewert.
  final int pa;

  /// Trefferpunkte als Würfelausdruck.
  final String tp;

  /// JSON-Abbild.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'at': at,
    'pa': pa,
    'tp': tp,
  };
}

/// Eine Geschwindigkeit aus der Startwerttabelle.
class VertrautenTempoDef {
  /// Erstellt die Geschwindigkeit.
  const VertrautenTempoDef(this.art, this.wert);

  /// Bewegungsart, z. B. „Boden“ oder „Fliegen“.
  final String art;

  /// Geschwindigkeit.
  final int wert;

  /// JSON-Abbild.
  Map<String, dynamic> toJson() => <String, dynamic>{'art': art, 'wert': wert};
}

/// Eine Vertrautenart mit Startwerten, Maxima und Bindungskosten.
class VertrautenArtDef {
  /// Erstellt die Art.
  const VertrautenArtDef({
    required this.id,
    required this.name,
    required this.bindungskosten,
    required this.eigenschaften,
    required this.iniBasis,
    required this.iniWuerfel,
    required this.lep,
    required this.asp,
    required this.aup,
    required this.rs,
    required this.mr,
    required this.angriffe,
    required this.geschwindigkeiten,
    required this.kampfregeln,
    required this.tiersinne,
    this.ausbildungIds = const <String>[],
    this.hinweis = '',
  });

  /// Stabile ID (`vart_…`).
  final String id;

  /// Anzeigename der Art.
  final String name;

  /// AP, die die Hexe für die Bindung zahlt (ohne Zusatzpunkte).
  final int bindungskosten;

  /// Startwert und Maximum je Eigenschaft (`mu` … `kk`).
  final Map<String, VertrautenWertspanne> eigenschaften;

  /// INI-Basiswert ohne Würfel.
  final int iniBasis;

  /// Würfel der INI, z. B. „1W6“.
  final String iniWuerfel;

  /// Lebensenergie.
  final int lep;

  /// Astralenergie.
  final int asp;

  /// Ausdauer.
  final int aup;

  /// Natürlicher Rüstungsschutz.
  final int rs;

  /// Magieresistenz.
  final int mr;

  /// Angriffe; leer, wenn das Tier nicht angreift.
  final List<VertrautenAngriffDef> angriffe;

  /// Geschwindigkeiten.
  final List<VertrautenTempoDef> geschwindigkeiten;

  /// Besondere Kampfregeln als kurze Stichworte.
  final List<String> kampfregeln;

  /// Sinne, die der Zauber Tiersinne überträgt (WdZ S. 128).
  final String tiersinne;

  /// Ausbildungsstufen, die die ZBA-Tabelle für verwandte Tiere nennt.
  final List<String> ausbildungIds;

  /// Ergänzender Hinweis (Tag-/Nachtwerte, nicht darstellbare Werte).
  final String hinweis;

  /// JSON-Abbild.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'bindungskosten': bindungskosten,
    'eigenschaften': <String, dynamic>{
      for (final eintrag in eigenschaften.entries)
        eintrag.key: eintrag.value.toJson(),
    },
    'iniBasis': iniBasis,
    'iniWuerfel': iniWuerfel,
    'lep': lep,
    'asp': asp,
    'aup': aup,
    'rs': rs,
    'mr': mr,
    'angriffe': angriffe.map((a) => a.toJson()).toList(growable: false),
    'geschwindigkeiten': geschwindigkeiten
        .map((g) => g.toJson())
        .toList(growable: false),
    'kampfregeln': kampfregeln,
    'tiersinne': tiersinne,
    if (ausbildungIds.isNotEmpty) 'ausbildungIds': ausbildungIds,
    if (hinweis.isNotEmpty) 'hinweis': hinweis,
  };
}

/// Lern- und Zugangsdaten eines Vertrautenzaubers (WdZ S. 126–128).
///
/// Verknüpft über [name] mit dem Ritual aus `vertrautenmagie_preset.dart`.
class VertrautenZauberDef {
  /// Erstellt den Eintrag.
  const VertrautenZauberDef({
    required this.id,
    required this.name,
    required this.lernkosten,
    this.tierartIds = const <String>[],
    this.nurMachtvoll = false,
    this.halbFuerMachtvoll = false,
    this.mitBindung = false,
  });

  /// Stabile ID (`vzaub_…`).
  final String id;

  /// Name wie im Ritual-Preset.
  final String name;

  /// Lernkosten in AP des Vertrauten.
  final int lernkosten;

  /// Zugelassene Arten; leer heißt alle.
  final List<String> tierartIds;

  /// Nur für Machtvolle Vertraute.
  final bool nurMachtvoll;

  /// Machtvolle Vertraute zahlen die Hälfte.
  final bool halbFuerMachtvoll;

  /// Kommt mit der Bindung, ohne Lernkosten.
  final bool mitBindung;

  /// JSON-Abbild.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'lernkosten': lernkosten,
    if (tierartIds.isNotEmpty) 'tierartIds': tierartIds,
    if (nurMachtvoll) 'nurMachtvoll': true,
    if (halbFuerMachtvoll) 'halbFuerMachtvoll': true,
    if (mitBindung) 'mitBindung': true,
  };
}

/// Wertänderungen einer Ausbildungsstufe (ZBA S. 21).
class VertrautenModifikationen {
  /// Erstellt die Änderungen; nicht genannte Werte bleiben 0.
  const VertrautenModifikationen({
    this.mu = 0,
    this.kl = 0,
    this.inn = 0,
    this.ch = 0,
    this.ff = 0,
    this.ge = 0,
    this.ko = 0,
    this.kk = 0,
    this.at = 0,
    this.pa = 0,
    this.tp = 0,
    this.ini = 0,
    this.gs = 0,
    this.lep = 0,
    this.aup = 0,
  });

  /// Mut.
  final int mu;

  /// Klugheit.
  final int kl;

  /// Intuition.
  final int inn;

  /// Charisma.
  final int ch;

  /// Fingerfertigkeit.
  final int ff;

  /// Gewandtheit.
  final int ge;

  /// Konstitution.
  final int ko;

  /// Körperkraft.
  final int kk;

  /// Attacke aller Angriffe.
  final int at;

  /// Parade aller Angriffe.
  final int pa;

  /// Trefferpunkte aller Angriffe.
  final int tp;

  /// Initiative.
  final int ini;

  /// Geschwindigkeit.
  final int gs;

  /// Lebenspunkte.
  final int lep;

  /// Ausdauer.
  final int aup;

  /// Änderung des Werts [schluessel] (`mu` … `kk`, `at`, `pa`, `tp`, `ini`,
  /// `gs`, `lep`, `aup`); unbekannte Schlüssel ergeben 0.
  int wert(String schluessel) => toJson()[schluessel] as int? ?? 0;

  /// JSON-Abbild; nur belegte Werte.
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (mu != 0) 'mu': mu,
    if (kl != 0) 'kl': kl,
    if (inn != 0) 'inn': inn,
    if (ch != 0) 'ch': ch,
    if (ff != 0) 'ff': ff,
    if (ge != 0) 'ge': ge,
    if (ko != 0) 'ko': ko,
    if (kk != 0) 'kk': kk,
    if (at != 0) 'at': at,
    if (pa != 0) 'pa': pa,
    if (tp != 0) 'tp': tp,
    if (ini != 0) 'ini': ini,
    if (gs != 0) 'gs': gs,
    if (lep != 0) 'lep': lep,
    if (aup != 0) 'aup': aup,
  };
}

/// Eine Ausbildungsstufe für Tiere außer Pferden (ZBA S. 21).
class VertrautenAusbildungDef {
  /// Erstellt die Stufe.
  const VertrautenAusbildungDef({
    required this.id,
    required this.name,
    required this.tapStern,
    required this.erschwernis,
    required this.modifikationen,
    this.hinweis = '',
    this.fuerVertraute = true,
  });

  /// Stabile ID (`vausb_…`).
  final String id;

  /// Anzeigename.
  final String name;

  /// Benötigte TaP* der Abrichten-Proben.
  final int tapStern;

  /// Erschwernis der Abrichten-Proben.
  final int erschwernis;

  /// Wertänderungen.
  final VertrautenModifikationen modifikationen;

  /// Fertigkeiten und Talentboni als Stichworte.
  final String hinweis;

  /// `false` für das Kampftier, das Vertraute üblicherweise nicht lernen
  /// (WdZ S. 124).
  final bool fuerVertraute;

  /// AP-Kosten für Vertraute: TaP* × 10 (WdZ S. 124).
  int get apKosten => tapStern * 10;

  /// JSON-Abbild.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'tapStern': tapStern,
    'erschwernis': erschwernis,
    'modifikationen': modifikationen.toJson(),
    if (hinweis.isNotEmpty) 'hinweis': hinweis,
    if (!fuerVertraute) 'fuerVertraute': false,
  };
}

/// Eine allgemeine Tierfertigkeit (ZBA S. 21 f.).
class VertrautenFertigkeitDef {
  /// Erstellt die Fertigkeit.
  const VertrautenFertigkeitDef({
    required this.id,
    required this.name,
    required this.erschwernis,
    this.voraussetzungId = '',
    this.mehrfach = false,
    this.hinweis = '',
  });

  /// Stabile ID (`vfert_…`).
  final String id;

  /// Anzeigename.
  final String name;

  /// Erschwernis der Abrichten-Probe.
  final int erschwernis;

  /// Fertigkeit, die vorher sitzen muss; leer, wenn keine.
  final String voraussetzungId;

  /// Mehrfach lernbar (Tricks, höchstens KL Stück).
  final bool mehrfach;

  /// Kurzbeschreibung.
  final String hinweis;

  /// AP-Vorschlag: 10 + 5 × Erschwernis, begrenzt auf 10–50 (Entscheidung
  /// zu WdZ S. 124 „10–50 AP je nach Komplexität“).
  int get apVorschlag => (10 + 5 * erschwernis).clamp(10, 50);

  /// JSON-Abbild.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'erschwernis': erschwernis,
    if (voraussetzungId.isNotEmpty) 'voraussetzungId': voraussetzungId,
    if (mehrfach) 'mehrfach': true,
    if (hinweis.isNotEmpty) 'hinweis': hinweis,
  };
}
