# Schreibpfade der Heldenverwaltung (ARCH-05)

Stand: 29.09.2026, nachgeführt nach dem fünften ARCH-05-Teilstand
(Sofortaktionen des Bogens). Bestandsaufnahme für
[ARCH-05 — Schreibende Aktionen fachlich aufteilen](architecture_roadmap.md#arch-05--schreibende-aktionen-fachlich-aufteilen).
Sie beschreibt, **wo** Heldendaten heute geschrieben werden, mit welchen
Eingaben, Vorbedingungen, Seiteneffekten und Speichergrenzen. Zeilenangaben
gelten für den Stand dieses Datums; bei Folgearbeit neu prüfen.

Begriffe:

- **Bogen** = `HeroSheet`, **Zustand** = `HeroState` (Laufzeitwerte).
- **frisch**: Der Schreibweg lädt den gespeicherten Stand unmittelbar vor dem
  Schreiben und ändert nur seine Felder. **Snapshot**: Er schreibt einen beim
  Rendern erfassten Stand vollständig zurück und überschreibt damit
  zwischenzeitlich gespeicherte Änderungen anderer Felder.
- **Fehler → UI**: Ein Speicherfehler erreicht die bedienende Oberfläche
  sichtbar (Snackbar, Blatt, Dialog).

## Speichergrenzen

- Jeder Heldenschreibweg endet in `HeroRepository.saveHero` bzw.
  `saveHeroState` (`lib/data/hero_repository.dart`). Mit Konto liegt
  `SyncingHeroRepository` als Dekorator davor und überträgt selbst; kein
  Ablauf ruft den Sync ausdrücklich auf. Beim **Zustand** endet
  `saveHeroState` nach dem lokalen Speichern; den Upload bündelt
  `GebuendelteLaeufe` (`lib/data/sync/gebuendelte_laeufe.dart`) je Held im
  Hintergrund, immer mit dem neuesten lokalen Stand. Online-Stände, die
  währenddessen eintreffen, bewertet das Repository erst danach. Der Bogen
  wartet weiterhin auf seinen Upload.
- Bogen und Zustand sind **getrennte** Schreibvorgänge. Es gibt keine
  Transaktion über beide und keine über Laden → Ändern → Schreiben. Beide
  haben aber je eine Warteschlange je Held (`ReihenfolgeJeHeld`), sodass
  Schreibwege über `HeroActions` einander nicht zwischen Laden und Speichern
  überholen.
- Avatarbilder liegen außerhalb des Heldenmodells (`AvatarFileStorage`,
  Firebase Storage), Gruppen in Firestore und `ExterneHeldenRepository`.

## Anwendungsabläufe (`lib/ablaeufe/`)

Seit dem ersten ARCH-05-Teilstand gibt es eine eigene Schicht für
Anwendungsabläufe. Sie hängt nicht von Riverpod ab und bekommt ihre
Abhängigkeiten per Konstruktor; die Provider liegen in
`lib/state/ablauf_providers.dart`.

| Ablauf | Einstieg | Schreibt | Stand |
|---|---|---|---|
| Rast abschließen | `RastAbschliessen` (`lib/ablaeufe/rast_abschliessen.dart`) | Zustand, frisch | extrahiert |
| Schaden erhalten | `SchadenErhalten` (`lib/ablaeufe/schaden_erhalten.dart`) | Zustand, frisch | extrahiert |
| Zustand frisch ändern | `aendereGespeichertenZustand` (`lib/ablaeufe/zustand_schreiben.dart`) | Zustand, frisch, je Held nacheinander | Baustein, `HeroActions.updateHeroState` delegiert |
| Bogen frisch ändern | `aendereGespeichertenHelden`, `reiheBogenvorgangEin` (`lib/ablaeufe/held_schreiben.dart`) | Bogen, frisch, je Held nacheinander | Baustein, `HeroActions.updateHero` delegiert, `saveHero` reiht sich ein |
| Steigerungsrunde übernehmen | `SteigerungsrundeUebernehmen` (`lib/ablaeufe/steigerungsrunde_uebernehmen.dart`) | Bogen, Hash-Prüfung gegen die Sitzungsbasis | extrahiert, Provider `steigerungsrundeUebernehmenProvider` |
| Held importieren | `HeldImportieren` (`lib/ablaeufe/held_importieren.dart`) | eigener Katalog, Bilddateien, Bogen (ein `saveHero`), Zustand eingereiht | extrahiert, `HeroActions.importiereHeld` bindet ihn an (kein Provider: Zyklus über `heroActionsProvider`) |

`aendereGespeichertenZustand` reiht Änderungen desselben Helden über
denselben Speicher ein: Jede lädt erst, wenn die vorige gespeichert oder
gescheitert ist. Die Warteschlange (`ReihenfolgeJeHeld`,
`lib/ablaeufe/reihenfolge_je_held.dart`) hängt per `Expando` am
Speicherobjekt. Schreibwege, die an der Funktion vorbei speichern
(`saveHeroState`), sind nicht eingereiht.

Für den Bogen gilt dasselbe mit einer eigenen Warteschlange:
`aendereGespeichertenHelden` lädt frisch, ändert und speichert über die
injizierte Normalisierung von `HeroActions`. Gibt die Änderung dasselbe
Objekt zurück, wird nichts gespeichert. Anders als beim Zustand reiht sich
auch das direkte `saveHero` (Editoren, Steigerungsübernahme) ein; es
überholt eine laufende frische Änderung also nicht, und die Hash-Prüfung
der Steigerungsrunde sieht jede eingereihte Änderung. Seit dem zehnten
ARCH-05-Teilstand gilt das auch für die Anzeige nicht passender SF, die
ohne Normalisierung direkt ins Repository schreibt.

In der Oberfläche ist `aendereZustandMitMeldung`
(`lib/ui/screens/shared/zustand_aendern.dart`) der gemeinsame Einstieg:
frisch über `updateHeroState`, Fehler „… nicht gespeichert“ im nächsten
`ZustandFehlerBereich` (Blatt, Dialog, Inspector-Tab), sonst als Snackbar.
Wunden nutzen darüber `aendereWundZustand` und `fuegeWundeHinzu`
(`lib/ui/screens/workspace/wund_zustand_speichern.dart`), Zaubereffekte die
Regeln aus `lib/rules/derived/active_spell_state_rules.dart`.

Für Sofortaktionen am Bogen ist `aendereHeldMitMeldung` (dieselbe Datei)
der Einstieg: frisch über `updateHero`, derselbe Fehlerweg. Bei offener
Steigerungsrunde schreibt er nicht und meldet „Während einer Planung ist der
Heldenbogen gesperrt.“; Inspector-Statuswerte und das Wundschwellen-Zahnrad
sind dann zusätzlich sichtbar gesperrt.

Editorentwürfe speichern über `speichereEditorEntwurf`
(`lib/ui/screens/shared/editor_entwurf_speichern.dart`), seit dem neunten
ARCH-05-Teilstand. Jeder Editor merkt sich den Helden, aus dem er seinen
Entwurf gefüllt hat (Basis). `uebernimmEditorEntwurf`
(`lib/rules/derived/editor_entwurf_rules.dart`) gleicht Basis, Entwurf und
frisch geladenen Helden je oberstem JSON-Schlüssel ab:

- Im Entwurf Unverändertes nimmt den gespeicherten Wert.
- Nur im Entwurf Geändertes gewinnt.
- AP-Gesamt und ausgegebene AP sind Zähler.
- Beidseitig verschieden Geändertes ist ein Konflikt; der Dialog bietet
  „Weiter bearbeiten“ oder „Meine Fassung speichern“ (nur diese Bereiche).

Nie erzwingbar ist, was eine Buchung zurücknähme: ein inzwischen
abgeschlossenes oder wieder geöffnetes Abenteuer und angewendete
Reisebericht-Belohnungen. Der Reisebericht bucht seine Belohnungen über
`bucheReiseberichtEntwurf` auf den gespeicherten Helden.

## `HeroActions` (`lib/state/hero_actions.dart`)

`HeroActions(this._ref)` liest bis zu 16 Provider über `Ref`; bezogen wird es
ausschließlich über `heroActionsProvider` (`lib/state/hero_providers.dart`).

### Normalisierung in `saveHero`

Jeder Bogenschreibweg über `HeroActions` durchläuft `saveHero`:

1. AP auf mindestens 0, Stufe und freie AP aus `apSpent` neu berechnet.
2. Vor-/Nachteile: `merkmaleZumSpeichern` (Migration nur mit geladenem
   Katalog, ARCH-02).
3. Modifikatortexte geparst, unbekannte Fragmente gegen den Katalog gefiltert
   (`_filterKnownTraitWarnings`).
4. Effektive Startwerte neu berechnet (`Attributes.uebernimmWerte`).
5. Neue Kampf-Slots bekommen UUIDs (`withStableIds`).
6. Ritualkategorien normalisiert.
7. Inventar mit Kampf abgeglichen (`reconcileInventoryWithCombat`).
8. Rein ganzzahlige `anzahl` ohne `menge` überführt
   (`ueberfuehreInventarMengen`), danach fehlende oder doppelte Instanz-IDs
   vergeben (`vergibInstanzIds`, ARCH-03; beides nie beim Laden).
9. Jeder verknüpfte Slot bekommt die Instanz-ID seines Eintrags als
   `inventarInstanzId` (`bindeSlotsAnInstanzen`, ARCH-03; nie beim Laden).
10. `lastModified` frisch gestempelt.
11. Optional: `expectedContentHash` gegen den gespeicherten Stand geprüft
   (optimistische Sperre der Steigerungsrunde).

### Öffentliche Methoden

| Methode | Schreibt | Vorbedingungen / Seiteneffekte |
|---|---|---|
| `createHero` | Bogen (über `saveHero`), Zustand direkt über das Repository (ohne Zeitstempel), Auswahl | Heldenlimit, neue UUID, Standardtalente, wählt den Helden aus |
| `saveHero` | Bogen | Normalisierung oben; je Held eingereiht (`reiheBogenvorgangEin`), liefert den gespeicherten Helden |
| `updateHero` | Bogen, frisch, je Held nacheinander | delegiert an `aendereGespeichertenHelden`; dasselbe Objekt zurück heißt: nichts speichern; liefert den gespeicherten Helden; keine Transaktion |
| `saveHeroState` | Zustand, Snapshot des Aufrufers | stempelt `lastModified` |
| `updateHeroState` | Zustand, frisch | delegiert an `aendereGespeichertenZustand`, liefert den gespeicherten Zustand |
| `deleteHero` | löscht Bogen und Zustand, Auswahl | — |
| `buildExportJson` / `parseImportJson` | nichts | Avatar und Galerie als Base64, eigene Katalogeinträge |
| `importiereHeld` / `importHeroBundle` | eigener Katalog, Galeriedateien, Bogen, Zustand, Auswahl | über den Ablauf `HeldImportieren`: Heldenlimit für jede noch unbekannte Ziel-ID; Bilder vor dem Helden, Dateinamen aus der Ablage; ein `saveHero`; Zustand über `aendereGespeichertenZustand`; nicht speicherbare Bilder werden gezählt statt abzubrechen; lädt den Katalog neu. `importHeroBundle` liefert nur die ID |
| `saveHeroAvatar`, `uploadHeroImage` | Bilddatei, dann Bogen | Bildlimit bzw. Größenlimit, Gesichtserkennung beim Anlegen |
| `setPrimaerbild`, `setAvatarHeaderFocus`, `setActiveAvatar` | Bogen | Fokus/Zoom begrenzt |
| `removeGalleryImage`, `removeHeroAvatar` | löscht Dateien, dann Bogen | `removeHeroAvatar` hat keinen Aufrufer mehr |
| `erstelleGruppe`, `trittGruppeBei`, `verlasseGruppe`, `addManuellerHeld`, `removeExternerHeld`, `syncGruppen`, `syncVisitenkarten` | Firestore, externe Helden, Bogen (`gruppen`) | Firestore-Verfügbarkeit; Visitenkarte mit Vorschaubild |

## Aufrufer nach fachlichem Ablauf

„inline“ heißt: Das Widget rechnet vor dem Schreiben selbst Regeln oder
Domainlogik.

| Ablauf | Einstieg | Schreibt | Stand | Fehler → UI | Regelrechnung inline |
|---|---|---|---|---|---|
| Rast abschließen | `RestPanel` (`workspace/rest_dialog.dart`) → `RastAbschliessen` | Zustand | frisch | ja, im Panel | nein (seit ARCH-05) |
| Schaden erhalten | `SchadenPanel` (`workspace/schaden/schaden_dialog.dart`, Inspector-Vitals und UI2-Schnellaktion) → `SchadenErhalten` | Zustand | frisch, je Held nacheinander | ja, im Panel | nein, `schaden_rules.dart` |
| Steigerung übernehmen | `AdvancementSessionController.commit` (`state/advancement_providers.dart`) → `SteigerungsrundeUebernehmen.uebernehmeRunde` | Bogen | Hash-Prüfung gegen die Sitzungsbasis, erneut in `saveHero` vor dem Schreiben | ja (Snackbar) | nein, `commitAdvancements` |
| Anzeige nicht passender SF | `setShowInapplicableSpecialAbilities` (ebd.) → `SteigerungsrundeUebernehmen.speichereSfAnzeige` | Bogen direkt über das Repository, ohne Normalisierung | frisch, je Held nacheinander; bei offener Runde Hash-Prüfung | ja | nein |
| Inventar (Löschen, Dukaten) | `hero_inventory/inventory_mutations.dart` (`_deleteEntry`, `_saveDukaten`, `_verschiebeDukaten`) | Bogen | frisch, je Held nacheinander; Löschen findet den Eintrag über seine Instanz-ID, Altdaten über den Inhalt; Münzknöpfe zählen vom gespeicherten Betrag | ja (Snackbar) | nein, `inventar_aenderung_rules.dart` |
| Inventar (Editor) | `hero_inventory/inventory_mutations.dart` (`_saveNewEntry`, `_saveUpdatedEntry`, `_teileStapel`, `_uebernehmeInKampf`, `_fuehreStapelZusammen`, `_verkaufe`) über `aendereHeldImEditor` | Bogen | frisch, je Held nacheinander; trifft den geöffneten Gegenstand über seine Instanz-ID (Altdaten über den Inhalt), ein inzwischen geänderter wird abgewiesen; Teilen schreibt auch die Geschossmenge des eigenen Slots; „In Kampfbereich übernehmen“ legt den Slot eines abgelegten Gegenstands wieder an (`kampfgegenstand_ablegen_rules.dart`); Zusammenführen und Verkaufen (`inventar_stapel_rules.dart`, `inventar_verkauf_rules.dart`) schreiben bei Geschossen am Bogen den Slotbestand, Verkaufen auch den Geldstand; bei offener Planung gesperrt | ja, im Editor | nein, `inventar_aenderung_rules.dart` |
| Kampf (Sofortspeichern) | `hero_combat/combat_sofort_aenderungen.dart` über `_aendereKampf` bzw. `_aendereKampfUndInventar` (`combat_state_helpers.dart`) | Bogen | frisch, je Held nacheinander; Slots über ihre ID; Entfernen fragt „Nur ablegen“/„Ganz entfernen“ und schreibt beim Ablegen Kampf und Inventar gemeinsam (im Bearbeitungsmodus über den Inventarentwurf); Geschosse zählen vom gespeicherten Bestand, Editorergebnisse auf geänderte Slots werden abgewiesen | ja (Snackbar) | Slotprüfung `neuerKampfSlotFehler` (`kampf_slot_pruefung_rules.dart`): nur neu eingeführte Fehler sperren; sonst `kampf_aenderung_rules.dart` |
| Kampf (Editor) | `hero_combat/combat_state_helpers.dart` (`_saveChanges`) über `speichereEditorEntwurf` | Bogen | frisch, Abgleich mit dem Bearbeitungsbeginn (`uebernimmEditorEntwurf`); bei Überschneidung Rückfrage; bei offener Planung gesperrt | ja (Dialog bzw. Snackbar) | Slotprüfung (`pruefeKampfSlots`, erster Befund), Talentverteilung; AP-Delta als Zähler |
| Ressourcen (LeP, Au, AsP, KaP) | `resource_stepper_dialog.dart`, `inspector_vitals_tab.dart`, `inspector_magie_tab.dart` | Zustand | frisch, Schritt vom gespeicherten Wert (`RessourcenAenderung`) | ja (im Blatt bzw. Tab) | Grenzen nur in Schrittrichtung |
| Belastung | `inspector_belastung_section.dart` | Zustand | frisch, zählt vom gespeicherten Wert | ja (im Inspector-Tab bzw. Zustandsblock) | Untergrenze 0 |
| Ressourcen UI2 | `ui/bridges/karto_spiel_bruecke.dart` | Zustand | frisch, Schritt vom gespeicherten Wert | ja (im Blatt) | nein |
| Dauermodifikatoren | `inspector_statuswerte_block.dart` | Bogen | frisch, Schritt vom gespeicherten Wert; bei offener Planung gesperrt | ja (im Inspector-Tab bzw. Zustandsblock) | nein, `modifikator_aenderung_rules.dart` |
| Wunden | `wunden_detail_dialog.dart`, `inspector_wunden_card.dart` über `wund_zustand_speichern.dart` | Zustand (+ Bogen für Wundschwelle) | Zustand frisch, zählt vom gespeicherten Wundzustand; Wundschwelle frisch, bei offener Planung gesperrt | ja (im Dialog bzw. Tab) | Wundeffekte für den Unterdrückungsdialog |
| Zaubereffekte | `shared/active_spell_effects_dialog.dart` | Zustand | frisch, Regeln aus `active_spell_state_rules.dart` | ja (im Dialog) | nein |
| Würfelprotokoll | `shared/dice_log_persistence.dart` (`persistDiceLogEntries`, oft per `unawaited`) | Zustand | frisch, je Held nacheinander | ja (Snackbar in `showLoggedProbeDialog`) | — |
| Abenteuerblatt UI2 | `ui2/spielen/karto_abenteuerblatt.dart` | Bogen | frisch (`updateHero`) | ja, im Blatt | `ersetzeAbenteuer` (UI2) |
| Abenteuer (Bestand) | `hero_notes_tab.dart` (Editor) über `speichereEditorEntwurf` | Bogen | frisch, Abgleich mit dem Bearbeitungsbeginn; unberührte Listen bleiben gespeichert; ein inzwischen abgeschlossenes Abenteuer ist nie überschreibbar | ja (Dialog bzw. Snackbar) | Bereinigung leerer Einträge |
| Abenteuer abschließen / wiedereröffnen | `hero_notes_tab.dart` (`_completeAdventureFor`, `_reopenAdventureFor`) | Bogen | frisch, nie doppelt gebucht | ja (Snackbar) | nein, `schliesseAbenteuerAb`/`oeffneAbenteuerWieder` |
| Reisebericht | `hero_reisebericht_tab.dart` über `speichereEditorEntwurf` | Bogen | frisch; Belohnungen auf den gespeicherten Helden (`bucheReiseberichtEntwurf`), nie doppelt | ja (Dialog bzw. Snackbar) | Belohnungen errechnet `computePendingRewards` |
| Merkmalsblatt UI2 | `ui2/merkmale/karto_merkmalsblatt.dart` | Bogen | frisch (`updateHero`) | ja, im Blatt | Merkmalsänderung über Regeln |
| Übersicht (Editor) | `hero_overview_tab.dart` über `speichereEditorEntwurf` | Bogen (seit Teilstand 9 kein Zustand mehr) | frisch, Abgleich mit dem Bearbeitungsbeginn; AP als Zähler | ja (Dialog bzw. Snackbar) | Merkmalsentwurf, Zahlengrenzen |
| Übersicht (Sofortaktionen) | `hero_overview_tab.dart`, `hero_overview_stats_section.dart`, `hero_overview_epic_section.dart`, `hero_overview_base_info_section.dart` | Bogen | frisch; AP als Schritt, Ressourcenschalter nur umgestellte | ja (Ressourcenblatt im Blatt, sonst Snackbar) | nein, u. a. `epic_status_rules.dart` |
| Talente / Magie / Begleiter (Editor) | `hero_talents_edit_actions.dart`, `hero_magic_tab.dart`, `hero_begleiter_tab.dart` über `speichereEditorEntwurf` | Bogen | frisch, Abgleich mit dem Bearbeitungsbeginn; bei Überschneidung Rückfrage; bei offener Planung gesperrt | ja (Dialog bzw. Snackbar) | Talentverteilung, Meta-Talente; AP-Delta als Zähler |
| Vertrauten-Steigerung | `hero_begleiter_tab.dart` (`_bucheSteigerung`) | Bogen | frisch; abgewiesen, wenn der Ausgangsstand sich geändert hat | ja (Snackbar) | nein, `begleiter_aenderung_rules.dart` |
| Avatar | `hero_overview/hero_avatar_section.dart`, `avatar_generation_dialog.dart` | Datei + Bogen | frisch | ja | — |
| Gruppen | `hero_gruppe/` | Firestore + Bogen | frisch | ja | — |
| Anlegen / Löschen / Import / Export | `heroes_home_screen.dart`, `workspace_import_export_actions.dart` | Bogen, Zustand | — | ja | — |
| Startimport | `data/startup_hero_importer.dart` | Bogen und Zustand **direkt über das Repository**, ohne Normalisierung und Zeitstempel | — | — | — |

## Ablauf „Rast abschließen“ im Detail

- **Eingaben:** Aktivität (kurze Rast, Schlaf, Bettruhe, nur ausruhen),
  gewünschte Stunden der kurzen Rast, zweite Bettruhe-Phase, Würfe und
  Proben je `RestRollSlot` (digital oder manuell), Umgebung, erkannte
  Rastfähigkeiten, effektive Eigenschaften, Leiteigenschaft,
  Magieaktivierung und die Maxima für LeP, Au und AsP.
- **Regel:** `computeRestOutcome` (`lib/rules/derived/rest_outcome_rules.dart`)
  rechnet vom übergebenen Stand aus; `applyRestOutcome` ersetzt genau
  LeP, Au, AsP, Überanstrengung und Erschöpfung. Der Fullrestore bleibt
  `buildFullRestoreState` (`rest_rules.dart`).
- **Ablauf:** `RastAbschliessen.uebernehmeRast` lädt den Zustand frisch,
  rechnet auf den frischen Werten, hängt die Würfelprotokolleinträge an,
  stempelt Protokoll und `lastModified` mit demselben Zeitpunkt und
  speichert. `vollstaendigeErholung` wendet den Fullrestore auf den frischen
  Zustand an.
- **Vorbedingungen:** keine über die Eingaben hinaus. Fehlt der Zustand,
  gilt `HeroState.empty()`.
- **Fehler:** werden nicht gefangen; `RestPanel` zeigt sie im Panel an und
  lässt den Dialog offen. Während des Speicherns sind beide Knöpfe gesperrt.
- **Grenzen:** Die Maxima und die KO/IN-Zielwerte stammen aus dem
  berechneten Snapshot (`heroComputedProvider`), der `tempMods` bzw.
  `tempAttributeMods` des Zustands einbezieht. Ändert sich einer dieser Werte
  zwischen letzter Anzeige und Übernehmen, rechnet die Rast mit dem alten
  Maximum. Laden, Ändern und Schreiben ist keine Transaktion (ARCH-06).

## Ablauf „Schaden erhalten“ im Detail

- **Eingaben:** Art (Lebensenergie oder Ausdauer/TP(A)), TP, RS (vorbelegt
  aus der Kampfvorschau), Trefferzone (Auswahl oder W20),
  Wundschwellen-Modifikator des Angriffs, vom Nutzer bestätigte Wundzahl,
  Zusatzwürfe der Zone (Extraschaden, Kopf-INI-Malus).
- **Regel:** `schaden_rules.dart` — Vorschlag aus den Wundschwellenstufen,
  `wendeSchadenAn` ersetzt genau `currentLep` und `wpiZustand` bzw.
  `currentAu`.
- **Ablauf:** `SchadenErhalten.uebernehmeSchaden` lädt frisch, wendet an,
  hängt einen Protokolleintrag an und stempelt mit demselben Zeitpunkt.
  Wunden über die freien Plätze der gespeicherten Zone verfallen und stehen
  im Ergebnis.
- **Fehler:** werden nicht gefangen; das Panel zeigt sie und bleibt offen.
- **Grenzen:** Wundschwellen und RS stammen aus dem berechneten Snapshot.
  Die Zusatzwürfe beziehen sich auf die angezeigte Wundzahl der Zone; ändert
  ein anderer Weg sie zwischendurch, bleibt der eingetragene Zusatzschaden
  trotzdem gebucht. Keine Rücknahme (ARCH-06).

## Befunde für Folgeaufträge

1. ~~**Snapshot-Schreibwege im Zustand.** Ressourcen-Stepper, Inspector-Tabs,
   Zaubereffekte und das Würfelprotokoll schreiben einen vorher erfassten
   Zustand vollständig zurück. Zwei kurz nacheinander protokollierte Würfe
   (`unawaited`) können sich gegenseitig überschreiben.~~ *Behoben im
   zweiten ARCH-05-Teilstand:* Alle genannten Wege und die Wunden schreiben
   frisch und je Held nacheinander. Snapshot-Schreibwege des Zustands gibt
   es nur noch im Übersichtseditor (Editorentwurf, Befund 3), beim
   Anlegen und beim Import. Snapshot-Schreibwege des **Bogens** bleiben
   (Dauermodifikatoren, Wundschwelle, Inventar, Kampf, Übersicht).
   *Teilweise behoben im fünften ARCH-05-Teilstand:* Die Sofortaktionen des
   Bogens (Dauermodifikatoren, Wundschwelle, Übersicht, Inventar-Löschen und
   Dukaten, Abenteuerabschluss, Vertrauten-Steigerung) schreiben frisch und je
   Held nacheinander; `saveHero` ist eingereiht. Snapshots bleiben
   Inventareditor, Kampf-Sofortspeichern und die Editorentwürfe.
   *Im siebten ARCH-05-Teilstand behoben:* das Kampf-Sofortspeichern
   (Waffen- und Nebenhandwahl, Entfernung, Geschosse, Waffen-, Rüstungs- und
   Nebenhandteile) schreibt frisch über `kampf_aenderung_rules.dart`.
   Snapshots bleiben der Inventareditor und die Editorentwürfe.
   *Im achten ARCH-05-Teilstand behoben:* der Inventareditor (Anlegen und
   Bearbeiten) schreibt frisch über `inventar_aenderung_rules.dart`.
   Snapshots bleiben nur noch die Editorentwürfe.
   *Im neunten ARCH-05-Teilstand behoben:* Alle sieben Editorentwürfe
   (Übersicht, Talente, Magie, Begleiter, Notizen, Reisebericht,
   Kampf-Editor) gleichen beim Speichern gegen den frisch geladenen Helden ab
   (`editor_entwurf_rules.dart`, `speichereEditorEntwurf`). Der Bogen hat
   damit keinen Snapshot-Schreibweg mehr; beim Zustand bleiben Anlegen und
   Import.
2. ~~**`_filterKnownTraitWarnings` wartet mit `rulesCatalogProvider.future`**~~
   *Behoben:* `saveHero` wartet jetzt über ein Abo auf den Katalog
   (`HeroActions._warteAufRegelkatalog`), höchstens
   `kKatalogWartezeitBeimSpeichern` (20 s). Bei Fehler oder
   Zeitüberschreitung bleiben die Parser-Restfragmente ungefiltert,
   gespeichert wird trotzdem. Nachgewiesen war der Hänger für einen Katalog,
   der nie fertig wird; ein direkt scheiternder Katalog beendete `.future`
   schon bisher mit Fehler. Dasselbe Warten per `.future` steht noch an
   weiteren Stellen und ist ein Folgekandidat:
   `hero_talents/hero_talents_edit_actions.dart` und
   `hero_combat/combat_state_helpers.dart` (Editor-Speichern),
   `hero_workspace_screen.dart` (Vorwärmen), `HeroActions.buildExportJson`
   und `importHeroBundle` (`catalogRuntimeDataProvider.future`),
   `HeroActions._resolveHeroStoragePath` (`heroStorageLocationProvider.future`),
   `house_rule_pack_admin_providers.dart` und `catalog_unlock_dialog.dart`.
3. ~~**Bogen und Zustand im Übersichtseditor** werden nacheinander, nicht
   gemeinsam geschrieben (ARCH-06).~~ *Entfallen im neunten
   ARCH-05-Teilstand:* Der Übersichtseditor schreibt nur noch den Bogen. Seine
   LeP-/AuP-/AsP-/KaP-Felder wurden nie angezeigt und setzten den Zustand vom
   Bearbeitungsbeginn zurück (negative LeP wurden 0).
4. **`createHero` und der Startimport** schreiben den Zustand ohne
   Zeitstempel; der Startimport umgeht zusätzlich die Normalisierung.
5. **Probenlogik doppelt:** `isRestProbeSuccessful` und
   `diceLogEntryFromSimpleCheck` (`lib/domain/dice_log_entry.dart`) werten
   eine einfache W20-Probe jeweils selbst aus.
6. **Regelrechnung in Widgets** vor dem Schreiben: Inventar-/Kampfabgleich,
   Talentverteilung, Wundeffekte, Abenteuer- und Reiseberichtbelohnungen,
   Epik-Start-AP. Die Regelfunktionen existieren, nur die Orchestrierung
   liegt im Widget. *Teilweise behoben:* Epik-Start-AP
   (`epic_status_rules.dart`), Abenteuerabschluss und -rücknahme
   (`schliesseAbenteuerAb`, `oeffneAbenteuerWieder`) und die
   Vertrauten-Steigerung (`begleiter_aenderung_rules.dart`) liegen jetzt als
   Regeln vor; ebenso der Inventar-/Kampfabgleich des Inventareditors
   (`mitGeaendertemInventarEintrag`).
