// Grundbegriffe des waffenlosen Kampfes ohne Abhängigkeit auf die
// Kampfvorschau, damit `combat_rules.dart` sie selbst verwenden kann
// (WdS S. 89–91, Aventurisches Arsenal S. 69 f., 97 f., 150).

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';

/// Waffenloses Kampftalent.
enum WaffenlosesTalent {
  /// Schläge, Tritte, Kopfstöße: 1W6 TP(A), TP/KK 10/3, INI −2 (AA S. 150).
  raufen('tal_raufen', 'Raufen'),

  /// Griffe und Würfe: Schaden nur bei Würfen (WdS S. 89), sonst Position.
  ringen('tal_ringen', 'Ringen');

  const WaffenlosesTalent(this.talentId, this.talentName);
  final String talentId;
  final String talentName;

  /// Stabile ID des virtuellen Kampfmittels.
  String get kampfmittelId => 'waffenlos:$name';
}

/// Ob [slot] nur der leere Platzhalter eines Helden ohne Waffe ist.
///
/// Ein neuer Held und einer, dessen letzte Waffe entfernt wurde, tragen
/// diesen Platzhalter (`kampf_aenderung_rules.dart`); er ist keine Waffe.
bool istLeererWaffenplatzhalter(MainWeaponSlot slot) =>
    slot.name.trim().isEmpty &&
    slot.talentId.trim().isEmpty &&
    slot.weaponType.trim().isEmpty;

/// Tatsächlich geführte Hauptwaffe; der leere Platzhalter zählt nicht.
MainWeaponSlot? gefuehrteHauptwaffe(CombatConfig config) {
  final slot = config.selectedWeaponOrNull;
  return slot == null || istLeererWaffenplatzhalter(slot) ? null : slot;
}

/// Waffe, die mit Raufen oder Ringen geführt wird.
///
/// Handgemengewaffen wie Schlagring, Orchidee, Veteranenhand, Panzerarm und
/// Drachenklaue (Talent Raufen) wirken im waffenlosen Kampf; ihr Träger
/// bleibt waffenlos kampfbereit.
bool istWaffenloseWaffe(MainWeaponSlot slot) =>
    WaffenlosesTalent.values.any((t) => t.talentId == slot.talentId.trim());

/// Weder Hauptwaffe noch Nebenhand belegt.
bool haendeFrei(CombatConfig config) =>
    gefuehrteHauptwaffe(config) == null && config.offhandAssignment.isNone;

/// Ob der Held waffenlos kämpfen kann, ohne eine Waffe beiseitezulassen.
///
/// WdS S. 89: Raufen und Ringen sind Zweihandtechniken, die eigentlich
/// keine weitere Waffe und keinen Schild erlauben. Waffenlos geführte
/// Handgemengewaffen sind keine solche weitere Waffe.
bool waffenlosKampfbereit(CombatConfig config) {
  final haupt = gefuehrteHauptwaffe(config);
  if (haupt != null && !istWaffenloseWaffe(haupt)) return false;
  final neben = config.offhandAssignment;
  if (neben.isNone) return true;
  if (!neben.usesWeapon) return false;
  final slots = config.weaponSlots;
  return neben.weaponIndex < slots.length &&
      istWaffenloseWaffe(slots[neben.weaponIndex]);
}

/// Virtueller Waffenslot des waffenlosen Kampfes; wird nie gespeichert.
///
/// Werte des Katalogeintrags „Hände“ (AA S. 150): TP/KK 10/3, INI −2. Die
/// WM −1/−2 gilt nur, sobald ein Beteiligter eine Waffe führt; sie hängt vom
/// Gegner ab und steht deshalb als Hinweis, nicht im Grundwert.
MainWeaponSlot waffenloserSlot(WaffenlosesTalent talent) => MainWeaponSlot(
  id: talent.kampfmittelId,
  name: '${talent.talentName} (waffenlos)',
  talentId: talent.talentId,
  distanceClass: 'H',
  kkBase: 10,
  kkThreshold: 3,
  iniMod: -2,
  isOneHanded: false,
);

