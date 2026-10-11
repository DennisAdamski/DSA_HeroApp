import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';

/// Ausgang des Stabilitätswurfs einer Matrix bei einer Anwendung.
enum MatrixAusgang {
  /// Die Auslösung gelingt ohne Zwischenfall.
  ok,

  /// Die Auslösung ist für W6 Spielrunden gehemmt.
  gehemmt,

  /// Die Matrix ist irreparabel beschädigt.
  irreparabel,
}

/// Würfe einer Matrixauslösung. Gewürfelt wird in der Oberfläche (oder von
/// Hand am Tisch eingetragen), die Regeln rechnen nur mit den Werten.
class MatrixWuerfe {
  /// Erstellt die Würfe einer Auslösung.
  const MatrixWuerfe({
    required this.w20,
    this.w20Zusatz = 1,
    this.w6Hemmung = 1,
    this.w6Kosten = 1,
  });

  /// W20 für den Stabilitätstest.
  final int w20;

  /// Zusätzlicher W20, nur bei unempfindlicher Matrix auf einer 20 gewertet.
  final int w20Zusatz;

  /// W6 für die Dauer einer Hemmung in Spielrunden.
  final int w6Hemmung;

  /// W6 für die AsP-Differenz (nur Regelfassung 2011).
  final int w6Kosten;
}

/// Ergebnis des Stabilitätstests.
class MatrixStabilitaetsErgebnis {
  /// Erstellt ein Ergebnis.
  const MatrixStabilitaetsErgebnis(this.ausgang, {this.hemmungSr = 0});

  /// Was mit der Auslösung geschieht.
  final MatrixAusgang ausgang;

  /// Spielrunden, die die Auslösung gehemmt ist (nur bei [MatrixAusgang.gehemmt]).
  final int hemmungSr;
}

// Untergrenzen: ab hemmt gehemmt, ab defekt ist die Matrix beschädigt.
typedef _Schwellen = ({int gehemmtAb, int defektAb});

// Wege der Alchimie, 2. Auflage 2012, S. 88: labil 12–18 / 19–20,
// stabil 17–19 / 20, sehr stabil 18–19 / 20, unempfindlich 20 / 20 (+ Zusatzwurf).
const Map<MatrixStabilitaet, _Schwellen> _schwellenAlchimie2012 = {
  MatrixStabilitaet.labil: (gehemmtAb: 12, defektAb: 19),
  MatrixStabilitaet.stabil: (gehemmtAb: 17, defektAb: 20),
  MatrixStabilitaet.sehrStabil: (gehemmtAb: 18, defektAb: 20),
  MatrixStabilitaet.unempfindlich: (gehemmtAb: 20, defektAb: 20),
};

// Stäbe, Ringe, Dschinnenlampen 2011, S. 17: labil 10–18 / 19–20,
// stabil 16–19 / 20, sehr stabil 18–19 / 20, unempfindlich 20 / 20.
const Map<MatrixStabilitaet, _Schwellen> _schwellenStaebeRinge2011 = {
  MatrixStabilitaet.labil: (gehemmtAb: 10, defektAb: 19),
  MatrixStabilitaet.stabil: (gehemmtAb: 16, defektAb: 20),
  MatrixStabilitaet.sehrStabil: (gehemmtAb: 18, defektAb: 20),
  MatrixStabilitaet.unempfindlich: (gehemmtAb: 20, defektAb: 20),
};

/// Kleinster Zusatzwurf, bei dem eine unempfindliche Matrix auf einer 20
/// tatsächlich irreparabel beschädigt wird.
const int kMatrixUnempfindlichZusatzAb = 15;

/// Wertet den Stabilitätswurf einer Auslösung aus.
///
/// Bei jeder Anwendung eines Matrixgebers kann die Auslösung für W6 SR
/// gehemmt oder das Artefakt irreparabel beschädigt sein. Eine
/// unempfindliche Matrix wird auf einer 20 nur gehemmt; beschädigt wird sie
/// erst, wenn ein weiterer W20 15 bis 20 zeigt.
MatrixStabilitaetsErgebnis wertMatrixStabilitaet({
  required MatrixStabilitaet stabilitaet,
  required MatrixRegelfassung regelfassung,
  required MatrixWuerfe wuerfe,
}) {
  final tabelle = regelfassung == MatrixRegelfassung.staebeRinge2011
      ? _schwellenStaebeRinge2011
      : _schwellenAlchimie2012;
  final schwellen = tabelle[stabilitaet]!;
  final w20 = wuerfe.w20;
  if (w20 < schwellen.gehemmtAb) {
    return const MatrixStabilitaetsErgebnis(MatrixAusgang.ok);
  }
  final defekt = stabilitaet == MatrixStabilitaet.unempfindlich
      ? wuerfe.w20Zusatz >= kMatrixUnempfindlichZusatzAb
      : w20 >= schwellen.defektAb;
  if (defekt) {
    return const MatrixStabilitaetsErgebnis(MatrixAusgang.irreparabel);
  }
  return MatrixStabilitaetsErgebnis(
    MatrixAusgang.gehemmt,
    hemmungSr: wuerfe.w6Hemmung,
  );
}

