// Abgleich der Waffen eines Helden mit dem Waffenkatalog.
//
// Die Grundwerte einer Waffe (TP/KK, TP-Zuschlag, WM INI, WM AT, WM PA, BF)
// stehen für die unveränderte Waffe; Verbesserungen der Waffe selbst, etwa
// meisterlich geschmiedet, stehen getrennt in den Mod-Feldern
// (`kkBaseMod`/`kkThresholdMod`, `tpFlatMod`, `iniModMod`, `wmAtMod`,
// `wmPaMod`, `breakFactorMod`). Bestandswaffen tragen solche Verbesserungen
// aber oft schon direkt im Grundwert, etwa 11/2 statt 12/3 oder TP 1W6+5
// statt 1W6+4. Die Prüfung findet solche Abweichungen zur Laufzeit; die
// Oberfläche bietet an, den Unterschied als Verbesserung einzutragen, die
// Waffe zu bearbeiten oder die Abweichung zu akzeptieren.
//
// Für INI/GE ist das mehr als Ordnung: INI/GE rechnet nur mit der TP/KK der
// unveränderten Waffe (`computeIniGe`).

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

/// TP/KK-Grundwerte, z. B. `12/3`.
typedef TpKkWerte = ({int basis, int schwelle});

/// Trefferpunkte einer Katalogwaffe, z. B. `1W6+4`.
typedef TpWerte = ({int wuerfel, int zuschlag});

/// Grundwert einer Waffe, den der Katalogabgleich vergleicht.
enum WaffenGrundwertArt {
  /// KK-Basis und KK-Schwelle (`kkBase`/`kkThreshold`).
  tpKk('TP/KK'),

  /// Fester TP-Zuschlag (`tpFlat`), nur bei gleicher Würfelzahl.
  tp('TP'),

  /// Initiativmodifikator der Waffe (`iniMod`).
  ini('INI'),

  /// Waffenmodifikator AT (`wmAt`).
  at('AT'),

  /// Waffenmodifikator PA (`wmPa`), nur im Nahkampf.
  pa('PA'),

  /// Bruchfaktor (`breakFactor`); gemeldet nur, wenn er unter dem Katalog
  /// liegt, denn ein höherer BF entsteht im Spiel durch Abnutzung.
  bf('BF');

  const WaffenGrundwertArt(this.kuerzel);

  /// Kurzbezeichnung für Meldungen und den Bestätigungsschlüssel.
  final String kuerzel;
}

/// Grundwerte einer Katalogwaffe; `null` steht für einen Wert, den der
/// Katalog nicht lesbar führt (z. B. TP/KK `-` oder leerer BF).
class WaffenKatalogWerte {
  /// Erzeugt die Katalogwerte.
  const WaffenKatalogWerte({
    this.tpKk,
    this.tp,
    this.ini = 0,
    this.at = 0,
    this.pa = 0,
    this.bf,
  });

  /// Liest die vergleichbaren Grundwerte aus [def].
  factory WaffenKatalogWerte.aus(WeaponDef def) {
    return WaffenKatalogWerte(
      tpKk: leseKatalogTpKk(def.tpkk),
      tp: leseKatalogTp(def.tp),
      ini: def.iniMod,
      at: def.atMod,
      pa: def.paMod,
      bf: leseKatalogBruchfaktor(def.breakFactor),
    );
  }

  /// TP/KK laut Katalog.
  final TpKkWerte? tpKk;

  /// Trefferpunkte laut Katalog.
  final TpWerte? tp;

  /// WM INI laut Katalog.
  final int ini;

  /// WM AT laut Katalog.
  final int at;

  /// WM PA laut Katalog.
  final int pa;

  /// Bruchfaktor laut Katalog.
  final int? bf;
}

/// Ein Grundwert, der vom Katalog abweicht.
class WaffenGrundwertAbweichung {
  /// Erzeugt die Abweichung.
  const WaffenGrundwertAbweichung({
    required this.art,
    required this.eingetragen,
    required this.katalog,
    required this.verbesserung,
  });

  /// Betroffener Grundwert.
  final WaffenGrundwertArt art;