/// Hauptwaffe, mit der die Kampfvorschau rechnet.
///
/// Ohne Waffe und mit freien Händen kämpft der Held waffenlos (Raufen);
/// sonst bleibt es der gewählte Slot bzw. der leere Platzhalter.
MainWeaponSlot vorschauHauptwaffe(CombatConfig config) {
  if (haendeFrei(config)) return waffenloserSlot(WaffenlosesTalent.raufen);
  return config.selectedWeapon;
}

/// Talente, mit denen ein waffenloses Manöver laut Katalogtyp ausgeführt
/// wird (z. B. „Ringen-AT / Ringen-PA“); leer für alle übrigen Manöver.
Set<WaffenlosesTalent> waffenloseManoevertalente(ManeuverDef m) {
  final typ = m.typ.toLowerCase();
  return {
    for (final t in WaffenlosesTalent.values)
      if (typ.contains(t.talentName.toLowerCase())) t,
  };
}

/// Regeln einer waffenlos geführten Handgemengewaffe.
class Raufenwaffe {
  const Raufenwaffe({
    required this.manoeverIds,
    required this.tpAusdauer,
    this.hinweis = '',
  });

  /// Waffenlose Manöver, mit denen die Waffe eingesetzt werden kann.
  final Set<String> manoeverIds;

  /// Richtet TP(A) statt echter TP an.
  final bool tpAusdauer;
  final String hinweis;
}

/// Bekannte Handgemengewaffen (Talent Raufen) nach Katalogname.
///
/// AA S. 69 f. (Schlagring, Orchidee, Veteranenhand) und S. 97 f.
/// (Panzerarm, Drachenklaue). Für den Bock nennt der Index keine
/// Manöverliste; er bleibt deshalb ohne Einschränkung.
const Map<String, Raufenwaffe> kRaufenwaffen = {
  'Schlagring': Raufenwaffe(
    manoeverIds: {
      'man_doppelschlag',
      'man_gerade',
      'man_handkante',
      'man_schwinger',
    },
    tpAusdauer: true,
    hinweis:
        'Schlagring: TP(A), bei der Halbierung zu echten SP aufrunden '
        '(AA S. 69).',
  ),
  'Orchidee': Raufenwaffe(
    manoeverIds: {'man_doppelschlag', 'man_handkante', 'man_schwinger'},
    tpAusdauer: false,
    hinweis:
        'Orchidee: echte TP, Zonen-RS 1; Gerade nur mit geraden Klingen '
        '(AA S. 70).',
  ),
  'Veteranenhand': Raufenwaffe(
    manoeverIds: {'man_gerade'},
    tpAusdauer: false,
    hinweis: 'Veteranenhand: echte TP, Zonen-RS 2 (AA S. 70).',
  ),
  'Panzerarm': Raufenwaffe(
    manoeverIds: {'man_gerade'},
    tpAusdauer: false,
    hinweis: 'Panzerarm: echte TP; als Parierwaffe auch Binden (AA S. 97).',
  ),
  'Drachenklaue': Raufenwaffe(
    manoeverIds: {'man_gerade'},
    tpAusdauer: false,
    hinweis:
        'Drachenklaue: echte TP; Schwinger nur mit langer Klinge; Binden '
        'und Entwaffnen möglich (AA S. 98 f.).',
  ),
};

/// Regeln der Handgemengewaffe [slot], sonst `null`.
Raufenwaffe? raufenwaffeFuer(MainWeaponSlot slot) {
  if (slot.talentId.trim() != WaffenlosesTalent.raufen.talentId) return null;
  return kRaufenwaffen[slot.weaponType.trim()] ??
      kRaufenwaffen[slot.name.trim()];
}

/// Hinweise am Kampfmittel einer waffenlos geführten Waffe.
List<String> raufenwaffenHinweise(MainWeaponSlot slot) => [
  if (istWaffenloseWaffe(slot)) ...[
    'Waffenlos geführt (${slot.talentId.trim() == WaffenlosesTalent.raufen.talentId ? 'Raufen' : 'Ringen'}): '
        'bei Paraden gegen Waffen unbewaffnet (optional PA −2, halber Schaden).',
    if (raufenwaffeFuer(slot) case final r?) r.hinweis,
  ],
];
