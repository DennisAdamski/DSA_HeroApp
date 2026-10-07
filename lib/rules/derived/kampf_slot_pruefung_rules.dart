// Slotprüfung der Kampfkonfiguration (ARCH-05): Waffenplätze und Nebenhand.
//
// Bisher lag sie im Kampf-Tab-Widget. Die Prüfung liefert **alle** Befunde,
// damit eine Sofortänderung nur dann abgewiesen wird, wenn sie einen neuen
// Fehler einführt; eine bereits gespeicherte ungültige Konfiguration sperrt
// so nicht jede weitere Bedienung. „Speichern“ im Editor prüft weiterhin
// alles und meldet den ersten Befund.

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/validation/combat_talent_validation.dart';

/// Art eines Befunds der Slotprüfung.
enum KampfSlotFehlerArt {
  /// Das gewählte Talent ist kein Kampftalent des Katalogs.
  talentUngueltig,

  /// Das Talent passt nicht zum Kampftyp des Slots.
  talentPasstNichtZumKampftyp,

  /// Die Waffenart gehört nicht zum gewählten Talent.
  waffenartPasstNichtZumTalent,

  /// Eine Waffenart ist ohne Talent eingetragen.
  waffenartOhneTalent,

  /// Die KK-Schwelle ist negativ.
  kkSchwelleNegativ,

  /// TP/KK ist nur halb deaktiviert.
  tpKkUnvollstaendig,

  /// Weniger als ein Schadenswürfel.
  wuerfelanzahlZuKlein,

  /// Negative Ladezeit einer Fernkampfwaffe.
  ladezeitNegativ,

  /// Negativer Geschossbestand.
  geschossbestandNegativ,

  /// Haupt- und Nebenhand nutzen dieselbe Waffe.
  nebenhandGleicheWaffe,

  /// Parierwaffe ohne Sonderfertigkeit Linkhand.
  parierwaffeOhneLinkhand,

  /// Negativer Bruchfaktor des Nebenhandteils.
  nebenhandBfNegativ,
}

/// Ein Befund der Slotprüfung.
class KampfSlotFehler {
  /// Erzeugt den Befund.
  const KampfSlotFehler({
    required this.slotSchluessel,
    required this.art,
    required this.meldung,
  });

  /// Stabiler Bezug des Befunds: Slot-ID, ersatzweise die Position, oder
  /// `nebenhand`. Bleibt beim Umsortieren gleich, anders als die Meldung.
  final String slotSchluessel;

  /// Art des Befunds.
  final KampfSlotFehlerArt art;

  /// Meldung für die Oberfläche, z. B. „Waffe 2: …“.
  final String meldung;
}

/// Prüft Waffenplätze und Nebenhand von [config] gegen [catalog].
///
/// Liefert alle Befunde in Slotreihenfolge, die Nebenhand zuletzt; der erste
/// Befund ist die Meldung, die der Editor beim Speichern zeigt.
List<KampfSlotFehler> pruefeKampfSlots({
  required CombatConfig config,
  required RulesCatalog catalog,
}) {
  final talentById = <String, TalentDef>{
    for (final talent in catalog.talents.where(isCombatTalentDef))
      talent.id: talent,
  };
  final befunde = <KampfSlotFehler>[];
  final slots = config.weaponSlots;
  for (var i = 0; i < slots.length; i++) {
    final slot = slots[i];
    final hasAnyData =
        slot.name.trim().isNotEmpty ||
        slot.talentId.trim().isNotEmpty ||
        slot.weaponType.trim().isNotEmpty;
    if (!hasAnyData) {
      continue;
    }
    final slotLabel = 'Waffe ${i + 1}';
    final schluessel = slot.id.trim().isEmpty ? '#$i' : slot.id;
    void melde(KampfSlotFehlerArt art, String text) {
      befunde.add(
        KampfSlotFehler(
          slotSchluessel: schluessel,
          art: art,
          meldung: '$slotLabel: $text',
        ),
      );
    }

    final talentId = slot.talentId.trim();
    final talent = talentId.isEmpty ? null : talentById[talentId];
    final weaponType = slot.weaponType.trim();
    if (talentId.isNotEmpty && talent == null) {
      melde(
        KampfSlotFehlerArt.talentUngueltig,
        'Das gewählte Talent ist kein gültiges Kampftalent.',
      );
    } else if (talent != null) {
      if (combatTypeFromTalent(talent) != slot.combatType) {
        melde(
          KampfSlotFehlerArt.talentPasstNichtZumKampftyp,
          'Talent "${talent.name}" passt nicht zum Waffenkampftyp.',
        );
      } else if (weaponType.isNotEmpty &&
          !weaponTypeOptionsForTalent(
            talent: talent,
            catalog: catalog,
            combatType: slot.combatType,
          ).contains(weaponType)) {
        melde(
          KampfSlotFehlerArt.waffenartPasstNichtZumTalent,
          'Waffenart "$weaponType" passt nicht zum Talent "${talent.name}".',
        );
      }
    } else if (weaponType.isNotEmpty) {
      melde(
        KampfSlotFehlerArt.waffenartOhneTalent,
        'Waffenart "$weaponType" benötigt ein gültiges Talent.',
      );
    }
    if (slot.kkThreshold < 0) {
      melde(
        KampfSlotFehlerArt.kkSchwelleNegativ,
        'KK-Schwelle darf nicht negativ sein.',
      );
    } else if (slot.kkThreshold == 0 && slot.kkBase != 0) {
      melde(
        KampfSlotFehlerArt.tpKkUnvollstaendig,
        'TP/KK darf nur als 0/0 deaktiviert werden.',
      );
    }
    if (slot.tpDiceCount < 1) {
      melde(
        KampfSlotFehlerArt.wuerfelanzahlZuKlein,
        'Würfelanzahl muss >= 1 sein.',
      );
    }
    if (slot.isRanged && slot.rangedProfile.reloadTime < 0) {
      melde(
        KampfSlotFehlerArt.ladezeitNegativ,
        'Ladezeit darf nicht negativ sein.',
      );
    }
    if (slot.isRanged &&
        slot.rangedProfile.projectiles.any((geschoss) => geschoss.count < 0)) {
      melde(
        KampfSlotFehlerArt.geschossbestandNegativ,
        'Geschossbestände dürfen nicht negativ sein.',
      );
    }
  }

  void meldeNebenhand(KampfSlotFehlerArt art, String text) {
    befunde.add(
      KampfSlotFehler(
        slotSchluessel: 'nebenhand',
        art: art,
        meldung: 'Nebenhand: $text',
      ),
    );
  }

  final assignment = config.offhandAssignment;
  if (assignment.weaponIndex >= 0 &&
      assignment.weaponIndex == config.selectedWeaponIndex) {
    meldeNebenhand(
      KampfSlotFehlerArt.nebenhandGleicheWaffe,
      'Haupthand und Nebenhand dürfen nicht dieselbe Waffe nutzen.',
    );
  }
  if (assignment.usesEquipment &&
      assignment.equipmentIndex >= 0 &&
      assignment.equipmentIndex < config.offhandEquipment.length) {
    final offhandEntry = config.offhandEquipment[assignment.equipmentIndex];
    if (offhandEntry.type == OffhandEquipmentType.parryWeapon &&
        !config.specialRules.linkhandActive) {
      meldeNebenhand(
        KampfSlotFehlerArt.parierwaffeOhneLinkhand,
        'Parierwaffen erfordern die Sonderfertigkeit Linkhand.',
      );
    }
    if (offhandEntry.breakFactor < 0) {
      meldeNebenhand(
        KampfSlotFehlerArt.nebenhandBfNegativ,
        'BF darf nicht negativ sein.',
      );
    }
  }
  return befunde;
}

