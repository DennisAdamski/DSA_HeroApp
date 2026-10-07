/// Regeln zur Ausbildung von Reittieren (ZBA S. 32–37).
///
/// Die eingetragenen Werte eines Reittiers enthalten bereits alles bis zur
/// Ausgangsstufe. Wirksam werden hier nur die in der App gebuchten Schritte,
/// beim Schritt nach „geschult“ die Variante samt LO +3, und die Unarten.
/// Nichts davon wird in Grundwerte geschrieben (siehe
/// `begleiter_wirkwert_rules.dart`).
library;

import 'package:dsa_heldenverwaltung/catalog/reittier_ausbildung_katalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';

/// Stufe nach allen gebuchten Schritten.
ReittierAusbildungsstufe aktuelleStufe(ReittierAusbildung a) =>
    a.schritte.isEmpty ? a.ausgangsstufe : a.schritte.last.nach;

/// Ausbildungsart des zuletzt gebuchten Schritts (sonst die Ausgangsart).
ReittierAusbildungsart aktuelleArt(ReittierAusbildung a) =>
    a.schritte.isEmpty ? a.ausgangsart : a.schritte.last.art;

/// `true`, wenn der Begleiter ein Reittier mit erfasster Ausbildung ist.
///
/// Nur dann wirken Ausbildungsmodifikationen; ein Typwechsel auf
/// „Vertrauter“ schaltet sie ab, ohne die Daten zu löschen.
bool istReittierMitAusbildung(HeroCompanion c) =>
    c.typ == BegleiterTyp.reittier && c.reittierAusbildung != null;

/// Gewählte Ausbildungsvariante; `null` ohne oder bei unbekannter ID.
ReittierAusbildungsvarianteDef? gewaehlteVariante(ReittierAusbildung a) =>
    a.varianteId.isEmpty ? null : reittierVariante(a.varianteId);

/// `true`, wenn das Tier gerade als geschultes Kampfpferd gilt.
bool istGeschultesKampfpferd(ReittierAusbildung a) =>
    aktuelleStufe(a) == ReittierAusbildungsstufe.geschult &&
    (gewaehlteVariante(a)?.kampfpferd ?? false);

/// Katalogschritt von [von] nach [nach] in der Art [art]; `null`, wenn es
/// diesen Schritt nicht gibt (etwa ländlich nach „geschult“).
ReittierStufenschrittDef? reittierStufenschritt(
  ReittierAusbildungsstufe von,
  ReittierAusbildungsstufe nach,
  ReittierAusbildungsart art,
) {
  for (final schritt in kReittierStufenschritte) {
    if (schritt.von == von && schritt.nach == nach && schritt.art == art) {
      return schritt;
    }
  }
  return null;
}

/// Ein Posten der Modifikationsherleitung (für Vorschau und Erklärung).
class ReittierModQuelle {
  /// Erstellt den Posten.
  const ReittierModQuelle(this.bezeichnung, this.modifikationen);

  /// Woher die Änderung stammt, z. B. „erprobt → geschult (fundiert)“.
  final String bezeichnung;

  /// Werteänderung dieses Postens.
  final ReittierModifikationen modifikationen;
}

/// Herleitung aller wirksamen Ausbildungsmodifikationen in Reihenfolge.
///
/// Ein ländlicher Schritt nach fundierter Ausbildung zählt halb (ZBA S. 35).
/// Ein gebuchter Schritt, den der Katalog nicht kennt, trägt nichts bei.
List<ReittierModQuelle> reittierModifikationsHerkunft(ReittierAusbildung a) {
  final quellen = <ReittierModQuelle>[];
  var stufe = a.ausgangsstufe;
  var fundiertGearbeitet = a.ausgangsart == ReittierAusbildungsart.fundiert;
  final variante = gewaehlteVariante(a);
  for (final schritt in a.schritte) {
    final def = reittierStufenschritt(stufe, schritt.nach, schritt.art);
    final laendlichNachFundiert =
        schritt.art == ReittierAusbildungsart.laendlich && fundiertGearbeitet;
    final titel =
        '${stufe.label} → ${schritt.nach.label} (${schritt.art.label})';
    if (def != null && !def.modifikationen.istLeer) {
      quellen.add(
        laendlichNachFundiert
            ? ReittierModQuelle(
                '$titel, halbiert',
                def.modifikationen.halbiert(),
              )
            : ReittierModQuelle(titel, def.modifikationen),
      );
    }
    final wirdGeschult = schritt.nach == ReittierAusbildungsstufe.geschult;
    if (def != null && wirdGeschult && variante != null) {
      quellen.add(
        ReittierModQuelle('Variante ${variante.name}', variante.modifikationen),
      );
    }
    if (schritt.art == ReittierAusbildungsart.fundiert) {
      fundiertGearbeitet = true;
    }
    stufe = schritt.nach;
  }
  for (final id in a.unartIds) {
    final unart = pferdeUnart(id);
    if (unart != null && unart.lo != 0) {
      quellen.add(
        ReittierModQuelle(
          'Unart ${unart.name}',
          ReittierModifikationen(lo: unart.lo),
        ),
      );
    }
  }
  return quellen;
}

