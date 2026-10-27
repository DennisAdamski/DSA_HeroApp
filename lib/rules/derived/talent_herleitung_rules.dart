/// Herleitung von TaW*, eBE und Probenwerten der Talente (ARCH-04).
///
/// Die Werte rechnen weiter `computeTalentComputedTaw` und `computeTalentEbe`;
/// hier stehen dieselben Beträge als benannte Schritte daneben, und die Summe
/// der Schritte ist der verwendete Wert (Tests pinnen die Gleichheit).
library;

import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/eigenschaft_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_main_attribute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_modifier_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_nutzung_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

/// Bezeichnung des TaW-Grundwerts.
const String kTalentTawSchritt = 'TaW';

/// Bezeichnung des eBE-Schritts in der TaW*-Herleitung.
const String kTalentEbeSchritt = 'eBE';

/// Bezeichnung des Grundschritts der eBE-Herleitung.
const String kTalentBeRegelSchritt = 'Behinderung (BE Kampf)';

/// Bezeichnung der situativen BE-Anpassung (Talent-BE-Override).
const String kTalentBeAnpassungSchritt = 'BE-Anpassung (situativ)';

/// Bezeichnung der epischen KK-Halbierung der eBE.
const String kTalentEpischeHalbierungSchritt = 'Epische KK-Halbierung';

/// Bezeichnung des Wundabzugs auf einer Probeneigenschaft.
const String kTalentWundenSchritt = 'Wunden';

/// Herleitungen einer Talentprobe: TaW*, eBE und die drei Probenwerte.
class TalentHerleitungen {
  /// Hält die Herleitungen eines Talents.
  TalentHerleitungen({
    required this.taw,
    required this.ebe,
    required List<Herleitung> eigenschaften,
  }) : eigenschaften = List<Herleitung>.unmodifiable(eigenschaften);

  /// TaW* = TaW + Modifikatoren + Inventar + eBE.
  final Herleitung taw;

  /// Effektive Behinderung (negativ oder 0).
  final Herleitung ebe;

  /// Probenwerte der Eigenschaftskette (Wunden eingerechnet).
  final List<Herleitung> eigenschaften;
}

/// Herleitung der effektiven Behinderung eines Talents.
///
/// [beKampf] ist die Kampf-BE aus der Rüstung, [beOverride] die vorübergehende
/// Talent-BE (situative Anpassung ohne Rüstungswechsel). [beRegel] ist die
/// BE-Regel des Talents (`-`, `-N`, `xN`), [reduktionsFaktor] die epische
/// KK-Halbierung (0,5) oder 1,0. Die Summe ist `computeTalentEbe` mit der
/// wirksamen BE.
Herleitung herleiteTalentEbe({
  required int beKampf,
  int? beOverride,
  required String beRegel,
  double reduktionsFaktor = 1.0,
}) {
  final regel = beRegel.trim();
  final wirksameBe = beOverride ?? beKampf;
  final beiKampfBe = computeTalentEbe(baseBe: beKampf, talentBeRule: beRegel);
  final beiWirksamerBe = computeTalentEbe(
    baseBe: wirksameBe,
    talentBeRule: beRegel,
  );
  final skaliert = computeTalentEbe(
    baseBe: wirksameBe,
    talentBeRule: beRegel,
    reductionMultiplier: reduktionsFaktor,
  );
  return Herleitung(
    bezeichnung: kTalentEbeSchritt,
    schritte: <HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: kTalentBeRegelSchritt,
        betrag: beiKampfBe,
        art: HerleitungsArt.grundwert,
        formel: regel.isEmpty || regel == '-'
            ? 'keine BE-Regel'
            : 'BE $beKampf, Regel $regel',
        quelle: 'Rüstung',
      ),
      HerleitungsSchritt(
        bezeichnung: kTalentBeAnpassungSchritt,
        betrag: beiWirksamerBe - beiKampfBe,
        art: HerleitungsArt.modifikator,
        formel: beOverride == null ? null : 'BE $beKampf → $beOverride',
        quelle: 'Talent-BE-Override',
      ),
      HerleitungsSchritt(
        bezeichnung: kTalentEpischeHalbierungSchritt,
        betrag: skaliert - beiWirksamerBe,
        art: HerleitungsArt.sonderfertigkeit,
        quelle: 'Epische Haupteigenschaft KK',
      ),
    ],
  );
}

