// Ablegen und Zurückholen von Kampfgegenständen (ARCH-03, Entscheidung vom
// 06.10.2026).
//
// Wer im Kampfbereich eine Waffe, ein Geschoss, ein Rüstungsteil oder ein
// Schild bzw. eine Parierwaffe entfernt, wählt „Nur ablegen“ oder „Ganz
// entfernen“. Abgelegt verlässt der Slot die Kampfkonfiguration; das
// Exemplar bleibt mit derselben Instanz-ID als unverknüpfter
// Inventareintrag und merkt sich seine Kampfwerte
// (`HeroInventoryEntry.abgelegt`). „In Kampfbereich übernehmen“ legt den Slot
// daraus wieder an; der Abgleich verknüpft ihn über die Instanz.
//
// Geschosse gehen nie still verloren: Auch eine ganz entfernte
// Fernkampfwaffe legt ihre Geschosse ab, und ein Bestand von 0 löscht
// nichts.

import 'package:dsa_heldenverwaltung/domain/abgelegter_kampfgegenstand.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/inventar_verweise.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_aenderung_rules.dart';

/// Was mit einem im Kampfbereich entfernten Gegenstand geschieht.
enum KampfgegenstandEntfernen {
  /// Der Slot geht, das Exemplar bleibt im Inventar und lässt sich
  /// zurückholen.
  ablegen,

  /// Slot und Inventareintrag gehen.
  ganzEntfernen,
}

/// Entfernt die angezeigte Waffe aus dem Kampfbereich.
///
/// Abgelegt bleibt ihr Exemplar im Inventar. Ihre Geschosse werden in
/// beiden Fällen abgelegt, auch mit Bestand 0. Ohne die letzte Waffe steht
/// der Held wie ein neuer da ([ohneWaffe]).
HeroSheet ohneWaffeImKampf(
  HeroSheet held,
  MainWeaponSlot angezeigt, {
  int? index,
  required KampfgegenstandEntfernen wie,
  required String Function() neueId,
}) {
  final gespeichert = gespeicherteWaffe(
    held.combatConfig,
    angezeigt,
    index: index,
  );
  final kampf = ohneWaffe(held.combatConfig, angezeigt, index: index);
  var eintraege = _legeGeschosseAb(
    held.inventoryEntries,
    gespeichert,
    _benannteGeschosse(gespeichert),
    neueId,
  );
  if (wie == KampfgegenstandEntfernen.ablegen) {
    final ohneGeschosse = gespeichert.copyWith(
      rangedProfile: gespeichert.rangedProfile.copyWith(
        projectiles: const <RangedProjectile>[],
        selectedProjectileIndex: -1,
      ),
    );
    eintraege = _legeAb(
      eintraege,
      verweis: verweisFuerWaffe(gespeichert),
      instanz: gespeichert.inventarInstanzId,
      quelle: InventoryItemSource.waffe,
      profil: AbgelegterKampfgegenstand(
        waffe: ohneGeschosse.copyWith(inventarInstanzId: ''),
      ),
      ersatz: () => HeroInventoryEntry(
        gegenstand: gespeichert.name,
        itemType: InventoryItemType.ausruestung,
        isMagisch: gespeichert.isArtifact,
        magischDescription: gespeichert.artifactDescription,
        isGeweiht: gespeichert.isGeweiht,
        geweihtDescription: gespeichert.geweihtDescription,
      ),
      neueId: neueId,
    );
  }
  return _mit(held, kampf, eintraege);
}

/// Ersetzt die im Editor bearbeitete Waffe ([ersetzeWaffe]) und legt
/// Geschosse ab, die das Editorergebnis nicht mehr führt.
///
/// Mit [geschosseAblegen] `false` gehen diese Geschosse ganz.
HeroSheet ersetzeWaffeImKampf(
  HeroSheet held, {
  required MainWeaponSlot ausgang,
  required MainWeaponSlot neu,
  int? index,
  required bool geschosseAblegen,
  required String Function() neueId,
}) {
  final gespeichert = gespeicherteWaffe(
    held.combatConfig,
    ausgang,
    index: index,
  );
  final kampf = ersetzeWaffe(
    held.combatConfig,
    ausgang: ausgang,
    neu: neu,
    index: index,
  );
  if (!geschosseAblegen) {
    return held.copyWith(combatConfig: kampf);
  }
  final weg = entfernteGeschosse(gespeichert, neu);
  final eintraege = _legeGeschosseAb(
    held.inventoryEntries,
    gespeichert,
    weg,
    neueId,
  );
  return _mit(held, kampf, eintraege);
}

