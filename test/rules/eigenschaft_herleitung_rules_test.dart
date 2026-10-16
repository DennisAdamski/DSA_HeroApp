import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/eigenschaft_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

const _basis = Attributes(
  mu: 14,
  kl: 12,
  inn: 13,
  ch: 11,
  ff: 10,
  ge: 12,
  ko: 14,
  kk: 13,
);

HerleitungsSchritt _schritt(Herleitung h, String bezeichnung) =>
    h.schritte.singleWhere((s) => s.bezeichnung == bezeichnung);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Wert, eigene Modifikatoren, Inventar und Zauber als Schritte', () {
    final quellen = sammleEigenschaftQuellen(
      textMods: const AttributeModifiers(ko: 1),
      eigene: <String, List<HeroTalentModifier>>{
        'mu': <HeroTalentModifier>[
          HeroTalentModifier(modifier: 2, description: 'Mut des Löwen'),
        ],
      },
      inventar: const AttributeModifiers(mu: 1),
      temporaer: const AttributeModifiers(mu: 3),
    );
    final h = computeEigenschaftHerleitungen(
      gespeichert: _basis,
      quellen: quellen,
    );
    final mu = h.fuer('mu')!;
    expect(mu.wert, 14 + 2 + 1 + 3);
    expect(_schritt(mu, 'Eingetragener Wert').betrag, 14);
    expect(_schritt(mu, 'Mut des Löwen').quelle, 'Eigener Modifikator');
    expect(_schritt(mu, 'Temporär').art, HerleitungsArt.zauber);
    expect(_schritt(h.fuer('ko')!, 'Herkunft, Vor- und Nachteile').betrag, 1);
    // Der eigene MU-Modifikator wirkt nicht auf KO.
    expect(_schritt(h.fuer('ko')!, 'Mut des Löwen').betrag, 0);
    expect(h.werteAuf(_basis).mu, 20);
  });

  test('ohne temporäre Quelle fehlt der Zauberschritt', () {
    final h = computeEigenschaftHerleitungen(
      gespeichert: _basis,
      quellen: sammleEigenschaftQuellen(
        textMods: const AttributeModifiers(),
        eigene: const <String, List<HeroTalentModifier>>{},
      ),
    );
    expect(
      h.fuer('mu')!.schritte.where((s) => s.bezeichnung == 'Temporär'),
      isEmpty,
    );
    expect(h.werteAuf(_basis).toJson(), _basis.toJson());
  });

  test('eine unpassende Textaufteilung fällt auf einen Schritt zurück', () {
    final h = computeEigenschaftHerleitungen(
      gespeichert: _basis,
      quellen: sammleEigenschaftQuellen(
        textMods: const AttributeModifiers(kk: 1),
        eigene: const <String, List<HeroTalentModifier>>{},
        textAufteilung: const <EigenschaftModifikatorQuelle>[
          EigenschaftModifikatorQuelle(
            bezeichnung: 'Rasse',
            mods: AttributeModifiers(kk: 2),
          ),
        ],
      ),
    );
    final kk = h.fuer('kk')!;
    expect(kk.wert, 14);
    expect(kk.schritte.where((s) => s.bezeichnung == 'Rasse'), isEmpty);
  });

  group('Bestandshelden', () {
    late EchterKatalog katalog;

    setUpAll(() async {
      katalog = await ladeEchtenRegelkatalog();
    });

    for (final bestand in Bestandsheld.values) {
      test('${bestand.datei}: Herleitung gleicht den effektiven Werten', () {
        final bundle = ladeBestandsheld(bestand);
        final snapshot = buildHeroComputedSnapshot(
          hero: bundle.hero,
          state: bundle.state.copyWith(
            wpiZustand: const WundZustand(
              wundenProZone: <WundZone, int>{WundZone.kopf: 1},
            ),
          ),
          catalog: katalog.catalog,
          epicAdvantagesActive: true,
        );
        final h = snapshot.eigenschaftHerleitungen!;
        expect(
          h.werteAuf(bundle.hero.attributes).toJson(),
          snapshot.effectiveAttributes.toJson(),
        );
        for (final key in kEigenschaftSchluessel) {
          expect(
            h
                .fuer(key)!
                .schritte
                .any((s) => s.bezeichnung == 'Herkunft, Vor- und Nachteile'),
            isFalse,
            reason: '${bestand.datei} $key',
          );
        }
      });
    }
  });
}