/// Herleitung von TaW* aus dem Heldeneintrag.
///
/// [ebe] ist die Herleitung der effektiven Behinderung, [inventar] die
/// Beiträge ausgerüsteter Gegenstände. Die Summe entspricht
/// `computeTalentComputedTaw`.
Herleitung herleiteTalentTaw({
  required HeroTalentEntry eintrag,
  required Herleitung ebe,
  List<InventoryModifierQuelle> inventar = const <InventoryModifierQuelle>[],
}) {
  return Herleitung(
    bezeichnung: 'TaW*',
    schritte: <HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: kTalentTawSchritt,
        betrag: eintrag.talentValue ?? 0,
        art: HerleitungsArt.zukauf,
      ),
      ..._modifikatorSchritte(eintrag),
      ..._inventarSchritte(inventar),
      HerleitungsSchritt(
        bezeichnung: kTalentEbeSchritt,
        betrag: ebe.wert,
        art: HerleitungsArt.modifikator,
        quelle: 'Rüstung',
      ),
    ],
  );
}

List<HerleitungsSchritt> _modifikatorSchritte(HeroTalentEntry eintrag) {
  if (eintrag.talentModifiers.isEmpty) {
    return <HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: 'Modifikator',
        betrag: eintrag.modifier,
        art: HerleitungsArt.modifikator,
        quelle: 'Eigener Modifikator',
      ),
    ];
  }
  return <HerleitungsSchritt>[
    for (final mod in eintrag.talentModifiers)
      HerleitungsSchritt(
        bezeichnung: mod.description,
        betrag: mod.modifier,
        art: HerleitungsArt.modifikator,
        quelle: 'Eigener Modifikator',
      ),
  ];
}

List<HerleitungsSchritt> _inventarSchritte(
  List<InventoryModifierQuelle> inventar,
) => <HerleitungsSchritt>[
  for (final quelle in inventar)
    HerleitungsSchritt(
      bezeichnung: quelle.gegenstand,
      betrag: quelle.wert,
      art: HerleitungsArt.modifikator,
      quelle: 'Ausrüstung',
      bedingung: quelle.gruppe == null ? null : 'Talentgruppe ${quelle.gruppe}',
    ),
];

/// Probenwerte der Eigenschaftskette: die effektive Eigenschaft samt ihren
/// Quellen, je Zauber-Eigenschaftsquelle (Karnifilo) ein eigener Schritt
/// und, falls vorhanden, der Wundabzug als eigener Schritt.
List<Herleitung> herleiteProbenEigenschaften({
  required HeroComputedSnapshot snapshot,
  required List<String> eigenschaften,
}) {
  final ergebnis = <Herleitung>[];
  for (final name in eigenschaften) {
    final code = parseAttributeCode(name);
    if (code == null) continue;
    final schluessel = code.name;
    final effektiv = readAttributeValue(snapshot.effectiveAttributes, code);
    final probe = readAttributeValue(snapshot.probenEigenschaften, code);
    final quellen = snapshot.eigenschaftHerleitungen?.fuer(schluessel);
    final zauberSchritte = <HerleitungsSchritt>[
      for (final zauber
          in snapshot.derivedStats.zauberEffekte.eigenschaftsQuellen)
        HerleitungsSchritt(
          bezeichnung: zauber.bezeichnung,
          betrag: readAttributeModifierValue(zauber.mods, code),
          art: HerleitungsArt.zauber,
          quelle: zauber.quelle,
          bedingung: 'nur Proben',
        ),
    ];
    ergebnis.add(
      Herleitung(
        bezeichnung: attributeCodeKey(code),
        schritte: <HerleitungsSchritt>[
          if (quellen != null && quellen.wert == effektiv)
            ...quellen.schritte
          else
            HerleitungsSchritt(
              bezeichnung: kEigenschaftKuerzel[schluessel] ?? schluessel,
              betrag: effektiv,
              art: HerleitungsArt.grundwert,
            ),
          ...zauberSchritte,
          HerleitungsSchritt(
            bezeichnung: kTalentWundenSchritt,
            betrag: probe - effektiv - summeDer(zauberSchritte),
            art: HerleitungsArt.modifikator,
            quelle: 'Wunden',
          ),
        ],
      ),
    );
  }
  return ergebnis;
}

