import 'package:dsa_heldenverwaltung/domain/house_rule_descriptor.dart';

/// Schluessel-Konstanten fuer die Hausregel-Gruppen rund um die epischen Stufen.
///
/// Die Keys werden identisch in den Katalog-Eintraegen unter
/// `ruleMeta.sourceKey` verwendet. Sub-Keys bilden eine Punkt-Hierarchie.
class EpicRuleKeys {
  EpicRuleKeys._();

  static const String master = 'epic_rules_v1';
  static const String combatSf = 'epic_rules_v1.combat_sf';
  static const String generalSf = 'epic_rules_v1.general_sf';
  static const String magicSf = 'epic_rules_v1.magic_sf';
  static const String karmalSf = 'epic_rules_v1.karmal_sf';
  static const String liturgies = 'epic_rules_v1.liturgies';
  static const String paths = 'epic_rules_v1.paths';
  static const String advantages = 'epic_rules_v1.advantages';
  static const String disadvantages = 'epic_rules_v1.disadvantages';
}

/// Zentrale Registry aller bekannten Hausregel-Gruppen.
///
/// Die Liste ist bewusst statisch: Hausregeln sind Kompilierzeit-Features
/// mit festen Abhaengigkeiten zu Regel-Modulen. Laufzeit-Registrierung
/// waere nur Ballast, da kein Hot-Reload von Regeln vorgesehen ist.
class HouseRuleRegistry {
  HouseRuleRegistry._();

  static const List<HouseRuleDescriptor> all = <HouseRuleDescriptor>[
    HouseRuleDescriptor(
      sourceKey: EpicRuleKeys.master,
      title: 'Epische Stufen',
      description:
          'Regelpaket fuer Helden ab Stufe 21: Epischer Status, '
          'Vor- und Nachteile sowie epische Sonderfertigkeiten. '
          'Quelle: Hausregel-Dokument „Epische Stufen".',
    ),
    HouseRuleDescriptor(
      sourceKey: EpicRuleKeys.advantages,
      parentSourceKey: EpicRuleKeys.master,
      title: 'Vorteile des epischen Status',
      description:
          'Haupteigenschafts-Boni, 2:1-Erschwernis-Umlage und '
          '5 Punkte Erweiterung der Eigenschafts-Obergrenzen (Kap. 2.1).',
    ),
    HouseRuleDescriptor(
      sourceKey: EpicRuleKeys.disadvantages,
      parentSourceKey: EpicRuleKeys.master,
      title: 'Nachteile des epischen Status',
      description:
          '+25 % AP-Aufschlag auf normale Talente, Zauber und Eigenschaften; '
          'reduzierte AsP-Stufenboni; Sperren fuer neue Repraesentationen '
          'und Waffenmeisterschaften (Kap. 2.2).',
    ),
    HouseRuleDescriptor(
      sourceKey: EpicRuleKeys.combatSf,
      parentSourceKey: EpicRuleKeys.master,
      title: 'Epische Kampf-Sonderfertigkeiten',
      description:
          'Allgemeine Kampf-SF, waffenlose Kampfstile, Waffen-Grossmeister '
          'und Waffenmeisterschaften (Kap. 3.1).',
    ),
    HouseRuleDescriptor(
      sourceKey: EpicRuleKeys.generalSf,
      parentSourceKey: EpicRuleKeys.master,
      title: 'Epische Allgemeine Sonderfertigkeiten',
      description: 'Nicht-kampfbezogene epische SF (Kap. 3.2).',
    ),
    HouseRuleDescriptor(
      sourceKey: EpicRuleKeys.magicSf,
      parentSourceKey: EpicRuleKeys.master,
      title: 'Epische Magische Sonderfertigkeiten',
      description: 'Epische SF fuer Zauberer (Kap. 3.3).',
    ),
    HouseRuleDescriptor(
      sourceKey: EpicRuleKeys.karmalSf,
      parentSourceKey: EpicRuleKeys.master,
      title: 'Epische Geweihten-Sonderfertigkeiten',
      description: 'Epische SF fuer Geweihte (Kap. 3.4.1).',
    ),
    HouseRuleDescriptor(
      sourceKey: EpicRuleKeys.liturgies,
      parentSourceKey: EpicRuleKeys.master,
      title: 'Epische Liturgien',
      description: 'Liturgien mit epischer Wirkung (Kap. 3.4.2).',
    ),
    HouseRuleDescriptor(
      sourceKey: EpicRuleKeys.paths,
      parentSourceKey: EpicRuleKeys.master,
      title: 'Pfade der Erleuchteten',
      description:
          'Goettliche Pfade, die Geweihte nach epischem Aufstieg '
          'beschreiten koennen (Kap. 3.4.3).',
    ),
  ];

  /// Liefert den Descriptor fuer einen Key, oder `null` wenn unbekannt.
  static HouseRuleDescriptor? find(String sourceKey) {
    for (final entry in all) {
      if (entry.sourceKey == sourceKey) return entry;
    }
    return null;
  }

  /// Alle Root-Eintraege (ohne Parent).
  static Iterable<HouseRuleDescriptor> get roots =>
      all.where((entry) => entry.isRoot);

  /// Kinder eines Keys (direkte Nachfahren).
  static Iterable<HouseRuleDescriptor> childrenOf(String sourceKey) =>
      all.where((entry) => entry.parentSourceKey == sourceKey);
}
