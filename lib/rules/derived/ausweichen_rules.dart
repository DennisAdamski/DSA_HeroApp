import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';

// Sonderfertigkeit-Bonus auf Ausweichen (Ausweichen I/II/III).
int computeSfAusweichenBonus(CombatSpecialRules special) {
  var total = 0;
  if (special.ausweichenI) {
    total += 3;
  }
  if (special.ausweichenII) {
    total += 3;
  }
  if (special.ausweichenIII) {
    total += 3;
  }
  return total;
}

// Akrobatik-Bonus auf Ausweichen: max(0, floor((TaW+Mod - 9) / 3)).
int computeAkrobatikBonus(Map<String, HeroTalentEntry> talents) {
  var akrobatikTaw = 0;
  for (final entry in talents.entries) {
    if (entry.key.toLowerCase().contains('akrobatik')) {
      akrobatikTaw = (entry.value.talentValue ?? 0) + entry.value.modifier;
      break;
    }
  }
  final raw = ((akrobatikTaw - 9) / 3).floor();
  return raw > 0 ? raw : 0;
}

// INI-Bonus auf Ausweichen: ab Kampf-INI 21 aufwaerts, ROUNDUP((INI-20)/10).
int computeIniAusweichenBonus({required int kampfInitiative}) {
  if (kampfInitiative < 21) return 0;
  return roundUpAwayFromZero((kampfInitiative - 20) / 10);
}

// Endwert Ausweichen: max(0, PA-Basis + SF-Bonus + Akrobatik + Axx + INI-Bonus + Mod - beKampf).
int computeAusweichen({
  required int paBase,
  required int sfAusweichenBonus,
  required int akrobatikBonus,
  required int axxAusweichenBonus,
  required int iniAusweichenBonus,
  required int ausweichenMod,
  required int beKampf,
}) {
  return clampNonNegative(
    paBase +
        sfAusweichenBonus +
        akrobatikBonus +
        axxAusweichenBonus +
        iniAusweichenBonus +
        ausweichenMod -
        beKampf,
  );
}
