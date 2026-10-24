import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

part 'bestandshelden_regelwerte_basis_cases.dart';
part 'bestandshelden_regelwerte_ergaenzung_cases.dart';

// Flache, lesbare Auswahl der Werte, die ein Nutzer am Helden sieht.
Map<String, Object?> _projektion(
  HeroSheet held,
  HeroState zustand,
  EchterKatalog katalog, {
  required bool epischeVorteile,
}) {
  final snapshot = buildHeroComputedSnapshot(
    hero: held,
    state: zustand,
    catalog: katalog.catalog,
    epicAdvantagesActive: epischeVorteile,
  );
  final basis = snapshot.derivedStats;
  final kampf = snapshot.combatPreviewStats;
  return <String, Object?>{
    'maxLep': basis.maxLep,
    'maxAu': basis.maxAu,
    'maxAsp': basis.maxAsp,
    'maxKap': basis.maxKap,
    'mr': basis.mr,
    'iniBase': basis.iniBase,
    'atBase': basis.atBase,
    'paBase': basis.paBase,
    'fkBase': basis.fkBase,
    'gs': basis.gs,
    'ausweichen': basis.ausweichen,
    'eigenschaften': snapshot.effectiveAttributes.toJson(),
    'startwerte': snapshot.effectiveStartAttributes.toJson(),
    'maxima': snapshot.attributeMaximums.toJson(),
    'wundschwelle': snapshot.wundschwelle,
    // Wunden wirken auf Proben über Eigenschaftsverluste (WdS S. 108 f.).
    'wundEigenschaften': <String, Object?>{
      for (final eintrag
          in snapshot.wundEffekte.eigenschaftsVerluste.toJson().entries)
        if (eintrag.value != 0) eintrag.key: eintrag.value,
    },
    // Unterdrücken aller bestehenden Wunden (WdS S. 83), episch halbiert.
    'sbErschwernis': computeSbUnterdrueckungErschwernis(
      gesamtWunden: zustand.wpiZustand.gesamtWunden,
      halbiert: snapshot.wundEffekte.unterdrueckungHalbiert,
    ),
    'magie': snapshot.resourceActivation.magic.isEnabled,
    'karma': snapshot.resourceActivation.divine.isEnabled,
    'kampf': <String, Object?>{
      'rs': kampf.rsTotal,
      'be': kampf.beKampf,
      'at': kampf.at,
      'pa': kampf.pa,
      'ini': kampf.initiative,
      'ausweichen': kampf.ausweichen,
      'schildPa': kampf.shieldPa,
      'tp': kampf.tpExpression,
    },
    'hinweise': pendingAttributeTraitNotices(held),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  void pruefe(
    String name,
    Bestandsheld held, {
    required bool episch,
    WundZustand? wunden,
    HeroSheet Function(HeroSheet held)? aendern,
  }) {
    test(name, () {
      final bundle = ladeBestandsheld(held);
      final zustand = wunden == null
          ? bundle.state
          : bundle.state.copyWith(wpiZustand: wunden);
      final heldImTest = aendern == null ? bundle.hero : aendern(bundle.hero);
      final ist = _projektion(
        heldImTest,
        zustand,
        katalog,
        epischeVorteile: episch,
      );
      expect(ist, _erwartet[name]);
    });
  }

  test('alle eingebauten Hausregel-Pakete sind aktiv', () {
    expect(katalog.epicAdvantagesActive, isTrue);
  });

  for (final held in Bestandsheld.values) {
    pruefe(held.datei, held, episch: true);
  }

  // Nur im Speicher: Mit Linkshänder ist der verwundete linke Arm von f01
  // der Schwertarm (Katalogschalter `linkshaender`); die Fixture bleibt.
  pruefe(
    '${Bestandsheld.kriegerNormal.datei} mit Linkshänder',
    Bestandsheld.kriegerNormal,
    episch: true,
    aendern: (held) =>
        held.copyWith(vorteileText: '${held.vorteileText}, Linkshänder'),
  );

  // KO ist bei f04 Haupteigenschaft: Mit dem Hausregel-Paket fuer epische
  // Vorteile halbiert sich die SB-Erschwernis beim Unterdruecken, ohne es
  // nicht.
  const brustwunde = WundZustand(wundenProZone: {WundZone.brust: 1});
  pruefe(
    '${Bestandsheld.episch.datei} mit Brustwunde',
    Bestandsheld.episch,
    episch: true,
    wunden: brustwunde,
  );
  pruefe(
    '${Bestandsheld.episch.datei} mit Brustwunde ohne epische Vorteile',
    Bestandsheld.episch,
    episch: false,
    wunden: brustwunde,
  );
}
