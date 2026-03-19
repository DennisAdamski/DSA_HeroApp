import 'package:dsa_heldenverwaltung/domain/avatar_style.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Baut einen vollstaendigen Bildgenerierungs-Prompt aus Heldendaten.
///
/// Der Prompt wird auf Englisch generiert, da alle grossen Bild-APIs
/// damit deutlich bessere Ergebnisse liefern.
String buildAvatarPrompt({
  required HeroSheet hero,
  required AvatarStyle style,
  String additionalDescription = '',
}) {
  final parts = <String>[
    'Half-body portrait of a fantasy character in tall vertical composition, '
        'showing head, torso, and arms, facing the viewer',
  ];

  final raceDesc = mapRaceToVisualDescription(hero.background.rasse);
  if (raceDesc.isNotEmpty) {
    parts.add(raceDesc);
  }

  final genderDesc = mapGenderToDescription(hero.appearance.geschlecht);
  if (genderDesc.isNotEmpty) {
    parts.add(genderDesc);
  }

  final physicalTraits = _buildPhysicalTraits(hero);
  if (physicalTraits.isNotEmpty) {
    parts.add(physicalTraits);
  }

  final cultureDesc = _mapCultureToDescription(hero.background.kultur);
  if (cultureDesc.isNotEmpty) {
    parts.add(cultureDesc);
  }

  final professionDesc = _mapProfessionToDescription(
    hero.background.profession,
  );
  if (professionDesc.isNotEmpty) {
    parts.add(professionDesc);
  }

  final combatIdentity = _buildCombatIdentity(hero);
  if (combatIdentity.isNotEmpty) {
    parts.add(combatIdentity);
  }

  final statusDesc = _buildStatusHint(hero);
  if (statusDesc.isNotEmpty) {
    parts.add(statusDesc);
  }

  final personaDesc = _buildPersonaHint(
    hero.background.familieHerkunftHintergrund,
  );
  if (personaDesc.isNotEmpty) {
    parts.add(personaDesc);
  }

  final demeanorDesc = _buildDemeanor(hero);
  if (demeanorDesc.isNotEmpty) {
    parts.add(demeanorDesc);
  }

  final equipmentDesc = _buildEquipmentDetails(hero);
  if (equipmentDesc.isNotEmpty) {
    parts.add(equipmentDesc);
  }

  final magicHint = _buildMagicHint(hero);
  if (magicHint.isNotEmpty) {
    parts.add(magicHint);
  }

  final appearanceDesc = _buildAppearanceDetails(hero);
  if (appearanceDesc.isNotEmpty) {
    parts.add(appearanceDesc);
  }

  final extra = additionalDescription.trim();
  if (extra.isNotEmpty) {
    parts.add(extra);
  }

  parts.add(style.promptFragment);
  parts.add('Medieval fantasy setting, dramatic lighting');
  parts.add('No text, no watermark, no UI elements, no frame');

  return _composePrompt(parts);
}

/// Mappt DSA-Rassen auf visuelle Beschreibungen.
String mapRaceToVisualDescription(String rasse) {
  final normalized = _normalizeForLookup(rasse);
  if (normalized.isEmpty) return '';

  if (normalized.contains('halbelf') ||
      (normalized.contains('halb') && normalized.contains('elf'))) {
    return 'a half-elf with subtly pointed ears and refined features';
  }
  if (normalized.contains('elf')) {
    return 'an elf with elegant pointed ears and graceful features';
  }
  if (normalized.contains('zwerg')) {
    return 'a stout dwarf with a sturdy build and strong features';
  }
  if (normalized.contains('ork')) {
    return 'a half-orc with strong, rugged features and slightly greenish skin';
  }
  if (normalized.contains('goblin')) {
    return 'a small goblin-like creature with sharp features';
  }
  if (normalized.contains('achaz')) {
    return 'a reptilian humanoid with scaled skin and slit-pupil eyes';
  }
  // Menschen und unbekannte Rassen
  return 'a human';
}

/// Mappt Geschlecht auf englische Beschreibung.
String mapGenderToDescription(String geschlecht) {
  final normalized = _normalizeForLookup(geschlecht);
  if (normalized.isEmpty) return '';

  if (normalized.contains('weib') || normalized == 'w' || normalized == 'f') {
    return 'female';
  }
  if (normalized.contains('mann') ||
      normalized.contains('maenn') ||
      normalized == 'm') {
    return 'male';
  }
  return '';
}