/// Benannte Geschosse von [vorher], die [nachher] nicht mehr führt.
///
/// Verglichen wird über die Geschoss-ID; Geschosse ohne ID sind noch nie
/// gespeichert worden und haben keinen Inventareintrag.
List<RangedProjectile> entfernteGeschosse(
  MainWeaponSlot vorher,
  MainWeaponSlot nachher,
) {
  final bleiben = <String>{
    if (nachher.fuehrtGeschosse)
      for (final geschoss in nachher.rangedProfile.projectiles) geschoss.id,
  };
  return <RangedProjectile>[
    for (final geschoss in _benannteGeschosse(vorher))
      if (geschoss.id.isNotEmpty && !bleiben.contains(geschoss.id)) geschoss,
  ];
}

/// Entfernt das angezeigte Rüstungsteil aus dem Kampfbereich; abgelegt
/// bleibt sein Exemplar im Inventar.
HeroSheet ohneRuestungsteilImKampf(
  HeroSheet held,
  ArmorPiece angezeigt, {
  int? index,
  required KampfgegenstandEntfernen wie,
  required String Function() neueId,
}) {
  final gespeichert = gespeichertesRuestungsteil(
    held.combatConfig,
    angezeigt,
    index: index,
  );
  final kampf = ohneRuestungsteil(held.combatConfig, angezeigt, index: index);
  if (wie == KampfgegenstandEntfernen.ganzEntfernen) {
    return held.copyWith(combatConfig: kampf);
  }
  final eintraege = _legeAb(
    held.inventoryEntries,
    verweis: verweisFuerRuestung(gespeichert),
    instanz: gespeichert.inventarInstanzId,
    quelle: InventoryItemSource.ruestung,
    profil: AbgelegterKampfgegenstand(
      ruestungsteil: gespeichert.copyWith(inventarInstanzId: ''),
    ),
    ersatz: () => HeroInventoryEntry(
      gegenstand: gespeichert.name,
      itemType: InventoryItemType.ausruestung,
      isMagisch: gespeichert.isArtifact,
      magischDescription: gespeichert.artifactDescription,
      isGeweiht: gespeichert.isGeweiht,
      geweihtDescription: gespeichert.geweihtDescription,
    ),
    neueId: neueId,
  );
  return _mit(held, kampf, eintraege);
}

/// Entfernt das angezeigte Schild bzw. die Parierwaffe aus dem
/// Kampfbereich; abgelegt bleibt das Exemplar im Inventar.
HeroSheet ohneNebenhandteilImKampf(
  HeroSheet held,
  OffhandEquipmentEntry angezeigt, {
  int? index,
  required KampfgegenstandEntfernen wie,
  required String Function() neueId,
}) {
  final gespeichert = gespeichertesNebenhandteil(
    held.combatConfig,
    angezeigt,
    index: index,
  );
  final kampf = ohneNebenhandTeil(held.combatConfig, angezeigt, index: index);
  if (wie == KampfgegenstandEntfernen.ganzEntfernen) {
    return held.copyWith(combatConfig: kampf);
  }
  final eintraege = _legeAb(
    held.inventoryEntries,
    verweis: verweisFuerNebenhand(gespeichert),
    instanz: gespeichert.inventarInstanzId,
    quelle: InventoryItemSource.nebenhand,
    profil: AbgelegterKampfgegenstand(
      nebenhandteil: gespeichert.copyWith(inventarInstanzId: ''),
    ),
    ersatz: () => HeroInventoryEntry(
      gegenstand: gespeichert.name,
      itemType: InventoryItemType.ausruestung,
      isMagisch: gespeichert.isArtifact,
      magischDescription: gespeichert.artifactDescription,
      isGeweiht: gespeichert.isGeweiht,
      geweihtDescription: gespeichert.geweihtDescription,
    ),
    neueId: neueId,
  );
  return _mit(held, kampf, eintraege);
}

