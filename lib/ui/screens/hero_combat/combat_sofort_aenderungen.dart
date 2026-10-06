part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Einstiege der sofort wirksamen Bedienelemente im Kampf-Tab.
///
/// Jede Bedienung reicht den **angezeigten** Slot durch, nie nur seine
/// Position: Die Regeln in `kampf_aenderung_rules.dart` finden ihn damit im
/// gespeicherten Stand wieder, auch wenn ein anderer Schreibweg die Liste
/// inzwischen verschoben hat. Geschrieben wird über [_aendereKampf].
extension _CombatSofortAenderungen on _HeroCombatTabState {
  /// Macht [waffe] zur aktiven Hauptwaffe, `null` heißt „keine Waffe“.
  Future<void> _waehleWaffe(
    MainWeaponSlot? waffe, {
    int? index,
    required RulesCatalog catalog,
  }) async {
    await _aendereKampf(
      was: 'Waffenwahl',
      aenderung: (config) => mitAktiverWaffe(config, waffe, index: index),
      catalog: catalog,
    );
  }

  /// Wählt die Entfernungsstufe [stufe] der angezeigten Fernkampfwaffe.
  Future<void> _waehleEntfernung(
    MainWeaponSlot waffe,
    int stufe, {
    int? index,
    required RulesCatalog catalog,
  }) async {
    await _aendereKampf(
      was: 'Entfernung',
      aenderung: (config) => mitEntfernung(config, waffe, stufe, index: index),
      catalog: catalog,
    );
  }

  /// Wählt das Geschoss an [geschossIndex] der angezeigten [waffe], `null`
  /// heißt „kein Geschoss“.
  Future<void> _waehleGeschoss(
    MainWeaponSlot waffe,
    int? geschossIndex, {
    int? index,
    required RulesCatalog catalog,
  }) async {
    final geschosse = waffe.rangedProfile.projectiles;
    final geschoss = geschossIndex == null
        ? null
        : geschosse.elementAtOrNull(geschossIndex);
    await _aendereKampf(
      was: 'Geschosswahl',
      aenderung: (config) => mitGeschossWahl(
        config,
        waffe,
        geschoss,
        index: index,
        geschossIndex: geschossIndex,
      ),
      catalog: catalog,
    );
  }

  /// Verschiebt den Bestand des angezeigten aktiven Geschosses von [waffe].
  Future<void> _zaehleGeschoss(
    MainWeaponSlot waffe,
    int delta, {
    int? index,
    required RulesCatalog catalog,
  }) async {
    final profil = waffe.rangedProfile;
    final geschoss = profil.selectedProjectileOrNull;
    if (geschoss == null) {
      return;
    }
    await _aendereKampf(
      was: 'Geschossbestand',
      aenderung: (config) => mitGeschossSchritt(
        config,
        waffe,
        geschoss,
        delta,
        index: index,
        geschossIndex: profil.selectedProjectileIndex,
      ),
      catalog: catalog,
    );
  }

  /// Belegt die Nebenhand gemäß [auswahl] (`weapon:i`, `equipment:i` oder
  /// `none`) aus den beim Aufbau angezeigten [waffen] und [teile].
  Future<void> _waehleNebenhand(
    String auswahl, {
    required List<MainWeaponSlot> waffen,
    required List<OffhandEquipmentEntry> teile,
    required RulesCatalog catalog,
  }) async {
    final waffenIndex = _auswahlIndex(auswahl, 'weapon:');
    final teilIndex = _auswahlIndex(auswahl, 'equipment:');
    final waffe = waffenIndex == null
        ? null
        : waffen.elementAtOrNull(waffenIndex);
    final teil = teilIndex == null ? null : teile.elementAtOrNull(teilIndex);
    await _aendereKampf(
      was: 'Nebenhand',
      aenderung: (config) => mitNebenhand(
        config,
        waffe: waffe,
        waffenIndex: waffenIndex,
        teil: teil,
        teilIndex: teilIndex,
      ),
      catalog: catalog,
    );
  }

  // Position hinter [praefix] in einem Auswahlwert, sonst `null`.
  int? _auswahlIndex(String auswahl, String praefix) {
    if (!auswahl.startsWith(praefix)) {
      return null;
    }
    return int.tryParse(auswahl.substring(praefix.length));
  }

  /// Übernimmt ein Editorergebnis: neu angelegt ohne [ausgang], sonst als
  /// Ersatz der beim Öffnen angezeigten Waffe.
  ///
  /// Führt das Ergebnis Geschosse nicht mehr, fragt der Tab, ob sie nur
  /// abgelegt oder ganz entfernt werden (ARCH-03); Abbruch speichert nicht.
  Future<bool> _speichereWaffe(
    MainWeaponSlot slot, {
    MainWeaponSlot? ausgang,
    int? slotIndex,
    required RulesCatalog catalog,
  }) async {
    final bisher = ausgang;
    if (bisher == null) {
      return _aendereKampf(
        was: 'Waffe',
        aenderung: (config) => mitNeuerWaffe(config, slot),
        catalog: catalog,
      );
    }
    final weg = entfernteGeschosse(bisher, slot);
    var wie = KampfgegenstandEntfernen.ganzEntfernen;
    if (weg.isNotEmpty) {
      final namen = weg.map((geschoss) => geschoss.name.trim()).toList();
      final antwort = await frageGeschosseEntfernen(context, namen);
      if (antwort == null || !mounted) {
        return false;
      }
      wie = antwort;
    }
    return _aendereKampfUndInventar(
      was: 'Waffe',
      aenderung: (held) => ersetzeWaffeImKampf(
        held,
        ausgang: bisher,
        neu: slot,
        index: slotIndex,
        geschosseAblegen: wie == KampfgegenstandEntfernen.ablegen,
        neueId: neueEditorSlotId,
      ),
      catalog: catalog,
    );
  }