String _buildPhysicalTraits(HeroSheet hero) {
  final traits = <String>[];

  final age = _parseAgeYears(hero.appearance.alter);
  if (age != null) {
    if (age < 20) {
      traits.add('young adult');
    } else if (age < 35) {
      traits.add('in their twenties');
    } else if (age < 50) {
      traits.add('middle-aged');
    } else {
      traits.add('older, weathered');
    }
  }

  final bodyBuild = _estimateBodyBuild(
    hero.appearance.groesse.trim(),
    hero.appearance.gewicht.trim(),
  );
  if (bodyBuild.isNotEmpty) {
    traits.add(bodyBuild);
  }

  final haarfarbe = hero.appearance.haarfarbe.trim();
  if (haarfarbe.isNotEmpty) {
    traits.add('$haarfarbe hair');
  }

  final augenfarbe = hero.appearance.augenfarbe.trim();
  if (augenfarbe.isNotEmpty) {
    traits.add('$augenfarbe eyes');
  }

  return traits.isEmpty ? '' : traits.join(', ');
}

/// Schaetzt den Koerperbau anhand von Groesse (cm) und Gewicht (kg).
String _estimateBodyBuild(String groesse, String gewicht) {
  final height = _parseHeightInCm(groesse);
  final weight = _parseWeightInKg(gewicht);
  final parts = <String>[];

  if (height != null) {
    if (height < 150) {
      parts.add('very short');
    } else if (height < 165) {
      parts.add('short');
    } else if (height > 190) {
      parts.add('very tall');
    } else if (height > 180) {
      parts.add('tall');
    }
  }

  if (height != null && weight != null && height > 0) {
    final heightM = height / 100.0;
    final bmi = weight / (heightM * heightM);
    if (bmi < 17) {
      parts.add('very thin build');
    } else if (bmi < 20) {
      parts.add('slender build');
    } else if (bmi < 25) {
      parts.add('athletic build');
    } else if (bmi < 30) {
      parts.add('stocky build');
    } else {
      parts.add('heavy build');
    }
  }

  return parts.join(', ');
}

String _mapCultureToDescription(String kultur) {
  final normalized = _normalizeForLookup(kultur);
  if (normalized.isEmpty) return '';

  if (normalized.contains('aranien')) {
    return 'Aranian and tulamid-inspired clothing, elegant fabrics, jewelry, '
        'and refined court fashion';
  }
  if (normalized.contains('thorwal')) {
    return 'Norse/Viking-inspired clothing and style';
  }
  if (normalized.contains('tulamid') || normalized.contains('novadi')) {
    return 'Middle-Eastern inspired clothing and ornaments';
  }
  if (normalized.contains('norbard') || normalized.contains('svellt')) {
    return 'rugged northern clothing, furs and leather';
  }
  if (normalized.contains('horasisch') || normalized.contains('almada')) {
    return 'elegant Renaissance-era clothing';
  }
  if (normalized.contains('wald') && normalized.contains('elf')) {
    return 'flowing nature-inspired elven garments';
  }
  if (normalized.contains('mittelreich') || normalized.contains('garetien')) {
    return 'Central European medieval clothing';
  }
  return '';
}

String _mapProfessionToDescription(String profession) {
  final normalized = _normalizeForLookup(profession);
  if (normalized.isEmpty) return '';

  if (normalized.contains('balayan') || normalized.contains('ishannah')) {
    return 'poised like a trained sword dancer, elegant duelist, and covert '
        'court agent';
  }
  if (normalized.contains('krieger') || normalized.contains('soeldner')) {
    return 'wearing armor, warrior bearing';
  }
  if (normalized.contains('magier') || normalized.contains('maga')) {
    return 'wearing robes, carrying a staff, scholarly appearance';
  }
  if (normalized.contains('hexe')) {
    return 'mystical appearance, natural elements in attire';
  }
  if (normalized.contains('jaeger') || normalized.contains('waldlaeufer')) {
    return 'wearing practical hunting gear, leather armor, carrying a bow';
  }
  if (normalized.contains('dieb') || normalized.contains('streuner')) {
    return 'wearing dark, practical clothing, hooded cloak';
  }
  if (normalized.contains('priester') || normalized.contains('geweihte')) {
    return 'wearing religious vestments, holy symbol visible';
  }
  if (normalized.contains('barde') || normalized.contains('gauckler')) {
    return 'wearing colorful clothing, carrying a musical instrument';
  }
  if (normalized.contains('handwerker') || normalized.contains('schmied')) {
    return 'wearing a work apron, strong hands';
  }
  if (normalized.contains('ritter')) {
    return 'wearing plate armor, noble bearing, heraldic symbols';
  }
  // Generischer Fallback: Profession direkt einbauen
  return 'a $profession';
}