  /// Eingetragener Grundwert als Text, z. B. `11/2` oder `1W6+5`.
  final String eingetragen;

  /// Katalogwert als Text, z. B. `12/3` oder `1W6+4`.
  final String katalog;

  /// Verbesserung der Waffe nach dem Übernehmen als Modifikation, z. B.
  /// `−1/−1` oder `+1`.
  final String verbesserung;

  /// Teil der Meldung, z. B. `TP/KK 11/2 statt 12/3`.
  String get beschreibung => '${art.kuerzel} $eingetragen statt $katalog';
}

/// Eine Waffe, deren Grundwerte von ihrer Katalogwaffe abweichen.
class WaffenKatalogAbweichung {
  /// Erzeugt den Befund.
  const WaffenKatalogAbweichung({
    required this.slotIndex,
    required this.waffe,
    required this.katalogName,
    required this.katalog,
    required this.abweichungen,
  });

  /// Position der Waffe in `CombatConfig.weaponSlots`.
  final int slotIndex;

  /// Die Waffe, wie sie geprüft wurde (Bezug für das frische Schreiben).
  final MainWeaponSlot waffe;

  /// Name der Katalogwaffe, gegen die verglichen wurde.
  final String katalogName;

  /// Grundwerte laut Katalog.
  final WaffenKatalogWerte katalog;

  /// Abweichende Grundwerte in fester Reihenfolge (TP/KK, TP, INI, AT, PA,
  /// BF); nie leer.
  final List<WaffenGrundwertAbweichung> abweichungen;

  /// Ob die TP/KK abweicht (betrifft auch INI/GE).
  bool get betrifftTpKk =>
      abweichungen.any((a) => a.art == WaffenGrundwertArt.tpKk);

  /// Anzeigename der Waffe, ersatzweise der Katalogname.
  String get waffenName {
    final name = waffe.name.trim();
    return name.isEmpty ? katalogName : name;
  }

  /// Meldung für die Oberfläche.
  String get meldung {
    final teile = abweichungen.map((a) => a.beschreibung).join(', ');
    final iniGe = betrifftTpKk
        ? ' INI/GE rechnet mit dem Grundwert der Waffe.'
        : '';
    return '$waffenName weicht vom Katalog „$katalogName“ ab: $teile.$iniGe';
  }

  /// Vorschlag für „Als Modifikation übernehmen“, z. B.
  /// „Verbesserung TP/KK −1/−1, TP +1“.
  String get vorschlag {
    final teile = abweichungen
        .map((a) => '${a.art.kuerzel} ${a.verbesserung}')
        .join(', ');
    return 'Verbesserung $teile';
  }
}

/// Text einer TP/KK, z. B. `12/3`.
String tpKkText(TpKkWerte werte) => '${werte.basis}/${werte.schwelle}';

/// Text der Trefferpunkte, z. B. `1W6+4`.
String tpText(int wuerfel, int zuschlag) {
  final zusatz = zuschlag == 0 ? '' : mitVorzeichen(zuschlag);
  return '${wuerfel}W6$zusatz'.replaceAll('−', '-');
}

/// Liest die TP/KK einer Katalogwaffe (`12/3`); `null` ohne lesbaren Wert,
/// z. B. bei `-` für Fernkampfwaffen.
TpKkWerte? leseKatalogTpKk(String tpkk) {
  final treffer = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(tpkk);
  if (treffer == null) {
    return null;
  }
  final basis = int.tryParse(treffer.group(1) ?? '');
  final schwelle = int.tryParse(treffer.group(2) ?? '');
  if (basis == null || schwelle == null) {
    return null;
  }
  return (basis: basis, schwelle: schwelle);
}

/// Liest die Trefferpunkte einer Katalogwaffe (`1W6+4`, auch mit Zusätzen
/// wie `1W6+6*` oder `1W6(A)`); `null` ohne Würfelangabe.
TpWerte? leseKatalogTp(String tp) {
  final treffer = RegExp(r'(\d+)\s*W6\s*([+-]\s*\d+)?').firstMatch(tp);
  if (treffer == null) {
    return null;
  }
  final wuerfel = int.tryParse(treffer.group(1) ?? '');
  if (wuerfel == null) {
    return null;
  }
  final roh = (treffer.group(2) ?? '').replaceAll(' ', '');
  final zuschlag = roh.isEmpty ? 0 : int.tryParse(roh);
  if (zuschlag == null) {
    return null;
  }
  return (wuerfel: wuerfel < 1 ? 1 : wuerfel, zuschlag: zuschlag);
}

