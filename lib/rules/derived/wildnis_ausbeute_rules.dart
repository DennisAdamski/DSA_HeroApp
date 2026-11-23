import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_aenderung_rules.dart';

// Was eine Wildnisprobe einbringt und verbraucht: Tagesrationen fürs Inventar
// (Wege des Entdeckers S. 122 f.: eine Ration ist der Essensbedarf eines
// Tages, etwa ein Stein Lebensmittel) und der Verlust an Geschossen bei der
// Jagd (S. 108: Schleudersteine 1W6+1, Pfeile und Bolzen bei 3–5 auf 2W20,
// Speere bei 3–7, Wurfwaffen bei 3–9).
//
// Beide Buchungen arbeiten auf dem frisch geladenen Helden bzw. der frisch
// geladenen Kampfkonfiguration (CLAUDE.md, Regel 4); sie zählen vom
// gespeicherten Bestand.

/// Gewicht einer Tagesration in Gramm (etwa ein Stein, WdE S. 123).
const int kWildnisRationGewichtGramm = 1000;

/// Tagesrationen, die eine Wildnisprobe ins Inventar bringen kann.
class WildnisRationen {
  /// Erstellt die Angabe.
  const WildnisRationen({
    required this.gegenstand,
    required this.anzahl,
    required this.taetigkeit,
    this.beschreibung = '',
    this.gewichtGramm = kWildnisRationGewichtGramm,
  });

  /// Name des Inventareintrags (`Wildbret (frisch)`).
  final String gegenstand;

  /// Zahl der Tagesrationen.
  final int anzahl;

  /// Tätigkeit, aus der die Rationen stammen (`Pirschjagd`); Teil der
  /// Herkunft.
  final String taetigkeit;

  /// Haltbarkeit und Hinweise für den Eintrag.
  final String beschreibung;

  /// Gewicht je Ration in Gramm.
  final int gewichtGramm;
}

/// Herkunft eines Rationeneintrags: Tätigkeit und, falls bekannt, das
/// aventurische Datum (`Pirschjagd am 5. Praios 1043 BF`).
String wildnisRationenHerkunft(WildnisRationen rationen, {String datum = ''}) {
  final tag = datum.trim();
  return tag.isEmpty ? rationen.taetigkeit : '${rationen.taetigkeit} am $tag';
}

/// Bucht [rationen] ins Inventar des gespeicherten Helden [held].
///
/// Gibt es schon einen manuellen Verbrauchseintrag des Helden mit gleichem
/// Namen, gleicher Herkunft (Tätigkeit und Tag) und gleicher Beschreibung und
/// klarer Menge, wächst dessen Menge; sonst kommt ein neuer Eintrag hinzu.
/// Ohne Rationen bleibt [held] unverändert.
HeroSheet mitWildnisRationen(
  HeroSheet held,
  WildnisRationen rationen, {
  String datum = '',
}) {
  if (rationen.anzahl <= 0) return held;
  final herkunft = wildnisRationenHerkunft(rationen, datum: datum);
  final eintraege = List<HeroInventoryEntry>.of(held.inventoryEntries);
  final index = eintraege.indexWhere(
    (e) =>
        e.source == InventoryItemSource.manuell &&
        e.itemType == InventoryItemType.verbrauchsgegenstand &&
        e.traegerTyp == InventoryTraeger.held &&
        e.gegenstand == rationen.gegenstand &&
        e.herkunft == herkunft &&
        e.beschreibung == rationen.beschreibung &&
        e.gewichtGramm == rationen.gewichtGramm &&
        wirksameInventarMenge(e) != null &&
        !inventarMengenstand(e).abweichend,
  );
  if (index >= 0) {
    final vorhanden = eintraege[index];
    eintraege[index] = mitInventarMenge(
      vorhanden,
      wirksameInventarMenge(vorhanden)! + rationen.anzahl,
    );
  } else {
    eintraege.add(
      mitInventarMenge(
        HeroInventoryEntry(
          gegenstand: rationen.gegenstand,
          itemType: InventoryItemType.verbrauchsgegenstand,
          herkunft: herkunft,
          beschreibung: rationen.beschreibung,
          gewichtGramm: rationen.gewichtGramm,
        ),
        rationen.anzahl,
      ),
    );
  }
  return held.copyWith(
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(eintraege),
  );
}

/// Was beim Jagen an Geschossen verloren geht (WdE S. 108).
enum JagdVerbrauch {
  /// Schleudersteine, Arbalettenkugeln: 1W6+1 Stück je Jagd.
  kugeln('1W6+1 Schleudersteine oder Kugeln gehen verloren.', null),