/// Ob sich [e] in den Kampfbereich zurückholen lässt.
bool istAbgelegterKampfgegenstand(HeroInventoryEntry e) {
  final abgelegt = e.abgelegt;
  return e.sourceRef == null && abgelegt != null && abgelegt.hatKampfwerte;
}

/// Quelle, unter der [e] im Inventar angezeigt und gefiltert wird.
///
/// Ein abgelegter Gegenstand ist ein manueller Eintrag, erscheint aber
/// weiter als Waffe, Geschoss, Rüstung oder Nebenhand, damit er unter
/// „Waffen“ bzw. „Geschosse“ auffindbar bleibt.
InventoryItemSource anzeigeQuelleImInventar(HeroInventoryEntry e) {
  final abgelegt = e.abgelegt;
  if (!istAbgelegterKampfgegenstand(e) || abgelegt == null) {
    return e.source;
  }
  if (abgelegt.waffe != null) return InventoryItemSource.waffe;
  if (abgelegt.geschoss != null) return InventoryItemSource.geschoss;
  if (abgelegt.ruestungsteil != null) return InventoryItemSource.ruestung;
  return InventoryItemSource.nebenhand;
}

/// Ob [e] ein abgelegtes Geschoss ist; es braucht eine Zielwaffe.
bool istAbgelegtesGeschoss(HeroInventoryEntry e) {
  return istAbgelegterKampfgegenstand(e) && e.abgelegt!.geschoss != null;
}

/// Fernkampfwaffen in [kampf], an die ein abgelegtes Geschoss zurück kann.
List<MainWeaponSlot> zielwaffenFuerGeschoss(CombatConfig kampf) {
  return <MainWeaponSlot>[
    for (final waffe in kampf.weaponSlots)
      if (waffe.name.trim().isNotEmpty && waffe.fuehrtGeschosse) waffe,
  ];
}

/// Holt den angezeigten abgelegten Gegenstand [angezeigt] in den
/// Kampfbereich zurück.
///
/// Der Slot entsteht aus den gemerkten Kampfwerten; eine inzwischen
/// doppelte Slot-ID ersetzt das Speichern (`CombatConfig.withStableIds`).
/// Name und
/// Markierungen (magisch, geweiht) kommen vom Eintrag, der sie während des
/// Ablegens führte. Er hängt hinten an und verweist auf die Instanz des
/// Eintrags; der Eintrag wird wieder verknüpft, ohne seine Angaben zu
/// verlieren. Ein Geschoss kommt an die Fernkampfwaffe mit der ID
/// [zielWaffeId] und bringt seine Menge mit.
///
/// Wirft einen [StateError], wenn der Eintrag inzwischen geändert wurde,
/// nichts Zurückholbares trägt oder die Zielwaffe fehlt.
HeroSheet mitUebernommenemKampfgegenstand(
  HeroSheet held,
  HeroInventoryEntry angezeigt, {
  String? zielWaffeId,
  required String Function() neueId,
}) {
  final index = findeInventarEintragZurAenderung(
    held.inventoryEntries,
    angezeigt,
  );
  if (index < 0) {
    throw StateError('Der Gegenstand wurde inzwischen geändert oder entfernt.');
  }
  final eintrag = held.inventoryEntries[index];
  if (!istAbgelegterKampfgegenstand(eintrag)) {
    throw StateError('Für diesen Gegenstand sind keine Kampfwerte gemerkt.');
  }
  final instanz = eintrag.instanzId ?? neueId();
  final profil = eintrag.abgelegt!;
  final name = eintrag.gegenstand.trim();
  if (name.isEmpty) {
    throw StateError('Der Gegenstand braucht einen Namen.');
  }
  final (kampf, quelle, verweis) = _mitSlot(
    held.combatConfig,
    profil,
    eintrag,
    instanz: instanz,
    name: name,
    zielWaffeId: zielWaffeId,
  );
  final eintraege = List<HeroInventoryEntry>.of(held.inventoryEntries);
  eintraege[index] = eintrag.copyWith(
    source: quelle,
    sourceRef: verweis,
    slotRef: null,
    instanzId: instanz,
    abgelegt: null,
  );
  return _mit(held, kampf, eintraege);
}

