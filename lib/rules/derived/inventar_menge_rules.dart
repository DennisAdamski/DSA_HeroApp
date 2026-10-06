// Strukturierte Menge eines Inventareintrags (ARCH-03).
//
// `menge` ist die Stückzahl, `anzahl` ihr Text. Diese Version schreibt beide
// immer gemeinsam (`mitInventarMenge`). Ältere Versionen kennen nur `anzahl`;
// eine Version vom 29.09. bis 05.10.2026 bewahrt `menge` als unbekanntes Feld
// und ändert allein `anzahl`. Passen beide nicht mehr zusammen, hat also eine
// ältere Version die Anzahl geändert: Dann gilt `anzahl`, und die Abweichung
// wird angezeigt, aber nie still aufgelöst (Entscheidung vom 06.10.2026).
// Leere oder freie Angaben („ein paar“) bleiben offen; geraten wird nie.

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';

/// Wie die Menge eines Eintrags zu lesen ist.
class InventarMengenstand {
  /// [wirksam] ist `null`, wenn die Menge offen ist.
  const InventarMengenstand({this.wirksam, this.ueberholteMenge});

  /// Stückzahl, mit der Regeln rechnen; `null` bei offener Menge.
  final int? wirksam;

  /// Gespeicherte `menge`, die eine ältere Version über `anzahl` geändert
  /// hat; `null`, wenn beide zusammenpassen oder keine `menge` vorliegt.
  final int? ueberholteMenge;

  /// Ob die Menge offen ist (leer oder Freitext).
  bool get offen => wirksam == null;

  /// Ob eine ältere Version die Anzahl abweichend von `menge` geändert hat.
  bool get abweichend => ueberholteMenge != null;
}

/// Liest [anzahl] als rein ganzzahlige, nicht negative Stückzahl.
///
/// Vorzeichen, Einheiten und Freitext ergeben `null`.
int? inventarZahlAusText(String anzahl) {
  final text = anzahl.trim();
  if (!RegExp(r'^\d+$').hasMatch(text)) {
    return null;
  }
  return int.tryParse(text);
}

/// Mengenstand von [e] nach den Regeln oben.
InventarMengenstand inventarMengenstand(HeroInventoryEntry e) {
  final textZahl = inventarZahlAusText(e.anzahl);
  final menge = e.menge;
  if (menge == null || textZahl == menge) {
    return InventarMengenstand(wirksam: textZahl);
  }
  return InventarMengenstand(wirksam: textZahl, ueberholteMenge: menge);
}

/// Stückzahl, mit der Regeln rechnen, oder `null` bei offener Menge.
int? wirksameInventarMenge(HeroInventoryEntry e) =>
    inventarMengenstand(e).wirksam;

/// Derselbe Eintrag mit der Stückzahl [menge]; `anzahl` zeigt sie als Text.
HeroInventoryEntry mitInventarMenge(HeroInventoryEntry e, int menge) {
  return e.copyWith(menge: menge, anzahl: '$menge');
}

/// Übernimmt die im Editor eingegebene Anzahl [text].
///
/// Eine reine Zahl wird zur Menge, alles andere bleibt offener Text ohne
/// `menge`. Ist [text] unverändert und passt zur Menge, kommt [e] selbst
/// zurück; eine Abweichung gilt mit dem Speichern als bestätigt.
HeroInventoryEntry mitInventarMengeAusText(HeroInventoryEntry e, String text) {
  final neu = text.trim();
  if (neu == e.anzahl && !inventarMengenstand(e).abweichend) {
    return e;
  }
  final zahl = inventarZahlAusText(neu);
  if (zahl == null) {
    return e.copyWith(anzahl: neu, menge: null);
  }
  return mitInventarMenge(e, zahl);
}

/// Überführt rein ganzzahlige `anzahl`-Angaben ohne `menge` in die Menge.
///
/// Läuft nur beim Speichern (`HeroActions.saveHero`), nie beim Laden, damit
/// die Inhalts-Hashes der Bestandshelden stehen bleiben. Offene und
/// abweichende Einträge bleiben unverändert. Gibt dieselbe Liste zurück, wenn
/// nichts zu ändern ist.
List<HeroInventoryEntry> ueberfuehreInventarMengen(
  List<HeroInventoryEntry> eintraege,
) {
  var geaendert = false;
  final ergebnis = <HeroInventoryEntry>[];
  for (final eintrag in eintraege) {
    final zahl = inventarZahlAusText(eintrag.anzahl);
    if (eintrag.menge != null || zahl == null) {
      ergebnis.add(eintrag);
      continue;
    }
    ergebnis.add(eintrag.copyWith(menge: zahl));
    geaendert = true;
  }
  return geaendert
      ? List<HeroInventoryEntry>.unmodifiable(ergebnis)
      : eintraege;
}