String _buildCombatIdentity(HeroSheet hero) {
  final saberTalent = hero.talents['tal_saebel']?.talentValue ?? 0;
  if (saberTalent >= 18) {
    return 'an accomplished saber duelist with a controlled, elegant stance';
  }

  final daggerTalent = hero.talents['tal_dolche']?.talentValue ?? 0;
  if (daggerTalent >= 18) {
    return 'clearly trained in close-quarters knife fighting';
  }

  return '';
}

String _buildStatusHint(HeroSheet hero) {
  final title = _normalizeForLookup(hero.background.titel);
  final stand = _normalizeForLookup(hero.background.stand);
  final sozialstatus = hero.background.sozialstatus;

  if (title.contains('baron') ||
      title.contains('graf') ||
      title.contains('prinz') ||
      title.contains('koenig') ||
      stand.contains('adel') ||
      stand.contains('nobel')) {
    return 'noble bearing, luxurious presentation, subtle signs of rank';
  }
  if (sozialstatus >= 12) {
    return 'aristocratic bearing and luxurious presentation';
  }
  if (sozialstatus >= 9) {
    return 'high-status, refined presentation';
  }
  if (sozialstatus >= 6) {
    return 'well-kept, respectable presentation';
  }
  return '';
}

String _buildPersonaHint(String backgroundText) {
  final normalized = _normalizeForLookup(backgroundText);
  if (normalized.contains('deckname') || normalized.contains('alias')) {
    return 'carefully curated, refined presentation as if maintaining a '
        'convincing cover identity';
  }
  return '';
}

String _buildDemeanor(HeroSheet hero) {
  final source = _normalizeForLookup(
    '${hero.vorteileText} ${hero.nachteileText}',
  );
  final details = <String>[];

  void addIf(bool condition, String value) {
    if (condition && !details.contains(value)) {
      details.add(value);
    }
  }

  addIf(source.contains('herausragendes aussehen'), 'striking beauty');
  addIf(
    source.contains('arroganz') || source.contains('eitelkeit'),
    'proud, self-assured bearing',
  );
  addIf(
    source.contains('prinzipientreue') || source.contains('verpflichtungen'),
    'disciplined, composed presence',
  );
  addIf(source.contains('flink'), 'light-footed, agile posture');
  addIf(source.contains('guter ruf'), 'polished, reputable presentation');
  addIf(source.contains('neugier'), 'keen, alert gaze');

  return details.take(3).join(', ');
}

String _buildEquipmentDetails(HeroSheet hero) {
  final details = <String>[];
  final seen = <String>{};

  void addDetail(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      return;
    }
    final normalized = _normalizeForLookup(cleaned);
    if (seen.contains(normalized)) {
      return;
    }
    seen.add(normalized);
    details.add(cleaned);
  }

  final selectedWeapon = hero.combatConfig.selectedWeaponOrNull;
  if (selectedWeapon != null) {
    addDetail(
      _mapWeaponToDescription(selectedWeapon.name, selectedWeapon.weaponType),
    );
  }

  for (final equipment in hero.combatConfig.offhandEquipment) {
    addDetail(_mapEquipmentNameToDescription(equipment.name));
    if (details.length >= 2) {
      break;
    }
  }

  if (details.length < 2) {
    for (final armorPiece in hero.combatConfig.armor.pieces) {
      if (!armorPiece.isActive) {
        continue;
      }
      addDetail(_mapArmorToDescription(armorPiece.name));
      if (details.length >= 2) {
        break;
      }
    }
  }

  if (details.length < 2) {
    for (final entry in hero.inventoryEntries) {
      addDetail(_mapInventoryItemToDescription(entry));
      if (details.length >= 2) {
        break;
      }
    }
  }

  return details.join(', ');
}

String _buildMagicHint(HeroSheet hero) {
  final hasMagic =
      hero.representationen.isNotEmpty ||
      hero.spells.isNotEmpty ||
      hero.magicSpecialAbilities.isNotEmpty;
  if (!hasMagic) {
    return '';
  }

  final spellIds = hero.spells.keys.map(_normalizeForLookup).join(' ');
  final inventoryText = hero.inventoryEntries
      .map(
        (entry) =>
            _normalizeForLookup('${entry.gegenstand} ${entry.beschreibung}'),
      )
      .join(' ');
  if (spellIds.contains('axxeleratus') ||
      inventoryText.contains('axxeleratus')) {
    return 'subtle impression of supernatural speed and controlled motion';
  }

  return 'a subtle arcane aura';
}