/// Alle Herleitungen einer Talentprobe des Helden.
///
/// Nimmt dieselben Eingaben wie `talentProbenwertFuer`. `null`, wenn der Held
/// das Talent nicht führt.
TalentHerleitungen? herleiteTalent({
  required HeroComputedSnapshot snapshot,
  required TalentDef talent,
  required bool epicAdvantagesActive,
  int? talentBeOverride,
  List<String>? eigenschaften,
}) {
  final hero = snapshot.hero;
  final eintrag = talentEintragFuerProbe(hero, talent);
  if (eintrag == null) return null;
  final ebe = herleiteTalentEbe(
    beKampf: snapshot.combatPreviewStats.beKampf,
    beOverride: talentBeOverride,
    beRegel: talent.be,
    reduktionsFaktor: epicTalentEbeMultiplier(
      ruleActive: epicAdvantagesActive,
      isEpisch: hero.isEpisch,
      mainAttributes: hero.epicMainAttributes,
      talentAttributes: talent.attributes,
    ),
  );
  return TalentHerleitungen(
    taw: herleiteTalentTaw(
      eintrag: eintrag,
      ebe: ebe,
      inventar:
          snapshot.inventoryTalentQuellen[talent.id] ??
          const <InventoryModifierQuelle>[],
    ),
    ebe: ebe,
    eigenschaften: herleiteProbenEigenschaften(
      snapshot: snapshot,
      eigenschaften: eigenschaften ?? talent.attributes,
    ),
  );
}

/// Herleitungen des Talents [talentId] für den Helden des [snapshot].
///
/// `null`, wenn das Talent nicht im Katalog steht oder der Held keinen TaW
/// führt (nicht aktiviert).
TalentHerleitungen? talentHerleitungNachId({
  required HeroComputedSnapshot snapshot,
  required Iterable<TalentDef> talente,
  required String talentId,
  required bool epicAdvantagesActive,
  int? talentBeOverride,
}) {
  if (snapshot.hero.talents[talentId]?.talentValue == null) return null;
  for (final talent in talente) {
    if (talent.id != talentId) continue;
    return herleiteTalent(
      snapshot: snapshot,
      talent: talent,
      epicAdvantagesActive: epicAdvantagesActive,
      talentBeOverride: talentBeOverride,
    );
  }
  return null;
}

/// TaW* des Talents [talentId] für den Helden des [snapshot]; Summe von
/// [talentHerleitungNachId].
int? talentTawNachId({
  required HeroComputedSnapshot snapshot,
  required Iterable<TalentDef> talente,
  required String talentId,
  required bool epicAdvantagesActive,
  int? talentBeOverride,
}) => talentHerleitungNachId(
  snapshot: snapshot,
  talente: talente,
  talentId: talentId,
  epicAdvantagesActive: epicAdvantagesActive,
  talentBeOverride: talentBeOverride,
)?.taw.wert;

/// Ein Talent des Helden mit seinen Herleitungen für die Wertesuche.
class TalentUebersicht {
  /// Erzeugt den Eintrag; [id] ist die Talent- bzw. Meta-Talent-ID.
  const TalentUebersicht({
    required this.id,
    required this.name,
    required this.herleitungen,
  });

  /// Talent-ID (bei Meta-Talenten `meta-<id>`).
  final String id;

  /// Anzeigename.
  final String name;

  /// TaW*, eBE und Probenwerte.
  final TalentHerleitungen herleitungen;
}

