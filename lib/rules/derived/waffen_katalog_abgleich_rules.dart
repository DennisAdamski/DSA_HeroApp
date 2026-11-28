// Abgleich der Waffen eines Helden mit dem Waffenkatalog.
//
// INI/GE rechnet mit den TP/KK-Grundwerten der unveränderten Waffe
// (`computeIniGe`). Bestandswaffen tragen aber oft schon verbesserte Werte
// direkt in KK-Basis und KK-Schwelle, etwa eine meisterlich geschmiedete
// Klinge mit 11/2 statt 12/3. Die Prüfung findet solche Abweichungen zur
// Laufzeit; die Oberfläche bietet an, den Unterschied als Verbesserung der
// Waffe (`kkBaseMod`/`kkThresholdMod`) einzutragen, die Waffe zu bearbeiten
// oder die Abweichung zu akzeptieren.

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

/// TP/KK-Grundwerte, z. B. `12/3`.
typedef TpKkWerte = ({int basis, int schwelle});

/// Eine Waffe, deren TP/KK-Grundwerte von ihrer Katalogwaffe abweichen.
class WaffenKatalogAbweichung {
  /// Erzeugt den Befund.
  const WaffenKatalogAbweichung({
    required this.slotIndex,
    required this.waffe,
    required this.katalogName,
    required this.katalog,
  });

  /// Position der Waffe in `CombatConfig.weaponSlots`.
  final int slotIndex;

  /// Die Waffe, wie sie geprüft wurde (Bezug für das frische Schreiben).
  final MainWeaponSlot waffe;

  /// Name der Katalogwaffe, gegen die verglichen wurde.
  final String katalogName;

  /// TP/KK-Grundwerte laut Katalog.
  final TpKkWerte katalog;

  /// Eingetragene TP/KK-Grundwerte der Waffe.
  TpKkWerte get eingetragen => _grundwerte(waffe);

  /// Anzeigename der Waffe, ersatzweise der Katalogname.
  String get waffenName {
    final name = waffe.name.trim();
    return name.isEmpty ? katalogName : name;
  }

  /// Verbesserung der Waffe nach dem Übernehmen als Modifikation.
  ///
  /// Die wirksame TP/KK bleibt gleich: Was bisher im Grundwert steckte,
  /// wandert zusätzlich zu einer schon eingetragenen Verbesserung in den Mod.
  TpKkWerte get modifikationNachUebernahme =>
      _modifikationNachUebernahme(waffe, katalog);

  /// Meldung für die Oberfläche.
  String get meldung {
    final waffeText = tpKkText(eingetragen);
    final katalogText = tpKkText(katalog);
    return '$waffenName: TP/KK $waffeText weicht vom Katalog '
        '„$katalogName“ ($katalogText) ab. INI/GE rechnet mit dem '
        'Grundwert der Waffe.';
  }

  /// Vorschlag für „Als Modifikation übernehmen“, z. B.
  /// „Grundwert 12/3, Verbesserung −1/−1“.
  String get vorschlag {
    final mod = modifikationNachUebernahme;
    final basis = mitVorzeichen(mod.basis);
    final schwelle = mitVorzeichen(mod.schwelle);
    return 'Grundwert ${tpKkText(katalog)}, Verbesserung $basis/$schwelle';
  }
}

// Eingetragene TP/KK-Grundwerte eines Slots.
TpKkWerte _grundwerte(MainWeaponSlot slot) {
  return (basis: slot.kkBase, schwelle: slot.kkThreshold);
}

// Verbesserung, die den bisherigen Unterschied zum Katalog [katalog] in den
// Mod verschiebt, ohne die wirksame TP/KK von [slot] zu ändern.
TpKkWerte _modifikationNachUebernahme(MainWeaponSlot slot, TpKkWerte katalog) {
  final basis = slot.kkBaseMod + slot.kkBase - katalog.basis;
  final schwelle = slot.kkThresholdMod + slot.kkThreshold - katalog.schwelle;
  return (basis: basis, schwelle: schwelle);
}

/// Text einer TP/KK, z. B. `12/3`.
String tpKkText(TpKkWerte werte) => '${werte.basis}/${werte.schwelle}';

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

