import 'package:dsa_heldenverwaltung/domain/hero_spielansicht.dart';

/// Die Kacheln der Spielansicht und was jede erlaubt (SPIEL-07).
///
/// Die Reihenfolge der Werte ist die Standardanordnung: zuerst, was am Tisch
/// ständig gebraucht wird, dann Kampf, Effekte und Zustand, zuletzt, was man
/// nachschlägt. Breiten, Ausblenden und Einklappen legt die Kachel selbst fest;
/// gespeicherte Wünsche, die sie nicht erlaubt, fallen beim Auflösen weg.
enum KartoSpielkachelArt {
  /// Farbige Schnellaktionen und zuletzt gewürfelte Proben.
  schnellaktionen(
    'Schnellaktionen',
    breiten: SpielkachelBreite.values,
    standard: SpielkachelBreite.voll,
    gewicht: 200,
    ausblendbar: false,
    einklappbar: false,
  ),

  /// LeP, AsP, KaP und Ausdauer.
  ressourcen(
    'Ressourcen',
    breiten: SpielkachelBreite.values,
    standard: SpielkachelBreite.mittel,
    gewicht: 120,
    ausblendbar: false,
    einklappbar: false,
  ),

  /// Häufige Proben (Favoriten).
  proben(
    'Häufige Proben',
    breiten: SpielkachelBreite.values,
    standard: SpielkachelBreite.mittel,
    gewicht: 200,
  ),

  /// Eigenschaften als Würfelleiste.
  eigenschaften(
    'Eigenschaften',
    breiten: <SpielkachelBreite>[
      SpielkachelBreite.mittel,
      SpielkachelBreite.voll,
    ],
    standard: SpielkachelBreite.mittel,
    gewicht: 140,
  ),

  /// Kampfproben und Gefecht.
  kampf(
    'Kampf',
    breiten: <SpielkachelBreite>[
      SpielkachelBreite.schmal,
      SpielkachelBreite.mittel,
    ],
    standard: SpielkachelBreite.schmal,
    gewicht: 260,
  ),

  /// Laufende Zauber und Effekte.
  effekte(
    'Aktive Effekte',
    breiten: <SpielkachelBreite>[
      SpielkachelBreite.schmal,
      SpielkachelBreite.mittel,
    ],
    standard: SpielkachelBreite.schmal,
    gewicht: 200,
  ),

  /// Wunden, Erschöpfung und weitere Zustände.
  zustand(
    'Zustand',
    breiten: <SpielkachelBreite>[
      SpielkachelBreite.schmal,
      SpielkachelBreite.mittel,
    ],
    standard: SpielkachelBreite.schmal,
    gewicht: 240,
  ),

  /// Begleiter mit laufenden Werten; nur mit Begleitern vorhanden.
  begleiter(
    'Begleiter',
    breiten: SpielkachelBreite.values,
    standard: SpielkachelBreite.schmal,
    gewicht: 220,
  ),

  /// Geld und Verbrauchsgegenstände.
  dabei(
    'Dabei',
    breiten: <SpielkachelBreite>[
      SpielkachelBreite.schmal,
      SpielkachelBreite.mittel,
    ],
    standard: SpielkachelBreite.schmal,
    gewicht: 280,
  ),

  /// Laufendes Abenteuer mit Standort, Notizen und Personen.
  abenteuer(
    'Abenteuer',
    breiten: <SpielkachelBreite>[
      SpielkachelBreite.mittel,
      SpielkachelBreite.voll,
    ],
    standard: SpielkachelBreite.mittel,
    gewicht: 360,
  ),

  /// Vor- und Nachteile.
  merkmale(
    'Vor- und Nachteile',
    breiten: SpielkachelBreite.values,
    standard: SpielkachelBreite.mittel,
    gewicht: 300,
  ),

  /// Die letzten Würfe.
  protokoll(
    'Würfelprotokoll',
    breiten: SpielkachelBreite.values,
    standard: SpielkachelBreite.mittel,
    gewicht: 300,
  );

  const KartoSpielkachelArt(
    this.titel, {
    required this.breiten,
    required this.standard,
    required this.gewicht,
    this.ausblendbar = true,
    this.einklappbar = true,
  });

  /// Anzeigename im Anordnen-Modus.
  final String titel;

  /// Erlaubte Breiten, schmal vor breit.
  final List<SpielkachelBreite> breiten;

  /// Breite ohne gespeicherten Wunsch.
  final SpielkachelBreite standard;

  /// Richtwert für die Höhe in dp; nur das Verhältnis der Kacheln zählt.
  ///
  /// Das Raster wählt die Spalte einer Kachel aus diesen Gewichten und nicht
  /// aus der echten Höhe. So bleibt die Anordnung stabil, wenn eine Kachel
  /// eingeklappt wird oder ihr Inhalt wächst. Das Gewicht wird nicht
  /// gespeichert.
  final double gewicht;