String _buildAppearanceDetails(HeroSheet hero) {
  final details = <String>[];
  final normalized = _normalizeForLookup(hero.appearance.aussehen);

  if (normalized.contains('panther') && normalized.contains('tattoo')) {
    details.add('visible panther tattoo');
  }

  final aussehen = hero.appearance.aussehen.trim();
  if (aussehen.isNotEmpty) {
    details.add(aussehen);
  }

  return _dedupeParts(details).join(', ');
}

String _mapWeaponToDescription(String name, String weaponType) {
  final normalized = _normalizeForLookup('$name $weaponType');
  if (normalized.isEmpty) {
    return '';
  }
  if (normalized.contains('pantherprank')) {
    return 'panther-claw gauntlets';
  }
  if (normalized.contains('kriegsfaecher')) {
    return 'a bladed war fan';
  }
  if (normalized.contains('amazonen') ||
      normalized.contains('khunchomer') ||
      normalized.contains('saebel') ||
      normalized.contains('sabel')) {
    if (normalized.contains('zahn')) {
      return 'an ornate curved saber with a fang-like blade';
    }
    return 'an elegant curved saber';
  }
  if (normalized.contains('dolch')) {
    return 'a dagger';
  }
  if (normalized.contains('speer')) {
    return 'a ceremonial spear';
  }
  return '';
}

String _mapEquipmentNameToDescription(String name) {
  final normalized = _normalizeForLookup(name);
  if (normalized.contains('kriegsfaecher')) {
    return 'a bladed war fan';
  }
  if (normalized.contains('schild')) {
    return 'a shield';
  }
  return '';
}

String _mapArmorToDescription(String name) {
  final normalized = _normalizeForLookup(name);
  if (normalized.contains('tuchruestung')) {
    return 'layered cloth armor';
  }
  if (normalized.contains('amazonenruestung')) {
    return 'amazon-style armor';
  }
  return '';
}

String _mapInventoryItemToDescription(HeroInventoryEntry entry) {
  final normalized = _normalizeForLookup(
    '${entry.gegenstand} ${entry.typ} ${entry.beschreibung}',
  );
  if (normalized.isEmpty) {
    return '';
  }
  if (normalized.contains('pantherprank')) {
    return 'panther-claw gauntlets';
  }
  if (normalized.contains('schmuck')) {
    return 'fine jewelry';
  }
  if (normalized.contains('schone kleidung')) {
    return 'elegant fine clothing';
  }
  if (normalized.contains('elfenbauschmantel')) {
    return 'a feather-light elven cloak';
  }
  if (normalized.contains('speer') && normalized.contains('hohepriester')) {
    return 'a ceremonial priestly spear';
  }
  return '';
}

String _composePrompt(List<String> rawParts) {
  final cleaned = _dedupeParts(rawParts);
  return cleaned.join('. ');
}

List<String> _dedupeParts(List<String> rawParts) {
  final cleaned = <String>[];
  final seen = <String>{};

  for (final part in rawParts) {
    final normalizedWhitespace = part.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedWhitespace.isEmpty) {
      continue;
    }
    final normalized = _normalizeForLookup(normalizedWhitespace);
    if (normalized.isEmpty || seen.contains(normalized)) {
      continue;
    }
    seen.add(normalized);
    cleaned.add(normalizedWhitespace);
  }

  return cleaned;
}

int? _parseAgeYears(String value) {
  final match = RegExp(r'(\d{1,3})').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(1)!);
}

int? _parseHeightInCm(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }

  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(normalized);
  if (match == null) {
    return null;
  }

  final parsed = double.tryParse(match.group(1)!);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  if (parsed >= 100 && parsed <= 260) {
    return parsed.round();
  }
  if (parsed >= 1.2 && parsed <= 2.5) {
    return (parsed * 100).round();
  }
  return null;
}

int? _parseWeightInKg(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }

  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(normalized);
  if (match == null) {
    return null;
  }

  final parsed = double.tryParse(match.group(1)!);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  if (parsed >= 20 && parsed <= 300) {
    return parsed.round();
  }
  return null;
}

String _normalizeForLookup(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