  /// Entfernt die angezeigte Waffe nach Rückfrage: nur ablegen oder ganz
  /// entfernen (ARCH-03). Ihre Geschosse bleiben im Inventar.
  Future<void> _entferneWaffe(
    int index,
    MainWeaponSlot angezeigt, {
    required RulesCatalog catalog,
  }) async {
    final wie = await frageKampfgegenstandEntfernen(
      context,
      titel: 'Waffe entfernen',
      name: angezeigt.name,
      art: 'den Waffen',
      mitGeschossen:
          angezeigt.fuehrtGeschosse &&
          angezeigt.rangedProfile.projectiles.isNotEmpty,
    );
    if (wie == null || !mounted) {
      return;
    }
    await _aendereKampfUndInventar(
      was: 'Entfernen der Waffe',
      aenderung: (held) => ohneWaffeImKampf(
        held,
        angezeigt,
        index: index,
        wie: wie,
        neueId: neueEditorSlotId,
      ),
      catalog: catalog,
    );
  }

  /// Ändert einzelne Felder der angezeigten Waffe (Tabelle).
  Future<void> _aendereWaffenfeld(
    int index,
    MainWeaponSlot angezeigt,
    MainWeaponSlot Function(MainWeaponSlot gespeichert) update, {
    required RulesCatalog catalog,
  }) async {
    await _aendereKampf(
      was: 'Waffe',
      aenderung: (config) =>
          aendereWaffe(config, angezeigt, update, index: index),
      catalog: catalog,
    );
  }

  /// Übernimmt ein Rüstungsteil aus dem Editor.
  Future<void> _speichereRuestungsteil(
    ArmorPiece neu, {
    ArmorPiece? ausgang,
    int? index,
    required RulesCatalog catalog,
  }) async {
    await _aendereKampf(
      was: 'Rüstungsteil',
      aenderung: (config) =>
          mitRuestungsteil(config, neu, ausgang: ausgang, index: index),
      catalog: catalog,
    );
  }

  /// Entfernt das angezeigte Rüstungsteil nach Rückfrage: nur ablegen oder
  /// ganz entfernen (ARCH-03).
  Future<void> _entferneRuestungsteil(
    int index,
    ArmorPiece angezeigt, {
    required RulesCatalog catalog,
  }) async {
    final wie = await frageKampfgegenstandEntfernen(
      context,
      titel: 'Rüstungsteil entfernen',
      name: angezeigt.name,
      art: 'der Rüstung',
    );
    if (wie == null || !mounted) {
      return;
    }
    await _aendereKampfUndInventar(
      was: 'Entfernen des Rüstungsteils',
      aenderung: (held) => ohneRuestungsteilImKampf(
        held,
        angezeigt,
        index: index,
        wie: wie,
        neueId: neueEditorSlotId,
      ),
      catalog: catalog,
    );
  }

  /// Übernimmt ein Nebenhandteil (Schild, Parierwaffe) aus dem Editor.
  Future<void> _speichereNebenhandTeil(
    OffhandEquipmentEntry neu, {
    OffhandEquipmentEntry? ausgang,
    int? index,
    required RulesCatalog catalog,
  }) async {
    await _aendereKampf(
      was: 'Nebenhandteil',
      aenderung: (config) =>
          mitNebenhandTeil(config, neu, ausgang: ausgang, index: index),
      catalog: catalog,
    );
  }

  /// Entfernt das angezeigte Nebenhandteil nach Rückfrage: nur ablegen oder
  /// ganz entfernen (ARCH-03).
  Future<void> _entferneNebenhandTeil(
    int index,
    OffhandEquipmentEntry angezeigt, {
    required RulesCatalog catalog,
  }) async {
    final wie = await frageKampfgegenstandEntfernen(
      context,
      titel: angezeigt.isShield ? 'Schild entfernen' : 'Parierwaffe entfernen',
      name: angezeigt.name,
      art: 'der Nebenhand-Ausrüstung',
    );
    if (wie == null || !mounted) {
      return;
    }
    await _aendereKampfUndInventar(
      was: 'Entfernen des Nebenhandteils',
      aenderung: (held) => ohneNebenhandteilImKampf(
        held,
        angezeigt,
        index: index,
        wie: wie,
        neueId: neueEditorSlotId,
      ),
      catalog: catalog,
    );
  }
}