/// Summe aller wirksamen Ausbildungsmodifikationen.
ReittierModifikationen reittierAusbildungsModifikationen(ReittierAusbildung a) {
  var summe = ReittierModifikationen.keine;
  for (final quelle in reittierModifikationsHerkunft(a)) {
    summe = summe.plus(quelle.modifikationen);
  }
  return summe;
}

/// `true`, wenn das Tier fundiert begonnen und danach ländlich
/// weitergeführt wurde; es kann dann nicht weiter geschult werden (ZBA S. 35).
bool istFundiertBegonnenLaendlichWeitergefuehrt(ReittierAusbildung a) {
  var fundiert = a.ausgangsart == ReittierAusbildungsart.fundiert;
  for (final schritt in a.schritte) {
    if (schritt.art == ReittierAusbildungsart.laendlich && fundiert) {
      return true;
    }
    if (schritt.art == ReittierAusbildungsart.fundiert) {
      fundiert = true;
    }
  }
  return false;
}

/// Ein möglicher nächster Ausbildungsschritt.
class ReittierSchrittOption {
  /// Erstellt die Option.
  const ReittierSchrittOption({
    required this.schritt,
    this.sperrgrund,
    this.hinweise = const <String>[],
  });

  /// Der Katalogschritt.
  final ReittierStufenschrittDef schritt;

  /// Warum der Schritt regulär nicht geht; buchbar nur per Meisterentscheid.
  final String? sperrgrund;

  /// Zusätzliche Hinweise (Erschwernisse, halbe Modifikationen).
  final List<String> hinweise;

  /// Der Schritt nach „geschult“ verlangt eine Ausbildungsvariante.
  bool get brauchtVariante => schritt.nach == ReittierAusbildungsstufe.geschult;
}

/// Alle Schritte, die von der aktuellen Stufe aus beschrieben sind.
///
/// Gesperrte Schritte bleiben in der Liste, damit die Oberfläche sie mit
/// Begründung zeigt und per Meisterentscheid zulassen kann.
List<ReittierSchrittOption> naechsteAusbildungsschritte(ReittierAusbildung a) {
  final stufe = aktuelleStufe(a);
  final art = aktuelleArt(a);
  final festgefahren = istFundiertBegonnenLaendlichWeitergefuehrt(a);
  final fundiertBisher =
      a.ausgangsart == ReittierAusbildungsart.fundiert ||
      a.schritte.any((s) => s.art == ReittierAusbildungsart.fundiert);
  return <ReittierSchrittOption>[
    for (final schritt in kReittierStufenschritte)
      if (schritt.von == stufe)
        _option(
          schritt,
          festgefahren: festgefahren,
          laendlichBisher: art == ReittierAusbildungsart.laendlich,
          fundiertBisher: fundiertBisher,
        ),
  ];
}

// Bewertet einen Kandidaten für den nächsten Schritt.
ReittierSchrittOption _option(
  ReittierStufenschrittDef schritt, {
  required bool festgefahren,
  required bool laendlichBisher,
  required bool fundiertBisher,
}) {
  final fundiert = schritt.art == ReittierAusbildungsart.fundiert;
  final hinweise = <String>[];
  String? sperrgrund;
  if (fundiert && festgefahren) {
    sperrgrund =
        'Fundiert begonnen und ländlich weitergeführt: keine weitere '
        'Schulung möglich (ZBA S. 35).';
  } else if (fundiert && laendlichBisher) {
    hinweise.add(
      'Bisher ländlich gearbeitet: Proben um bis zu 5 zusätzlich erschwert, '
      'um eingeschliffene Gewohnheiten abzulegen.',
    );
  }
  if (!fundiert && fundiertBisher) {
    hinweise.add(
      'Nach fundiertem Beginn wirken nur die halben Modifikationen; danach '
      'ist keine Schulung mehr möglich.',
    );
  }
  return ReittierSchrittOption(
    schritt: schritt,
    sperrgrund: sperrgrund,
    hinweise: hinweise,
  );
}

