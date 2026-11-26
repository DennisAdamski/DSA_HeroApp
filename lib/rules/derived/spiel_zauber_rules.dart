import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'magic_rules.dart';
import 'tradition_rules.dart';
import 'zauber_herleitung_rules.dart';

/// Sortierkriterium der Zauberkachel am Spieltisch.
enum SpielZauberSortierung {
  /// Alphabetisch nach Name.
  name,

  /// Nach ZfW*, Gleichstand nach Name.
  zfw,
}

/// Ein gelernter Zauber in der Zauberkachel.
///
/// Reine Darstellungsgrundlage: ZfW* kommt aus [herleiteZfw], alles andere
/// steht unverändert im Katalog oder im Heldeneintrag.
class SpielZauberEintrag {
  /// Eintrag für [zauber] mit [zfw] (= ZfW*).
  const SpielZauberEintrag({
    required this.zauber,
    required this.zfw,
    required this.merkmale,
    this.repraesentation,
    this.hauszauber = false,
    this.spezialisierungen = const <String>[],
  });

  /// Katalogzauber.
  final SpellDef zauber;

  /// ZfW* (ZfW + Modifikator).
  final int zfw;

  /// Merkmale des Zaubers einzeln (`Elementar (Erz)` bleibt ein Merkmal).
  final List<String> merkmale;

  /// Gelernte Repräsentation; `null`, wenn keine eingetragen ist.
  final String? repraesentation;

  /// Ob der Zauber Hauszauber ist.
  final bool hauszauber;

  /// Eingetragene Zauberspezialisierungen (nicht leere Namen).
  final List<String> spezialisierungen;

  /// Die Probe als Kürzelkette, etwa `MU/KL/CH`.
  String get eigenschaften => zauber.attributes.join('/');
}

/// Kopfdaten der Zauberkachel: Repräsentationen, Leiteigenschaft, Kenntnisse.
class SpielZauberKopf {
  /// Kopf mit den angezeigten Namen.
  const SpielZauberKopf({
    required this.traditionen,
    required this.leiteigenschaften,
    required this.merkmalskenntnisse,
  });

  /// Namen der aufgelösten Traditionen, etwa `Gildenmagier`.
  final List<String> traditionen;

  /// Leiteigenschaft als Kürzel; das manuelle Feld des Helden hat Vorrang.
  final List<String> leiteigenschaften;

  /// Erworbene Merkmalskenntnisse.
  final List<String> merkmalskenntnisse;

  /// Ob der Kopf nichts zu zeigen hat.
  bool get leer =>
      traditionen.isEmpty &&
      leiteigenschaften.isEmpty &&
      merkmalskenntnisse.isEmpty;
}

/// Kopfdaten aus dem gespeicherten Helden des [snapshot].
SpielZauberKopf spielZauberKopf(HeroComputedSnapshot snapshot) {
  final hero = snapshot.hero;
  final traditionen = resolveHeroTraditionen(
    repraesentationen: hero.representationen,
    gewaehlteTraditionen: hero.repraesentationsTraditionen,
    ritualkenntnisse: hero.ritualKnowledge.keys,
  );
  final leit = leiteigenschaftenFuer(
    traditionen,
    override: hero.magicLeadAttribute,
  ).toList()..sort();
  return SpielZauberKopf(
    traditionen: <String>[for (final t in traditionen) t.name],
    leiteigenschaften: leit,
    merkmalskenntnisse: List<String>.unmodifiable(hero.merkmalskenntnisse),
  );
}

/// Ob der Held Zauber führt: Magie aktiviert oder mindestens ein Zauber mit
/// ZfW. Eine Heldin ohne beides bekommt die Kachel nicht angeboten.
bool fuehrtZauber(HeroComputedSnapshot snapshot) =>
    snapshot.resourceActivation.magic.isEnabled ||
    snapshot.hero.spells.values.any((e) => e.spellValue != null);

/// Gelernte Katalogzauber für die Zauberkachel.
///
/// Nur Zauber mit ZfW erscheinen: ein eingetragener, nicht aktivierter Zauber
/// ist nicht wirkbar. [suche] filtert ohne Groß-/Kleinschreibung nach dem
/// Namen, [merkmal] auf Zauber mit genau diesem Merkmal. [aufsteigend] dreht
/// nur das Hauptkriterium; Gleichstand ordnet aufsteigend nach Name.
List<SpielZauberEintrag> spielZauberListe(
  HeroComputedSnapshot snapshot,
  RulesCatalog katalog, {
  String suche = '',
  String? merkmal,
  SpielZauberSortierung sortierung = SpielZauberSortierung.name,
  bool aufsteigend = true,
}) {
  final filter = suche.trim().toLowerCase();
  final eintraege = <SpielZauberEintrag>[
    for (final z in katalog.spells)
      if (snapshot.hero.spells[z.id] case final e? when e.spellValue != null)
        if (filter.isEmpty || z.name.toLowerCase().contains(filter))
          if (merkmal == null || parseSpellTraits(z.traits).contains(merkmal))
            SpielZauberEintrag(
              zauber: z,
              zfw: herleiteZfw(e).wert,
              merkmale: parseSpellTraits(z.traits),
              repraesentation: (e.learnedRepresentation ?? '').trim().isEmpty
                  ? null
                  : e.learnedRepresentation!.trim(),
              hauszauber: e.hauszauber,
              spezialisierungen: <String>[
                for (final s in e.specializations)
                  if (s.trim().isNotEmpty) s.trim(),
              ],
            ),
  ];
  final richtung = aufsteigend ? 1 : -1;
  int nachName(SpielZauberEintrag a, SpielZauberEintrag b) =>
      a.zauber.name.toLowerCase().compareTo(b.zauber.name.toLowerCase());
  eintraege.sort((a, b) {
    switch (sortierung) {
      case SpielZauberSortierung.name:
        return richtung * nachName(a, b);
      case SpielZauberSortierung.zfw:
        final v = a.zfw.compareTo(b.zfw);
        return v != 0 ? richtung * v : nachName(a, b);
    }
  });
  return List<SpielZauberEintrag>.unmodifiable(eintraege);
}

/// Die Merkmale der [eintraege], eindeutig und alphabetisch.
List<String> spielZauberMerkmale(Iterable<SpielZauberEintrag> eintraege) {
  final merkmale = <String>{for (final e in eintraege) ...e.merkmale};
  return merkmale.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}
