/// Rechnen mit TP-Angaben in DSA-Schreibweise („1W6+4“, „2W6“, „1W+2 (A)“).
library;

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

final RegExp _tpAusdruck = RegExp(
  r'^\s*(\d*\s*[Ww]\s*\d*)\s*(?:([+\-])\s*(\d+))?(.*)$',
);

/// Erhöht die TP-Angabe [tp] um [zuschlag] Punkte.
///
/// Erkennt die Würfelangabe samt festem Anteil und rechnet den Zuschlag
/// hinein (`'2W6+1'` und 2 ergeben `'2W6+3'`). Text hinter dem festen Anteil
/// bleibt stehen. Lässt sich [tp] nicht lesen, wird der Zuschlag angehängt
/// (`'Huf +2'`), damit er sichtbar bleibt statt verloren zu gehen.
String tpMitZuschlag(String tp, int zuschlag) {
  if (zuschlag == 0) {
    return tp;
  }
  final treffer = _tpAusdruck.firstMatch(tp);
  if (treffer == null) {
    final vorzeichen = zuschlag > 0 ? '+' : '';
    return '${tp.trim()} $vorzeichen$zuschlag'.trim();
  }
  final wuerfel = treffer.group(1)!.replaceAll(' ', '');
  final betrag = int.tryParse(treffer.group(3) ?? '') ?? 0;
  final fest = treffer.group(2) == '-' ? -betrag : betrag;
  final summe = fest + zuschlag;
  final rest = treffer.group(4)!;
  final festText = switch (summe) {
    0 => '',
    > 0 => '+$summe',
    _ => '$summe',
  };
  return '$wuerfel$festText$rest';
}

final RegExp _tpWuerfel = RegExp(
  r'^\s*(\d*)\s*[Ww]\s*(\d*)\s*(?:([+\-])\s*(\d+))?\s*(?:\(.*\))?\s*$',
);

/// Liest eine TP-Angabe als Würfelausdruck, oder `null`, wenn sie sich nicht
/// lesen lässt.
///
/// Erkennt „1W6“, „2W6+3“, „W6-1“ und „1W+2“ (ohne Seitenzahl gilt der W6,
/// wie in der DSA-Schreibweise); ein Zusatz in Klammern hinter dem Ausdruck
/// („(A)“) wird übergangen. Freitext wie „Huf +2“ oder eine leere Angabe
/// ergeben `null`, damit niemand auf geratene Würfel würfelt.
DiceSpec? tpAusdruckZuWuerfel(String tp) {
  final treffer = _tpWuerfel.firstMatch(tp);
  if (treffer == null) return null;
  final anzahl = treffer.group(1)!.isEmpty ? 1 : int.parse(treffer.group(1)!);
  final seiten = treffer.group(2)!.isEmpty ? 6 : int.parse(treffer.group(2)!);
  if (anzahl < 1 || seiten < 2) return null;
  final betrag = int.tryParse(treffer.group(4) ?? '') ?? 0;
  final fest = treffer.group(3) == '-' ? -betrag : betrag;
  return DiceSpec(count: anzahl, sides: seiten, modifier: fest);
}