  /// Pfeile, Bolzen, Blasrohrpfeile, Speerschleuderspeere: je Schuss bei 3–5
  /// auf 2W20.
  pfeile('Jeder Pfeil oder Bolzen geht bei 3–5 auf 2W20 verloren.', 5),

  /// Speere aller Art: je Wurf bei 3–7 auf 2W20.
  speere('Jeder Speer geht bei 3–7 auf 2W20 verloren.', 7),

  /// Wurfmesser, -beile, -dolche, Disken: je Wurf bei 3–9 auf 2W20.
  wurfwaffen('Jede Wurfwaffe geht bei 3–9 auf 2W20 verloren.', 9);

  const JagdVerbrauch(this.hinweis, this.verlorenBis);

  /// Text für die Ergebnisanzeige.
  final String hinweis;

  /// Höchste Summe auf 2W20, bei der ein Geschoss verloren geht (ab 3);
  /// `null` bei festem Verlust je Jagd ([kugeln]).
  final int? verlorenBis;

  /// Ob der Verlust je Schuss gewürfelt wird.
  bool get jeSchuss => verlorenBis != null;
}

/// Munition einer Jagd, deren Verlust gewürfelt werden kann.
class WildnisMunition {
  /// Erstellt die Angabe.
  const WildnisMunition({
    required this.waffenName,
    required this.verbrauch,
    this.waffenSlotId,
  });

  /// Anzeigename der Waffe.
  final String waffenName;

  /// Art des Verlusts.
  final JagdVerbrauch verbrauch;

  /// Slot-ID der Waffe des Helden; `null` bei einer Waffe aus der Tabelle,
  /// deren Bestand die App nicht kennt.
  final String? waffenSlotId;
}

/// Ein ausgewürfelter Geschossverlust.
class Geschossverlust {
  /// Erstellt das Ergebnis.
  const Geschossverlust({required this.wuerfe, required this.verloren});

  /// Die Würfe: je Schuss die Summe der 2W20, bei festem Verlust der 1W6.
  final List<int> wuerfe;

  /// Verlorene Geschosse.
  final int verloren;
}

/// Würfelt den Verlust für [schuesse] Schüsse oder Würfe mit [roller].
///
/// Pfeile, Speere und Wurfwaffen: je Schuss 2W20, verloren bei 3 bis
/// [JagdVerbrauch.verlorenBis] (eine Doppel-1 zählt nicht). Schleudersteine
/// und Kugeln: 1W6+1 unabhängig von den Schüssen.
Geschossverlust wuerfleGeschossverlust(
  JagdVerbrauch verbrauch, {
  required int schuesse,
  required DiceRoller roller,
}) {
  final bis = verbrauch.verlorenBis;
  if (bis == null) {
    final w6 = roller.rollDie(6);
    return Geschossverlust(wuerfe: <int>[w6], verloren: w6 + 1);
  }
  final wuerfe = <int>[
    for (var i = 0; i < (schuesse < 0 ? 0 : schuesse); i++)
      roller.rollDie(20) + roller.rollDie(20),
  ];
  return Geschossverlust(
    wuerfe: List<int>.unmodifiable(wuerfe),
    verloren: wuerfe.where((summe) => summe >= 3 && summe <= bis).length,
  );
}

/// Bucht [verloren] Geschosse vom angezeigten [geschoss] der angezeigten
/// [waffe] ab, gezählt vom gespeicherten Bestand in [config] und höchstens
/// so viele, wie noch da sind.
///
/// Fehlt Waffe oder Geschoss inzwischen, wirft die Funktion einen
/// [StateError] (aus [mitGeschossSchritt]).
CombatConfig mitJagdGeschossverlust(
  CombatConfig config, {
  required MainWeaponSlot waffe,
  required RangedProjectile geschoss,
  required int verloren,
}) {
  if (verloren <= 0) return config;
  final frisch = config.weaponSlots
      .where((w) => w.id == waffe.id)
      .firstOrNull
      ?.rangedProfile
      .projectiles
      .where((g) => g.id == geschoss.id)
      .firstOrNull;
  final bestand = frisch?.count ?? geschoss.count;
  final abzug = verloren > bestand ? bestand : verloren;
  if (abzug <= 0) return config;
  return mitGeschossSchritt(config, waffe, geschoss, -abzug);
}

/// Die Waffe mit [slotId] und ihr gewähltes Geschoss, soweit vorhanden.
({MainWeaponSlot waffe, RangedProjectile? geschoss})? jagdWaffeUndGeschoss(
  HeroSheet held,
  String? slotId,
) {
  if (slotId == null || slotId.isEmpty) return null;
  final waffe = held.combatConfig.weaponSlots
      .where((w) => w.id == slotId)
      .firstOrNull;
  if (waffe == null) return null;
  return (waffe: waffe, geschoss: waffe.rangedProfile.selectedProjectileOrNull);
}
