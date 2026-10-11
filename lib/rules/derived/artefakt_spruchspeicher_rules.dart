import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';

// Regeln für ladungsbasierte Spruchspeicher (Stäbe, Ringe, Dschinnenlampen
// S. 8 und 16 f.; Wege der Alchimie 2. Auflage S. 80–88). Gewürfelt wird in
// der Oberfläche; die Regeln rechnen nur mit den Werten.

/// Kurzbezeichnung der Artefaktart für Anzeige und Protokoll.
String artefaktArtLabel(ArtefaktArt art) => switch (art) {
  ArtefaktArt.matrixgeber => 'Matrixgeber',
  ArtefaktArt.spruchspeicherEinmalig => 'Spruchspeicher, einmalig',
  ArtefaktArt.spruchspeicherAufladbar => 'Spruchspeicher, aufladbar',
  ArtefaktArt.spruchspeicherSemipermanent => 'Spruchspeicher, semipermanent',
};

/// Ob [art] ein Spruchspeicher ist (ladungs- oder intervallbasiert).
bool artefaktIstSpruchspeicher(ArtefaktArt art) =>
    art != ArtefaktArt.matrixgeber;

/// Ob [art] ein ladungsbasierter Spruchspeicher ist: Er führt `ladungen`.
bool artefaktHatLadungen(ArtefaktArt art) =>
    art == ArtefaktArt.spruchspeicherEinmalig ||
    art == ArtefaktArt.spruchspeicherAufladbar;

/// Ladungen, die noch nicht ausgelöst wurden.
List<ArtefaktLadung> freieLadungen(ArtefaktDaten daten) =>
    daten.ladungen.where((l) => !l.verbraucht).toList(growable: false);

/// Ob ein einmaliger Spruchspeicher alle Ladungen verbraucht hat.
///
/// Er verliert dann jede magische Wirkung, auch den ARCANOVI (Wege der
/// Alchimie S. 82). Ohne hinterlegte Ladung ist er nicht erloschen, sondern
/// noch nicht erfasst.
bool spruchspeicherErloschen(ArtefaktDaten daten) =>
    daten.art == ArtefaktArt.spruchspeicherEinmalig &&
    daten.ladungen.isNotEmpty &&
    freieLadungen(daten).isEmpty;

/// Ob ein aufladbarer Spruchspeicher leer ist und neu geladen werden kann.
bool spruchspeicherAufladbarLeer(ArtefaktDaten daten) =>
    daten.art == ArtefaktArt.spruchspeicherAufladbar &&
    daten.ladungen.isNotEmpty &&
    freieLadungen(daten).isEmpty;

/// Ob das Artefakt jetzt ausgelöst werden kann.
///
/// Ein beschädigtes Artefakt und ein ladungsbasierter Spruchspeicher ohne
/// freie Ladung lassen sich nicht auslösen. Ein Matrixgeber und ein
/// semipermanenter Spruchspeicher nur dann nicht, wenn sie beschädigt sind;
/// der Intervallstand ist für Letzteren eine Anzeige (Meisterentscheid).
bool artefaktAusloesbar(ArtefaktDaten daten) {
  if (daten.defekt) {
    return false;
  }
  return !artefaktHatLadungen(daten.art) || freieLadungen(daten).isNotEmpty;
}

/// Prüfergebnis vor dem Auslösen oder Aufladen eines Spruchspeichers.
class SpruchspeicherPruefung {
  /// Erstellt ein Prüfergebnis.
  const SpruchspeicherPruefung({
    this.sperrgrund,
    this.hinweise = const <String>[],
  });

  /// Grund, warum es nicht geht; `null`, wenn es geht.
  final String? sperrgrund;

  /// Hinweise, die den Vorgang nicht verhindern (Meisterentscheid).
  final List<String> hinweise;

  /// Ob der Vorgang möglich ist.
  bool get moeglich => sperrgrund == null;
}

/// Prüft, ob eine Ladung (bzw. eine Anwendung) von [daten] ausgelöst werden
/// kann.
///
/// Wirkung, ZfP*, Reichweite und Dauer stehen im Artefakt fest. Es gibt weder
/// Zauberdauer noch AsP-Kosten für den Anwender, und er muss nicht
/// zauberkundig sein (Wege der Alchimie S. 87). Unvollständige Angaben bleiben
/// Hinweise. Bei einem semipermanenten Speicher gibt es nie einen
/// Sperrgrund außer der Beschädigung: ein erschöpftes Intervall ist ein
/// Hinweis, den [intervallHinweis] liefert.
SpruchspeicherPruefung pruefeSpruchspeicherAusloesung(
  ArtefaktDaten daten, {
  String? intervallHinweis,
}) {
  if (daten.defekt) {
    return const SpruchspeicherPruefung(
      sperrgrund: 'Die Haltematrix ist irreparabel beschädigt.',
    );
  }
  if (daten.art == ArtefaktArt.spruchspeicherSemipermanent) {
    return SpruchspeicherPruefung(
      hinweise: [
        if (daten.zauber.isEmpty) 'Im Artefakt ist kein Zauber hinterlegt.',
        ?intervallHinweis,
      ],
    );
  }
  if (daten.ladungen.isEmpty) {
    return const SpruchspeicherPruefung(
      sperrgrund: 'Im Artefakt ist keine Ladung hinterlegt.',
    );
  }
  if (freieLadungen(daten).isEmpty) {
    return SpruchspeicherPruefung(
      sperrgrund: spruchspeicherErloschen(daten)
          ? 'Alle Ladungen sind verbraucht; der einmalige Spruchspeicher hat '
                'jede magische Wirkung verloren.'
          : 'Alle Ladungen sind verbraucht. Der Spruchspeicher lässt sich '
                'wieder aufladen.',
    );
  }
  final hinweise = <String>[
    if (freieLadungen(daten).any((l) => l.zauber.isEmpty))
      'Eine freie Ladung enthält keinen Zauber.',
  ];
  return SpruchspeicherPruefung(hinweise: hinweise);
}

