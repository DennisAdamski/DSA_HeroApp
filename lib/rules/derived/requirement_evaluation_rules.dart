/// Prueft strukturierte Erwerbsvoraussetzungen gegen den Stand eines Helden.
///
/// Das Ergebnis ist bewusst kein einzelnes `bool`, sondern eine Liste von
/// Einzelbefunden: Die App blockiert einen Erwerb nie, sondern zeigt eine
/// Checkliste und verlangt bei offenen Punkten eine bewusste Bestaetigung
/// (Meisterentscheid). Dafuer muss jede Bedingung einzeln erklaeren koennen,
/// warum sie erfuellt ist oder was fehlt.
library;

import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/tradition_rules.dart';

/// Ergebnisstatus einer einzelnen Voraussetzung.
enum RequirementStatus {
  /// Der Held erfuellt die Bedingung.
  erfuellt,

  /// Die Bedingung ist pruefbar und nicht erfuellt.
  nichtErfuellt,

  /// Nicht maschinell pruefbar (Regeltext, fehlende Bezugsdaten). Wird
  /// angezeigt, blockiert aber nie.
  hinweis,
}

/// Befund zu genau einer Voraussetzung.
class RequirementCheckResult {
  /// Erzeugt einen unveraenderlichen Befund.
  const RequirementCheckResult({
    required this.requirement,
    required this.status,
    required this.sollText,
    this.istText = '',
    this.teilergebnisse = const <RequirementCheckResult>[],
  });

  /// Die gepruefte Bedingung.
  final SpecialAbilityRequirement requirement;

  /// Ergebnis der Pruefung.
  final RequirementStatus status;

  /// Was gefordert ist, z. B. `MU 15`.
  final String sollText;

  /// Was der Held mitbringt, z. B. `Held hat 12`. Leer, wenn es dazu nichts
  /// Sinnvolles zu sagen gibt.
  final String istText;

  /// Befunde der Teilbedingungen einer Oder-Gruppe.
  final List<RequirementCheckResult> teilergebnisse;

  /// Ob dieser Befund den Erwerb offen laesst.
  bool get istOffen => status == RequirementStatus.nichtErfuellt;
}

/// Alles, was zum Pruefen von Voraussetzungen ueber einen Helden bekannt sein
/// muss.
///
/// Bewusst entkoppelt von `HeroSheet`: Die Werte kommen aus verschiedenen
/// Quellen (Heldenmodell, Katalog fuer Talent- und Zaubernamen, abgeleitete
/// Traditionen) und lassen sich so in Tests direkt setzen. Gebaut wird der
/// Kontext von `buildHeroRequirementContext` in
/// `hero_requirement_context.dart`.
class HeroRequirementContext {
  /// Erzeugt einen unveraenderlichen Pruefkontext.
  const HeroRequirementContext({
    this.eigenschaften = const <String, int>{},
    this.sonderfertigkeiten = const <String>[],
    this.zauberwerte = const <String, int>{},
    this.talentwerte = const <String, int>{},
    this.ritualkenntnisse = const <String, int>{},
    this.traditionen = const <TraditionDef>[],
    this.merkmalskenntnisse = const <String>[],
    this.vorteile = const <String>[],
    this.nachteile = const <String>[],
    this.rasse = '',
    this.leiteigenschaftOverride = '',
  });

  /// Eigenschaftswerte nach Kuerzel (`MU`, `KL`, …).
  final Map<String, int> eigenschaften;

  /// Namen aller erworbenen Sonderfertigkeiten (allgemein, magisch, karmal,
  /// Kampf) in ihrer gespeicherten Schreibweise.
  final List<String> sonderfertigkeiten;

  /// ZfW je Zaubername.
  final Map<String, int> zauberwerte;

  /// TaW je Talentname.
  final Map<String, int> talentwerte;

  /// RkW je Ritualkenntnis-Name.
  final Map<String, int> ritualkenntnisse;

  /// Aufgeloeste Traditionen des Helden (Repraesentationen ∪ Ritualkenntnisse).
  final List<TraditionDef> traditionen;

  /// Bekannte Merkmale.
  final List<String> merkmalskenntnisse;

  /// Vorteile als Textfragmente.
  final List<String> vorteile;

  /// Nachteile als Textfragmente.
  final List<String> nachteile;