/// Liest den Bruchfaktor einer Katalogwaffe; `null`, wenn der Katalog keine
/// einzelne Zahl führt (leer, `-`, „je nach Schild“).
int? leseKatalogBruchfaktor(String bf) {
  final treffer = RegExp(r'^\s*(-?\d+)\s*$').firstMatch(bf);
  return treffer == null ? null : int.tryParse(treffer.group(1) ?? '');
}

/// Schlüssel einer akzeptierten Abweichung für
/// [MainWeaponSlot.katalogAbgleichAkzeptiert], z. B.
/// `Schwert|TP/KK 11/2:12/3;TP 1W6+5:1W6+4`.
///
/// Enthält Katalogwaffe, eingetragene und Katalogwerte aller abweichenden
/// Grundwerte: Ändert sich einer davon, gilt die Bestätigung nicht mehr.
String katalogAbgleichSchluessel({
  required String katalogName,
  required List<WaffenGrundwertAbweichung> abweichungen,
}) {
  final werte = abweichungen
      .map((a) => '${a.art.kuerzel} ${a.eingetragen}:${a.katalog}')
      .join(';');
  return '${katalogName.trim()}|$werte';
}

/// Vergleicht die Grundwerte von [waffe] mit [katalog].
///
/// Verglichen wird immer der Grundwert, nicht der wirksame Wert: Eine
/// schon als Mod eingetragene Verbesserung ist kein Befund. Ausgenommen sind
/// eine bewusst deaktivierte TP/KK (0/0), TP bei abweichender Würfelzahl,
/// PA im Fernkampf und ein BF über dem Katalogwert (Abnutzung).
List<WaffenGrundwertAbweichung> vergleicheWaffeMitKatalog(
  MainWeaponSlot waffe,
  WaffenKatalogWerte katalog,
) {
  return <WaffenGrundwertAbweichung>[
    for (final art in WaffenGrundwertArt.values)
      ?_vergleicheWert(art, waffe, katalog),
  ];
}

// Abweichung eines einzelnen Grundwerts oder `null`.
WaffenGrundwertAbweichung? _vergleicheWert(
  WaffenGrundwertArt art,
  MainWeaponSlot waffe,
  WaffenKatalogWerte katalog,
) {
  switch (art) {
    case WaffenGrundwertArt.tpKk:
      final kat = katalog.tpKk;
      if (kat == null || (waffe.kkBase == 0 && waffe.kkThreshold == 0)) {
        return null;
      }
      final eingetragen = (basis: waffe.kkBase, schwelle: waffe.kkThreshold);
      if (eingetragen == kat) {
        return null;
      }
      final mod = _tpKkModNachUebernahme(waffe, kat);
      return WaffenGrundwertAbweichung(
        art: art,
        eingetragen: tpKkText(eingetragen),
        katalog: tpKkText(kat),
        verbesserung:
            '${mitVorzeichen(mod.basis)}/${mitVorzeichen(mod.schwelle)}',
      );
    case WaffenGrundwertArt.tp:
      final kat = katalog.tp;
      final wuerfel = waffe.tpDiceCount < 1 ? 1 : waffe.tpDiceCount;
      if (kat == null || kat.wuerfel != wuerfel) {
        return null;
      }
      return _einfacheAbweichung(
        art,
        eingetragen: waffe.tpFlat,
        katalog: kat.zuschlag,
        mod: waffe.tpFlatMod,
        text: (wert) => tpText(wuerfel, wert),
      );
    case WaffenGrundwertArt.ini:
      return _einfacheAbweichung(
        art,
        eingetragen: waffe.iniMod,
        katalog: katalog.ini,
        mod: waffe.iniModMod,
      );
    case WaffenGrundwertArt.at:
      return _einfacheAbweichung(
        art,
        eingetragen: waffe.wmAt,
        katalog: katalog.at,
        mod: waffe.wmAtMod,
      );
    case WaffenGrundwertArt.pa:
      if (waffe.isRanged) {
        return null;
      }
      return _einfacheAbweichung(
        art,
        eingetragen: waffe.wmPa,
        katalog: katalog.pa,
        mod: waffe.wmPaMod,
      );
    case WaffenGrundwertArt.bf:
      final kat = katalog.bf;
      // Ein höherer BF als im Katalog ist Abnutzung, keine Verbesserung.
      if (kat == null || waffe.breakFactor >= kat) {
        return null;
      }
      return _einfacheAbweichung(
        art,
        eingetragen: waffe.breakFactor,
        katalog: kat,
        mod: waffe.breakFactorMod,
        text: (wert) => '$wert',
      );
  }
}

