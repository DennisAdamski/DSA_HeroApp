import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

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

/// Erwartete Werte je Fall.
///
/// Aktualisieren nur im selben Commit wie eine gewollte Regel- oder
/// Kataloganpassung, mit Zeilenkommentar zum Grund; nie per Kopie der
/// Ist-Ausgabe. Waffenslots ohne TP/KK-Angabe (Schwelle 1) rechnen die volle
/// KK als TP-Bonus, wie die App es bei unvollständig gepflegten Waffen tut —
/// daher etwa `1W6+13` beim Magierstab von f02.
const Map<String, Map<String, Object?>>
_erwartet = <String, Map<String, Object?>>{
  'f01_krieger_normal': <String, Object?>{
    'maxLep': 42,
    'maxAu': 48,
    'maxAsp': 33,
    'maxKap': 0,
    'mr': 5,
    'iniBase': 13,
    // Eine Wunde am linken Arm (Schildarm): allgemein AT/PA/FK −2, der
    // Armanteil AT/PA −2 trifft nur den Schild (WdS S. 58, 108 f.). Bis
    // ARCH-05 (6) rechnete sie AT/PA −4 und FK −6 für alle Waffen: 4/4/1.
    'atBase': 6,
    'paBase': 6,
    'fkBase': 5,
    'gs': 3,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 15,
      'kl': 10,
      'inn': 12,
      'ch': 11,
      'ff': 11,
      'ge': 13,
      'ko': 14,
      'kk': 14,
    },
    'startwerte': <String, Object?>{
      'mu': 13,
      'kl': 10,
      'inn': 12,
      'ch': 11,
      'ff': 11,
      'ge': 12,
      'ko': 13,
      'kk': 14,
    },
    'maxima': <String, Object?>{
      'mu': 20,
      'kl': 15,
      'inn': 18,
      'ch': 17,
      'ff': 17,
      'ge': 18,
      'ko': 20,
      'kk': 21,
    },
    // KO 14 / 2 + Eisern 2 (WdS S. 58); bis ARCH-05 (4) ohne Eisern: 7.
    'wundschwelle': 9,
    // Statt pauschal Proben −3: GE −2 allgemein, FF/KK −2 vom Arm.
    'wundEigenschaften': <String, Object?>{'ff': -2, 'ge': -2, 'kk': -2},
    'sbErschwernis': 4,
    'magie': false,
    'karma': false,
    // Die Hauptwaffe liegt im Schwertarm und trägt nur die allgemeinen −2
    // (bis ARCH-05 (6): 9/8, vor ARCH-07-B7: 13/12). Ausweichen folgt der
    // PA-Basis: 6 − BE 4 = 2 (bis ARCH-05 (6): 0). Der Holzschild trägt den
    // Armanteil und eBE-PA-Anteil 1 (WdS 71, MCP 7016):
    // PA-Basis 6 + Schild-WM 3 − Armwunde 2 − eBE 1 = 6; bisher ohne eBE: 7.
    'kampf': <String, Object?>{
      'rs': 4,
      'be': 4,
      'at': 11,
      'pa': 10,
      'ini': 10,
      'ausweichen': 2,
      'schildPa': 6,
      'tp': '1W6+4',
    },
    'hinweise': <String>[],
  },
  'f01_krieger_normal mit Linkshänder': <String, Object?>{
    'maxLep': 42,
    'maxAu': 48,
    'maxAsp': 33,
    'maxKap': 0,
    'mr': 5,
    'iniBase': 13,
    // Eine Wunde am linken Arm (Schildarm): allgemein AT/PA/FK −2, der
    // Armanteil AT/PA −2 trifft nur den Schild (WdS S. 58, 108 f.). Bis
    // ARCH-05 (6) rechnete sie AT/PA −4 und FK −6 für alle Waffen: 4/4/1.
    'atBase': 6,
    'paBase': 6,
    'fkBase': 5,
    'gs': 3,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 15,
      'kl': 10,
      'inn': 12,
      'ch': 11,
      'ff': 11,
      'ge': 13,
      'ko': 14,
      'kk': 14,
    },
    'startwerte': <String, Object?>{
      'mu': 13,
      'kl': 10,
      'inn': 12,
      'ch': 11,
      'ff': 11,
      'ge': 12,
      'ko': 13,
      'kk': 14,
    },
    'maxima': <String, Object?>{
      'mu': 20,
      'kl': 15,
      'inn': 18,
      'ch': 17,
      'ff': 17,
      'ge': 18,
      'ko': 20,
      'kk': 21,
    },
    // KO 14 / 2 + Eisern 2 (WdS S. 58); bis ARCH-05 (4) ohne Eisern: 7.
    'wundschwelle': 9,
    // Statt pauschal Proben −3: GE −2 allgemein, FF/KK −2 vom Arm.
    'wundEigenschaften': <String, Object?>{'ff': -2, 'ge': -2, 'kk': -2},
    'sbErschwernis': 4,
    'magie': false,
    'karma': false,
    // Linkshänder: Der verwundete linke Arm ist der Schwertarm. Die
    // Hauptwaffe trägt den Armanteil (11/10 − 2), der Schild nicht
    // (PA-Basis 6 + Schild-WM 3 − eBE-PA-Anteil 1 = 8; WdS 71 / 7016).
    'kampf': <String, Object?>{
      'rs': 4,
      'be': 4,
      'at': 9,
      'pa': 8,
      'ini': 10,
      'ausweichen': 2,
      'schildPa': 8,
      'tp': '1W6+4',
    },
    'hinweise': <String>[],
  },
  'f02_geode_magisch': <String, Object?>{
    'maxLep': 37,
    'maxAu': 46,
    'maxAsp': 46,
    'maxKap': 0,
    'mr': 10,
    'iniBase': 10,
    'atBase': 7,
    'paBase': 7,
    'fkBase': 8,
    'gs': 8,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 12,
      'kl': 13,
      'inn': 14,
      'ch': 13,
      'ff': 12,
      'ge': 11,
      'ko': 13,
      'kk': 12,
    },
    'startwerte': <String, Object?>{
      'mu': 12,
      'kl': 13,
      'inn': 13,
      'ch': 12,
      'ff': 12,
      'ge': 11,
      'ko': 13,
      'kk': 12,
    },
    'maxima': <String, Object?>{
      'mu': 18,
      'kl': 20,
      'inn': 20,
      'ch': 18,
      'ff': 18,
      'ge': 17,
      'ko': 20,
      'kk': 18,
    },
    // KO 13 / 2 = 6,5, kaufmännisch 7 (WdS S. 58); bis ARCH-05 (4)
    // abgerundet: 6.
    'wundschwelle': 7,
    'wundEigenschaften': <String, Object?>{},
    'sbErschwernis': 0,
    'magie': true,
    'karma': false,
    'kampf': <String, Object?>{
      'rs': 2,
      'be': 0,
      'at': 10,
      'pa': 9,
      'ini': 8,
      'ausweichen': 7,
      'schildPa': 0,
      'tp': '1W6+13',
    },
    'hinweise': <String>[],
  },
  'f03_geweihter_karmal': <String, Object?>{
    'maxLep': 34,
    'maxAu': 40,
    'maxAsp': 32,
    'maxKap': 24,
    'mr': 3,
    'iniBase': 10,
    'atBase': 7,
    'paBase': 7,
    'fkBase': 8,
    'gs': 8,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 12,
      'kl': 12,
      'inn': 14,
      'ch': 13,
      'ff': 13,
      'ge': 11,
      'ko': 12,
      'kk': 11,
    },
    'startwerte': <String, Object?>{
      'mu': 12,
      'kl': 12,
      'inn': 14,
      'ch': 13,
      'ff': 13,
      'ge': 11,
      'ko': 12,
      'kk': 11,
    },
    'maxima': <String, Object?>{
      'mu': 18,
      'kl': 18,
      'inn': 21,
      'ch': 20,
      'ff': 20,
      'ge': 17,
      'ko': 18,
      'kk': 17,
    },
    'wundschwelle': 6,
    'wundEigenschaften': <String, Object?>{},
    'sbErschwernis': 0,
    'magie': false,
    'karma': true,
    'kampf': <String, Object?>{
      'rs': 0,
      'be': 0,
      'at': 7,
      'pa': 7,
      'ini': 7, // ohne Waffe: Fausthieb INI −2 mit INI/GE aus TP/KK 10/3 (AA S. 150)
      'ausweichen': 7,
      'schildPa': 0,
      'tp': '1W6', // ohne Waffe: Fausthieb 1W6 TP(A), TP/KK 10/3 statt Platzhalter mit voller KK
    },
    'hinweise': <String>[],
  },
  'f04_episch': <String, Object?>{
    'maxLep': 59,
    'maxAu': 79,
    'maxAsp': 67,
    'maxKap': 0,
    'mr': 5,
    'iniBase': 17,
    'atBase': 10,
    'paBase': 10,
    'fkBase': 9,
    'gs': 9,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 17,
      'kl': 16,
      'inn': 15,
      'ch': 14,
      'ff': 14,
      'ge': 16,
      'ko': 18,
      'kk': 17,
    },
    'startwerte': <String, Object?>{
      'mu': 15,
      'kl': 14,
      'inn': 14,
      'ch': 13,
      'ff': 13,
      'ge': 14,
      'ko': 15,
      'kk': 15,
    },
    'maxima': <String, Object?>{
      'mu': 23,
      'kl': 21,
      'inn': 21,
      'ch': 20,
      'ff': 20,
      'ge': 22,
      'ko': 25,
      'kk': 25,
    },
    // KO 18 / 2 + Eisern 2 (WdS S. 58); bis ARCH-05 (4) ohne Eisern: 9.
    'wundschwelle': 11,
    'wundEigenschaften': <String, Object?>{},
    'sbErschwernis': 0,
    'magie': false,
    'karma': false,
    'kampf': <String, Object?>{
      'rs': 0,
      'be': 0,
      'at': 21,
      'pa': 19,
      'ini': 17,
      'ausweichen': 16,
      'schildPa': 0,
      'tp': '1W6+5',
    },
    'hinweise': <String>[],
  },
  'f05_freitext_merkmale': <String, Object?>{
    'maxLep': 35,
    'maxAu': 38,
    'maxAsp': 28,
    'maxKap': 0,
    'mr': 3,
    // Inspector INI +1 zählt einfach (vor Behebung von ARCH-07-B1: 12).
    'iniBase': 11,
    'atBase': 7,
    'paBase': 7,
    'fkBase': 7,
    'gs': 8,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 12,
      'kl': 12,
      'inn': 12,
      'ch': 12,
      'ff': 12,
      'ge': 12,
      'ko': 12,
      'kk': 12,
    },
    'startwerte': <String, Object?>{
      'mu': 12,
      'kl': 12,
      'inn': 12,
      'ch': 12,
      'ff': 12,
      'ge': 12,
      'ko': 12,
      'kk': 12,
    },
    'maxima': <String, Object?>{
      'mu': 18,
      'kl': 18,
      'inn': 18,
      'ch': 18,
      'ff': 18,
      'ge': 18,
      'ko': 18,
      'kk': 18,
    },
    'wundschwelle': 6,
    'wundEigenschaften': <String, Object?>{},
    'sbErschwernis': 0,
    'magie': false,
    'karma': false,
    'kampf': <String, Object?>{
      'rs': 0,
      'be': 0,
      'at': 7,
      'pa': 7,
      'ini': 8, // ohne Waffe: Fausthieb INI −2 mit INI/GE aus TP/KK 10/3 (AA S. 150)
      'ausweichen': 7,
      'schildPa': 0,
      'tp': '1W6', // ohne Waffe: Fausthieb 1W6 TP(A), TP/KK 10/3 statt Platzhalter mit voller KK
    },
    'hinweise': <String>[],
  },
  // f09 ist f05 mit anderen Vor-/Nachteilen im strukturierten Format:
  // Hohe Lebenskraft 3 (LeP +3), Ausdauernd 2 und Kurzatmig 1 (AuP +1),
  // Hohe Magieresistenz 1 (MR +1), Flink (GS +1, Ausweichen +1 in der
  // Kampfvorschau). LEP+2 bleibt frei und wirkt wie bei f05; der mehrdeutige
  // Alttext wirkt nicht.
  'f09_strukturierte_merkmale': <String, Object?>{
    'maxLep': 38,
    'maxAu': 39,
    'maxAsp': 28,
    'maxKap': 0,
    'mr': 4,
    'iniBase': 11,
    'atBase': 7,
    'paBase': 7,
    'fkBase': 7,
    'gs': 9,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 12,
      'kl': 12,
      'inn': 12,
      'ch': 12,
      'ff': 12,
      'ge': 12,
      'ko': 12,
      'kk': 12,
    },
    'startwerte': <String, Object?>{
      'mu': 12,
      'kl': 12,
      'inn': 12,
      'ch': 12,
      'ff': 12,
      'ge': 12,
      'ko': 12,
      'kk': 12,
    },
    'maxima': <String, Object?>{
      'mu': 18,
      'kl': 18,
      'inn': 18,
      'ch': 18,
      'ff': 18,
      'ge': 18,
      'ko': 18,
      'kk': 18,
    },
    'wundschwelle': 6,
    'wundEigenschaften': <String, Object?>{},
    'sbErschwernis': 0,
    'magie': false,
    'karma': false,
    'kampf': <String, Object?>{
      'rs': 0,
      'be': 0,
      'at': 7,
      'pa': 7,
      'ini': 8, // ohne Waffe: Fausthieb INI −2 mit INI/GE aus TP/KK 10/3 (AA S. 150)
      'ausweichen': 8,
      'schildPa': 0,
      'tp': '1W6', // ohne Waffe: Fausthieb 1W6 TP(A), TP/KK 10/3 statt Platzhalter mit voller KK
    },
    'hinweise': <String>[],
  },
  'f06_gleichnamige_ausruestung': <String, Object?>{
    'maxLep': 23,
    'maxAu': 30,
    'maxAsp': 28,
    'maxKap': 0,
    'mr': 7,
    'iniBase': 11,
    'atBase': 8,
    'paBase': 8,
    'fkBase': 8,
    'gs': 6,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 13,
      'kl': 11,
      'inn': 13,
      'ch': 10,
      'ff': 14,
      'ge': 14,
      'ko': 12,
      'kk': 12,
    },
    'startwerte': <String, Object?>{
      'mu': 13,
      'kl': 11,
      'inn': 13,
      'ch': 10,
      'ff': 14,
      'ge': 14,
      'ko': 12,
      'kk': 12,
    },
    'maxima': <String, Object?>{
      'mu': 20,
      'kl': 17,
      'inn': 20,
      'ch': 15,
      'ff': 21,
      'ge': 21,
      'ko': 18,
      'kk': 18,
    },
    'wundschwelle': 6,
    'wundEigenschaften': <String, Object?>{},
    'sbErschwernis': 0,
    'magie': false,
    'karma': false,
    'kampf': <String, Object?>{
      'rs': 2,
      'be': 2,
      'at': 13,
      'pa': 10,
      'ini': 8,
      'ausweichen': 6,
      'schildPa': 0,
      'tp': '1W6+13',
    },
    'hinweise': <String>[],
  },
  'f07_legacy_schema1': <String, Object?>{
    // Alte persistentMods LeP +2 zählen einfach (vor ARCH-07-B1: 36).
    'maxLep': 34,
    'maxAu': 32,
    'maxAsp': 20,
    'maxKap': 0,
    'mr': 3,
    // Alte persistentMods INI +1 zählen einfach (vor ARCH-07-B1: 16).
    'iniBase': 15,
    'atBase': 8,
    'paBase': 8,
    'fkBase': 8,
    'gs': 8,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 13,
      'kl': 11,
      'inn': 12,
      'ch': 10,
      'ff': 12,
      'ge': 13,
      'ko': 13,
      'kk': 14,
    },
    'startwerte': <String, Object?>{
      'mu': 13,
      'kl': 11,
      'inn': 12,
      'ch': 10,
      'ff': 12,
      'ge': 13,
      'ko': 13,
      'kk': 14,
    },
    'maxima': <String, Object?>{
      'mu': 20,
      'kl': 17,
      'inn': 18,
      'ch': 15,
      'ff': 18,
      'ge': 20,
      'ko': 20,
      'kk': 21,
    },
    // KO 13 / 2 = 6,5, kaufmännisch 7 (WdS S. 58); bis ARCH-05 (4)
    // abgerundet: 6.
    'wundschwelle': 7,
    'wundEigenschaften': <String, Object?>{},
    'sbErschwernis': 0,
    'magie': false,
    'karma': false,
    'kampf': <String, Object?>{
      'rs': 0,
      'be': 0,
      'at': 13,
      'pa': 12,
      'ini': 12,
      'ausweichen': 8,
      // Alt-Nebenhand `offhand` (Holzschild): PA-Basis 8 + 2, ohne Schild-SF.
      'schildPa': 10,
      'tp': '1W6+18',
    },
    'hinweise': <String>['KK +2'],
  },
  'f08_steigerungshistorie': <String, Object?>{
    'maxLep': 24,
    'maxAu': 31,
    'maxAsp': 31,
    'maxKap': 0,
    'mr': 7,
    'iniBase': 14,
    'atBase': 7,
    'paBase': 7,
    'fkBase': 7,
    'gs': 8,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 13,
      'kl': 12,
      'inn': 13,
      'ch': 11,
      'ff': 12,
      'ge': 13,
      'ko': 12,
      'kk': 11,
    },
    'startwerte': <String, Object?>{
      'mu': 12,
      'kl': 12,
      'inn': 13,
      'ch': 11,
      'ff': 12,
      'ge': 13,
      'ko': 12,
      'kk': 11,
    },
    'maxima': <String, Object?>{
      'mu': 18,
      'kl': 18,
      'inn': 20,
      'ch': 17,
      'ff': 18,
      'ge': 20,
      'ko': 18,
      'kk': 17,
    },
    'wundschwelle': 6,
    'wundEigenschaften': <String, Object?>{},
    'sbErschwernis': 0,
    'magie': false,
    'karma': false,
    'kampf': <String, Object?>{
      'rs': 0,
      'be': 0,
      'at': 7,
      'pa': 7,
      'ini': 12, // ohne Waffe: Fausthieb INI −2 mit INI/GE aus TP/KK 10/3 (AA S. 150)
      'ausweichen': 7,
      'schildPa': 0,
      'tp': '1W6', // ohne Waffe: Fausthieb 1W6 TP(A), TP/KK 10/3 statt Platzhalter mit voller KK
    },
    'hinweise': <String>[],
  },
  // Wie f08: Ein Verlaufseintrag unbekannter Art aendert keinen Wert.
  'f08b_unbekannte_steigerungsart': <String, Object?>{
    'maxLep': 24,
    'maxAu': 31,
    'maxAsp': 31,
    'maxKap': 0,
    'mr': 7,
    'iniBase': 14,
    'atBase': 7,
    'paBase': 7,
    'fkBase': 7,
    'gs': 8,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 13,
      'kl': 12,
      'inn': 13,
      'ch': 11,
      'ff': 12,
      'ge': 13,
      'ko': 12,
      'kk': 11,
    },
    'startwerte': <String, Object?>{
      'mu': 12,
      'kl': 12,
      'inn': 13,
      'ch': 11,
      'ff': 12,
      'ge': 13,
      'ko': 12,
      'kk': 11,
    },
    'maxima': <String, Object?>{
      'mu': 18,
      'kl': 18,
      'inn': 20,
      'ch': 17,
      'ff': 18,
      'ge': 20,
      'ko': 18,
      'kk': 17,
    },
    'wundschwelle': 6,
    'wundEigenschaften': <String, Object?>{},
    'sbErschwernis': 0,
    'magie': false,
    'karma': false,
    'kampf': <String, Object?>{
      'rs': 0,
      'be': 0,
      'at': 7,
      'pa': 7,
      'ini': 12, // ohne Waffe: Fausthieb INI −2 mit INI/GE aus TP/KK 10/3 (AA S. 150)
      'ausweichen': 7,
      'schildPa': 0,
      'tp': '1W6', // ohne Waffe: Fausthieb 1W6 TP(A), TP/KK 10/3 statt Platzhalter mit voller KK
    },
    'hinweise': <String>[],
  },
  'f04_episch mit Brustwunde': <String, Object?>{
    'maxLep': 59,
    'maxAu': 79,
    'maxAsp': 67,
    'maxKap': 0,
    'mr': 5,
    'iniBase': 15,
    'atBase': 7,
    'paBase': 7,
    // Brustwunde: FK nur allgemein −2 (bis ARCH-05 (6): −3, also 6).
    'fkBase': 7,
    'gs': 8,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 17,
      'kl': 16,
      'inn': 15,
      'ch': 14,
      'ff': 14,
      'ge': 16,
      'ko': 18,
      'kk': 17,
    },
    'startwerte': <String, Object?>{
      'mu': 15,
      'kl': 14,
      'inn': 14,
      'ch': 13,
      'ff': 13,
      'ge': 14,
      'ko': 15,
      'kk': 15,
    },
    'maxima': <String, Object?>{
      'mu': 23,
      'kl': 21,
      'inn': 21,
      'ch': 20,
      'ff': 20,
      'ge': 22,
      'ko': 25,
      'kk': 25,
    },
    // KO 18 / 2 + Eisern 2 (WdS S. 58); bis ARCH-05 (4) ohne Eisern: 9.
    'wundschwelle': 11,
    // Statt pauschal Proben −3 (episch −1): GE −2, KO/KK −1.
    'wundEigenschaften': <String, Object?>{'ge': -2, 'ko': -1, 'kk': -1},
    // Epische KO: SB-Erschwernis 4 halbiert (Epische Stufen S. 4).
    'sbErschwernis': 2,
    'magie': false,
    'karma': false,
    // Brustwunde: AT/PA/Ausweichen je −3 (vor ARCH-07-B7: 21/19/16).
    'kampf': <String, Object?>{
      'rs': 0,
      'be': 0,
      'at': 18,
      'pa': 16,
      'ini': 15,
      'ausweichen': 13,
      'schildPa': 0,
      'tp': '1W6+5',
    },
    'hinweise': <String>[],
  },
  'f04_episch mit Brustwunde ohne epische Vorteile': <String, Object?>{
    'maxLep': 59,
    'maxAu': 79,
    'maxAsp': 67,
    'maxKap': 0,
    'mr': 5,
    'iniBase': 15,
    'atBase': 7,
    'paBase': 7,
    // Brustwunde: FK nur allgemein −2 (bis ARCH-05 (6): −3, also 6).
    'fkBase': 7,
    'gs': 8,
    'ausweichen': 0,
    'eigenschaften': <String, Object?>{
      'mu': 17,
      'kl': 16,
      'inn': 15,
      'ch': 14,
      'ff': 14,
      'ge': 16,
      'ko': 18,
      'kk': 17,
    },
    'startwerte': <String, Object?>{
      'mu': 15,
      'kl': 14,
      'inn': 14,
      'ch': 13,
      'ff': 13,
      'ge': 14,
      'ko': 15,
      'kk': 15,
    },
    'maxima': <String, Object?>{
      'mu': 23,
      'kl': 21,
      'inn': 21,
      'ch': 20,
      'ff': 20,
      'ge': 22,
      'ko': 25,
      'kk': 25,
    },
    // KO 18 / 2 + Eisern 2 (WdS S. 58); bis ARCH-05 (4) ohne Eisern: 9.
    'wundschwelle': 11,
    // Statt pauschal Proben −3 (episch −1): GE −2, KO/KK −1.
    'wundEigenschaften': <String, Object?>{'ge': -2, 'ko': -1, 'kk': -1},
    'sbErschwernis': 4,
    'magie': false,
    'karma': false,
    // Brustwunde: AT/PA/Ausweichen je −3, unabhängig von epischen Vorteilen.
    'kampf': <String, Object?>{
      'rs': 0,
      'be': 0,
      'at': 18,
      'pa': 16,
      'ini': 15,
      'ausweichen': 13,
      'schildPa': 0,
      'tp': '1W6+5',
    },
    'hinweise': <String>[],
  },
};

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
