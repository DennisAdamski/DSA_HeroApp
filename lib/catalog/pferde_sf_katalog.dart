/// Sonderfertigkeiten und Unarten von Pferden und anderen Reittieren
/// (ZBA S. 36–40).
///
/// Teil des Reittier-Ausbildungskatalogs (`reittier_ausbildung_katalog.dart`,
/// der diese Datei mit exportiert). Texte sind kurze Zusammenfassungen in
/// eigenen Worten.
library;

import 'package:dsa_heldenverwaltung/catalog/reittier_ausbildung_typen.dart';

/// Grunderschwernis, um einem Tier nachträglich eine allgemeine
/// Sonderfertigkeit beizubringen (ZBA S. 36).
const int kPferdeSfNachtraeglichErschwernis = 5;

/// Erschwernis für Schrecksicher und Stillstand bei Nervosität (ZBA S. 37).
const int kPferdeSfNervositaetErschwernis = 8;

/// Rassen, die für Capriola zu schwer sind (ZBA S. 32, 36).
const List<String> _zuSchwerFuerCapriola = <String>[
  'Tralloper Riese',
  'Svellttaler Kaltblut',
  'Norburger Riese',
  'Tobimora-Falbe',
];

/// Alle Pferde-Sonderfertigkeiten (ZBA S. 36, 39 f.).
const List<PferdeSfDef> kPferdeSonderfertigkeiten = <PferdeSfDef>[
  PferdeSfDef(
    id: 'psf_almadaner_schritt',
    name: 'Almadaner Schritt',
    typ: PferdeSfTyp.speziell,
    kurzwirkung: 'Stolzierender Schritt mit hoch angehobenen Vorderbeinen.',
  ),
  PferdeSfDef(
    id: 'psf_capriola',
    name: 'Capriola',
    typ: PferdeSfTyp.speziell,
    kampf: true,
    kurzwirkung:
        'Sprung mit Ausschlagen der Hinterhand, verschafft im Getümmel Platz.',
    ausgeschlosseneRassen: _zuSchwerFuerCapriola,
    manoever: PferdemanoeverDef(
      reitAtErschwernis: 5,
      dk: 'N',
      hinweis:
          'TP doppelt, nur Ausweichen möglich; Getroffene stürzen ohne '
          'gelungene KK-Probe erschwert um die SP.',
    ),
  ),
  PferdeSfDef(
    id: 'psf_corbetto',
    name: 'Corbetto',
    typ: PferdeSfTyp.speziell,
    kampf: true,
    kurzwirkung: 'Sätze auf der Hinterhand mit schlagenden Vorderläufen.',
    manoever: PferdemanoeverDef(
      reitAtErschwernis: 3,
      dk: 'HN',
      aktionen: 2,
      hinweis:
          'Zwei Tritte je Kampfrunde, bis zu zwei Runden; der Reiter handelt '
          'währenddessen nicht selbst.',
    ),
  ),
  PferdeSfDef(
    id: 'psf_eingefahren',
    name: 'Eingefahren',
    typ: PferdeSfTyp.speziell,
    kurzwirkung: 'Lässt sich auch vor einen Wagen spannen.',
  ),
  PferdeSfDef(
    id: 'psf_galoppwechsel',
    name: 'Galoppwechsel',
    typ: PferdeSfTyp.allgemein,
    kurzwirkung: 'Wechselt auf Kommando die Galopprichtung.',
  ),
  PferdeSfDef(
    id: 'psf_gelaendehindernisse',
    name: 'Geländehindernisse',
    typ: PferdeSfTyp.allgemein,
    kurzwirkung:
        'Durchquert Brücken, Bäche, Unterholz und Geröll trittsicher; '
        'Reiten-Proben dort 3 Punkte weniger erschwert.',
  ),
  PferdeSfDef(
    id: 'psf_gespanngewoehnung',
    name: 'Gespanngewöhnung',
    typ: PferdeSfTyp.speziell,
    kurzwirkung:
        'Auf das eigene Gespann eingespielt: Fahrzeug Lenken −3; in fremder '
        'Anspannung entfällt das, LO −2.',
  ),
  PferdeSfDef(
    id: 'psf_gezielter_biss',
    name: 'Gezielter Biss',
    typ: PferdeSfTyp.allgemein,
    kampf: true,
    kurzwirkung: 'Beißt auf Kommando einen Gegner vor sich.',
    manoever: PferdemanoeverDef(
      reitAtErschwernis: 1,
      dk: 'H',
      hinweis: 'Gegner vor dem Pferd; Kamele erreichen DK N.',
    ),
  ),
  PferdeSfDef(
    id: 'psf_gezielter_tritt',
    name: 'Gezielter Tritt',
    typ: PferdeSfTyp.speziell,
    kampf: true,
    kurzwirkung:
        'Schlägt auf Kommando nach einem Gegner neben oder hinter sich.',
    manoever: PferdemanoeverDef(
      reitAtErschwernis: 1,
      dk: 'N',
      hinweis: 'Gegner neben oder hinter dem Pferd; Kamele erreichen DK NS.',
    ),
  ),
  PferdeSfDef(
    id: 'psf_hinlegen',
    name: 'Hinlegen',
    typ: PferdeSfTyp.allgemein,
    kurzwirkung: 'Legt sich auf Kommando hin und bleibt liegen.',
  ),
  PferdeSfDef(
    id: 'psf_kehrtwende',
    name: 'Kehrtwende',
    typ: PferdeSfTyp.allgemein,
    kurzwirkung: 'Wendet nach einem Stopp und läuft sofort wieder an.',
    voraussetzungSfIds: <String>['psf_stopp'],
  ),
  PferdeSfDef(
    id: 'psf_kniefall',
    name: 'Kniefall',
    typ: PferdeSfTyp.speziell,
    kurzwirkung: 'Lässt sich auf ein Vorderknie nieder, ein Pferdeknicks.',
  ),
  PferdeSfDef(
    id: 'psf_kommen_auf_signal',
    name: 'Kommen auf Signal',
    typ: PferdeSfTyp.allgemein,
    kurzwirkung: 'Kommt auf Name oder Pfiff zu seinem Herrn.',
  ),
  PferdeSfDef(
    id: 'psf_kreisel',
    name: 'Kreisel',
    typ: PferdeSfTyp.speziell,
    kampf: true,
    kurzwirkung: 'Dreht sich kraftvoll um die Hinterhand und drängt Gegner ab.',
    manoever: PferdemanoeverDef(
      reitAtErschwernis: 5,
      dk: 'N',
      hinweis:
          'Fußkämpfer weichen eine DK zurück und stürzen ohne KK-Probe +GS; '
          'bis zu 4 Kampfrunden, der Reiter handelt nicht selbst.',
    ),
  ),
  PferdeSfDef(
    id: 'psf_lanzengang',
    name: 'Lanzengang',
    typ: PferdeSfTyp.speziell,
    kurzwirkung:
        'Trägt den Lanzenangriff mit: Reiten-Probe und Lanzen-AT je 3 Punkte '
        'erleichtert (Reiter braucht Turnier- oder Kriegsreiterei).',
  ),
  PferdeSfDef(
    id: 'psf_lenken_ohne_zuegel',
    name: 'Lenken ohne Zügel',
    typ: PferdeSfTyp.speziell,
    kurzwirkung:
        'Folgt Gewicht und Schenkeln; Reiten, Zauber und Fernkampf ohne '
        'Zusatzerschwernis für freie Hände. Nicht im Nahkampf.',
  ),
  PferdeSfDef(
    id: 'psf_mehrspaennig',
    name: 'Mehrspännig',
    typ: PferdeSfTyp.speziell,
    kurzwirkung: 'Läuft mit mehreren Tieren vor dem Wagen.',
  ),
  PferdeSfDef(
    id: 'psf_passage',
    name: 'Passage',
    typ: PferdeSfTyp.speziell,
    kurzwirkung: 'Schwebender, verlangsamter Trab.',
  ),
  PferdeSfDef(
    id: 'psf_piaffe',
    name: 'Piaffe',
    typ: PferdeSfTyp.speziell,
    kurzwirkung: 'Trab auf der Stelle.',
  ),
  PferdeSfDef(
    id: 'psf_rastullahs_schwingen',
    name: 'Rastullahs Schwingen',
    typ: PferdeSfTyp.speziell,
    kurzwirkung:
        'Letzte Reserven: bis zu 3 SR zusätzlicher Galopp, die erste mit '
        'GS +1; danach droht Zusammenbruch.',
  ),
  PferdeSfDef(
    id: 'psf_reitertreue',
    name: 'Reitertreue',
    typ: PferdeSfTyp.speziell,
    kurzwirkung: 'Lässt nur seinen Herrn aufsitzen; gegenüber Fremden LO −10.',
  ),
  PferdeSfDef(
    id: 'psf_schrecksicher',
    name: 'Schrecksicher',
    typ: PferdeSfTyp.speziell,
    kurzwirkung:
        'Erschrickt nicht vor Lärm oder Flattern; passende Proben 3 Punkte '
        'weniger erschwert.',
    nervositaetErschwert: true,
  ),
  PferdeSfDef(
    id: 'psf_seitengaenge',
    name: 'Seitengänge',
    typ: PferdeSfTyp.allgemein,
    kurzwirkung: 'Bewegt sich seitwärts.',
  ),
  PferdeSfDef(
    id: 'psf_separieren',
    name: 'Separieren',
    typ: PferdeSfTyp.speziell,
    kurzwirkung:
        'Hilft bei der Herdenarbeit mit; passende Proben 5 Punkte weniger '
        'erschwert.',
  ),
  PferdeSfDef(
    id: 'psf_sprungsicherheit',
    name: 'Sprungsicherheit',
    typ: PferdeSfTyp.speziell,
    kurzwirkung:
        'Überwindet Hindernisse sicher; Reiten-Probe beim Sprung 3 Punkte '
        'weniger erschwert.',
  ),
  PferdeSfDef(
    id: 'psf_steigen',
    name: 'Steigen',
    typ: PferdeSfTyp.allgemein,
    kampf: true,
    kurzwirkung: 'Steigt auf Kommando und schlägt mit den Vorderhufen.',
    manoever: PferdemanoeverDef(
      reitAtErschwernis: 1,
      dk: 'H',
      hinweis: 'Gegner vor dem Pferd; Kamele erreichen DK HN.',
    ),
  ),
  PferdeSfDef(
    id: 'psf_stille_wacht',
    name: 'Stille Wacht',
    typ: PferdeSfTyp.speziell,
    kurzwirkung:
        'Weckt seinen Herrn lautlos, wenn sich Fremde nähern '
        '(Sinnenschärfe 12, direkt mit W20).',
  ),
  PferdeSfDef(
    id: 'psf_stillstand',
    name: 'Stillstand',
    typ: PferdeSfTyp.allgemein,
    kurzwirkung:
        'Steht auf Kommando still; Zauber und Schüsse vom Rücken ohne '
        'Zusatzerschwernis.',
    nervositaetErschwert: true,
  ),
  PferdeSfDef(
    id: 'psf_stopp',
    name: 'Stopp',
    typ: PferdeSfTyp.allgemein,
    kurzwirkung: 'Hält aus jeder Gangart abrupt an.',
  ),
  PferdeSfDef(
    id: 'psf_trampeln',
    name: 'Trampeln',
    typ: PferdeSfTyp.speziell,
    kampf: true,
    kurzwirkung: 'Tritt gezielt auf einen am Boden liegenden Gegner.',
    manoever: PferdemanoeverDef(
      reitAtErschwernis: 5,
      dk: 'H',
      hinweis:
          'Nur gegen Liegende; TP des Pferdes doppelt, Ausweichen nur mit '
          'einem Ausweichen-Manöver +8.',
    ),
  ),
  PferdeSfDef(
    id: 'psf_wacht',
    name: 'Wacht',
    typ: PferdeSfTyp.allgemein,
    kurzwirkung:
        'Wiehert, wenn sich Fremde nähern (Sinnenschärfe 12, direkt mit W20).',
  ),
  PferdeSfDef(
    id: 'psf_weiches_gangwerk',
    name: 'Weiches Gangwerk',
    typ: PferdeSfTyp.speziell,
    kurzwirkung:
        'Besonders weich zu sitzende Gänge; in diesen Gängen GS je −1.',
  ),
  PferdeSfDef(
    id: 'psf_zaehlen',
    name: 'Zählen',
    typ: PferdeSfTyp.speziell,
    kurzwirkung: 'Klopft auf Signal, als würde es zählen.',
  ),
];