// Abweichung eines einzelnen Zahlenwerts; WM-Werte erscheinen mit Vorzeichen.
WaffenGrundwertAbweichung? _einfacheAbweichung(
  WaffenGrundwertArt art, {
  required int eingetragen,
  required int katalog,
  required int mod,
  String Function(int wert)? text,
}) {
  if (eingetragen == katalog) {
    return null;
  }
  final darstellung = text ?? (wert) => mitVorzeichen(wert);
  return WaffenGrundwertAbweichung(
    art: art,
    eingetragen: darstellung(eingetragen),
    katalog: darstellung(katalog),
    verbesserung: mitVorzeichen(mod + eingetragen - katalog),
  );
}

// Verbesserung der TP/KK, die den bisherigen Unterschied zum Katalog [kat]
// in den Mod verschiebt, ohne die wirksame TP/KK von [slot] zu ändern.
TpKkWerte _tpKkModNachUebernahme(MainWeaponSlot slot, TpKkWerte kat) {
  return (
    basis: slot.kkBaseMod + slot.kkBase - kat.basis,
    schwelle: slot.kkThresholdMod + slot.kkThreshold - kat.schwelle,
  );
}

/// Prüft die Grundwerte von [waffen] gegen die Katalogwaffen.
///
/// Verglichen wird mit der Katalogwaffe gleichen Namens und Kampftyps; der
/// Name stammt aus der Waffenart, ersatzweise aus dem Waffennamen. Führt der
/// Katalog mehrere Einträge des Namens (etwa ein- und zweihändig), gilt der
/// mit den wenigsten Abweichungen; passt einer ganz, gibt es keinen Befund.
/// Ohne Katalogtreffer und bei akzeptierter Abweichung gibt es ebenfalls
/// keinen Befund.
List<WaffenKatalogAbweichung> pruefeWaffenGegenKatalog({
  required List<MainWeaponSlot> waffen,
  required RulesCatalog? catalog,
}) {
  if (catalog == null || catalog.weapons.isEmpty) {
    return const <WaffenKatalogAbweichung>[];
  }
  final befunde = <WaffenKatalogAbweichung>[];
  for (var i = 0; i < waffen.length; i++) {
    final befund = _pruefeWaffe(i, waffen[i], catalog.weapons);
    if (befund != null) {
      befunde.add(befund);
    }
  }
  return List<WaffenKatalogAbweichung>.unmodifiable(befunde);
}

// Befund einer einzelnen Waffe oder `null`.
WaffenKatalogAbweichung? _pruefeWaffe(
  int index,
  MainWeaponSlot waffe,
  List<WeaponDef> katalogwaffen,
) {
  final art = waffe.weaponType.trim().isEmpty ? waffe.name : waffe.weaponType;
  final schluessel = normalizeCombatToken(art);
  if (schluessel.isEmpty) {
    return null;
  }
  WaffenKatalogAbweichung? bester;
  for (final def in katalogwaffen) {
    if (normalizeCombatToken(def.name) != schluessel) {
      continue;
    }
    if (weaponCombatTypeFromJson(def.type) != waffe.combatType) {
      continue;
    }
    final werte = WaffenKatalogWerte.aus(def);
    final abweichungen = vergleicheWaffeMitKatalog(waffe, werte);
    if (abweichungen.isEmpty) {
      return null;
    }
    if (bester == null || abweichungen.length < bester.abweichungen.length) {
      bester = WaffenKatalogAbweichung(
        slotIndex: index,
        waffe: waffe,
        katalogName: def.name.trim(),
        katalog: werte,
        abweichungen: List<WaffenGrundwertAbweichung>.unmodifiable(
          abweichungen,
        ),
      );
    }
  }
  if (bester == null) {
    return null;
  }
  final akzeptiert = katalogAbgleichSchluessel(
    katalogName: bester.katalogName,
    abweichungen: bester.abweichungen,
  );
  if (waffe.katalogAbgleichAkzeptiert == akzeptiert) {
    return null;
  }
  return bester;
}

