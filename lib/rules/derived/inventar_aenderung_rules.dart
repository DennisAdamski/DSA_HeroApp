// Änderungen im Inventar-Tab: Gegenstand anlegen, bearbeiten und löschen
// sowie Geldstand (ARCH-05).
//
// Alle arbeiten auf dem gespeicherten Helden. Ein Eintrag wird über seine
// Instanz-ID wiedergefunden (ARCH-03), Altdaten ohne ID über ihren Inhalt —
// nie über die Position, die ein anderer Schreibweg verschoben haben kann.

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';

/// Position des ersten Eintrags in [eintraege], der inhaltlich [gesucht]
/// gleicht, sonst `-1`.
///
/// Verglichen wird das vollständige JSON einschließlich unbekannter Felder.
/// Zwei gleiche Einträge sind nicht unterscheidbar; das Entfernen des ersten
/// ergibt dann dieselbe Liste wie das des zweiten.
///
/// Was das Speichern ergänzt (ARCH-03), zählt nicht, solange [gesucht] es
/// noch nicht kennt: eine fehlende Instanz-ID und die aus einer rein
/// ganzzahligen Anzahl überführte Menge. Ein inzwischen gespeicherter
/// Eintrag ist dadurch nicht geändert.
int findeGleichenInventarEintrag(
  List<HeroInventoryEntry> eintraege,
  HeroInventoryEntry gesucht,
) {
  final gesuchterHash = _inhalt(gesucht);
  for (var index = 0; index < eintraege.length; index++) {
    if (_inhalt(_wieGesucht(eintraege[index], gesucht)) == gesuchterHash) {
      return index;
    }
  }
  return -1;
}

/// Position des letzten Eintrags in [eintraege], der inhaltlich [gesucht]
/// gleicht, sonst `-1`.
///
/// Für einen gerade angehängten Gegenstand: Gleicht er einem älteren
/// Eintrag, ist er der hintere der beiden. Ergänzungen des Speicherns wie
/// bei [findeGleichenInventarEintrag].
int findeLetztenGleichenInventarEintrag(
  List<HeroInventoryEntry> eintraege,
  HeroInventoryEntry gesucht,
) {
  final gesuchterHash = _inhalt(gesucht);
  for (var index = eintraege.length - 1; index >= 0; index--) {
    if (_inhalt(_wieGesucht(eintraege[index], gesucht)) == gesuchterHash) {
      return index;
    }
  }
  return -1;
}

/// Position des gespeicherten Eintrags, den eine Änderung an [angezeigt]
/// treffen soll, sonst `-1`.
///
/// Mit Instanz-ID wird über sie gesucht, damit inhaltsgleiche Stapel
/// unterscheidbar bleiben; ohne über den Inhalt
/// ([findeGleichenInventarEintrag]). In beiden Fällen muss der gespeicherte
/// Eintrag noch [angezeigt] gleichen: Hat ein anderer Weg ihn inzwischen
/// geändert, ergibt das `-1`, statt die fremde Änderung zu überschreiben.
int findeInventarEintragZurAenderung(
  List<HeroInventoryEntry> eintraege,
  HeroInventoryEntry angezeigt,
) {
  final id = angezeigt.instanzId;
  if (id == null) {
    return findeGleichenInventarEintrag(eintraege, angezeigt);
  }
  final index = eintraege.indexWhere((eintrag) => eintrag.instanzId == id);
  if (index < 0) {
    return -1;
  }
  final gleich =
      _inhalt(_wieGesucht(eintraege[index], angezeigt)) == _inhalt(angezeigt);
  return gleich ? index : -1;
}

// [kandidat] ohne die Ergänzungen des Speicherns, die [gesucht] fehlen.
HeroInventoryEntry _wieGesucht(
  HeroInventoryEntry kandidat,
  HeroInventoryEntry gesucht,
) {
  var ergebnis = kandidat;
  if (gesucht.instanzId == null && ergebnis.instanzId != null) {
    ergebnis = ergebnis.copyWith(instanzId: null);
  }
  final ueberfuehrt =
      gesucht.menge == null &&
      ergebnis.menge != null &&
      ergebnis.menge == inventarZahlAusText(gesucht.anzahl);
  if (ueberfuehrt) {
    ergebnis = ergebnis.copyWith(menge: null);
  }
  return ergebnis;
}

// Inhalts-Hash eines Eintrags.
String _inhalt(HeroInventoryEntry eintrag) {
  return stableContentHash(eintrag.toJson());
}

/// Hängt den im Editor angelegten Gegenstand [neu] an das gespeicherte
/// Inventar an.
///
/// Neue Gegenstände sind manuelle Einträge; die Kampfkonfiguration bleibt,
/// wie sie gespeichert ist.
HeroSheet mitNeuemInventarEintrag(HeroSheet held, HeroInventoryEntry neu) {
  return held.copyWith(
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(
      <HeroInventoryEntry>[...held.inventoryEntries, neu],
    ),
  );
}