/// Unarten von Reit- und Lasttieren (ZBA S. 37 f.).
const List<PferdeUnartDef> kPferdeUnarten = <PferdeUnartDef>[
  PferdeUnartDef(
    id: 'punart_aufblasen',
    name: 'Aufblasen',
    kurzwirkung:
        'Bläht sich beim Satteln auf; der Gurt muss nachgezogen werden.',
  ),
  PferdeUnartDef(
    id: 'punart_bissigkeit',
    name: 'Bissigkeit',
    lo: -1,
    kurzwirkung: 'Versucht Menschen in seiner Nähe zu beißen.',
  ),
  PferdeUnartDef(
    id: 'punart_buckeln',
    name: 'Buckeln',
    kurzwirkung: 'Buckelt bei energischen Hilfen; zusätzliche Reiten-Proben.',
  ),
  PferdeUnartDef(
    id: 'punart_knabbern',
    name: 'Knabbern',
    kurzwirkung: 'Kaut alles an; Unterhalt 2 Silber im Monat teurer.',
  ),
  PferdeUnartDef(
    id: 'punart_kopfscheu',
    name: 'Kopfscheu',
    kurzwirkung: 'Schwer aufzuzäumen; weicht dabei mit Wert 10 aus.',
  ),
  PferdeUnartDef(
    id: 'punart_laut',
    name: 'Laut',
    kurzwirkung: 'Wiehert oder schreit besonders laut und oft.',
  ),
  PferdeUnartDef(
    id: 'punart_sattelzwang',
    name: 'Sattelzwang',
    lo: -2,
    kurzwirkung: 'Verweigert Satteln und Anschirren; weicht dabei mit 10 aus.',
  ),
  PferdeUnartDef(
    id: 'punart_scheu',
    name: 'Scheu',
    lo: -2,
    kurzwirkung: 'Läuft bei jeder Gelegenheit davon.',
  ),
  PferdeUnartDef(
    id: 'punart_spucken',
    name: 'Spucken',
    kurzwirkung: 'Spuckt Fremde an (Kamele).',
  ),
  PferdeUnartDef(
    id: 'punart_treten',
    name: 'Treten',
    lo: -1,
    kurzwirkung: 'Schlägt bei kleinster Missstimmung aus.',
  ),
];

/// Pferde-Sonderfertigkeit zu [id]; `null` für unbekannte IDs.
PferdeSfDef? pferdeSf(String id) {
  for (final sf in kPferdeSonderfertigkeiten) {
    if (sf.id == id) {
      return sf;
    }
  }
  return null;
}

/// Unart zu [id]; `null` für unbekannte IDs.
PferdeUnartDef? pferdeUnart(String id) {
  for (final unart in kPferdeUnarten) {
    if (unart.id == id) {
      return unart;
    }
  }
  return null;
}
