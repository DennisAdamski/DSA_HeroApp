/// Gemeinsames Ergebnisformat für erklärbare Regelberechnungen (ARCH-04).
///
/// Eine [Herleitung] ist eine geordnete Folge additiver [HerleitungsSchritt]e.
/// Ihr [Herleitung.wert] ist **per Konstruktion** die Summe aller Schritte:
/// Rundungen, Begrenzungen und Vervielfachungen erscheinen deshalb als eigene
/// Schritte mit dem Betrag, um den sie das Zwischenergebnis verändern. So
/// kann die Oberfläche die Herleitung anzeigen, ohne selbst nachzurechnen,
/// und der angezeigte Wert ist immer der tatsächlich verwendete.
library;

/// Fachliche Art eines Herleitungsschritts.
///
/// Die Oberfläche gruppiert und beschriftet danach; die Rechnung selbst
/// unterscheidet die Arten nicht, sie summiert nur.
enum HerleitungsArt {
  /// Grundwert aus einer Formel über Eigenschaften oder einer festen Basis.
  grundwert,

  /// Mit AP zugekaufte Punkte.
  zukauf,

  /// Anteil aus Heldenstufe oder Level.
  stufe,

  /// Additiver Modifikator aus einer benannten Quelle.
  modifikator,

  /// Wirkung einer Sonderfertigkeit.
  sonderfertigkeit,

  /// Wirkung eines laufenden Zaubers.
  zauber,

  /// Ausgleich durch eine Regelgrenze (Untergrenze, Höchstwert).
  begrenzung,
}

/// Ein additiver Schritt einer [Herleitung].
class HerleitungsSchritt {
  /// Erzeugt einen Schritt; [betrag] ist der Beitrag zum Endwert.
  const HerleitungsSchritt({
    required this.bezeichnung,
    required this.betrag,
    required this.art,
    this.formel,
    this.quelle,
    this.bedingung,
  });

  /// Kurzer Anzeigename, etwa „Grundwert“ oder „Rüstung (BE)“.
  final String bezeichnung;

  /// Beitrag zum Endwert; die Summe aller Beträge ist der Endwert.
  final int betrag;

  /// Fachliche Einordnung für Darstellung und Tests.
  final HerleitungsArt art;

  /// Rechenweg mit eingesetzten Werten, etwa „(KO 12 + KO 12 + KK 13) / 2“.
  final String? formel;

  /// Herkunft des Beitrags, etwa „Rasse“, „Vorteil Zäher Hund“ oder
  /// „Inventar“.
  final String? quelle;

  /// Voraussetzung, unter der der Schritt gilt, etwa „Axxeleratus aktiv“.
  final String? bedingung;

  @override
  String toString() =>
      'HerleitungsSchritt($bezeichnung: $betrag, ${art.name}'
      '${quelle == null ? '' : ', $quelle'})';
}

/// Erklärbares Ergebnis einer Regelberechnung.
class Herleitung {
  /// Erzeugt die Herleitung für [bezeichnung] aus geordneten [schritte]n.
  Herleitung({
    required this.bezeichnung,
    required List<HerleitungsSchritt> schritte,
  }) : schritte = List<HerleitungsSchritt>.unmodifiable(schritte);

  /// Anzeigename des hergeleiteten Werts, etwa „LeP“.
  final String bezeichnung;

  /// Alle Schritte in Rechenreihenfolge, auch solche mit Betrag 0.
  final List<HerleitungsSchritt> schritte;

  /// Endwert: die Summe aller Schritte.
  int get wert => summeDer(schritte);

  /// Schritte, die angezeigt werden sollten: alle mit Betrag ungleich 0
  /// sowie die Grundwerte, damit die Ausgangsbasis immer sichtbar ist.
  List<HerleitungsSchritt> get sichtbareSchritte => schritte
      .where((s) => s.betrag != 0 || s.art == HerleitungsArt.grundwert)
      .toList(growable: false);

  /// Summe der Schritte einer bestimmten [art].
  int summeVon(HerleitungsArt art) =>
      summeDer(schritte.where((schritt) => schritt.art == art));

  @override
  String toString() => 'Herleitung($bezeichnung = $wert, $schritte)';
}

/// Summiert die Beträge beliebiger [schritte].
int summeDer(Iterable<HerleitungsSchritt> schritte) {
  var summe = 0;
  for (final schritt in schritte) {
    summe += schritt.betrag;
  }
  return summe;
}

/// Ergänzt [schritte] um einen Begrenzungsschritt, wenn ihre Summe unter
/// [untergrenze] liegt, und gibt die Liste zurück.
///
/// Der Schritt gleicht genau die Differenz aus, so bleibt der Endwert die
/// Summe aller Schritte.
List<HerleitungsSchritt> mitUntergrenze(
  List<HerleitungsSchritt> schritte, {
  required int untergrenze,
  required String bezeichnung,
}) {
  final summe = summeDer(schritte);
  if (summe >= untergrenze) {
    return schritte;
  }
  return <HerleitungsSchritt>[
    ...schritte,
    HerleitungsSchritt(
      bezeichnung: bezeichnung,
      betrag: untergrenze - summe,
      art: HerleitungsArt.begrenzung,
    ),
  ];
}