// Hängt den Slot aus [profil] an [kampf] an; liefert Konfiguration, Quelle
// und Namensverweis des Eintrags.
(CombatConfig, InventoryItemSource, String) _mitSlot(
  CombatConfig kampf,
  AbgelegterKampfgegenstand profil,
  HeroInventoryEntry eintrag, {
  required String instanz,
  required String name,
  String? zielWaffeId,
}) {
  final waffe = profil.waffe;
  if (waffe != null) {
    final slot = waffe.copyWith(
      name: name,
      inventarInstanzId: instanz,
      isArtifact: eintrag.isMagisch,
      artifactDescription: eintrag.magischDescription,
      isGeweiht: eintrag.isGeweiht,
      geweihtDescription: eintrag.geweihtDescription,
    );
    final mitWaffe = mitNeuerWaffe(kampf, slot);
    return (mitWaffe, InventoryItemSource.waffe, weaponRef(name));
  }
  final geschoss = profil.geschoss;
  if (geschoss != null) {
    return _mitGeschoss(kampf, geschoss, eintrag, instanz, name, zielWaffeId);
  }
  final teil = profil.ruestungsteil;
  if (teil != null) {
    final stueck = teil.copyWith(
      name: name,
      inventarInstanzId: instanz,
      isArtifact: eintrag.isMagisch,
      artifactDescription: eintrag.magischDescription,
      isGeweiht: eintrag.isGeweiht,
      geweihtDescription: eintrag.geweihtDescription,
    );
    final mitTeil = mitRuestungsteil(kampf, stueck);
    return (mitTeil, InventoryItemSource.ruestung, armorRef(name));
  }
  final neben = profil.nebenhandteil!.copyWith(
    name: name,
    inventarInstanzId: instanz,
    isArtifact: eintrag.isMagisch,
    artifactDescription: eintrag.magischDescription,
    isGeweiht: eintrag.isGeweiht,
    geweihtDescription: eintrag.geweihtDescription,
  );
  final mitNeben = mitNebenhandTeil(kampf, neben);
  return (mitNeben, InventoryItemSource.nebenhand, offhandRef(name));
}

// Hängt das abgelegte [geschoss] an die Zielwaffe an.
(CombatConfig, InventoryItemSource, String) _mitGeschoss(
  CombatConfig kampf,
  RangedProjectile geschoss,
  HeroInventoryEntry eintrag,
  String instanz,
  String name,
  String? zielWaffeId,
) {
  final waffen = kampf.weaponSlots;
  final position = waffen.indexWhere(
    (w) => zielWaffeId != null && w.id == zielWaffeId && w.fuehrtGeschosse,
  );
  if (position < 0) {
    throw StateError('Bitte eine Fernkampfwaffe für das Geschoss wählen.');
  }
  final ziel = waffen[position];
  final menge = wirksameInventarMenge(eintrag);
  if (menge == null) {
    throw StateError('Geschosse brauchen eine Zahl als Anzahl.');
  }
  final profil = ziel.rangedProfile;
  final neu = geschoss.copyWith(
    name: name,
    count: menge,
    inventarInstanzId: instanz,
  );
  final slots = List<MainWeaponSlot>.of(waffen);
  slots[position] = ziel.copyWith(
    rangedProfile: profil.copyWith(
      projectiles: <RangedProjectile>[...profil.projectiles, neu],
    ),
  );
  final verweis = projectileRef(ziel.name, name);
  return (
    kampf.copyWith(weapons: slots),
    InventoryItemSource.geschoss,
    verweis,
  );
}

