/// Lernspalte eines Zaubers als Herleitung (ARCH-04).
///
/// Die Spalte der Steigerungskostentabelle ergibt sich (WdS S. 170 f., Wege
/// der Zauberei S. 74 und 382–386) aus der Komplexität des Zaubers, dem
/// Hauszauber, passenden Merkmalskenntnissen, Begabungen, Unfähigkeiten, einer
/// fremden Repräsentation und – bei elementaren Zaubern – dem Gegenelement.
/// Gehört der Zauber zu einer Hexalogie, werden seine Schritte bis zum ZfW des
/// höchsten anderen Zaubers der Gruppe eine weitere Spalte billiger.
library;

import 'package:dsa_heldenverwaltung/catalog/hexalogie_katalog.dart';
import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_begabung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/learning_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';

/// Grundwert: Komplexität des Zaubers im Katalog.
const String kSpalteKatalogSchritt = 'Komplexität des Zaubers';

/// Hauszauber: eine Spalte leichter.
const String kSpalteHauszauberSchritt = 'Hauszauber';

/// Passende Merkmalskenntnis: eine Spalte leichter.
const String kSpalteMerkmalskenntnisSchritt = 'Merkmalskenntnis';

/// Begabung: eine Spalte leichter.
const String kSpalteBegabungSchritt = 'Begabung';

/// Unfähigkeit: eine Spalte schwerer.
const String kSpalteUnfaehigkeitSchritt = 'Unfähigkeit';

/// Fremde Repräsentation: zwei Spalten schwerer.
const String kSpalteFremdeReprSchritt = 'Fremde Repräsentation';

/// Gegenelement: eine Spalte schwerer.
const String kSpalteGegenelementSchritt = 'Gegenelement';

/// Ausgleich an den Grenzen A* und H.
const String kSpalteGrenzeSchritt = 'Grenze der Tabelle';

/// Die Lernspalte eines Zaubers mit ihrer Herleitung.
class ZauberLernspalte {
  /// Hält Ergebnis, Herleitung und eine mögliche Hexalogie-Erleichterung.
  const ZauberLernspalte({
    required this.spalte,
    required this.herleitung,
    this.hexalogie,
    this.hexalogieBisWert,
    this.hexalogieHinweis,
    this.gegenelementHinweis,
  });

  /// Wirksame Spalte ohne Hexalogie (`A*` bis `H`).
  final String spalte;

  /// Herleitung in Spalten: Grundwert ist der Index der Katalogspalte, jeder
  /// Schritt verschiebt um eine oder mehrere Spalten. Leer, wenn der Katalog
  /// keine bekannte Komplexität nennt.
  final Herleitung herleitung;

  /// Hexalogie des Zaubers, wenn er zu einer gehört.
  final HexalogieDef? hexalogie;

  /// Bis zu diesem Zielwert kostet jeder Schritt eine weitere Spalte weniger;
  /// `null`, wenn keine Hexalogie-Erleichterung gilt.
  final int? hexalogieBisWert;

  /// Erklärung der Hexalogie-Lage für die Anzeige; `null` ohne Hexalogie.
  final String? hexalogieHinweis;

  /// Erklärung, warum der Zauber wegen des Gegenelements eine Spalte schwerer
  /// ist; `null`, wenn der Nachteil nicht greift.
  final String? gegenelementHinweis;
}

