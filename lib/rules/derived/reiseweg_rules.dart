import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';

// Reisewege zwischen Stationen: welche Anfrage an Avesmaps eine Etappe
// meint und wie das Ergebnis lesbar wird. Gerechnet wird bei Avesmaps.

/// Die Anfrage für den Weg von [von] nach [nach] mit der [anreise] (sonst
/// die Vorgabe), oder `null`, wenn einer der beiden Orte keine
/// Avesmaps-Kennung hat oder beide derselbe Ort sind.
AvesmapsRoutenAnfrage? reisewegAnfrage(
  HeroReiseStation? von,
  HeroReiseStation nach, {
  HeroReiseAnreise? anreise,
}) {
  if (von == null) return null;
  final vonId = von.ortId.trim();
  final nachId = nach.ortId.trim();
  if (vonId.isEmpty || nachId.isEmpty || vonId == nachId) return null;
  final wahl = anreise ?? nach.anreise;
  return AvesmapsRoutenAnfrage(
    vonId: vonId,
    nachId: nachId,
    wege: wahl?.wege ?? const <String>[],
    optimierung: wahl?.optimierung ?? kReiseOptimierungSchnellste,
  );
}

/// Die Anfrage für die [etappe] mit der an ihr gespeicherten Anreise.
AvesmapsRoutenAnfrage? reisewegAnfrageFuer(ReiseEtappe etappe) =>
    reisewegAnfrage(etappe.vorherige, etappe.station);

/// Der gemerkte Weg der [etappe] aus [wege], oder `null`.
AvesmapsRoute? reisewegFuer(
  ReiseEtappe etappe,
  Map<String, AvesmapsRoute> wege,
) {
  final anfrage = reisewegAnfrageFuer(etappe);
  return anfrage == null ? null : wege[anfrage.schluessel];
}

/// Die Anfragen aller [etappen], ohne doppelte.
List<AvesmapsRoutenAnfrage> reisewegAnfragen(List<ReiseEtappe> etappen) =>
    <AvesmapsRoutenAnfrage>{
      for (final etappe in etappen) ?reisewegAnfrageFuer(etappe),
    }.toList(growable: false);

/// Die Anreise zu [wege] und [optimierung], oder `null` für die Vorgabe
/// (alle Wege, schnellste).
HeroReiseAnreise? anreiseAus({
  required Iterable<String> wege,
  required String optimierung,
}) {
  final anfrage = AvesmapsRoutenAnfrage(
    vonId: '',
    nachId: '',
    wege: wege,
    optimierung: optimierung,
  );
  if (anfrage.alleWege && anfrage.optimierung == kReiseOptimierungSchnellste) {
    return null;
  }
  return HeroReiseAnreise(
    wege: anfrage.wege,
    optimierung: anfrage.optimierung == kReiseOptimierungSchnellste
        ? ''
        : anfrage.optimierung,
  );
}

/// Die erlaubten Wegarten der [anreise] (bekannte Werte; ohne Wahl alle).
Set<String> anreiseWege(HeroReiseAnreise? anreise) {
  final bekannt = <String>{
    for (final art in anreise?.wege ?? const <String>[])
      if (kReiseWegArten.contains(art)) art,
  };
  return bekannt.isEmpty ? kReiseWegArten.toSet() : bekannt;
}

/// Die Optimierung der [anreise] (`schnellste` ohne Wahl).
String anreiseOptimierung(HeroReiseAnreise? anreise) =>
    anreise?.optimierung == kReiseOptimierungKuerzeste
    ? kReiseOptimierungKuerzeste
    : kReiseOptimierungSchnellste;

/// Bezeichnung einer Wegart für Schalter und Texte.
String reiseWegArtName(String art) => switch (art) {
  kReiseWegLand => 'Land',
  kReiseWegFluss => 'Fluss',
  kReiseWegSee => 'See',
  _ => art,
};

/// Kurztext zur Anreise, etwa „Schnellster Weg“ oder „Kürzester Weg · nur
/// Land“.
String anreiseText(HeroReiseAnreise? anreise) {
  final art = anreiseOptimierung(anreise) == kReiseOptimierungKuerzeste
      ? 'Kürzester Weg'
      : 'Schnellster Weg';
  final wege = anreiseWege(anreise);
  if (wege.length == kReiseWegArten.length) return art;
  final namen = <String>[
    for (final w in kReiseWegArten)
      if (wege.contains(w)) reiseWegArtName(w),
  ];
  return '$art · nur ${namen.join(' und ')}';
}

/// Lesbare Wegarten eines Wegs nach Anteil an der Strecke, höchstens [limit];
/// unbekannte Arten und das Umsteigen entfallen.
List<String> reisewegArten(AvesmapsRoute weg, {int limit = 3}) {
  final meilen = <String, double>{};
  for (final etappe in weg.etappen) {
    final name = switch (etappe.art.toLowerCase()) {
      'reichsstrasse' => 'Reichsstraße',
      'strasse' => 'Straße',
      'weg' => 'Weg',
      'pfad' => 'Pfad',
      'flussweg' => 'Fluss',
      'seeweg' => 'See',
      'querfeldein' => 'querfeldein',
      _ => null,
    };
    if (name == null) continue;
    meilen[name] = (meilen[name] ?? 0) + etappe.meilen;
  }
  final reihe = meilen.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return <String>[for (final e in reihe.take(limit)) e.key];
}

/// Ob der Weg zu Wasser führt (Flusssegler oder Schiff).
bool reisewegZuWasser(AvesmapsRoute weg) => weg.etappen.any((e) {
  final art = e.art.toLowerCase();
  return art == 'flussweg' || art == 'seeweg';
});

/// Zusammenfassung eines Wegs: „341 Meilen · 5¾ Reisetage · Fluss, Straße“;
/// ohne Weg ein Satz zum Grund.
String reisewegText(AvesmapsRoute weg) {
  if (!weg.gefunden) {
    return switch (weg.grund) {
      'gesperrt' => 'Der Weg ist gesperrt.',
      AvesmapsRoute.grundOrtUnbekannt => 'Avesmaps kennt einen der Orte nicht.',
      _ => 'Avesmaps findet keinen Weg mit diesen Vorgaben.',
    };
  }
  final arten = reisewegArten(weg);
  return <String>[
    '${weg.meilen.round()} Meilen',
    formatiereReisezeit(weg),
    if (arten.isNotEmpty) arten.join(', '),
  ].join(' · ');
}

/// Eine Vorgabe zum Vergleichen im Etappendialog.
class ReisewegVariante {
  /// Erstellt die Variante.
  const ReisewegVariante({
    required this.name,
    required this.wege,
    required this.optimierung,
  });

  /// Anzeigename.
  final String name;

  /// Erlaubte Wegarten.
  final Set<String> wege;

  /// Optimierung.
  final String optimierung;
}

/// Die Varianten, die „Vergleichen“ holt.
const List<ReisewegVariante> kReisewegVarianten = <ReisewegVariante>[
  ReisewegVariante(
    name: 'Schnellster Weg',
    wege: <String>{kReiseWegLand, kReiseWegFluss, kReiseWegSee},
    optimierung: kReiseOptimierungSchnellste,
  ),
  ReisewegVariante(
    name: 'Nur über Land',
    wege: <String>{kReiseWegLand},
    optimierung: kReiseOptimierungSchnellste,
  ),
  ReisewegVariante(
    name: 'Kürzester Weg',
    wege: <String>{kReiseWegLand, kReiseWegFluss, kReiseWegSee},
    optimierung: kReiseOptimierungKuerzeste,
  ),
];