  /// Rasse des Helden.
  final String rasse;

  /// Manuell gesetzte Leiteigenschaft; schlaegt die Tradition.
  final String leiteigenschaftOverride;

  /// Die Leiteigenschafts-Kuerzel dieses Helden.
  Set<String> get leiteigenschaften =>
      leiteigenschaftenFuer(traditionen, override: leiteigenschaftOverride);

  /// Ob der Held Spruchzauberei betreibt — also mindestens eine Tradition mit
  /// Repraesentation fuehrt.
  bool get istSpruchzauberer => traditionen.any(
    (tradition) => tradition.repraesentation.isNotEmpty,
  );
}

/// Prueft eine Liste von Voraussetzungen.
List<RequirementCheckResult> evaluateRequirements(
  Iterable<SpecialAbilityRequirement> requirements,
  HeroRequirementContext context,
) {
  return requirements
      .map((requirement) => evaluateRequirement(requirement, context))
      .toList(growable: false);
}

/// Die Befunde, die den Erwerb offen lassen.
List<RequirementCheckResult> offeneVoraussetzungen(
  Iterable<RequirementCheckResult> ergebnisse,
) => ergebnisse.where((ergebnis) => ergebnis.istOffen).toList(growable: false);

/// Ob kein Befund offen ist. Reine Hinweise zaehlen als erfuellt.
bool alleVoraussetzungenErfuellt(
  Iterable<RequirementCheckResult> ergebnisse,
) => ergebnisse.every((ergebnis) => !ergebnis.istOffen);

/// Prueft genau eine Voraussetzung.
RequirementCheckResult evaluateRequirement(
  SpecialAbilityRequirement requirement,
  HeroRequirementContext context,
) {
  switch (requirement.art) {
    case RequirementArt.eigenschaft:
      return _pruefeEigenschaft(requirement, context);
    case RequirementArt.leiteigenschaft:
      return _pruefeLeiteigenschaft(requirement, context);
    case RequirementArt.sonderfertigkeit:
      return _pruefeSonderfertigkeit(requirement, context);
    case RequirementArt.zauber:
      return _pruefeWert(
        requirement,
        context.zauberwerte,
        bezeichnung: 'ZfW',
      );
    case RequirementArt.talent:
      return _pruefeWert(
        requirement,
        context.talentwerte,
        bezeichnung: 'TaW',
      );
    case RequirementArt.ritualkenntnis:
      return _pruefeWert(
        requirement,
        context.ritualkenntnisse,
        bezeichnung: 'RkW',
        praefix: 'Ritualkenntnis',
      );
    case RequirementArt.tradition:
      return _pruefeTradition(requirement, context);
    case RequirementArt.merkmalskenntnis:
      return _pruefeMerkmalskenntnis(requirement, context);
    case RequirementArt.vorteil:
      return _pruefeTraitFragment(
        requirement,
        context.vorteile,
        sollPraefix: 'Vorteil',
        erfuelltWennVorhanden: true,
      );
    case RequirementArt.nachteilVerboten:
      return _pruefeTraitFragment(
        requirement,
        context.nachteile,
        sollPraefix: 'ohne Nachteil',
        erfuelltWennVorhanden: false,
      );
    case RequirementArt.rasse:
      return _pruefeRasse(requirement, context);
    case RequirementArt.spruchzauberer:
      return RequirementCheckResult(
        requirement: requirement,
        status: context.istSpruchzauberer
            ? RequirementStatus.erfuellt
            : RequirementStatus.nichtErfuellt,
        sollText: 'Spruchzauberer',
        istText: context.istSpruchzauberer
            ? 'Repräsentation vorhanden'
            : 'keine Repräsentation eingetragen',
      );
    case RequirementArt.oderGruppe:
      return _pruefeGruppe(requirement, context, alleNoetig: false);
    case RequirementArt.undGruppe:
      return _pruefeGruppe(requirement, context, alleNoetig: true);
    case RequirementArt.hinweis:
    case RequirementArt.unbekannt:
      return RequirementCheckResult(
        requirement: requirement,
        status: RequirementStatus.hinweis,
        sollText: requirement.text,
      );
  }
}