/// Trägt den Unterschied zwischen [gespeichert] und dem Katalog als
/// Verbesserung der Waffe ein.
///
/// Jeder abweichende Grundwert (siehe [vergleicheWaffeMitKatalog]) wird zum
/// Katalogwert; der bisherige Unterschied kommt zur vorhandenen Verbesserung
/// hinzu. Die wirksamen Werte bleiben also gleich, INI/GE rechnet danach mit
/// der Katalog-TP/KK. Eine frühere Bestätigung entfällt. Arbeitet auf dem
/// frisch geladenen Slot.
MainWeaponSlot uebernimmKatalogAbweichungAlsModifikation(
  MainWeaponSlot gespeichert, {
  required WaffenKatalogWerte katalog,
}) {
  var neu = gespeichert.copyWith(katalogAbgleichAkzeptiert: '');
  for (final abweichung in vergleicheWaffeMitKatalog(gespeichert, katalog)) {
    neu = _uebernimm(neu, abweichung.art, katalog);
  }
  return neu;
}

// Verschiebt den Unterschied eines Grundwerts in seine Verbesserung.
MainWeaponSlot _uebernimm(
  MainWeaponSlot slot,
  WaffenGrundwertArt art,
  WaffenKatalogWerte katalog,
) {
  switch (art) {
    case WaffenGrundwertArt.tpKk:
      final kat = katalog.tpKk!;
      final mod = _tpKkModNachUebernahme(slot, kat);
      return slot.copyWith(
        kkBase: kat.basis,
        kkThreshold: kat.schwelle,
        kkBaseMod: mod.basis,
        kkThresholdMod: mod.schwelle,
      );
    case WaffenGrundwertArt.tp:
      final kat = katalog.tp!.zuschlag;
      return slot.copyWith(
        tpFlat: kat,
        tpFlatMod: slot.tpFlatMod + slot.tpFlat - kat,
      );
    case WaffenGrundwertArt.ini:
      return slot.copyWith(
        iniMod: katalog.ini,
        iniModMod: slot.iniModMod + slot.iniMod - katalog.ini,
      );
    case WaffenGrundwertArt.at:
      return slot.copyWith(
        wmAt: katalog.at,
        wmAtMod: slot.wmAtMod + slot.wmAt - katalog.at,
      );
    case WaffenGrundwertArt.pa:
      return slot.copyWith(
        wmPa: katalog.pa,
        wmPaMod: slot.wmPaMod + slot.wmPa - katalog.pa,
      );
    case WaffenGrundwertArt.bf:
      final kat = katalog.bf!;
      return slot.copyWith(
        breakFactor: kat,
        breakFactorMod: slot.breakFactorMod + slot.breakFactor - kat,
      );
  }
}

/// Bestätigt die Abweichung des frisch geladenen Slots [gespeichert] von
/// der Katalogwaffe [katalogName] mit [katalog] als gewollt.
///
/// Die Werte der Waffe bleiben unverändert; die Prüfung schweigt, bis sich
/// Waffe oder Katalog ändern.
MainWeaponSlot akzeptiereKatalogAbweichung(
  MainWeaponSlot gespeichert, {
  required String katalogName,
  required WaffenKatalogWerte katalog,
}) {
  final schluessel = katalogAbgleichSchluessel(
    katalogName: katalogName,
    abweichungen: vergleicheWaffeMitKatalog(gespeichert, katalog),
  );
  return gespeichert.copyWith(katalogAbgleichAkzeptiert: schluessel);
}
