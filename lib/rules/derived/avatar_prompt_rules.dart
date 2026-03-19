import 'package:dsa_heldenverwaltung/domain/avatar_style.dart';
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
  final parts = <String>[];

  // 1. Rahmen: Hochkant-Halbkoerper-Portrait
  parts.add(
    'Half-body portrait of a fantasy character in tall vertical composition, '
    'showing head, torso, and arms, facing the viewer',
  );

  // 2. Rasse
  final raceDesc = mapRaceToVisualDescription(hero.background.rasse);
  if (raceDesc.isNotEmpty) {
    parts.add(raceDesc);
  }

  // 3. Geschlecht
  final genderDesc = mapGenderToDescription(hero.appearance.geschlecht);
  if (genderDesc.isNotEmpty) {
    parts.add(genderDesc);
  }

  // 4. Koerperliche Merkmale
  final physicalTraits = _buildPhysicalTraits(hero);
  if (physicalTraits.isNotEmpty) {
    parts.add(physicalTraits);
  }

  // 5. Kultur
  final cultureDesc = _mapCultureToDescription(hero.background.kultur);
  if (cultureDesc.isNotEmpty) {
    parts.add(cultureDesc);
  }

  // 6. Profession
  final professionDesc = _mapProfessionToDescription(hero.background.profession);
  if (professionDesc.isNotEmpty) {
    parts.add(professionDesc);
  }

  // 7. Aussehen-Freitext
  final aussehen = hero.appearance.aussehen.trim();
  if (aussehen.isNotEmpty) {
    parts.add(aussehen);
  }

  // 8. Nutzerzusatz
  final extra = additionalDescription.trim();
  if (extra.isNotEmpty) {
    parts.add(extra);
  }

  // 9. Stil
  parts.add(style.promptFragment);

  // 10. Rahmenbedingungen
  parts.add('Medieval fantasy setting, dramatic lighting');
  parts.add('No text, no watermark, no UI elements, no frame');

  return parts.join('. ').replaceAll('.. ', '. ');
}

/// Mappt DSA-Rassen auf visuelle Beschreibungen.
String mapRaceToVisualDescription(String rasse) {
  final normalized = rasse.trim().toLowerCase();
  if (normalized.isEmpty) return '';

  if (normalized.contains('elf')) {
    return 'an elf with elegant pointed ears and graceful features';
  }
  if (normalized.contains('zwerg')) {
    return 'a stout dwarf with a sturdy build and strong features';
  }
  if (normalized.contains('halb') && normalized.contains('elf')) {
    return 'a half-elf with slightly pointed ears';
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
  final normalized = geschlecht.trim().toLowerCase();
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

  final alter = hero.appearance.alter.trim();
  if (alter.isNotEmpty) {
    final age = int.tryParse(alter);
    if (age != null) {
      if (age < 20) {
        traits.add('young');
      } else if (age < 35) {
        traits.add('in their twenties');
      } else if (age < 50) {
        traits.add('middle-aged');
      } else {
        traits.add('older, weathered');
      }
    }
  }

  // Koerperbau aus Groesse und Gewicht ableiten
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
  final height = int.tryParse(groesse);
  final weight = int.tryParse(gewicht);
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
  final normalized = kultur.trim().toLowerCase();
  if (normalized.isEmpty) return '';

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
  final normalized = profession.trim().toLowerCase();
  if (normalized.isEmpty) return '';

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
  if (normalized.contains('priester') ||
      normalized.contains('geweihte')) {
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
