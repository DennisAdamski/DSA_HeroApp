// Block „Dabei“ der Spielansicht (SPIEL-02): Geldstand und Verbrauchsgegenstände
// am Spieltisch zählen.
//
// Alle Schreibfunktionen arbeiten auf dem **gespeicherten** Helden und rechnen
// vom gespeicherten Wert aus, damit jeder schnelle Klick zählt (ARCH-05). Sie
// ändern nur ihr eigenes Feld: den Geldstand oder die Menge eines Eintrags.
// Gibt es nichts zu ändern, kommt der Held selbst zurück, damit nichts
// gespeichert wird.

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';

/// Höchstmenge eines Verbrauchsgegenstands; mehr lässt der Block nicht zu.
const int kDabeiMengeHoechstbestand = 9999;

/// Ob [eintrag] im Block „Dabei“ als Verbrauchsgegenstand gezählt wird.
///
/// Nur manuelle Verbrauchsgegenstände, die der Held selbst trägt. Mit dem Kampf
/// verknüpfte Einträge (auch Geschosse) und abgelegte Kampfgegenstände führen
/// ihre Menge über den Kampfbereich und bleiben dort.
bool istDabeiVerbrauchsgegenstand(HeroInventoryEntry eintrag) {
  return eintrag.itemType == InventoryItemType.verbrauchsgegenstand &&
      !isCombatLinkedInventorySource(eintrag.source) &&
      eintrag.abgelegt == null &&
      eintrag.traegerTyp == InventoryTraeger.held;
}

/// Die Verbrauchsgegenstände des Blocks in gespeicherter Reihenfolge.
List<HeroInventoryEntry> dabeiVerbrauchsgegenstaende(
  List<HeroInventoryEntry> eintraege,
) => List<HeroInventoryEntry>.unmodifiable(
  eintraege.where(istDabeiVerbrauchsgegenstand),
);

/// Gezeigter Name eines Eintrags; ein leerer Name heißt „Unbenannt“.
String dabeiName(HeroInventoryEntry eintrag) {
  final name = eintrag.gegenstand.trim();
  return name.isEmpty ? 'Unbenannt' : name;
}

/// Gezeigte Menge: die Stückzahl, sonst der gespeicherte Freitext.
String dabeiMengeText(HeroInventoryEntry eintrag) {
  final stand = inventarMengenstand(eintrag);
  if (stand.wirksam != null) return '${stand.wirksam}';
  final text = eintrag.anzahl.trim();
  return text.isEmpty ? '–' : text;
}

/// Ob sich die Menge von [eintrag] mit +/− ändern lässt.
///
/// Freitext („ein paar“) und eine von einer älteren App abweichend geänderte
/// Anzahl bleiben unangetastet; die Abweichung löst nur das Inventar.
bool dabeiMengeAenderbar(HeroInventoryEntry eintrag) {
  final stand = inventarMengenstand(eintrag);
  return stand.wirksam != null && !stand.abweichend;
}