/// Berechnet die Lernspalte des Zaubers [spell].
///
/// [fremdeReprSpalten] kommt aus `fremdeRepraesentationsSpalten`. [eintrag]
/// ist der Heldeneintrag (Hauszauber, Begabungshäkchen); [zauber]
/// sind alle Zauber des Helden und liefern die ZfW der Hexalogie-Geschwister.
/// [begabteMerkmale] und [merkmalskenntnisse] bestimmen mit, welches Element
/// der Held bevorzugt; [elementarharmonisiert] hebt den Nachteil gegenüber dem
/// Gegenelement auf (SF Elementarharmonisierte Aura).
ZauberLernspalte zauberLernspalte({
  required SpellDef spell,
  required HeroSpellEntry? eintrag,
  required int fremdeReprSpalten,
  required LernspaltenBefund befund,
  required List<String> merkmalskenntnisse,
  Set<String> begabteMerkmale = const <String>{},
  bool elementarharmonisiert = false,
  Map<String, HeroSpellEntry> zauber = const <String, HeroSpellEntry>{},
}) {
  final merkmale = parseSpellTraits(spell.traits);
  final hauszauber = eintrag?.hauszauber ?? false;
  final begabt = (eintrag?.gifted ?? false) || befund.begabungen.isNotEmpty;
  final merkmalskenntnis = merkmale.any(merkmalskenntnisse.contains);
  final element = einzigesElement(merkmale);
  final gegenelement =
      !elementarharmonisiert &&
      element != null &&
      _bevorzugt(element.gegenelement, merkmalskenntnisse, begabteMerkmale);

  final fremd = fremdeReprSpalten;
  final spalte = effectiveSpellLernkomplexitaet(
    basisKomplexitaet: spell.steigerung,
    istHauszauber: hauszauber,
    zauberMerkmale: merkmale,
    heldMerkmalskenntnisse: merkmalskenntnisse,
    gifted: begabt,
    penaltySteps: fremd + befund.erhoehung + (gegenelement ? 1 : 0),
    zusatzReduktion: befund.zusatzBegabungen.length,
  );

  final schritte = <HerleitungsSchritt>[];
  final basisIndex = kLernkomplexitaeten.indexOf(spell.steigerung.trim());
  if (basisIndex >= 0) {
    schritte.addAll(<HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: kSpalteKatalogSchritt,
        betrag: basisIndex,
        art: HerleitungsArt.grundwert,
        formel: 'Spalte ${spell.steigerung.trim()}',
      ),
      HerleitungsSchritt(
        bezeichnung: kSpalteHauszauberSchritt,
        betrag: hauszauber ? -1 : 0,
        art: HerleitungsArt.modifikator,
        quelle: 'Hauszauber',
      ),
      HerleitungsSchritt(
        bezeichnung: kSpalteMerkmalskenntnisSchritt,
        betrag: merkmalskenntnis ? -1 : 0,
        art: HerleitungsArt.modifikator,
        quelle: 'Merkmalskenntnis',
      ),
      HerleitungsSchritt(
        bezeichnung: kSpalteBegabungSchritt,
        betrag: -((begabt ? 1 : 0) + befund.zusatzBegabungen.length),
        art: HerleitungsArt.modifikator,
        quelle: <String>[
          if (eintrag?.gifted ?? false) 'Begabungshäkchen',
          ...befund.begabungsQuellen,
        ].join(', '),
      ),
      HerleitungsSchritt(
        bezeichnung: kSpalteUnfaehigkeitSchritt,
        betrag: befund.erhoehung,
        art: HerleitungsArt.modifikator,
        quelle: befund.unfaehigkeitsQuellen.join(', '),
      ),
      HerleitungsSchritt(
        bezeichnung: kSpalteFremdeReprSchritt,
        betrag: fremd,
        art: HerleitungsArt.modifikator,
        quelle: 'Repräsentation',
        bedingung:
            'Fremde Repräsentation: 2 Spalten, Schelme 3, Gildenmagier mit '
            'Scharlatan oder Borbaradianer 1',
      ),
      HerleitungsSchritt(
        bezeichnung: kSpalteGegenelementSchritt,
        betrag: gegenelement ? 1 : 0,
        art: HerleitungsArt.modifikator,
        quelle: element == null
            ? null
            : 'Siegel der Elemente (${element.gegenelement.anzeige} bevorzugt)',
        bedingung: 'Merkmalskenntnis oder Begabung im Gegenelement',
      ),
    ]);
    final summe = summeDer(schritte);
    final endIndex = kLernkomplexitaeten.indexOf(spalte);
    if (summe != endIndex) {
      schritte.add(
        HerleitungsSchritt(
          bezeichnung: kSpalteGrenzeSchritt,
          betrag: endIndex - summe,
          art: HerleitungsArt.begrenzung,
        ),
      );
    }
  }

  final hex = hexalogieFuerZauber(spell.id);
  int? bis;
  String? hinweis;
  if (hex != null) {
    final andere = <int>[
      for (final id in hex.zauberIds)
        if (id != spell.id)
          if (zauber[id]?.spellValue case final w? when w >= 0) w,
    ];
    if (gegenelement) {
      hinweis =
          '${hex.name}: Zauber eines Gegenelements profitieren nicht von der '
          'Hexalogie.';
    } else if (andere.isEmpty) {
      hinweis =
          '${hex.name}: Sobald ein weiterer Zauber der Hexalogie gelernt ist, '
          'sind die übrigen eine Spalte leichter bis zu dessen ZfW.';
    } else {
      bis = andere.reduce((a, b) => a > b ? a : b);
      hinweis =
          '${hex.name}: eine Spalte leichter bis ZfW $bis '
          '(höchster gelernter Zauber der Hexalogie).';
    }
  }

  return ZauberLernspalte(
    spalte: spalte,
    herleitung: Herleitung(bezeichnung: 'Lernspalte', schritte: schritte),
    hexalogie: hex,
    hexalogieBisWert: bis,
    hexalogieHinweis: hinweis,
    gegenelementHinweis: gegenelement
        ? 'Gegenelement: Der Held bevorzugt ${element.gegenelement.anzeige} '
              '(Merkmalskenntnis oder Begabung), das Gegenelement dieses '
              'Zaubers. Der Zauber ist deshalb eine Spalte schwerer (Siegel der '
              'Elemente); die SF Elementarharmonisierte Aura hebt das auf.'
        : null,
  );
}