// Benannte Geschosse einer Waffe, die Geschosse führt.
List<RangedProjectile> _benannteGeschosse(MainWeaponSlot waffe) {
  if (!waffe.fuehrtGeschosse) {
    return const <RangedProjectile>[];
  }
  return <RangedProjectile>[
    for (final geschoss in waffe.rangedProfile.projectiles)
      if (geschoss.name.trim().isNotEmpty) geschoss,
  ];
}

// Legt [geschosse] der gespeicherten [waffe] im Inventar ab.
List<HeroInventoryEntry> _legeGeschosseAb(
  List<HeroInventoryEntry> eintraege,
  MainWeaponSlot waffe,
  List<RangedProjectile> geschosse,
  String Function() neueId,
) {
  var ergebnis = eintraege;
  for (final geschoss in geschosse) {
    ergebnis = _legeAb(
      ergebnis,
      verweis: verweisFuerGeschoss(waffe, geschoss),
      instanz: geschoss.inventarInstanzId,
      quelle: InventoryItemSource.geschoss,
      profil: AbgelegterKampfgegenstand(
        geschoss: geschoss.copyWith(inventarInstanzId: ''),
      ),
      ersatz: () => HeroInventoryEntry(
        gegenstand: geschoss.name,
        itemType: InventoryItemType.verbrauchsgegenstand,
      ),
      menge: geschoss.count,
      neueId: neueId,
    );
  }
  return ergebnis;
}

// Macht den verknüpften Eintrag des Slots hinter [verweis] zu einem
// abgelegten Exemplar mit [profil]. Fehlt er (Slot nie gespeichert),
// entsteht er aus [ersatz]. [menge] führt bei Geschossen der Slot.
List<HeroInventoryEntry> _legeAb(
  List<HeroInventoryEntry> eintraege, {
  required SlotVerweis verweis,
  required String instanz,
  required InventoryItemSource quelle,
  required AbgelegterKampfgegenstand profil,
  required HeroInventoryEntry Function() ersatz,
  int? menge,
  required String Function() neueId,
}) {
  final ergebnis = List<HeroInventoryEntry>.of(eintraege);
  final index = _verknuepfterEintrag(ergebnis, verweis, instanz, quelle);
  final basis = index < 0 ? ersatz() : ergebnis[index];
  var abgelegt = basis.copyWith(
    source: InventoryItemSource.manuell,
    sourceRef: null,
    slotRef: null,
    istAusgeruestet: false,
    instanzId: basis.instanzId ?? neueId(),
    abgelegt: profil,
  );
  if (menge != null) {
    abgelegt = mitInventarMenge(abgelegt, menge);
  }
  if (index < 0) {
    ergebnis.add(abgelegt);
  } else {
    ergebnis[index] = abgelegt;
  }
  return ergebnis;
}

// Position des verknüpften Eintrags zum Slot: über seine Instanz, dann über
// den ID-Verweis; nur ein Slot ohne ID über den Namen. -1 ohne Eintrag.
int _verknuepfterEintrag(
  List<HeroInventoryEntry> eintraege,
  SlotVerweis verweis,
  String instanz,
  InventoryItemSource quelle,
) {
  bool verknuepft(HeroInventoryEntry e) =>
      e.source == quelle && e.sourceRef != null;
  if (instanz.isNotEmpty) {
    final perInstanz = eintraege.indexWhere(
      (e) => verknuepft(e) && e.instanzId == instanz,
    );
    if (perInstanz >= 0) return perInstanz;
  }
  final slotRef = verweis.slotRef;
  if (slotRef != null) {
    return eintraege.indexWhere((e) => verknuepft(e) && e.slotRef == slotRef);
  }
  return eintraege.indexWhere(
    (e) =>
        verknuepft(e) && e.slotRef == null && e.sourceRef == verweis.sourceRef,
  );
}

// [held] mit neuer Kampfkonfiguration und neuem Inventar.
HeroSheet _mit(
  HeroSheet held,
  CombatConfig kampf,
  List<HeroInventoryEntry> eintraege,
) {
  return held.copyWith(
    combatConfig: kampf,
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(eintraege),
  );
}