/// Ab welchem W20-Wurf die Zaubermatrix beim Aufladen beschädigt ist.
///
/// Wege der Alchimie 2012 (S. 87 f.): nur bei einer 20, doch jede bisherige
/// Aufladung erhöht die Gefahr um 1 Punkt. Stäbe, Ringe, Dschinnenlampen 2011
/// (S. 17): bei 19–20, ohne Steigerung.
int aufladeSchadenAb(MatrixRegelfassung fassung, int aufladungen) {
  if (fassung == MatrixRegelfassung.staebeRinge2011) {
    return 19;
  }
  final schwelle = 20 - (aufladungen < 0 ? 0 : aufladungen);
  return schwelle < 1 ? 1 : schwelle;
}

/// Ob der Wurf [w20] die Zaubermatrix beim Aufladen beschädigt.
bool aufladeBeschaedigt({
  required MatrixRegelfassung fassung,
  required int aufladungen,
  required int w20,
}) => w20 >= aufladeSchadenAb(fassung, aufladungen);

/// Prüft, ob [daten] mit den Ladungen [neu] wieder aufgeladen werden kann.
///
/// Gesperrt ist es bei einem beschädigten oder nicht aufladbaren Artefakt und
/// solange noch eine Ladung übrig ist. Abweichender Thesiskern und zu hohe
/// Gesamt-AsP sind Hinweise: die Entscheidung liegt beim Spielleiter.
SpruchspeicherPruefung pruefeAufladung({
  required ArtefaktDaten daten,
  required List<ArtefaktLadung> neu,
}) {
  if (daten.defekt) {
    return const SpruchspeicherPruefung(
      sperrgrund: 'Die Haltematrix ist irreparabel beschädigt.',
    );
  }
  if (daten.art != ArtefaktArt.spruchspeicherAufladbar) {
    return const SpruchspeicherPruefung(
      sperrgrund: 'Nur ein aufladbarer Spruchspeicher lässt sich aufladen.',
    );
  }
  if (daten.ladungen.isEmpty) {
    return const SpruchspeicherPruefung(
      sperrgrund: 'Im Artefakt ist keine Ladung hinterlegt.',
    );
  }
  if (freieLadungen(daten).isNotEmpty) {
    return const SpruchspeicherPruefung(
      sperrgrund:
          'Aufladen geht erst, wenn alle Ladungen verbraucht sind '
          '(Wege der Alchimie S. 88).',
    );
  }
  final hinweise = <String>[];
  if (!_gleicherThesiskern(daten.ladungen, neu)) {
    hinweise.add(
      'Die Sprüche gehören nicht alle zum selben Thesiskern wie beim '
      'Erschaffen. Zum Aufladen sind nur Sprüche desselben Thesiskerns '
      'erlaubt, Repräsentation, Spontane Modifikation und ZfP* dürfen '
      'abweichen.',
    );
  }
  final gesamt = daten.gesamtAspErschaffung;
  final neueAsp = neu
      .expand((l) => l.zauber)
      .fold<int>(0, (summe, z) => summe + (z.kostenAsp ?? 0));
  if (gesamt != null && neueAsp > gesamt) {
    hinweise.add(
      'Die neuen Sprüche kosten zusammen $neueAsp AsP und überschreiten die '
      'Gesamt-AsP der Erschaffung ($gesamt AsP).',
    );
  }
  return SpruchspeicherPruefung(hinweise: hinweise);
}

// Vergleicht die Thesiskerne (Zauber) der alten und neuen Ladungen als
// Mehrmenge: Katalog-ID, sonst der kleingeschriebene Name.
bool _gleicherThesiskern(List<ArtefaktLadung> alt, List<ArtefaktLadung> neu) {
  List<String> kerne(List<ArtefaktLadung> ladungen) => [
    for (final l in ladungen)
      for (final z in l.zauber) z.spellId ?? z.name.trim().toLowerCase(),
  ]..sort();
  final a = kerne(alt);
  final n = kerne(neu);
  if (a.length != n.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != n[i]) {
      return false;
    }
  }
  return true;
}