/// Verschiebt die Menge des Eintrags [angezeigt] um [delta] Stück.
///
/// Der Eintrag wird über seine Instanz-ID gefunden, ohne ID über seinen Inhalt.
/// Gerechnet wird vom **gespeicherten** Wert, damit mehrere schnelle Klicks
/// nacheinander alle zählen. Die Menge bleibt zwischen 0 und
/// [kDabeiMengeHoechstbestand]; ein aufgebrauchter Eintrag bleibt stehen.
///
/// Wirft einen [StateError], wenn der Eintrag fehlt, nicht mehr zum Block
/// gehört oder keine eindeutige Stückzahl hat.
HeroSheet mitVerbrauchsmengenSchritt(
  HeroSheet held,
  HeroInventoryEntry angezeigt,
  int delta,
) {
  final id = angezeigt.instanzId;
  final index = id == null
      ? findeGleichenInventarEintrag(held.inventoryEntries, angezeigt)
      : held.inventoryEntries.indexWhere((e) => e.instanzId == id);
  if (index < 0) {
    throw StateError('Der Gegenstand wurde inzwischen geändert oder entfernt.');
  }
  final gespeichert = held.inventoryEntries[index];
  if (!istDabeiVerbrauchsgegenstand(gespeichert)) {
    throw StateError(
      '„${dabeiName(gespeichert)}“ ist kein Verbrauchsgegenstand mehr.',
    );
  }
  final stand = inventarMengenstand(gespeichert);
  final aktuell = stand.wirksam;
  if (aktuell == null) {
    throw StateError(
      'Die Menge von „${dabeiName(gespeichert)}“ ist kein Zahlenwert. '
      'Bitte im Inventar festlegen.',
    );
  }
  if (stand.abweichend) {
    throw StateError(
      'Die Menge von „${dabeiName(gespeichert)}“ wurde von einer älteren '
      'App abweichend geändert. Bitte im Inventar bestätigen.',
    );
  }
  final neu = (aktuell + delta).clamp(0, kDabeiMengeHoechstbestand);
  if (neu == aktuell) return held;
  final eintraege = List<HeroInventoryEntry>.of(held.inventoryEntries);
  eintraege[index] = mitInventarMenge(gespeichert, neu);
  return held.copyWith(
    inventoryEntries: List<HeroInventoryEntry>.unmodifiable(eintraege),
  );
}

/// Geldstand als Münzaufschlüsselung (`12 D / 5 S / 3 K`).
///
/// `null`, wenn der gespeicherte Text kein Betrag ist; dann zeigt der Block den
/// Text unverändert und sperrt die Schritte.
String? dabeiGeldText(String dukaten) {
  final kreuzer = parseDsaCurrencyToKreuzer(dukaten);
  return kreuzer == null ? null : formatDsaCurrencyBreakdown(kreuzer);
}

/// Geldstand in Kreuzern; `null`, wenn der gespeicherte Text kein Betrag ist.
int? dabeiGeldKreuzer(String dukaten) => parseDsaCurrencyToKreuzer(dukaten);

/// Ob vom angezeigten Geldstand [dukaten] noch [kreuzer] abgezogen werden
/// können. Bei nicht lesbarem Geldstand `false`.
bool dabeiKannAbziehen(String dukaten, int kreuzer) {
  final vorhanden = parseDsaCurrencyToKreuzer(dukaten);
  return vorhanden != null && kreuzer > 0 && vorhanden >= kreuzer;
}

/// Liest einen eingegebenen Betrag (`12 D 5 S`, `12,5`) als positive Kreuzer.
///
/// `null` bei nicht lesbarer Eingabe, bei `0` und bei negativen Beträgen: Die
/// Richtung bestimmt der Knopf, nicht das Vorzeichen.
int? dabeiBetragKreuzer(String eingabe) {
  final kreuzer = parseDsaCurrencyToKreuzer(eingabe);
  if (kreuzer == null || kreuzer <= 0) return null;
  return kreuzer;
}

/// Verschiebt den gespeicherten Geldstand um [deltaKreuzer].
///
/// Anders als der Münzknopf im Inventar kappt dieser Weg nie still bei 0: Ein
/// Abzug über den Bestand hinaus ist ein [StateError], damit am Tisch kein
/// Betrag verloren geht, der gar nicht da war. Ist der gespeicherte Text kein
/// Betrag, wirft die Funktion ebenfalls.
HeroSheet mitGeldSchritt(HeroSheet held, int deltaKreuzer) {
  if (deltaKreuzer == 0) return held;
  final aktuell = parseDsaCurrencyToKreuzer(held.dukaten);
  if (aktuell == null) {
    throw StateError(
      'Der gespeicherte Dukatenwert ist nicht numerisch lesbar.',
    );
  }
  if (aktuell + deltaKreuzer < 0) {
    throw StateError(
      'Nicht genug Geld: ${formatDsaCurrencyBreakdown(aktuell)} vorhanden.',
    );
  }
  return mitDukatenSchritt(held, deltaKreuzer);
}