/// Ergebnis für die Reiten-Probe eines Reittiers.
class ReitenModifikator {
  /// Erstellt das Ergebnis.
  const ReitenModifikator({
    required this.erschwernis,
    this.reiterKampfErschwernis = 0,
    this.hinweise = const <String>[],
  });

  /// Modifikator der Reiten-Probe; positiv heißt erschwert.
  final int erschwernis;

  /// Zusatzerschwernis der Kampfhandlungen des Reiters (AT/PA/Ausweichen).
  final int reiterKampfErschwernis;

  /// Erklärungen zu den Bestandteilen.
  final List<String> hinweise;
}

/// Modifikator der Reiten-Probe nach Ausbildungsstand (ZBA S. 35).
///
/// Ohne erfasste Ausbildung gibt es keinen Modifikator. Situative
/// Erleichterungen aus Pferde-SF (Gelände, Sprung, Schreck) bleiben
/// Sache der jeweiligen Probe.
ReitenModifikator reitenProbenModifikator(
  HeroCompanion c, {
  required bool imKampf,
  bool reiterIstZauberer = false,
}) {
  final a = c.reittierAusbildung;
  if (!istReittierMitAusbildung(c) || a == null) {
    return const ReitenModifikator(erschwernis: 0);
  }
  final stufe = aktuelleStufe(a);
  final art = aktuelleArt(a);
  final tabelle = kReittierReitenModifikatoren.firstWhere(
    (m) => m.stufe == stufe,
  );
  final hinweise = <String>[];
  var erschwernis = tabelle.normal;
  var reiterKampf = 0;
  if (imKampf) {
    erschwernis = istGeschultesKampfpferd(a)
        ? tabelle.imKampfAlsKampfpferd
        : tabelle.imKampf;
    if (stufe == ReittierAusbildungsstufe.ungearbeitet) {
      reiterKampf += kReittierUngearbeitetKampfhandlungen;
      hinweise.add('Beide Hände am Zügel: AT, PA und Ausweichen +3.');
    } else if (art == ReittierAusbildungsart.laendlich) {
      erschwernis += kReittierLaendlichReitenImKampf;
      reiterKampf += kReittierLaendlichKampfhandlungen;
      hinweise.add(
        'Ländlich ausgebildet: Reiten +3 und Kampfhandlungen des Reiters +3.',
      );
    }
  }
  final magierpferd =
      stufe == ReittierAusbildungsstufe.geschult &&
      a.varianteId == 'pvar_magierpferd';
  if (magierpferd && reiterIstZauberer) {
    erschwernis -= kMagierpferdZaubererErleichterung;
    hinweise.add('Magierpferd: −1 für Zauberkundige.');
  }
  return ReitenModifikator(
    erschwernis: erschwernis,
    reiterKampfErschwernis: reiterKampf,
    hinweise: hinweise,
  );
}

/// Lernbarkeit einer Pferde-Sonderfertigkeit für ein Tier.
class PferdeSfLernbarkeit {
  /// Erstellt das Ergebnis.
  const PferdeSfLernbarkeit({
    this.sperrgrund,
    this.erschwernis,
    this.hinweise = const <String>[],
  });

  /// Warum die SF regulär nicht nachträglich erlernbar ist; per
  /// Meisterentscheid trotzdem möglich (außer „bereits erlernt“).
  final String? sperrgrund;

  /// Erschwernis der Abrichten-Probe (positiv heißt erschwert).
  final int? erschwernis;

  /// Zusätzliche Hinweise.
  final List<String> hinweise;

  /// Talent der Lernprobe.
  String get talentId => 'tal_abrichten';
}

/// Sperrgrund, wenn das Tier die Sonderfertigkeit schon beherrscht.
const String kPferdeSfBereitsErlernt = 'Bereits erlernt.';