/// Ersetzt den Gegenstand, mit dem der Editor geöffnet wurde ([angezeigt]),
/// im gespeicherten Inventar durch das Editorergebnis [neu].
///
/// Wurde der Gegenstand inzwischen geändert oder entfernt, wirft die
/// Funktion einen [StateError], statt einen anderen zu treffen oder die
/// fremde Änderung zu überschreiben. Gleicht [neu] dem angezeigten Stand,
/// kommt [held] selbst zurück, damit nichts gespeichert wird.
///
/// Hat das Speichern dem Gegenstand inzwischen eine Instanz-ID gegeben, die
/// [neu] noch nicht kennt, behält er sie.
///
/// Ein mit dem Kampf verknüpfter Eintrag gibt seine Markierungen (magisch,
/// geweiht) an seinen Slot weiter. Ein Geschoss schreibt seine Menge nur,
/// wenn sie sich im Editor geändert hat, und nur an sein eigenes Geschoss;
/// alle übrigen Mengen bleiben, wie sie gespeichert sind.
HeroSheet mitGeaendertemInventarEintrag(
  HeroSheet held,
  HeroInventoryEntry angezeigt,
  HeroInventoryEntry neu,
) {
  final index = findeInventarEintragZurAenderung(
    held.inventoryEntries,
    angezeigt,
  );
  if (index < 0) {
    throw StateError('Der Gegenstand wurde inzwischen geändert oder entfernt.');
  }
  if (stableContentHash(neu.toJson()) ==
      stableContentHash(angezeigt.toJson())) {
    return held;
  }
  final eintraege = List<HeroInventoryEntry>.of(held.inventoryEntries);
  final gespeicherteId = eintraege[index].instanzId;
  eintraege[index] = neu.instanzId == null && gespeicherteId != null
      ? neu.copyWith(instanzId: gespeicherteId)
      : neu;
  final verknuepft =
      _istMitKampfVerknuepft(angezeigt) || _istMitKampfVerknuepft(neu);
  return held.copyWith(
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(eintraege),
    combatConfig: verknuepft
        ? _kampfMitEintrag(held.combatConfig, eintraege, angezeigt, neu)
        : held.combatConfig,
  );
}

bool _istMitKampfVerknuepft(HeroInventoryEntry eintrag) {
  return eintrag.sourceRef != null &&
      isCombatLinkedInventorySource(eintrag.source);
}

CombatConfig _kampfMitEintrag(
  CombatConfig kampf,
  List<HeroInventoryEntry> eintraege,
  HeroInventoryEntry vorher,
  HeroInventoryEntry neu,
) {
  var ergebnis = applyLinkedInventoryDetailsToConfig(kampf, eintraege);
  final verweis = neu.slotRef ?? neu.sourceRef;
  final istGeschoss =
      neu.source == InventoryItemSource.geschoss && neu.sourceRef != null;
  final geaendert = neu.anzahl != vorher.anzahl || neu.menge != vorher.menge;
  if (istGeschoss && verweis != null && geaendert) {
    // Der Slot führt die Menge; Freitext setzte sie früher still auf 0.
    final menge = wirksameInventarMenge(neu);
    if (menge == null) {
      throw StateError('Geschosse brauchen eine Zahl als Anzahl.');
    }
    // Der ID-Verweis zuerst: der Namensverweis träfe bei zwei gleichnamigen
    // Bögen immer den ersten.
    ergebnis = applyAmmoCountChangeToConfig(ergebnis, verweis, menge);
  }
  return ergebnis;
}

/// Entfernt den angezeigten Gegenstand [angezeigt] aus dem gespeicherten
/// Inventar.
///
/// Nur die Inventareinträge ändern sich; die Kampfkonfiguration samt
/// Geschossmengen bleibt, wie sie gespeichert ist. Mit dem Kampf verknüpfte
/// Einträge entstehen und verschwinden über ihren Slot und lassen sich hier
/// nicht löschen. Wurde der Gegenstand inzwischen geändert oder entfernt,
/// wirft die Funktion einen [StateError], statt einen anderen zu treffen.
HeroSheet ohneInventarEintrag(HeroSheet held, HeroInventoryEntry angezeigt) {
  final verknuepft =
      angezeigt.sourceRef != null &&
      isCombatLinkedInventorySource(angezeigt.source);
  if (verknuepft) {
    throw StateError(
      'Mit dem Kampf verknüpfte Gegenstände werden im Kampf-Tab entfernt.',
    );
  }
  final index = findeInventarEintragZurAenderung(
    held.inventoryEntries,
    angezeigt,
  );
  if (index < 0) {
    throw StateError('Der Gegenstand wurde inzwischen geändert oder entfernt.');
  }
  final eintraege = List<HeroInventoryEntry>.of(held.inventoryEntries)
    ..removeAt(index);
  return held.copyWith(
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(eintraege),
  );
}

/// Setzt den Geldstand auf den eingegebenen Text [wert].
///
/// Ein eingetippter Gesamtbetrag ist bewusst absolut. Gleicht er dem
/// gespeicherten Stand, kommt [held] selbst zurück, damit nichts gespeichert
/// wird.
HeroSheet mitDukaten(HeroSheet held, String wert) {
  final neu = wert.trim();
  if (neu == held.dukaten.trim()) {
    return held;
  }
  return held.copyWith(dukaten: neu);
}

/// Verschiebt den gespeicherten Geldstand um [deltaKreuzer].
///
/// Gerechnet wird ab dem gespeicherten Text, damit jeder schnelle Klick auf
/// einen Münzknopf zählt. Ist er nicht als Betrag lesbar, wirft die Funktion
/// einen [StateError], statt einen falschen Wert zu schreiben.
HeroSheet mitDukatenSchritt(HeroSheet held, int deltaKreuzer) {
  final neu = adjustDsaCurrencyText(
    rawValue: held.dukaten,
    deltaKreuzer: deltaKreuzer,
  );
  if (neu == null) {
    throw StateError(
      'Der gespeicherte Dukatenwert ist nicht numerisch lesbar.',
    );
  }
  return mitDukaten(held, neu);
}