/// Sammelt die Herleitungen aller Nicht-Kampftalente mit Wert und aller
/// Meta-Talente des Helden, alphabetisch nach Name.
///
/// Kampftalente stehen in den Kampfherleitungen (AT/PA); Talente ohne Wert
/// (eingeblendet, nicht aktiviert) bleiben außen vor.
List<TalentUebersicht> sammleTalentHerleitungen({
  required HeroComputedSnapshot snapshot,
  required Iterable<TalentDef> talente,
  required bool epicAdvantagesActive,
  int? talentBeOverride,
}) {
  final hero = snapshot.hero;
  final ergebnis = <TalentUebersicht>[];
  for (final talent in talente) {
    if (talent.group == 'Kampftalent') continue;
    if (hero.talents[talent.id]?.talentValue == null) continue;
    final herleitungen = herleiteTalent(
      snapshot: snapshot,
      talent: talent,
      epicAdvantagesActive: epicAdvantagesActive,
      talentBeOverride: talentBeOverride,
    );
    if (herleitungen == null) continue;
    ergebnis.add(
      TalentUebersicht(
        id: talent.id,
        name: talent.name,
        herleitungen: herleitungen,
      ),
    );
  }
  for (final meta in hero.metaTalents) {
    ergebnis.add(
      TalentUebersicht(
        id: 'meta-${meta.id}',
        name: meta.name,
        herleitungen: herleiteMetaTalent(
          snapshot: snapshot,
          metaTalent: meta,
          epicAdvantagesActive: epicAdvantagesActive,
          talentBeOverride: talentBeOverride,
        ),
      ),
    );
  }
  ergebnis.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ergebnis;
}

/// Herleitung des TaW* eines Meta-Talents aus den Werten seiner Bestandteile.
///
/// [talentEntries] darf ein ungespeicherter Entwurf sein. Die Summe entspricht
/// `computeMetaTalentComputedTaw`.
Herleitung herleiteMetaTalentTaw({
  required Map<String, HeroTalentEntry> talentEntries,
  required List<String> componentTalentIds,
  required Herleitung ebe,
}) {
  final werte = <int>[
    for (final id in componentTalentIds) talentEntries[id]?.talentValue ?? 0,
  ];
  final basis = splitMetaTalentBaseTaw(
    talentEntries: talentEntries,
    componentTalentIds: componentTalentIds,
  );
  return Herleitung(
    bezeichnung: 'TaW*',
    schritte: <HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: basis.gedeckelt
            ? 'Mittelwert der Bestandteile (gedeckelt)'
            : 'Mittelwert der Bestandteile',
        betrag: basis.wert,
        art: HerleitungsArt.grundwert,
        formel: werte.isEmpty
            ? null
            : '(${werte.join(' + ')}) / ${werte.length}, kaufmännisch '
                  'gerundet = ${basis.mittelwert}'
                  '${basis.gedeckelt ? ', höchstens das Doppelte des niedrigsten '
                            'Bestandteils (2 × ${basis.deckel ~/ 2} = '
                            '${basis.deckel})' : ''}',
      ),
      HerleitungsSchritt(
        bezeichnung: kTalentEbeSchritt,
        betrag: ebe.wert,
        art: HerleitungsArt.modifikator,
        quelle: 'Rüstung',
      ),
    ],
  );
}

/// Herleitung des TaW* eines heldenspezifischen Meta-Talents.
///
/// Der Grundwert ist der kaufmännisch gerundete Mittelwert der Bestandteile
/// (`computeMetaTalentBaseTaw`), dazu die eBE der Meta-BE-Regel. Meta-Talente
/// kennen weder Modifikatoren noch Inventarboni.
TalentHerleitungen herleiteMetaTalent({
  required HeroComputedSnapshot snapshot,
  required HeroMetaTalent metaTalent,
  required bool epicAdvantagesActive,
  int? talentBeOverride,
}) {
  final hero = snapshot.hero;
  final ebe = herleiteTalentEbe(
    beKampf: snapshot.combatPreviewStats.beKampf,
    beOverride: talentBeOverride,
    beRegel: metaTalent.be,
    reduktionsFaktor: epicTalentEbeMultiplier(
      ruleActive: epicAdvantagesActive,
      isEpisch: hero.isEpisch,
      mainAttributes: hero.epicMainAttributes,
      talentAttributes: metaTalent.attributes,
    ),
  );
  return TalentHerleitungen(
    taw: herleiteMetaTalentTaw(
      talentEntries: hero.talents,
      componentTalentIds: metaTalent.componentTalentIds,
      ebe: ebe,
    ),
    ebe: ebe,
    eigenschaften: herleiteProbenEigenschaften(
      snapshot: snapshot,
      eigenschaften: metaTalent.attributes,
    ),
  );
}