  /// Ob die Kachel von der Seite genommen werden darf.
  final bool ausblendbar;

  /// Ob die Kachel auf ihren Kopf eingeklappt werden darf.
  final bool einklappbar;

  /// Gespeicherte Kennung; entspricht dem Namen.
  String get id => name;

  /// Kachel zur gespeicherten [id] oder `null`.
  static KartoSpielkachelArt? zurId(String id) =>
      KartoSpielkachelArt.values.asNameMap()[id];
}

/// Wirksame Einstellung einer Kachel nach dem Auflösen.
class KartoSpielkachel {
  /// Kachel [art] mit wirksamen Werten.
  const KartoSpielkachel({
    required this.art,
    required this.breite,
    this.ausgeblendet = false,
    this.eingeklappt = false,
  });

  /// Welche Kachel.
  final KartoSpielkachelArt art;

  /// Wirksame, erlaubte Breite.
  final SpielkachelBreite breite;

  /// Ob die Kachel ausgeblendet ist (nur bei ausblendbaren Kacheln).
  final bool ausgeblendet;

  /// Ob die Kachel eingeklappt ist (nur bei einklappbaren Kacheln).
  final bool eingeklappt;

  KartoSpielkachel copyWith({
    SpielkachelBreite? breite,
    bool? ausgeblendet,
    bool? eingeklappt,
  }) {
    return KartoSpielkachel(
      art: art,
      breite: breite ?? this.breite,
      ausgeblendet: ausgeblendet ?? this.ausgeblendet,
      eingeklappt: eingeklappt ?? this.eingeklappt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KartoSpielkachel &&
      other.art == art &&
      other.breite == breite &&
      other.ausgeblendet == ausgeblendet &&
      other.eingeklappt == eingeklappt;

  @override
  int get hashCode => Object.hash(art, breite, ausgeblendet, eingeklappt);
}

/// Löst die gespeicherte Anordnung gegen die [verfuegbar]en Kacheln auf.
///
/// Gespeicherte Kacheln stehen in ihrer Reihenfolge. Eine verfügbare Kachel
/// ohne Eintrag (neu in dieser Version oder nie angepasst) rückt hinter die
/// letzte Kachel, die ihr in der Standardanordnung vorausgeht. Unbekannte
/// oder nicht verfügbare IDs werden übergangen, bleiben aber gespeichert
/// (siehe [schreibeSpielansicht]). Eine nicht erlaubte Breite fällt auf den
/// Standard zurück; was eine Kachel nicht erlaubt, gilt als aus.
List<KartoSpielkachel> loeseSpielansichtAuf(
  HeroSpielansicht? gespeichert, {
  required Set<KartoSpielkachelArt> verfuegbar,
}) {
  KartoSpielkachel aufgeloest(
    KartoSpielkachelArt art,
    HeroSpielkachel? eintrag,
  ) {
    final wunsch = eintrag?.breite;
    return KartoSpielkachel(
      art: art,
      breite: wunsch != null && art.breiten.contains(wunsch)
          ? wunsch
          : art.standard,
      ausgeblendet: art.ausblendbar && (eintrag?.ausgeblendet ?? false),
      eingeklappt: art.einklappbar && (eintrag?.eingeklappt ?? false),
    );
  }

  final ergebnis = <KartoSpielkachel>[];
  for (final eintrag in gespeichert?.kacheln ?? const <HeroSpielkachel>[]) {
    final art = KartoSpielkachelArt.zurId(eintrag.id);
    if (art == null || !verfuegbar.contains(art)) continue;
    ergebnis.add(aufgeloest(art, eintrag));
  }
  for (final art in KartoSpielkachelArt.values) {
    if (!verfuegbar.contains(art) || ergebnis.any((k) => k.art == art)) {
      continue;
    }
    var stelle = 0;
    for (var i = 0; i < ergebnis.length; i++) {
      if (ergebnis[i].art.index < art.index) stelle = i + 1;
    }
    ergebnis.insert(stelle, aufgeloest(art, null));
  }
  return List<KartoSpielkachel>.unmodifiable(ergebnis);
}

/// Schreibt die aufgelösten [kacheln] zurück in eine [HeroSpielansicht].
///
/// Bestehende Einträge behalten ihre unbekannten Felder (`copyWith`).
/// Einträge, die [kacheln] nicht enthält (unbekannte IDs, ein gerade nicht
/// vorhandener Begleiter), bleiben hinter ihrem bisherigen Vorgänger stehen.
/// Die Standardbreite wird nicht geschrieben, damit die Kachel einer
/// späteren Änderung des Standards folgt.
HeroSpielansicht schreibeSpielansicht(
  List<KartoSpielkachel> kacheln, {
  required HeroSpielansicht? basis,
}) {
  final bisher = basis?.kacheln ?? const <HeroSpielkachel>[];
  final neu = <HeroSpielkachel>[
    for (final kachel in kacheln)
      (basis?.kachel(kachel.art.id) ?? HeroSpielkachel(id: kachel.art.id))
          .copyWith(
            breite: kachel.breite == kachel.art.standard ? null : kachel.breite,
            ausgeblendet: kachel.ausgeblendet,
            eingeklappt: kachel.eingeklappt,
          ),
  ];
  final enthalten = {for (final kachel in kacheln) kachel.art.id};
  for (var i = 0; i < bisher.length; i++) {
    final eintrag = bisher[i];
    if (enthalten.contains(eintrag.id)) continue;
    var stelle = 0;
    for (var j = i - 1; j >= 0; j--) {
      final vorgaenger = neu.indexWhere((k) => k.id == bisher[j].id);
      if (vorgaenger >= 0) {
        stelle = vorgaenger + 1;
        break;
      }
    }
    neu.insert(stelle, eintrag);
  }
  return (basis ?? const HeroSpielansicht()).copyWith(
    kacheln: List<HeroSpielkachel>.unmodifiable(neu),
  );
}

/// Setzt nur das Einklappen der Kachel [art] in der gespeicherten Anordnung.
///
/// Ohne bisherige Anordnung entsteht eine mit diesem einen Eintrag; die
/// übrigen Kacheln folgen beim Auflösen weiter der Standardanordnung.
HeroSpielansicht mitEingeklappt(
  HeroSpielansicht? basis,
  KartoSpielkachelArt art, {
  required bool eingeklappt,
}) {
  final ansicht = basis ?? const HeroSpielansicht();
  final vorhanden = ansicht.kachel(art.id) != null;
  return ansicht.copyWith(
    kacheln: List<HeroSpielkachel>.unmodifiable(<HeroSpielkachel>[
      for (final kachel in ansicht.kacheln)
        kachel.id == art.id
            ? kachel.copyWith(eingeklappt: eingeklappt)
            : kachel,
      if (!vorhanden && eingeklappt)
        HeroSpielkachel(id: art.id, eingeklappt: true),
    ]),
  );
}

/// Verschiebt die Kachel an [von] so, dass sie danach an [nach] steht.
List<KartoSpielkachel> verschiebeSpielkachel(
  List<KartoSpielkachel> kacheln,
  int von,
  int nach,
) {
  if (von < 0 || von >= kacheln.length) return kacheln;
  final ergebnis = [...kacheln];
  final kachel = ergebnis.removeAt(von);
  ergebnis.insert(nach.clamp(0, ergebnis.length), kachel);
  return List<KartoSpielkachel>.unmodifiable(ergebnis);
}

/// Fügt die Kachel [gezogen] [davor] oder dahinter an die Kachel [ziel] ein.
///
/// Anders als [verschiebeSpielkachel] richtet sich die Stelle nach der
/// Zielkachel und nicht nach einem Index, den das Entfernen der gezogenen
/// Kachel verschieben würde. Unbekannte oder gleiche Kacheln ändern nichts.
List<KartoSpielkachel> fuegeSpielkachelEin(
  List<KartoSpielkachel> kacheln,
  KartoSpielkachelArt gezogen,
  KartoSpielkachelArt ziel, {
  required bool davor,
}) {
  if (gezogen == ziel) return kacheln;
  final von = kacheln.indexWhere((k) => k.art == gezogen);
  if (von < 0 || !kacheln.any((k) => k.art == ziel)) return kacheln;
  final ergebnis = [...kacheln];
  final kachel = ergebnis.removeAt(von);
  final stelle = ergebnis.indexWhere((k) => k.art == ziel);
  ergebnis.insert(davor ? stelle : stelle + 1, kachel);
  return List<KartoSpielkachel>.unmodifiable(ergebnis);
}

/// Ersetzt die Kachel [art] durch [aenderung] ihrer bisherigen Fassung.
List<KartoSpielkachel> aendereSpielkachel(
  List<KartoSpielkachel> kacheln,
  KartoSpielkachelArt art,
  KartoSpielkachel Function(KartoSpielkachel kachel) aenderung,
) {
  return List<KartoSpielkachel>.unmodifiable(<KartoSpielkachel>[
    for (final kachel in kacheln)
      kachel.art == art ? aenderung(kachel) : kachel,
  ]);
}
