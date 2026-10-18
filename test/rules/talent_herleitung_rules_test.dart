import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung_uebersicht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_value_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  HeroComputedSnapshot snapshotFuer(
    Bestandsheld bestand, {
    HeroSheet Function(HeroSheet hero)? heldAnpassen,
  }) {
    final bundle = ladeBestandsheld(bestand);
    return buildHeroComputedSnapshot(
      hero: heldAnpassen == null ? bundle.hero : heldAnpassen(bundle.hero),
      state: bundle.state,
      catalog: katalog.catalog,
      epicAdvantagesActive: true,
    );
  }

  TalentDef talentMitKk() => katalog.catalog.talents.firstWhere(
    (t) =>
        t.group != 'Kampftalent' &&
        t.be.trim().toLowerCase().startsWith('x') &&
        t.attributes.any((a) => parseAttributeCode(a) == AttributeCode.kk),
  );

  group('Gleichheit mit den bisherigen Formeln', () {
    for (final bestand in Bestandsheld.values) {
      for (final override in <int?>[null, 4]) {
        test('${bestand.name}, BE-Override $override', () {
          final snapshot = snapshotFuer(bestand);
          var geprueft = 0;
          for (final talent in katalog.catalog.talents) {
            final eintrag = snapshot.hero.talents[talent.id];
            if (eintrag == null || talent.group == 'Kampftalent') continue;
            final h = herleiteTalent(
              snapshot: snapshot,
              talent: talent,
              epicAdvantagesActive: true,
              talentBeOverride: override,
            );
            expect(h, isNotNull, reason: talent.id);
            final ebe = computeTalentEbe(
              baseBe: override ?? snapshot.combatPreviewStats.beKampf,
              talentBeRule: talent.be,
              reductionMultiplier: 1.0,
            );
            // Epische Halbierung wirkt nur, wenn KK Haupteigenschaft ist; die
            // Bestandshelden besitzen keine, außer f04 (siehe eigener Test).
            if (!snapshot.hero.isEpisch) {
              expect(h!.ebe.wert, ebe, reason: talent.id);
            }
            expect(
              h!.taw.wert,
              computeTalentComputedTaw(
                talentValue: eintrag.talentValue,
                modifier: eintrag.modifier,
                ebe: h.ebe.wert,
                inventoryMod: snapshot.inventoryTalentMods[talent.id] ?? 0,
              ),
              reason: talent.id,
            );
            final wert = talentProbenwertFuer(
              snapshot: snapshot,
              talent: talent,
              epicAdvantagesActive: true,
              talentBeOverride: override,
            );
            if (wert != null) {
              expect(wert.taw, h.taw.wert, reason: talent.id);
              expect(wert.ebe, h.ebe.wert, reason: talent.id);
              expect(
                wert.ziele.map((z) => z.value),
                h.eigenschaften.map((e) => e.wert),
                reason: talent.id,
              );
            }
            geprueft++;
          }
          // Einige Bestandshelden führen keine Talente.
          if (bestand == Bestandsheld.kriegerNormal) {
            expect(geprueft, greaterThan(0));
          }
        });
      }
    }
  });

  group('eBE', () {
    test('zeigt die situative BE-Anpassung als eigenen Schritt', () {
      final talent = talentMitKk();
      final h = herleiteTalentEbe(
        beKampf: 2,
        beOverride: 5,
        beRegel: talent.be,
      );
      final anpassung = h.schritte.singleWhere(
        (s) => s.bezeichnung == kTalentBeAnpassungSchritt,
      );
      expect(
        anpassung.betrag,
        computeTalentEbe(baseBe: 5, talentBeRule: talent.be) -
            computeTalentEbe(baseBe: 2, talentBeRule: talent.be),
      );
      expect(anpassung.formel, contains('2'));
      expect(anpassung.formel, contains('5'));
      expect(h.wert, computeTalentEbe(baseBe: 5, talentBeRule: talent.be));
    });

    test('ohne Override ist die Anpassung 0 und unsichtbar', () {
      final h = herleiteTalentEbe(beKampf: 3, beRegel: 'x2');
      expect(h.wert, -6);
      expect(
        h.sichtbareSchritte.map((s) => s.bezeichnung),
        isNot(contains(kTalentBeAnpassungSchritt)),
      );
    });

    test('Override 0 hebt die Behinderung auf', () {
      final h = herleiteTalentEbe(beKampf: 3, beOverride: 0, beRegel: 'x2');
      expect(h.wert, 0);
      expect(h.schritte.first.betrag, -6);
    });

    test('epische KK-Halbierung ist ein eigener Ausgleichsschritt', () {
      final h = herleiteTalentEbe(
        beKampf: 4,
        beRegel: 'x2',
        reduktionsFaktor: 0.5,
      );
      expect(
        h.wert,
        computeTalentEbe(
          baseBe: 4,
          talentBeRule: 'x2',
          reductionMultiplier: 0.5,
        ),
      );
      final halbierung = h.schritte.singleWhere(
        (s) => s.bezeichnung == kTalentEpischeHalbierungSchritt,
      );
      expect(halbierung.betrag, 4);
      expect(h.wert, -4);
    });

    test('Talent ohne BE-Regel hat eBE 0', () {
      final h = herleiteTalentEbe(beKampf: 5, beRegel: '-');
      expect(h.wert, 0);
    });

    test('feste Reduktion (-N) wird wie computeTalentEbe gerechnet', () {
      for (final be in [0, 1, 2, 3, 6]) {
        final h = herleiteTalentEbe(
          beKampf: be,
          beOverride: be + 1,
          beRegel: '-2',
        );
        expect(
          h.wert,
          computeTalentEbe(baseBe: be + 1, talentBeRule: '-2'),
          reason: 'BE $be',
        );
      }
    });
  });

  group('TaW*', () {
    test('Modifikatoren und Inventar erscheinen einzeln', () {
      final talent = talentMitKk();
      final snapshot = snapshotFuer(
        Bestandsheld.kriegerNormal,
        heldAnpassen: (h) {
          return h.copyWith(
            talents: <String, HeroTalentEntry>{
              ...h.talents,
              talent.id: HeroTalentEntry(
                talentValue: 8,
                talentModifiers: <HeroTalentModifier>[
                  HeroTalentModifier(modifier: 2, description: 'Übung'),
                  HeroTalentModifier(modifier: -1, description: 'Müde'),
                ],
              ),
            },
            inventoryEntries: <HeroInventoryEntry>[
              HeroInventoryEntry(
                gegenstand: 'Kletterhaken',
                itemType: InventoryItemType.ausruestung,
                istAusgeruestet: true,
                modifiers: <InventoryItemModifier>[
                  InventoryItemModifier(
                    kind: InventoryModifierKind.talent,
                    targetId: talent.id,
                    wert: 3,
                  ),
                ],
              ),
              HeroInventoryEntry(
                gegenstand: 'Seil',
                itemType: InventoryItemType.ausruestung,
                istAusgeruestet: true,
                modifiers: <InventoryItemModifier>[
                  InventoryItemModifier(
                    kind: InventoryModifierKind.talentgruppe,
                    targetId: talent.group,
                    wert: 1,
                  ),
                ],
              ),
            ],
          );
        },
      );
      final h = herleiteTalent(
        snapshot: snapshot,
        talent: talent,
        epicAdvantagesActive: true,
        talentBeOverride: 0,
      )!;
      final namen = h.taw.schritte.map((s) => s.bezeichnung).toList();
      expect(
        namen,
        containsAll(<String>[
          kTalentTawSchritt,
          'Übung',
          'Müde',
          'Kletterhaken',
          'Seil',
          kTalentEbeSchritt,
        ]),
      );
      final seil = h.taw.schritte.firstWhere((s) => s.bezeichnung == 'Seil');
      expect(seil.bedingung, contains(talent.group));
      expect(seil.quelle, 'Ausrüstung');
      expect(h.taw.wert, 8 + 2 - 1 + 3 + 1 + 0);
      expect(h.taw.wert, snapshot.hero.talents[talent.id]!.talentValue! + 5);
    });

    test('Altmodifikator ohne Bausteine bleibt ein Schritt', () {
      final h = herleiteTalentTaw(
        eintrag: const HeroTalentEntry(talentValue: 5, modifier: 2),
        ebe: Herleitung(bezeichnung: 'eBE', schritte: const []),
      );
      expect(h.wert, 7);
      expect(
        h.sichtbareSchritte.map((s) => s.bezeichnung),
        containsAll(<String>[kTalentTawSchritt, 'Modifikator']),
      );
    });

    test('Talent ohne Wert zählt als TaW 0', () {
      final h = herleiteTalentTaw(
        eintrag: const HeroTalentEntry(),
        ebe: Herleitung(bezeichnung: 'eBE', schritte: const []),
      );
      expect(h.wert, 0);
    });
  });

  group('Probenwerte', () {
    test('Wunden stehen als eigener Schritt auf der Eigenschaft', () {
      final snapshot = snapshotFuer(Bestandsheld.kriegerNormal);
      final talent = katalog.catalog.talents.firstWhere(
        (t) =>
            snapshot.hero.talents.containsKey(t.id) && t.group != 'Kampftalent',
      );
      final h = herleiteTalent(
        snapshot: snapshot,
        talent: talent,
        epicAdvantagesActive: true,
      )!;
      expect(h.eigenschaften, hasLength(3));
      for (final e in h.eigenschaften) {
        expect(
          e.schritte.any((s) => s.bezeichnung == kTalentWundenSchritt),
          isTrue,
        );
        final code = parseAttributeCode(e.bezeichnung)!;
        expect(e.wert, readAttributeValue(snapshot.probenEigenschaften, code));
      }
    });

    test('Wundverlust fließt als Betrag ein', () {
      final snapshot = snapshotFuer(Bestandsheld.kriegerNormal);
      final verletzt = HeroComputedSnapshot(
        hero: snapshot.hero,
        state: snapshot.state,
        modifierParse: snapshot.modifierParse,
        resourceActivation: snapshot.resourceActivation,
        effectiveStartAttributes: snapshot.effectiveStartAttributes,
        attributeMaximums: snapshot.attributeMaximums,
        effectiveAttributes: snapshot.effectiveAttributes,
        probenEigenschaften: snapshot.probenEigenschaften.copyWith(
          mu: snapshot.effectiveAttributes.mu - 2,
        ),
        derivedStats: snapshot.derivedStats,
        combatPreviewStats: snapshot.combatPreviewStats,
        wundEffekte: snapshot.wundEffekte,
        wundschwelle: snapshot.wundschwelle,
        wundschwellenStufen: snapshot.wundschwellenStufen,
        eigenschaftHerleitungen: snapshot.eigenschaftHerleitungen,
      );
      final liste = herleiteProbenEigenschaften(
        snapshot: verletzt,
        eigenschaften: const <String>['MU', 'KL', 'IN'],
      );
      final mu = liste.first;
      expect(
        mu.schritte
            .singleWhere((s) => s.bezeichnung == kTalentWundenSchritt)
            .betrag,
        -2,
      );
      expect(mu.wert, snapshot.effectiveAttributes.mu - 2);
      expect(liste[1].wert, snapshot.effectiveAttributes.kl);
    });
  });

  group('Meta-Talente', () {
    test('Mittelwert und eBE stimmen mit den Metaformeln überein', () {
      final ids = katalog.catalog.talents
          .where((t) => t.group != 'Kampftalent')
          .take(3)
          .map((t) => t.id)
          .toList();
      final meta = HeroMetaTalent(
        id: 'm1',
        name: 'Testmeta',
        componentTalentIds: ids,
        attributes: const <String>['MU', 'KL', 'KK'],
        be: 'x1',
      );
      final snapshot = snapshotFuer(
        Bestandsheld.kriegerNormal,
        heldAnpassen: (h) {
          return h.copyWith(
            talents: <String, HeroTalentEntry>{
              ...h.talents,
              ids[0]: const HeroTalentEntry(talentValue: 8),
              ids[1]: const HeroTalentEntry(talentValue: 7),
              ids[2]: const HeroTalentEntry(talentValue: 10),
            },
            metaTalents: <HeroMetaTalent>[meta],
          );
        },
      );
      final h = herleiteMetaTalent(
        snapshot: snapshot,
        metaTalent: meta,
        epicAdvantagesActive: true,
        talentBeOverride: 3,
      );
      final basis = computeMetaTalentBaseTaw(
        talentEntries: snapshot.hero.talents,
        componentTalentIds: ids,
      );
      expect(basis, 8);
      expect(
        h.taw.wert,
        computeMetaTalentComputedTaw(
          baseTaw: basis,
          ebe: computeMetaTalentEbe(baseBe: 3, beRule: 'x1'),
        ),
      );
      expect(h.taw.schritte.first.formel, contains('8 + 7 + 10'));
    });
  });

  group('talentTawNachId (Selbstbeherrschung beim Unterdrücken)', () {
    HeroComputedSnapshot mitSb({int? wert, int bonus = 0}) => snapshotFuer(
      Bestandsheld.kriegerNormal,
      heldAnpassen: (h) => h.copyWith(
        talents: <String, HeroTalentEntry>{
          ...h.talents,
          'tal_selbstbeherrschung': HeroTalentEntry(
            talentValue: wert,
            modifier: 1,
          ),
        },
        inventoryEntries: <HeroInventoryEntry>[
          if (bonus != 0)
            HeroInventoryEntry(
              gegenstand: 'Amulett',
              itemType: InventoryItemType.ausruestung,
              istAusgeruestet: true,
              modifiers: <InventoryItemModifier>[
                InventoryItemModifier(
                  kind: InventoryModifierKind.talent,
                  targetId: 'tal_selbstbeherrschung',
                  wert: bonus,
                ),
              ],
            ),
        ],
      ),
    );

    test('zählt Modifikator und Ausrüstung mit', () {
      final taw = talentTawNachId(
        snapshot: mitSb(wert: 8, bonus: 2),
        talente: katalog.catalog.talents,
        talentId: 'tal_selbstbeherrschung',
        epicAdvantagesActive: true,
      );
      final talent = katalog.catalog.talents.firstWhere(
        (t) => t.id == 'tal_selbstbeherrschung',
      );
      final ebe = computeTalentEbe(
        baseBe: mitSb(wert: 8).combatPreviewStats.beKampf,
        talentBeRule: talent.be,
      );
      expect(taw, 8 + 1 + 2 + ebe);
    });

    test('Herleitung nach ID summiert sich zum TaW*', () {
      final snapshot = mitSb(wert: 8, bonus: 2);
      final herleitung = talentHerleitungNachId(
        snapshot: snapshot,
        talente: katalog.catalog.talents,
        talentId: 'tal_selbstbeherrschung',
        epicAdvantagesActive: true,
      )!;
      expect(
        herleitung.taw.wert,
        talentTawNachId(
          snapshot: snapshot,
          talente: katalog.catalog.talents,
          talentId: 'tal_selbstbeherrschung',
          epicAdvantagesActive: true,
        ),
      );
      expect(
        herleitung.taw.schritte.map((s) => s.bezeichnung),
        contains('Amulett'),
      );
    });

    test('null ohne Wert oder unbekanntes Talent', () {
      expect(
        talentTawNachId(
          snapshot: mitSb(),
          talente: katalog.catalog.talents,
          talentId: 'tal_selbstbeherrschung',
          epicAdvantagesActive: true,
        ),
        isNull,
      );
      expect(
        talentTawNachId(
          snapshot: mitSb(wert: 3),
          talente: katalog.catalog.talents,
          talentId: 'tal_gibt_es_nicht',
          epicAdvantagesActive: true,
        ),
        isNull,
      );
    });
  });

  group('Übersicht und Suche', () {
    test('Talente stehen als letzter Bereich und lassen sich suchen', () {
      final talent = talentMitKk();
      final snapshot = snapshotFuer(
        Bestandsheld.kriegerNormal,
        heldAnpassen: (h) {
          return h.copyWith(
            talents: <String, HeroTalentEntry>{
              ...h.talents,
              talent.id: const HeroTalentEntry(talentValue: 6),
            },
            inventoryEntries: <HeroInventoryEntry>[
              HeroInventoryEntry(
                gegenstand: 'Kletterhaken',
                itemType: InventoryItemType.ausruestung,
                istAusgeruestet: true,
                modifiers: <InventoryItemModifier>[
                  InventoryItemModifier(
                    kind: InventoryModifierKind.talent,
                    targetId: talent.id,
                    wert: 2,
                  ),
                ],
              ),
            ],
          );
        },
      );
      final talente = sammleTalentHerleitungen(
        snapshot: snapshot,
        talente: katalog.catalog.talents,
        epicAdvantagesActive: true,
      );
      expect(talente.any((t) => t.id == talent.id), isTrue);
      expect(
        talente.every((t) => !t.id.startsWith('tal_') || t.id.isNotEmpty),
        isTrue,
      );
      final eintraege = sammleHerleitungen(
        eigenschaften: snapshot.eigenschaftHerleitungen,
        basiswerte: snapshot.derivedStats.herleitungen,
        kampf: snapshot.combatPreviewStats,
        talente: talente,
      );
      final bereiche = eintraege.map((e) => e.bereich.index).toList();
      expect(bereiche, orderedEquals(List<int>.of(bereiche)..sort()));
      final eintrag = eintraege.singleWhere(
        (e) => e.id == 'talent-${talent.id}',
      );
      expect(eintrag.bereich, HerleitungsBereich.talente);
      expect(eintrag.ergebnisText, '${eintrag.herleitung.wert}');
      final treffer = filtereHerleitungen(eintraege, 'kletterhaken');
      expect(treffer.map((e) => e.id), contains('talent-${talent.id}'));
    });

    test('Kampftalente und Talente ohne Wert fehlen', () {
      final snapshot = snapshotFuer(Bestandsheld.kriegerNormal);
      final talente = sammleTalentHerleitungen(
        snapshot: snapshot,
        talente: katalog.catalog.talents,
        epicAdvantagesActive: true,
      );
      final kampfIds = katalog.catalog.talents
          .where((t) => t.group == 'Kampftalent')
          .map((t) => t.id)
          .toSet();
      for (final t in talente) {
        expect(kampfIds, isNot(contains(t.id)));
        expect(snapshot.hero.talents[t.id]?.talentValue, isNotNull);
      }
    });
  });
}
