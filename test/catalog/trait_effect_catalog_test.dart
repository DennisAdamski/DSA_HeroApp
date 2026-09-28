import 'package:dsa_heldenverwaltung/catalog/hero_trait_def.dart';
import 'package:dsa_heldenverwaltung/catalog/hero_trait_effect.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_reference_names.dart';

/// Prueft die deklarativen Wirkungen (`wirkungen`) der Vor- und Nachteile.
///
/// Eine unbekannte Art oder ein Tippfehler im Ziel wirkte im Betrieb still
/// gar nicht; ein fehlender Eintrag liesse einen Bestandshelden nach der
/// Umstellung auf Katalog-IDs Werte verlieren.
void main() {
  final advantages = ladeKatalogDatei('vorteile.json')
      .map(HeroTraitDef.fromJson)
      .toList(growable: false);
  final disadvantages = ladeKatalogDatei('nachteile.json')
      .map(HeroTraitDef.fromJson)
      .toList(growable: false);
  final alle = <HeroTraitDef>[...advantages, ...disadvantages];

  test('jede Wirkung hat eine bekannte Art und ein bekanntes Ziel', () {
    final fehler = <String>[];
    for (final trait in alle) {
      for (final wirkung in trait.wirkungen) {
        final ziele = kHeroTraitEffectZiele[wirkung.art];
        if (ziele == null) {
          fehler.add('${trait.id}: Art "${wirkung.rohArt}"');
          continue;
        }
        if (!ziele.contains(wirkung.ziel)) {
          fehler.add('${trait.id}: Ziel "${wirkung.ziel}"');
        }
      }
    }
    expect(fehler, isEmpty);
  });

  test('Wirkungen stehen nur an passenden Merkmalsarten', () {
    for (final trait in alle) {
      for (final wirkung in trait.wirkungen) {
        if (wirkung.art == HeroTraitEffectArt.eigenschaft) {
          expect(
            trait.selectionTemplate,
            contains('{choice}'),
            reason: '${trait.id}: Eigenschaft kommt aus der Auswahl',
          );
        }
        if (wirkung.art == HeroTraitEffectArt.basiswert) {
          expect(
            trait.selectionTemplate,
            contains('{value}'),
            reason: '${trait.id}: Betrag kommt aus dem Wert',
          );
          expect(wirkung.max, isNotNull, reason: trait.id);
        }
      }
    }
  });

  test('alle bisher per Namen wirkenden Merkmale tragen Wirkungen', () {
    final mitWirkung = <String>{
      for (final trait in alle)
        if (trait.wirkungen.isNotEmpty) trait.id,
    };
    expect(mitWirkung, <String>{
      'adv_hohe_lebenskraft',
      'adv_ausdauernd',
      'adv_astralmacht',
      'adv_hohe_magieresistenz',
      'adv_herausragende_eigenschaft',
      'adv_flink',
      'adv_eisern',
      'adv_schnelle_heilung',
      'adv_astrale_regeneration',
      'dis_niedrige_lebenskraft',
      'dis_kurzatmig',
      'dis_niedrige_astralkraft',
      'dis_niedrige_magieresistenz',
      'dis_behaebig',
      'dis_glasknochen',
      'dis_schlechte_regeneration',
      'dis_astraler_block_zauberer',
      'dis_astraler_block_viertelzauberer',
    });
  });

  test('Vorzeichen folgen der Merkmalsart', () {
    for (final trait in advantages) {
      for (final wirkung in trait.wirkungen) {
        expect(wirkung.jeWert, greaterThan(0), reason: trait.id);
        expect(wirkung.betrag, greaterThanOrEqualTo(0), reason: trait.id);
      }
    }
    for (final trait in disadvantages) {
      for (final wirkung in trait.wirkungen) {
        if (wirkung.art == HeroTraitEffectArt.basiswert) {
          expect(wirkung.jeWert, lessThan(0), reason: trait.id);
        }
        expect(wirkung.betrag, lessThanOrEqualTo(0), reason: trait.id);
      }
    }
  });

  test('toJson/fromJson ist verlustfrei, auch fuer unbekannte Arten', () {
    for (final trait in alle) {
      final zurueck = HeroTraitDef.fromJson(trait.toJson());
      expect(
        zurueck.wirkungen.map((w) => w.toJson()).toList(),
        trait.wirkungen.map((w) => w.toJson()).toList(),
      );
    }
    final unbekannt = HeroTraitEffect.fromJson(const <String, dynamic>{
      'art': 'zukunft',
      'ziel': 'x',
    });
    expect(unbekannt.art, HeroTraitEffectArt.unbekannt);
    expect(unbekannt.toJson(), <String, dynamic>{
      'art': 'zukunft',
      'ziel': 'x',
    });
  });
}