RequirementCheckResult _pruefeEigenschaft(
  SpecialAbilityRequirement requirement,
  HeroRequirementContext context,
) {
  final code = requirement.code.trim().toUpperCase();
  final min = requirement.min ?? 0;
  final ist = context.eigenschaften[code];
  final soll = '$code $min';
  if (ist == null) {
    return RequirementCheckResult(
      requirement: requirement,
      status: RequirementStatus.hinweis,
      sollText: soll,
      istText: 'Wert unbekannt',
    );
  }
  return RequirementCheckResult(
    requirement: requirement,
    status: ist >= min
        ? RequirementStatus.erfuellt
        : RequirementStatus.nichtErfuellt,
    sollText: soll,
    istText: 'Held hat $ist',
  );
}

RequirementCheckResult _pruefeLeiteigenschaft(
  SpecialAbilityRequirement requirement,
  HeroRequirementContext context,
) {
  final min = requirement.min ?? 0;
  final soll = 'Leiteigenschaft $min';
  final codes = context.leiteigenschaften;
  if (codes.isEmpty) {
    return RequirementCheckResult(
      requirement: requirement,
      status: RequirementStatus.hinweis,
      sollText: soll,
      istText: 'keine Tradition hinterlegt',
    );
  }

  // Bei mehreren Traditionen entscheidet die guenstigste: Ein Held mit zwei
  // Repraesentationen darf die staerkere seiner Leiteigenschaften ansetzen.
  var besterCode = '';
  var besterWert = -1;
  for (final code in codes) {
    final wert = context.eigenschaften[code] ?? 0;
    if (wert > besterWert) {
      besterWert = wert;
      besterCode = code;
    }
  }
  final herkunft = context.traditionen
      .where((tradition) => tradition.leiteigenschaft == besterCode)
      .map((tradition) => tradition.name)
      .join(', ');
  final istText = herkunft.isEmpty
      ? '$besterCode $besterWert'
      : '$besterCode $besterWert (über $herkunft)';
  return RequirementCheckResult(
    requirement: requirement,
    status: besterWert >= min
        ? RequirementStatus.erfuellt
        : RequirementStatus.nichtErfuellt,
    sollText: soll,
    istText: istText,
  );
}

RequirementCheckResult _pruefeSonderfertigkeit(
  SpecialAbilityRequirement requirement,
  HeroRequirementContext context,
) {
  final geforderteStufe = requirement.stufe ?? 0;
  final soll = geforderteStufe > 0
      ? 'SF ${requirement.name} ${_roemischeZahl(geforderteStufe)}'
      : 'SF ${requirement.name}';

  var besteStufe = -1;
  for (final owned in context.sonderfertigkeiten) {
    final stufe = besessenStufeFuer(owned, requirement.name);
    if (stufe != null && stufe > besteStufe) {
      besteStufe = stufe;
    }
  }

  if (besteStufe < 0) {
    return RequirementCheckResult(
      requirement: requirement,
      status: RequirementStatus.nichtErfuellt,
      sollText: soll,
      istText: 'nicht erworben',
    );
  }
  // Ein Eintrag ohne Stufenangabe (`Eiserner Wille` statt `Eiserner Wille I`)
  // ist der Grunderwerb und erfuellt damit die Forderung nach Stufe I.
  if (geforderteStufe <= 1 || besteStufe >= geforderteStufe) {
    return RequirementCheckResult(
      requirement: requirement,
      status: RequirementStatus.erfuellt,
      sollText: soll,
      istText: 'erworben',
    );
  }
  return RequirementCheckResult(
    requirement: requirement,
    status: RequirementStatus.nichtErfuellt,
    sollText: soll,
    istText: 'nur Stufe ${_roemischeZahl(besteStufe)}',
  );
}

/// Ermittelt, welche Kettenstufe von [basisName] in [gespeicherterName] steckt.
///
/// `null`, wenn der gespeicherte Name gar nicht zu [basisName] gehoert. `0`
/// bedeutet: erworben, aber ohne Stufenangabe. Katalog-Suffixe in Klammern
/// (`Regeneration II (ZH)`) und der alte Sammelname (`Eiserner Wille I / II`,
/// zaehlt als Stufe I) werden dabei beruecksichtigt.
int? besessenStufeFuer(String gespeicherterName, String basisName) {
  final basis = normalizeSpecialAbilityName(basisName);
  if (basis.isEmpty) {
    return null;
  }
  final name = normalizeSpecialAbilityName(
    gespeicherterName.replaceAll(RegExp(r'\([^)]*\)'), ' '),
  );
  if (name == basis) {
    return 0;
  }
  if (!name.startsWith('$basis ')) {
    return null;
  }
  final rest = name.substring(basis.length).trim();
  final ersterToken = rest.split(' ').first;
  return _roemischeZahlWert(ersterToken) ?? 0;
}

