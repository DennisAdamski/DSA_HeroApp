/// Rechnen mit TP-Angaben in DSA-Schreibweise („1W6+4“, „2W6“, „1W+2 (A)“).
library;

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