/// Ob und mit welcher Abrichten-Probe [c] die Pferde-SF [sfId] nachträglich
/// lernen kann (ZBA S. 36 f.).
///
/// Allgemeine SF: Abrichten +5; Nervosität hebt Schrecksicher und Stillstand
/// auf +8, Lernfähig erleichtert um 1. Spezielle SF gibt es regulär nur über
/// eine Ausbildungsvariante.
PferdeSfLernbarkeit pferdeSfLernbarkeit(HeroCompanion c, String sfId) {
  final sf = pferdeSf(sfId);
  if (sf == null) {
    return const PferdeSfLernbarkeit(
      sperrgrund: 'Unbekannte Sonderfertigkeit.',
    );
  }
  if (begleiterBeherrschtPferdeSf(c, sfId)) {
    return const PferdeSfLernbarkeit(sperrgrund: kPferdeSfBereitsErlernt);
  }
  final hinweise = <String>[];
  final gruende = <String>[
    if (sf.typ == PferdeSfTyp.speziell)
      'Nur über eine Ausbildungsvariante erlernbar.',
    for (final vorId in sf.voraussetzungSfIds)
      if (!begleiterBeherrschtPferdeSf(c, vorId))
        'Setzt ${pferdeSf(vorId)?.name ?? vorId} voraus.',
  ];
  final rasse = _ausgeschlosseneRasse(c, sf);
  if (rasse != null) {
    gruende.add('Für $rasse nicht ausführbar.');
  }
  final sperrgrund = gruende.isEmpty ? null : gruende.join(' ');
  var erschwernis = kPferdeSfNachtraeglichErschwernis;
  final nervoes = _hatMerkmal(c, 'Nervosität');
  if (sf.nervositaetErschwert && nervoes) {
    erschwernis = kPferdeSfNervositaetErschwernis;
    hinweise.add('Nervosität: Abrichten +8.');
  }
  if (sf.nervositaetErschwert && _hatMerkmal(c, 'Gutmütig')) {
    hinweise.add('Gutmütig: sehr leicht beizubringen (Meisterentscheid).');
  }
  if (_hatMerkmal(c, 'Lernfähig')) {
    erschwernis -= 1;
    hinweise.add('Lernfähig: Abrichten −1.');
  }
  final a = c.reittierAusbildung;
  final laendlich =
      a != null && aktuelleArt(a) == ReittierAusbildungsart.laendlich;
  if (sf.kampf && laendlich) {
    hinweise.add('Ländlich ausgebildet: im Kampf bleiben die +3 bestehen.');
  }
  return PferdeSfLernbarkeit(
    sperrgrund: sperrgrund,
    erschwernis: erschwernis,
    hinweise: hinweise,
  );
}

/// `true`, wenn [c] die Pferde-SF [sfId] führt (über die Katalog-ID oder,
/// bei Freitext, über den Namen).
bool begleiterBeherrschtPferdeSf(HeroCompanion c, String sfId) {
  final name = pferdeSf(sfId)?.name;
  for (final sf in c.sonderfertigkeiten) {
    if (sf.katalogId == sfId) {
      return true;
    }
    final freitext = sf.katalogId.isEmpty && name != null;
    if (freitext && _normalisiert(sf.name) == _normalisiert(name)) {
      return true;
    }
  }
  return false;
}

/// Gangart einer Geschwindigkeitsangabe, erkannt am Namen.
enum ReittierGangart { schritt, trab, galopp }

/// Erkennt die Gangart an der Bezeichnung; `null`, wenn keine passt.
ReittierGangart? reittierGangart(HeroCompanionSpeed s) {
  final art = _normalisiert(s.art);
  if (art.contains('galopp')) return ReittierGangart.galopp;
  if (art.contains('trab')) return ReittierGangart.trab;
  if (art.contains('schritt')) return ReittierGangart.schritt;
  return null;
}

/// Liest den KK-Faktor aus einer Trag- oder Zugkraftangabe („x5“, „×6“,
/// „5×KK“); `null`, wenn keiner erkennbar ist.
int? kraftFaktor(String text) {
  final treffer =
      RegExp(r'[x×]\s*(\d+)').firstMatch(text) ??
      RegExp(r'(\d+)\s*[x×]').firstMatch(text);
  return treffer == null ? null : int.tryParse(treffer.group(1)!);
}

// Erste ausgeschlossene Rasse, die in Familie oder Gattung des Tiers steht.
String? _ausgeschlosseneRasse(HeroCompanion c, PferdeSfDef sf) {
  final text = _normalisiert('${c.familie} ${c.gattung}');
  for (final rasse in sf.ausgeschlosseneRassen) {
    if (text.contains(_normalisiert(rasse))) {
      return rasse;
    }
  }
  return null;
}

// Erkennt einen Vor- oder Nachteil im Freitext des Begleiters.
bool _hatMerkmal(HeroCompanion c, String name) =>
    _normalisiert('${c.vorteile} ${c.nachteile}').contains(_normalisiert(name));

// Vereinheitlicht Groß-/Kleinschreibung und Umlaute für Textvergleiche.
String _normalisiert(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss');