/// Liefert den ersten Befund von [nachher], den [vorher] noch nicht hatte.
///
/// Verglichen wird über Slotbezug und Art, nicht über die Meldung, deren
/// Positionsangabe sich beim Umsortieren ändert. `null` bedeutet: Die
/// Änderung führt keinen neuen Fehler ein.
KampfSlotFehler? neuerKampfSlotFehler({
  required CombatConfig vorher,
  required CombatConfig nachher,
  required RulesCatalog catalog,
}) {
  final bekannt = <(String, KampfSlotFehlerArt)>{
    for (final befund in pruefeKampfSlots(config: vorher, catalog: catalog))
      (befund.slotSchluessel, befund.art),
  };
  for (final befund in pruefeKampfSlots(config: nachher, catalog: catalog)) {
    if (!bekannt.contains((befund.slotSchluessel, befund.art))) {
      return befund;
    }
  }
  return null;
}

/// Leitet den Kampftyp eines Talents aus seinem `type`-Feld ab.
WeaponCombatType combatTypeFromTalent(TalentDef talent) {
  return talent.type.trim().toLowerCase() == 'fernkampf'
      ? WeaponCombatType.ranged
      : WeaponCombatType.melee;
}

/// Normalisiert einen String-Token fuer case-insensitiven Vergleich.
String normalizeToken(String raw) {
  var value = raw.trim().toLowerCase();
  value = value
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

/// Parst Waffen-Kategorien aus einem mehrzeiligen String.
List<String> parseWeaponCategoryValues(String raw) {
  final seen = <String>{};
  final values = <String>[];
  for (final token in raw.split(RegExp(r'[\n,;]+'))) {
    final trimmed = token.trim();
    if (trimmed.isEmpty || seen.contains(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    values.add(trimmed);
  }
  return values;
}

/// Gibt die Waffenart-Optionen fuer ein Talent zurueck.
List<String> weaponTypeOptionsForTalent({
  required TalentDef? talent,
  required RulesCatalog catalog,
  required WeaponCombatType combatType,
}) {
  if (talent == null) {
    return const <String>[];
  }
  final seen = <String>{};
  final options = <String>[];
  final talentNameToken = normalizeToken(talent.name);
  for (final weapon in catalog.weapons) {
    if (weaponCombatTypeFromJson(weapon.type) != combatType) {
      continue;
    }
    if (normalizeToken(weapon.combatSkill) != talentNameToken) {
      continue;
    }
    final name = weapon.name.trim();
    if (name.isEmpty || seen.contains(name)) {
      continue;
    }
    seen.add(name);
    options.add(name);
  }
  for (final fallback in parseWeaponCategoryValues(talent.weaponCategory)) {
    if (seen.contains(fallback)) {
      continue;
    }
    seen.add(fallback);
    options.add(fallback);
  }
  options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return options;
}
