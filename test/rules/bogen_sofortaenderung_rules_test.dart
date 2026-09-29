import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_status_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifikator_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';

// Sofortänderungen am gespeicherten Bogen (ARCH-05): Jede Funktion ändert
// nur ihre eigenen Felder, rechnet vom übergebenen (gespeicherten) Stand und
// gibt bei „nichts zu tun“ denselben Helden zurück.

const _held = HeroSheet(
  id: 'held',
  name: 'Rondra',
  level: 1,
  apTotal: 1000,
  apSpent: 400,
  dukaten: '12',
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
);

HeroTalentModifier _mod(int wert, String text) =>
    HeroTalentModifier(modifier: wert, description: text);

const _seil = HeroInventoryEntry(gegenstand: 'Seil', anzahl: '1');
const _fackel = HeroInventoryEntry(gegenstand: 'Fackel', anzahl: '3');

void main() {
  group('mitDauermodifikator', () {
    test('zählt vom gespeicherten Wert und ändert nur das Feld', () {
      final gespeichert = _held.copyWith(
        name: 'Fremd',
        persistentMods: const StatModifiers(
          gs: 2,
          at: -1,
          unbekannteFelder: {'zukunft': 1},
        ),
      );

      final ergebnis = mitDauermodifikator(
        gespeichert,
        Dauermodifikator.gs,
        const RessourcenAenderung.schritt(1),
      );

      expect(ergebnis.persistentMods.gs, 3);
      expect(ergebnis.persistentMods.at, -1);
      expect(ergebnis.persistentMods.unbekannteFelder, {'zukunft': 1});
      expect(ergebnis.name, 'Fremd');
    });

    test('jede Art trifft ihr eigenes Feld', () {
      for (final art in Dauermodifikator.values) {
        final ergebnis = mitDauermodifikator(
          _held,
          art,
          const RessourcenAenderung.schritt(-2),
        );
        expect(dauermodifikatorWert(ergebnis.persistentMods, art), -2);
        final andere = Dauermodifikator.values.where((a) => a != art);
        for (final anderer in andere) {
          expect(dauermodifikatorWert(ergebnis.persistentMods, anderer), 0);
        }
      }
    });

    test('Zurücksetzen auf 0 und „nichts zu tun“', () {
      final gespeichert = _held.copyWith(
        persistentMods: const StatModifiers(rs: 3),
      );

      final zurueck = mitDauermodifikator(
        gespeichert,
        Dauermodifikator.rs,
        const RessourcenAenderung.setzen(0),
      );
      expect(zurueck.persistentMods.rs, 0);

      final unveraendert = mitDauermodifikator(
        zurueck,
        Dauermodifikator.rs,
        const RessourcenAenderung.setzen(0),
      );
      expect(identical(unveraendert, zurueck), isTrue);
    });
  });

  group('benannte Modifikatoren', () {
    test('ersetzen nur ihren Schlüssel', () {
      final gespeichert = _held.copyWith(
        statModifiers: {
          'au': [_mod(2, 'Fremd')],
          'wundschwelle': [_mod(1, 'Alt')],
        },
      );

      final ergebnis = mitBenanntenStatModifikatoren(
        gespeichert,
        'wundschwelle',
        [_mod(2, 'Neu')],
      );

      expect(ergebnis.statModifiers['wundschwelle']!.single.description, 'Neu');
      expect(ergebnis.statModifiers['au']!.single.description, 'Fremd');
    });

    test('eine leere Liste entfernt den Schlüssel', () {
      final gespeichert = _held.copyWith(
        attributeModifiers: {
          'mu': [_mod(1, 'Mut')],
          'kk': [_mod(1, 'Kraft')],
        },
      );

      final ergebnis = mitBenanntenEigenschaftsModifikatoren(
        gespeichert,
        'mu',
        const [],
      );

      expect(ergebnis.attributeModifiers.containsKey('mu'), isFalse);
      expect(ergebnis.attributeModifiers['kk'], hasLength(1));
    });
  });

  test('mitApSchritt zählt vom gespeicherten Konto', () {
    final gesamt = mitApSchritt(_held, ApKonto.gesamt, 50);
    expect(gesamt.apTotal, 1050);
    expect(gesamt.apSpent, 400);

    final ausgegeben = mitApSchritt(_held, ApKonto.ausgegeben, 25);
    expect(ausgegeben.apSpent, 425);
    expect(ausgegeben.apTotal, 1000);
  });

  group('mitRessourcenSchaltern', () {
    test('schreibt nur den umgestellten Schalter', () {
      // Ein anderer Weg hat inzwischen Karma eingeschaltet.
      final gespeichert = _held.copyWith(
        resourceActivationConfig: const HeroResourceActivationConfig(
          divineEnabledOverride: true,
        ),
      );

      final ergebnis = mitRessourcenSchaltern(
        gespeichert,
        magieVorher: null,
        magie: false,
        goettlichVorher: null,
        goettlich: null,
      );

      final config = ergebnis.resourceActivationConfig;
      expect(config.magicEnabledOverride, isFalse);
      expect(config.divineEnabledOverride, isTrue);
    });

    test('ohne Umstellen bleibt der Held unverändert', () {
      final ergebnis = mitRessourcenSchaltern(
        _held,
        magieVorher: true,
        magie: true,
        goettlichVorher: null,
        goettlich: null,
      );
      expect(identical(ergebnis, _held), isTrue);
    });
  });

  test('quittiereEigenschaftsHinweis senkt nie eine neuere Version', () {
    final alt = _held.copyWith(schemaVersion: 20);
    expect(
      quittiereEigenschaftsHinweis(alt).schemaVersion,
      kAttributeTraitEffectSchemaVersion,
    );

    final neuer = _held.copyWith(schemaVersion: 40);
    expect(identical(quittiereEigenschaftsHinweis(neuer), neuer), isTrue);
  });

  group('epischer Status', () {
    const bonus = Attributes(
      mu: 2,
      kl: 1,
      inn: 0,
      ch: 0,
      ff: 0,
      ge: 2,
      ko: 0,
      kk: 0,
    );
    const haupt = Attributes(
      mu: 1,
      kl: 0,
      inn: 0,
      ch: 0,
      ff: 0,
      ge: 0,
      ko: 0,
      kk: 1,
    );

    test('Start-AP und offene Talente kommen aus dem gespeicherten Helden', () {
      final gespeichert = _held.copyWith(
        apSpent: 700,
        talents: const {
          'tal_klettern': HeroTalentEntry(talentValue: 5),
          'tal_reiten': HeroTalentEntry(),
        },
      );

      final ergebnis = aktiviereEpischenStatus(
        gespeichert,
        obergrenzenBonus: bonus,
        haupteigenschaften: haupt,
        policy: 'standard',
      );

      expect(ergebnis.isEpisch, isTrue);
      expect(ergebnis.epicStartAp, 700);
      expect(ergebnis.epicUnactivatedTalentIds, {'tal_reiten'});
      expect(ergebnis.epicAttributeMaxBonus.mu, 2);
      expect(ergebnis.epicMainAttributes.kk, 1);
      expect(ergebnis.epicActivationPolicy, 'standard');
    });

    test('eine zweite Aktivierung wird abgewiesen', () {
      final episch = _held.copyWith(isEpisch: true, epicStartAp: 300);
      expect(
        () => aktiviereEpischenStatus(
          episch,
          obergrenzenBonus: bonus,
          haupteigenschaften: haupt,
          policy: null,
        ),
        throwsStateError,
      );
    });

    test('Korrektur lässt Start-AP und Talentsperre stehen', () {
      final episch = _held.copyWith(
        isEpisch: true,
        epicStartAp: 300,
        epicActivationPolicy: 'paktierer',
        epicUnactivatedTalentIds: const {'tal_reiten'},
      );

      final ergebnis = korrigiereEpischenStatus(
        episch,
        obergrenzenBonus: bonus,
        haupteigenschaften: haupt,
        policy: null,
      );

      expect(ergebnis.epicStartAp, 300);
      expect(ergebnis.epicUnactivatedTalentIds, {'tal_reiten'});
      expect(ergebnis.epicActivationPolicy, isNull);
      expect(ergebnis.epicAttributeMaxBonus.ge, 2);
      expect(
        () => korrigiereEpischenStatus(
          _held,
          obergrenzenBonus: bonus,
          haupteigenschaften: haupt,
          policy: null,
        ),
        throwsStateError,
      );
    });
  });

  group('Inventar', () {
    test('Löschen trifft den Eintrag auch nach einer Verschiebung', () {
      // Angezeigt war das Seil an Position 0; inzwischen wurde davor eine
      // Fackel gespeichert.
      final gespeichert = _held.copyWith(
        inventoryEntries: const [_fackel, _seil],
      );

      final ergebnis = ohneInventarEintrag(gespeichert, _seil);

      expect(ergebnis.inventoryEntries.map((e) => e.gegenstand), ['Fackel']);
    });

    test('ein geänderter oder entfernter Eintrag wird gemeldet', () {
      final gespeichert = _held.copyWith(
        inventoryEntries: [_seil.copyWith(anzahl: '2')],
      );
      expect(
        () => ohneInventarEintrag(gespeichert, _seil),
        throwsA(
          isA<StateError>().having(
            (fehler) => fehler.message,
            'message',
            contains('inzwischen geändert'),
          ),
        ),
      );
    });

    test('verknüpfte Einträge sind hier nicht löschbar', () {
      const bogen = HeroInventoryEntry(
        gegenstand: 'Kurzbogen',
        source: InventoryItemSource.waffe,
        sourceRef: 'w:Kurzbogen',
      );
      final gespeichert = _held.copyWith(inventoryEntries: const [bogen]);
      expect(() => ohneInventarEintrag(gespeichert, bogen), throwsStateError);
    });

    test('findeGleichenInventarEintrag vergleicht den Inhalt', () {
      expect(findeGleichenInventarEintrag(const [_fackel, _seil], _seil), 1);
      expect(findeGleichenInventarEintrag(const [_fackel], _seil), -1);
    });

    test('Münzschritte zählen vom gespeicherten Geldstand', () {
      final ergebnis = mitDukatenSchritt(
        _held.copyWith(dukaten: '7'),
        dsaKreuzerPerSilber,
      );
      expect(ergebnis.dukaten, '7,1');
    });

    test('ein unlesbarer Geldstand wird gemeldet', () {
      expect(
        () => mitDukatenSchritt(
          _held.copyWith(dukaten: 'viel'),
          dsaKreuzerPerSilber,
        ),
        throwsStateError,
      );
    });

    test('ein gleicher eingetippter Betrag speichert nichts', () {
      expect(identical(mitDukaten(_held, ' 12 '), _held), isTrue);
      expect(mitDukaten(_held, '15').dukaten, '15');
    });
  });
}
