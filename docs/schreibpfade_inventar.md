# Schreibpfade der Heldenverwaltung (ARCH-05)

Stand: 29.09.2026. Bestandsaufnahme für
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
  Ablauf ruft den Sync ausdrücklich auf.
- Bogen und Zustand sind **getrennte** Schreibvorgänge. Es gibt keine
  Transaktion über beide und keine über Laden → Ändern → Schreiben.
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
| Zustand frisch ändern | `aendereGespeichertenZustand` (`lib/ablaeufe/zustand_schreiben.dart`) | Zustand, frisch | Baustein, `HeroActions.updateHeroState` delegiert |

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
8. `lastModified` frisch gestempelt.
9. Optional: `expectedContentHash` gegen den gespeicherten Stand geprüft
   (optimistische Sperre der Steigerungsrunde).

### Öffentliche Methoden

| Methode | Schreibt | Vorbedingungen / Seiteneffekte |
|---|---|---|
| `createHero` | Bogen (über `saveHero`), Zustand direkt über das Repository (ohne Zeitstempel), Auswahl | Heldenlimit, neue UUID, Standardtalente, wählt den Helden aus |
| `saveHero` | Bogen | Normalisierung oben |
| `updateHero` | Bogen, frisch | wie `saveHero`; keine Transaktion |
| `saveHeroState` | Zustand, Snapshot des Aufrufers | stempelt `lastModified` |
| `updateHeroState` | Zustand, frisch | delegiert an `aendereGespeichertenZustand` |
| `deleteHero` | löscht Bogen und Zustand, Auswahl | — |
| `buildExportJson` / `parseImportJson` | nichts | Avatar und Galerie als Base64, eigene Katalogeinträge |
| `importHeroBundle` | eigener Katalog, Bogen, Zustand, Galeriedateien, Auswahl | Heldenlimit; bis zu drei `saveHero`; lädt den Katalog neu |
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
| Steigerung übernehmen | `AdvancementSessionController.commit` (`state/advancement_providers.dart`) | Bogen | Hash-Prüfung | ja (Snackbar) | nein, `commitAdvancements` |
| Anzeige nicht passender SF | `setShowInapplicableSpecialAbilities` (ebd.) | Bogen **direkt über das Repository**, ohne Normalisierung | Hash-Prüfung | ja | nein |
| Inventar | `hero_inventory/inventory_mutations.dart` (`_saveEntries`, `_saveDukaten`) | Bogen | Snapshot | teilweise | Verknüpfungs- und Geschossabgleich |
| Kampfkonfiguration | `hero_combat/combat_state_helpers.dart` (Sofortspeichern und Editor) | Bogen | Snapshot | teilweise | Slotprüfung, Talentverteilung, AP-Delta |
| Ressourcen (LeP, Au, AsP, KaP) | `resource_stepper_dialog.dart`, `inspector_vitals_tab.dart`, `inspector_magie_tab.dart`, `inspector_belastung_section.dart` | Zustand | Snapshot | nein | Stepper-Grenzen |
| Ressourcen UI2 | `ui/bridges/karto_spiel_bruecke.dart` | Zustand | frisch (`updateHeroState`) | ja | nein |
| Dauermodifikatoren | `inspector_statuswerte_block.dart` | Bogen | Snapshot | nein | — |
| Wunden | `wunden_detail_dialog.dart`, `inspector_wunden_card.dart` (zwei fast gleiche Wege) | Zustand (+ Bogen für Wundschwelle) | Provider-Stand kurz vor dem Schreiben | nein | Wundeffekte, Unterdrückung |
| Zaubereffekte | `shared/active_spell_effects_dialog.dart` | Zustand | Snapshot | nein | — |
| Würfelprotokoll | `shared/dice_log_persistence.dart` (`persistDiceLogEntries`, oft per `unawaited`) | Zustand | Provider-Stand | nein | — |
| Abenteuerblatt UI2 | `ui2/spielen/karto_abenteuerblatt.dart` | Bogen | frisch (`updateHero`) | ja, im Blatt | `ersetzeAbenteuer` (UI2) |
| Abenteuer (Bestand) | `hero_notes_tab.dart` (Editor, Abschluss, Wiedereröffnen) | Bogen | Editorentwurf | teilweise | Belohnungen buchen/zurücknehmen |
| Reisebericht | `hero_reisebericht_tab.dart` | Bogen | Editorentwurf | teilweise | Belohnungen |
| Merkmalsblatt UI2 | `ui2/merkmale/karto_merkmalsblatt.dart` | Bogen | frisch (`updateHero`) | ja, im Blatt | Merkmalsänderung über Regeln |
| Übersicht (Editor) | `hero_overview_tab.dart` | Bogen **und** Zustand, zwei getrennte Schreibvorgänge | Editorentwurf | teilweise | Merkmalsentwurf, Zahlengrenzen |
| Übersicht (Sofortaktionen) | `hero_overview_tab.dart`, `hero_overview_stats_section.dart`, `hero_overview_epic_section.dart`, `hero_overview_base_info_section.dart` | Bogen | Snapshot | teilweise | Epik-Start-AP |
| Talente / Magie / Begleiter (Editor) | `hero_talents_edit_actions.dart`, `hero_magic_tab.dart`, `hero_begleiter_tab.dart` | Bogen | Editorentwurf | teilweise | Talentverteilung, Meta-Talente, AP-Delta |
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

## Befunde für Folgeaufträge

1. **Snapshot-Schreibwege im Zustand.** Ressourcen-Stepper, Inspector-Tabs,
   Zaubereffekte und das Würfelprotokoll schreiben einen vorher erfassten
   Zustand vollständig zurück. Zwei kurz nacheinander protokollierte Würfe
   (`unawaited`) können sich gegenseitig überschreiben. Nächster Kandidat
   für einen Ablauf nach dem Rast-Muster.
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
3. **Bogen und Zustand im Übersichtseditor** werden nacheinander, nicht
   gemeinsam geschrieben (ARCH-06).
4. **`createHero` und der Startimport** schreiben den Zustand ohne
   Zeitstempel; der Startimport umgeht zusätzlich die Normalisierung.
5. **Probenlogik doppelt:** `isRestProbeSuccessful` und
   `diceLogEntryFromSimpleCheck` (`lib/domain/dice_log_entry.dart`) werten
   eine einfache W20-Probe jeweils selbst aus.
6. **Regelrechnung in Widgets** vor dem Schreiben: Inventar-/Kampfabgleich,
   Talentverteilung, Wundeffekte, Abenteuer- und Reiseberichtbelohnungen,
   Epik-Start-AP. Die Regelfunktionen existieren, nur die Orchestrierung
   liegt im Widget.