// Ob der Held das [element] bevorzugt: Merkmalskenntnis oder Begabung im
// speziellen Element (nicht in „Elementar (allgemein)“).
bool _bevorzugt(
  Magieelement element,
  List<String> merkmalskenntnisse,
  Set<String> begabteMerkmale,
) {
  final merkmal = element.merkmal.toLowerCase();
  return merkmalskenntnisse.any((m) => m.trim().toLowerCase() == merkmal) ||
      begabteMerkmale.any((m) => m.trim().toLowerCase() == merkmal);
}

/// Lernspalte eines Talents (auch Sprache oder Schrift) als Herleitung in
/// Spalten: Katalogspalte, Begabung und Unfähigkeit.
///
/// Wie bei Zaubern wird zuerst verteuert, dann um höchstens eine Spalte
/// verbilligt (`effectiveTalentLernkomplexitaet`); Grenzen der Tabelle stehen
/// als Ausgleichsschritt da.
Herleitung herleiteTalentLernspalte({
  required String basisSpalte,
  required LernspaltenBefund befund,
  required bool gifted,
}) {
  final basisIndex = kLernkomplexitaeten.indexOf(basisSpalte.trim());
  if (basisIndex < 0) {
    return Herleitung(bezeichnung: 'Lernspalte', schritte: const []);
  }
  final spalte = effectiveTalentLernkomplexitaet(
    basisKomplexitaet: basisSpalte,
    gifted: befund.istBegabt(gifted: gifted),
    unfaehigkeitsSchritte: befund.erhoehung,
  );
  final schritte = <HerleitungsSchritt>[
    HerleitungsSchritt(
      bezeichnung: 'Spalte im Katalog',
      betrag: basisIndex,
      art: HerleitungsArt.grundwert,
      formel: 'Spalte ${basisSpalte.trim()}',
    ),
    HerleitungsSchritt(
      bezeichnung: kSpalteBegabungSchritt,
      betrag: befund.istBegabt(gifted: gifted) ? -1 : 0,
      art: HerleitungsArt.modifikator,
      quelle: <String>[
        if (gifted) 'Begabungshäkchen',
        ...befund.begabungsQuellen,
      ].join(', '),
    ),
    HerleitungsSchritt(
      bezeichnung: kSpalteUnfaehigkeitSchritt,
      betrag: befund.erhoehung,
      art: HerleitungsArt.modifikator,
      quelle: befund.unfaehigkeitsQuellen.join(', '),
    ),
  ];
  final ausgleich = kLernkomplexitaeten.indexOf(spalte) - summeDer(schritte);
  if (ausgleich != 0) {
    schritte.add(
      HerleitungsSchritt(
        bezeichnung: kSpalteGrenzeSchritt,
        betrag: ausgleich,
        art: HerleitungsArt.begrenzung,
      ),
    );
  }
  return Herleitung(bezeichnung: 'Lernspalte', schritte: schritte);
}