/// Schlüssel einer akzeptierten Abweichung für
/// [MainWeaponSlot.katalogTpKkAkzeptiert], z. B. `11/2|Schwert 12/3`.
///
/// Enthält Waffe, Katalogwaffe und Katalogwert: Ändert sich einer davon,
/// gilt die Bestätigung nicht mehr.
String katalogTpKkSchluessel({
  required TpKkWerte eingetragen,
  required String katalogName,
  required TpKkWerte katalog,
}) {
  return '${tpKkText(eingetragen)}|${katalogName.trim()} ${tpKkText(katalog)}';
}

/// Prüft die TP/KK-Grundwerte von [waffen] gegen die Katalogwaffen.
///
/// Verglichen wird mit der Katalogwaffe gleichen Namens und Kampftyps; der
/// Name stammt aus der Waffenart, ersatzweise aus dem Waffennamen. Ohne
/// Katalogtreffer, ohne lesbare Katalog-TP/KK, bei bewusst deaktivierter
/// TP/KK (0/0) und bei akzeptierter Abweichung gibt es keinen Befund. Führt
/// der Katalog mehrere Einträge des Namens, genügt die Übereinstimmung mit
/// einem davon.
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
  if (waffe.kkBase == 0 && waffe.kkThreshold == 0) {
    return null;
  }
  final art = waffe.weaponType.trim().isEmpty ? waffe.name : waffe.weaponType;
  final schluessel = normalizeCombatToken(art);
  if (schluessel.isEmpty) {
    return null;
  }
  final kandidaten = <({WeaponDef def, TpKkWerte werte})>[];
  for (final def in katalogwaffen) {
    if (normalizeCombatToken(def.name) != schluessel) {
      continue;
    }
    if (weaponCombatTypeFromJson(def.type) != waffe.combatType) {
      continue;
    }
    final werte = leseKatalogTpKk(def.tpkk);
    if (werte != null) {
      kandidaten.add((def: def, werte: werte));
    }
  }
  if (kandidaten.isEmpty) {
    return null;
  }
  final grundwerte = _grundwerte(waffe);
  if (kandidaten.any((k) => k.werte == grundwerte)) {
    return null;
  }
  final vergleich = kandidaten.first;
  final befund = WaffenKatalogAbweichung(
    slotIndex: index,
    waffe: waffe,
    katalogName: vergleich.def.name.trim(),
    katalog: vergleich.werte,
  );
  final akzeptiert = katalogTpKkSchluessel(
    eingetragen: befund.eingetragen,
    katalogName: befund.katalogName,
    katalog: befund.katalog,
  );
  if (waffe.katalogTpKkAkzeptiert == akzeptiert) {
    return null;
  }
  return befund;
}

/// Trägt den Unterschied zwischen [gespeichert] und dem Katalog als
/// Verbesserung der Waffe ein.
///
/// KK-Basis und KK-Schwelle werden die Katalogwerte [katalog]; der bisherige
/// Unterschied kommt zur vorhandenen Verbesserung hinzu, die wirksame TP/KK
/// bleibt also gleich, INI/GE rechnet danach mit dem Katalogwert. Eine
/// frühere Bestätigung entfällt. Arbeitet auf dem frisch geladenen Slot.
MainWeaponSlot uebernimmKatalogAbweichungAlsModifikation(
  MainWeaponSlot gespeichert, {
  required TpKkWerte katalog,
}) {
  final mod = _modifikationNachUebernahme(gespeichert, katalog);
  return gespeichert.copyWith(
    kkBase: katalog.basis,
    kkThreshold: katalog.schwelle,
    kkBaseMod: mod.basis,
    kkThresholdMod: mod.schwelle,
    katalogTpKkAkzeptiert: '',
  );
}

/// Bestätigt die Abweichung des frisch geladenen Slots [gespeichert] von
/// der Katalogwaffe [katalogName] mit [katalog] als gewollt.
///
/// Die Werte der Waffe bleiben unverändert; die Prüfung schweigt, bis sich
/// Waffe oder Katalog ändern.
MainWeaponSlot akzeptiereKatalogAbweichung(
  MainWeaponSlot gespeichert, {
  required String katalogName,
  required TpKkWerte katalog,
}) {
  final schluessel = katalogTpKkSchluessel(
    eingetragen: _grundwerte(gespeichert),
    katalogName: katalogName,
    katalog: katalog,
  );
  return gespeichert.copyWith(katalogTpKkAkzeptiert: schluessel);
}