RequirementCheckResult _pruefeWert(
  SpecialAbilityRequirement requirement,
  Map<String, int> werte, {
  required String bezeichnung,
  String praefix = '',
}) {
  final min = requirement.min;
  final anzeigeName = praefix.isEmpty
      ? requirement.name
      : '$praefix ${requirement.name}';
  final soll = min == null
      ? anzeigeName
      : '$bezeichnung ${requirement.name} $min';

  final ist = _besterWert(werte, requirement.name);
  if (ist == null) {
    return RequirementCheckResult(
      requirement: requirement,
      status: RequirementStatus.nichtErfuellt,
      sollText: soll,
      istText: 'nicht vorhanden',
    );
  }
  if (min == null) {
    return RequirementCheckResult(
      requirement: requirement,
      status: RequirementStatus.erfuellt,
      sollText: soll,
      istText: 'vorhanden ($ist)',
    );
  }
  return RequirementCheckResult(
    requirement: requirement,
    status: ist >= min
        ? RequirementStatus.erfuellt
        : RequirementStatus.nichtErfuellt,
    sollText: soll,
    istText: 'Held hat $ist',
  );
}

/// Sucht den Wert zu [name] tolerant: exakter Treffer zuerst, danach ein
/// Eintrag, der den Namen enthaelt (`Ritualkenntnis Geode` fuer `Geode`).
int? _besterWert(Map<String, int> werte, String name) {
  final needle = normalizeSpecialAbilityName(name);
  if (needle.isEmpty) {
    return null;
  }
  int? treffer;
  for (final entry in werte.entries) {
    final kandidat = normalizeSpecialAbilityName(entry.key);
    if (kandidat == needle) {
      return entry.value;
    }
    if (kandidat.contains(needle) || needle.contains(kandidat)) {
      if (treffer == null || entry.value > treffer) {
        treffer = entry.value;
      }
    }
  }
  return treffer;
}

RequirementCheckResult _pruefeTradition(
  SpecialAbilityRequirement requirement,
  HeroRequirementContext context,
) {
  final gefordert = requirement.alleNamen;
  final soll = 'Tradition ${gefordert.join(' oder ')}';
  final eigene = context.traditionen.map((tradition) => tradition.id).toSet();
  final treffer = gefordert
      .expand(traditionenByName)
      .where((tradition) => eigene.contains(tradition.id))
      .toList(growable: false);
  if (treffer.isNotEmpty) {
    return RequirementCheckResult(
      requirement: requirement,
      status: RequirementStatus.erfuellt,
      sollText: soll,
      istText: treffer.map((tradition) => tradition.name).join(', '),
    );
  }
  final eigeneNamen = context.traditionen
      .map((tradition) => tradition.name)
      .join(', ');
  return RequirementCheckResult(
    requirement: requirement,
    status: RequirementStatus.nichtErfuellt,
    sollText: soll,
    istText: eigeneNamen.isEmpty
        ? 'keine Tradition eingetragen'
        : 'Held führt $eigeneNamen',
  );
}

RequirementCheckResult _pruefeMerkmalskenntnis(
  SpecialAbilityRequirement requirement,
  HeroRequirementContext context,
) {
  final merkmal = requirement.name.trim();
  if (merkmal.isEmpty) {
    final vorhanden = context.merkmalskenntnisse.isNotEmpty;
    return RequirementCheckResult(
      requirement: requirement,
      status: vorhanden
          ? RequirementStatus.erfuellt
          : RequirementStatus.nichtErfuellt,
      sollText: 'passende Merkmalskenntnis',
      istText: vorhanden
          ? context.merkmalskenntnisse.join(', ')
          : 'keine Merkmalskenntnis',
    );
  }
  final needle = normalizeSpecialAbilityName(merkmal);
  final vorhanden = context.merkmalskenntnisse.any(
    (kenntnis) => normalizeSpecialAbilityName(kenntnis) == needle,
  );
  return RequirementCheckResult(
    requirement: requirement,
    status: vorhanden
        ? RequirementStatus.erfuellt
        : RequirementStatus.nichtErfuellt,
    sollText: 'Merkmalskenntnis $merkmal',
    istText: vorhanden ? 'vorhanden' : 'nicht vorhanden',
  );
}