/// Ob der Wurf [w20] bei dieser Matrix einen Zusatzwurf verlangt.
bool matrixBrauchtZusatzwurf(MatrixStabilitaet stabilitaet, int w20) =>
    stabilitaet == MatrixStabilitaet.unempfindlich && w20 == 20;

/// Summe der AsP-Kosten aller gespeicherten Zauber ohne Würfeldifferenz.
int matrixGrundkosten(ArtefaktDaten daten) =>
    daten.zauber.fold<int>(0, (summe, z) => summe + (z.kostenAsp ?? 0));

/// Summe der je Zauber erfassten permanenten AsP; `null`, wenn kein Zauber
/// einen Wert trägt.
int? artefaktPAspSumme(ArtefaktDaten daten) {
  final werte = daten.alleZauber.map((z) => z.pAsP).whereType<int>();
  return werte.isEmpty ? null : werte.fold<int>(0, (summe, w) => summe + w);
}

/// Permanente AsP des Artefakts insgesamt.
///
/// Ein ausdrücklich eingetragener Gesamtwert (`ArtefaktDaten.pAsP`) gilt vor
/// der Summe der Zauber-pAsP; ohne beides ist das Ergebnis `null`.
int? artefaktPAspGesamt(ArtefaktDaten daten) =>
    daten.pAsP ?? artefaktPAspSumme(daten);

/// Ob für mindestens einen Zauber (oder die ganze Matrix) keine Kosten
/// hinterlegt sind.
bool matrixKostenOffen(ArtefaktDaten daten) =>
    daten.zauber.isEmpty || daten.zauber.any((z) => z.kostenAsp == null);

/// Ob die Regelfassung die W6-Differenz auf die AsP anwendet.
bool matrixKostenMitDifferenz(ArtefaktDaten daten) =>
    daten.regelfassung == MatrixRegelfassung.staebeRinge2011;

/// AsP, die der Träger beim Auslösen aufbringt.
///
/// Nach Fassung 2011 weichen die Kosten um [w6Kosten] ab: bei gerader
/// Augenzahl mehr, bei ungerader weniger, aber nie unter 0. In der Fassung
/// 2012 entsprechen sie den Kosten der gespeicherten Zauber.
int matrixAusloeseKosten(ArtefaktDaten daten, {int w6Kosten = 1}) {
  final grund = matrixGrundkosten(daten);
  if (!matrixKostenMitDifferenz(daten)) {
    return grund;
  }
  final kosten = w6Kosten.isEven ? grund + w6Kosten : grund - w6Kosten;
  return kosten < 0 ? 0 : kosten;
}

/// Prüfergebnis vor einer Auslösung.
class MatrixPruefung {
  /// Erstellt ein Prüfergebnis.
  const MatrixPruefung({this.sperrgrund, this.hinweise = const <String>[]});

  /// Grund, warum nicht ausgelöst werden kann; `null`, wenn es geht.
  final String? sperrgrund;

  /// Hinweise, die die Auslösung nicht verhindern.
  final List<String> hinweise;

  /// Ob die Auslösung möglich ist.
  bool get moeglich => sperrgrund == null;
}

/// Prüft, ob [daten] mit dem AsP-Vorrat des Trägers ausgelöst werden kann.
///
/// Ein beschädigtes Artefakt sperrt. Fehlende Zauberkunde (kein
/// AsP-Vorrat) und unvollständige Angaben bleiben Hinweise: der
/// Spielleiter entscheidet, nicht die App. Reichen die AsP nicht, bucht
/// der Ablauf nicht (siehe [matrixAspReichen]).
MatrixPruefung pruefeMatrixAusloesung({
  required ArtefaktDaten daten,
  required int maxAsp,
}) {
  final hinweise = <String>[];
  if (maxAsp <= 0) {
    hinweise.add(
      'Der Träger hat keinen Astralenergie-Vorrat. Ein Matrixgeber '
      'braucht einen zauberkundigen Träger.',
    );
  }
  if (daten.zauber.isEmpty) {
    hinweise.add('Im Artefakt ist kein Zauber hinterlegt.');
  } else if (matrixKostenOffen(daten)) {
    hinweise.add('Für mindestens einen Zauber fehlen die AsP-Kosten.');
  }
  if (daten.defekt) {
    return MatrixPruefung(
      sperrgrund: 'Die Matrix ist irreparabel beschädigt.',
      hinweise: hinweise,
    );
  }
  return MatrixPruefung(hinweise: hinweise);
}

/// Ob die AsP des Trägers für [kosten] ausreichen.
bool matrixAspReichen(int aktuelleAsp, int kosten) => aktuelleAsp >= kosten;
