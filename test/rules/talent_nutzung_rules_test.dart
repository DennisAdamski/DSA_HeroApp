import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_magie_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_nutzung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_probe_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_probenwahl.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  TalentDef talent(String id) =>
      katalog.catalog.talents.firstWhere((t) => t.id == id);

  HeroSheet held(Map<String, HeroTalentEntry> talente) {
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
    return bundle.hero.copyWith(talents: talente);
  }

  HeroComputedSnapshot snapshot(Map<String, HeroTalentEntry> talente) {
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
    return buildHeroComputedSnapshot(
      hero: held(talente),
      state: bundle.state,
      catalog: katalog.catalog,
      epicAdvantagesActive: false,
    );
  }

  group('talentEintragFuerProbe', () {
    test('Basis-Talent: ohne Eintrag, ohne Wert und negativ erlaubt', () {
      final klettern = talent('tal_klettern');
      expect(talentEintragFuerProbe(held({}), klettern)?.talentValue, 0);
      expect(
        talentEintragFuerProbe(
          held({'tal_klettern': const HeroTalentEntry()}),
          klettern,
        ),
        isNotNull,
      );
      expect(
        talentEintragFuerProbe(
          held({'tal_klettern': const HeroTalentEntry(talentValue: -2)}),
          klettern,
        )?.talentValue,
        -2,
      );
    });

    test('Spezial-Talent: nur mit Wert von mindestens 0', () {
      final reiten = talent('tal_reiten');
      expect(talentEintragFuerProbe(held({}), reiten), isNull);
      expect(
        talentEintragFuerProbe(
          held({'tal_reiten': const HeroTalentEntry()}),
          reiten,
        ),
        isNull,
      );
      expect(
        talentEintragFuerProbe(
          held({'tal_reiten': const HeroTalentEntry(talentValue: -1)}),
          reiten,
        ),
        isNull,
      );
      expect(
        talentEintragFuerProbe(
          held({'tal_reiten': const HeroTalentEntry(talentValue: 0)}),
          reiten,
        ),
        isNotNull,
      );
    });

    test('unbekanntes Talent verlangt einen Wert', () {
      const eigen = TalentDef(
        id: 'tal_eigen',
        name: 'Eigen',
        group: 'Wissenstalente',
        steigerung: 'B',
        attributes: ['Mut', 'Klugheit', 'Intuition'],
      );
      expect(talentEintragFuerProbe(held({}), eigen), isNull);
      expect(
        talentEintragFuerProbe(
          held({'tal_eigen': const HeroTalentEntry()}),
          eigen,
        ),
        isNull,
      );
      expect(
        talentEintragFuerProbe(
          held({'tal_eigen': const HeroTalentEntry(talentValue: 2)}),
          eigen,
        ),
        isNotNull,
      );
    });
  });

  group('Proben', () {
    test('Basis-Talent ohne Eintrag liefert TaW* aus TaW 0', () {
      final s = snapshot({});
      final sinne = talent('tal_sinnesschaerfe');
      final wert = talentProbenwertFuer(
        snapshot: s,
        talent: sinne,
        epicAdvantagesActive: false,
      );
      expect(wert, isNotNull);
      expect(wert!.taw, wert.ebe);
      expect(gefechtsTalentprobe(s, sinne), isNotNull);
    });

    test('Spezial-Talent ohne Wert liefert keine Probe', () {
      final s = snapshot({'tal_reiten': const HeroTalentEntry()});
      expect(
        talentProbenwertFuer(
          snapshot: s,
          talent: talent('tal_reiten'),
          epicAdvantagesActive: false,
        ),
        isNull,
      );
      expect(gefechtsTalentprobe(s, talent('tal_reiten')), isNull);
    });
  });

  group('Ausweichen', () {
    test('Optionen nennen nur Talente, die der Held proben darf', () {
      final optionen = talentErsatzOptionen(
        hero: held({}),
        talent: talent('tal_reiten'),
        katalog: katalog.catalog.talents,
      );
      // Körperbeherrschung ist Basis, Akrobatik nicht aktiviert.
      expect(optionen.map((o) => o.talent.id), ['tal_koerperbeherrschung']);
      expect(optionen.single.zuschlag, 10);
      final mitAkrobatik = talentErsatzOptionen(
        hero: held({'tal_akrobatik': const HeroTalentEntry(talentValue: 5)}),
        talent: talent('tal_reiten'),
        katalog: katalog.catalog.talents,
      );
      expect(mitAkrobatik.map((o) => o.talent.id), [
        'tal_koerperbeherrschung',
        'tal_akrobatik',
      ]);
    });

    test('Ersatzprobe zieht den Zuschlag vom TaW* des Ersatztalents ab', () {
      final s = snapshot({
        'tal_koerperbeherrschung': const HeroTalentEntry(talentValue: 12),
      });
      final option = talentErsatzOptionen(
        hero: s.hero,
        talent: talent('tal_reiten'),
        katalog: katalog.catalog.talents,
      ).first;
      final basis = talentProbenwertFuer(
        snapshot: s,
        talent: talent('tal_koerperbeherrschung'),
        epicAdvantagesActive: false,
      )!;
      final probe = talentErsatzprobeFuer(
        snapshot: s,
        talent: talent('tal_reiten'),
        option: option,
        epicAdvantagesActive: false,
      )!;
      expect(probe.basePool, basis.taw - 10);
      expect(probe.title, contains('Reiten'));
      expect(probe.title, contains('Körperbeherrschung'));
      expect(
        probe.targets.map((t) => t.label),
        basis.ziele.map((t) => t.label),
      );
    });

    test('talentErsatzproben listet nur nicht erlaubte Talente', () {
      final s = snapshot({'tal_reiten': const HeroTalentEntry(talentValue: 6)});
      final liste = talentErsatzproben(
        snapshot: s,
        katalog: katalog.catalog.talents,
        epicAdvantagesActive: false,
      );
      expect(liste, isNotEmpty);
      expect(liste.any((e) => e.talent.id == 'tal_reiten'), isFalse);
      expect(liste.any((e) => e.talent.id == 'tal_skifahren'), isTrue);
      expect(
        liste.every((e) => talentEintragFuerProbe(s.hero, e.talent) == null),
        isTrue,
      );
    });

    test('Gefecht zeigt Ausweichproben nur als markierte Kandidaten', () {
      final s = snapshot({});
      final kandidaten = gefechtsProbenkandidaten(
        s,
        katalog.catalog,
        epicAdvantagesActive: false,
      );
      final ausweichen = kandidaten.where((k) => k.ausweichen).toList();
      expect(ausweichen, isNotEmpty);
      expect(ausweichen.any((k) => k.name.startsWith('Reiten (über')), isTrue);
      // Basis-Talente erscheinen ohne Eintrag, Spezial-Talente nicht direkt.
      final direkt = kandidaten.where((k) => !k.ausweichen).map((k) => k.name);
      expect(direkt, contains('Klettern'));
      expect(direkt, isNot(contains('Reiten')));
    });
  });
}