RequirementCheckResult _pruefeTraitFragment(
  SpecialAbilityRequirement requirement,
  List<String> fragmente, {
  required String sollPraefix,
  required bool erfuelltWennVorhanden,
}) {
  final needle = normalizeSpecialAbilityName(requirement.name);
  final vorhanden =
      needle.isNotEmpty &&
      fragmente.any(
        (fragment) => normalizeSpecialAbilityName(fragment).contains(needle),
      );
  return RequirementCheckResult(
    requirement: requirement,
    status: vorhanden == erfuelltWennVorhanden
        ? RequirementStatus.erfuellt
        : RequirementStatus.nichtErfuellt,
    sollText: '$sollPraefix ${requirement.name}',
    istText: vorhanden ? 'vorhanden' : 'nicht vorhanden',
  );
}

RequirementCheckResult _pruefeRasse(
  SpecialAbilityRequirement requirement,
  HeroRequirementContext context,
) {
  final gefordert = requirement.alleNamen;
  final eigene = normalizeSpecialAbilityName(context.rasse);
  final passt = gefordert.any((name) {
    final needle = normalizeSpecialAbilityName(name);
    return needle.isNotEmpty && eigene.contains(needle);
  });
  return RequirementCheckResult(
    requirement: requirement,
    status: passt
        ? RequirementStatus.erfuellt
        : RequirementStatus.nichtErfuellt,
    sollText: 'Rasse ${gefordert.join(' oder ')}',
    istText: context.rasse.trim().isEmpty
        ? 'keine Rasse eingetragen'
        : context.rasse.trim(),
  );
}

/// Prueft eine Oder- bzw. Und-Gruppe.
///
/// Eine Gruppe aus lauter Hinweisen kann nichts entscheiden und bleibt deshalb
/// selbst ein Hinweis — sonst wuerde ein unpruefbarer Regeltext den Erwerb als
/// blockiert darstellen.
RequirementCheckResult _pruefeGruppe(
  SpecialAbilityRequirement requirement,
  HeroRequirementContext context, {
  required bool alleNoetig,
}) {
  final teilergebnisse = evaluateRequirements(
    requirement.bedingungen,
    context,
  );
  final nurHinweise =
      teilergebnisse.isEmpty ||
      teilergebnisse.every(
        (ergebnis) => ergebnis.status == RequirementStatus.hinweis,
      );
  final erfuellt = alleNoetig
      ? teilergebnisse.every((ergebnis) => !ergebnis.istOffen)
      : teilergebnisse.any(
          (ergebnis) => ergebnis.status == RequirementStatus.erfuellt,
        );
  return RequirementCheckResult(
    requirement: requirement,
    status: nurHinweise
        ? RequirementStatus.hinweis
        : (erfuellt
              ? RequirementStatus.erfuellt
              : RequirementStatus.nichtErfuellt),
    sollText: teilergebnisse
        .map((ergebnis) => ergebnis.sollText)
        .join(alleNoetig ? ' und ' : ' oder '),
    istText: teilergebnisse
        .where((ergebnis) => ergebnis.istText.isNotEmpty)
        .map((ergebnis) => ergebnis.istText)
        .join('; '),
    teilergebnisse: teilergebnisse,
  );
}

const List<String> _roemischeZahlen = <String>[
  '',
  'I',
  'II',
  'III',
  'IV',
  'V',
  'VI',
  'VII',
];

String _roemischeZahl(int wert) =>
    wert > 0 && wert < _roemischeZahlen.length
    ? _roemischeZahlen[wert]
    : '$wert';

int? _roemischeZahlWert(String token) {
  final needle = token.trim().toUpperCase();
  if (needle.isEmpty) {
    return null;
  }
  final index = _roemischeZahlen.indexOf(needle);
  return index > 0 ? index : null;
}
