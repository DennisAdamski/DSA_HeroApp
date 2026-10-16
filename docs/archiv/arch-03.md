# Archiv — ARCH-03 Gemeinsame Ausrüstungsdaten für Inventar und Kampf

Archiv der Architektur-Roadmap, Stand 16.10.2026. Dies ist der unveränderte Wortlaut des früheren Roadmap-Abschnitts; die Roadmap ([architecture_roadmap.md](../architecture_roadmap.md)) führt nur noch Status und offene Punkte. Verweise wie „Teilstand (3)“ in Code, CLAUDE.md und anderen Dokumenten beziehen sich auf diesen Text.

---

## ARCH-03 — Gemeinsame Ausrüstungsdaten für Inventar und Kampf

**Ausgangszustand:** Kampfausrüstung und Inventar werden über
`reconcileInventoryWithCombat` abgeglichen. Verknüpfungsschlüssel für Waffen,
Rüstung und Geschosse enthielten Namen; es bestehen mehrere Darstellungen eines
Gegenstands mit unterschiedlichen Zuständigkeiten für seine Felder.

**Ziel:** Jeden konkreten Gegenstand einmal mit stabiler Instanz-ID speichern.
Kampfkonfiguration und Ausrüstungsplätze referenzieren ihn. Eine Katalog-ID
beschreibt den Gegenstandstyp, eine Instanz-ID das konkrete Exemplar.

**Einstieg:** `lib/domain/hero_inventory_entry.dart`, `lib/domain/combat_config/`,
`lib/rules/derived/inventory_sync_rules.dart`,
`lib/rules/derived/inventory_modifier_rules.dart`, `lib/state/hero_actions.dart`,
`lib/ui/screens/hero_inventory/` und `lib/ui/screens/hero_combat/`.

- [x] Zuständigkeiten für Gegenstandseigenschaften, Menge und ausgerüstete Slots
  festlegen und ein gemeinsames Modell mit stabilen Referenzen einführen.
- [x] Vorhandene Kampf-/Inventareinträge migrieren; gleichnamige Exemplare,
  individuelle Eigenschaften und Geschossmengen verlustfrei erhalten.
- [x] Umbenennen, Ablegen, Verkaufen und Ausrüsten auf das gemeinsame Modell
  umstellen; den namensbasierten Abgleich nach abgesicherter Migration ablösen.

**Abnahme:** Zwei gleichnamige Waffen bleiben unabhängig bearbeitbar. Umbenennen
ändert keine Zuordnung und verliert keine Zusatzdaten. Entfernen eines
Gegenstands hinterlässt keine ungültigen Slot-Referenzen. Kampfwerte und
Inventarmodifikatoren beziehen sich konsistent auf die tatsächlich ausgerüsteten
Exemplare; Import/Export erhält IDs und Verknüpfungen.

**Prüfung:** `test/domain/hero_inventory_entry_model_test.dart`, vorhandene
Inventar-/Kampfregeltests unter `test/rules/`, `test/ui/inventory/` und
Import-/Exporttests um Migration, Namensgleichheit und Slotwechsel ergänzen.

**Abhängigkeiten / offene Entscheidungen:** Bestandsfälle aus ARCH-07 nutzen.
Mengenstapel, aufgeteilte Munition und Identitätsregeln beim Kopieren eines Helden
vor der Modelländerung klären. Schreibvorgänge mit ARCH-05/06 abstimmen.

**Entscheidungen vom 04.10.2026 (Dennis):**

1. *Mengenstapel und Munition:* Ein Stapel ist **ein** Gegenstand mit einer
   Instanz-ID und einer Menge (auch Waffen und Rüstung, sofern Menge > 1).
   Teilt man einen Stapel (z. B. 10 Pfeile am Bogen, 10 im Rucksack),
   entsteht ein zweiter Stapel mit neuer Instanz-ID; Kampf-Slots verweisen
   auf den jeweiligen Stapel. Die heutige Freitext-Menge `anzahl` und die
   Geschossmengen am Slot bleiben als Altdarstellung lesbar (nur additive
   Formatänderung, neue Menge unter neuem Schlüssel).
2. *Identität beim Kopieren eines Helden:* Instanz- und Slot-IDs bleiben
   erhalten. Sie sind nur innerhalb eines Helden eindeutig; die Kopie
   bekommt nur eine neue Helden-ID (wie bisher in `HeroActions`). Kein
   Umschreiben von Verweisen.

**Teilstand 04.10.2026 — Instanz-ID und Menge im Inventareintrag.**
`HeroInventoryEntry` trägt additiv `instanzId` und `menge`; beide stehen nur
bei belegtem Wert im JSON und in `jsonSchluessel`. `vergibInstanzIds`
(`rules/derived/inventar_instanz_rules.dart`) vergibt fehlende oder doppelte
IDs ausschließlich in `HeroActions.saveHero`, nie beim Laden, damit die
Hash-Pins der Bestandshelden stehen bleiben. Das erste Speichern ändert je
Eintrag nur diesen Schlüssel; `bestandsheld_ablauf_test.dart` erlaubt genau
diese Pfade. Noch nicht umgesetzt: Kampf-Slots verweisen weiter über
`slotRef`/`sourceRef`, `anzahl` bleibt Freitext, Umbenennen/Ablegen/Verkaufen
laufen noch über den alten Abgleich. Risiko: Die veröffentlichte App verwirft
`instanzId` beim Zurückschreiben; die nächste Speicherung dieser Version
vergibt dann eine neue ID. Verweise müssen deshalb weiter über `slotRef`
laufen, bis eine Version mit dem Feld verbreitet ist. Volle Suite grün.

*Veröffentlicht* mit dem Merge-Commit `2ecfb48` (PR #221, 6.10.2026, Release
`test` → `main`, Production-Deploy grün). Präzisierung des Risikos: Die
Web-Produktion bewahrt unbekannte Felder schon seit PR #199–#201
(28./29.09.2026) und hätte `instanzId` also erhalten. Verworfen hätte es nur
ein Build vor dem 28.09. (Stand `7f0f830`, den
`test/test_support/veroeffentlichte_app.dart` nachbildet). Laut Dennis läuft
seit dem 6.10. keine ältere App mehr, weder nativ noch im Web; die
Instanz-ID darf damit führende Identität werden.

**Teilstand 06.10.2026 — Menge und Stapel.** Entscheidungen (Dennis,
6.10.2026):

- a) Es läuft nur noch die Web-App, keine ältere Version. Die Instanz-ID darf
  führen; `sourceRef` und `slotRef` werden weiter geschrieben.
- b) Ein rein ganzzahliges `anzahl` wird beim Speichern zu `menge`. Leer und
  Freitext bleiben offen. Weicht ein ganzzahliges `anzahl` von `menge` ab, hat
  eine ältere Version es geändert: `anzahl` gilt, die Abweichung wird
  angezeigt.
- c) „Stapel teilen“ im Inventareditor spaltet einen unverknüpften Stapel mit
  neuer ID ab; bei Geschossen sinkt die Menge am Slot.

*Zuständigkeit je Feld.*

- **Identität:** `instanzId`, bei verknüpften Einträgen zusätzlich `slotRef`
  auf den Slot.
- **Name:** beim unverknüpften Eintrag der Eintrag, beim verknüpften der Slot.
- **Magisch/geweiht:** beim verknüpften Eintrag Slot ↔ Editor, bidirektional.
- **Gewicht, Wert, Ort, Träger, Modifikatoren:** immer der Eintrag.
- **Menge:** beim unverknüpften Eintrag `menge`, mit `anzahl` als Text. Beim
  Geschoss führt `count` am Slot, der Eintrag ist Projektion, und der Editor
  schreibt über `slotRef` zurück. Waffe, Rüstung und Nebenhand sind
  Einzelstücke.
- **Ausgerüstet:** beim verknüpften Eintrag der Slot, sonst
  `istAusgeruestet`.
- **Verweisrichtung:** bleibt vorerst Eintrag → Slot. Die Umkehr nützt erst
  zusammen mit „Ablegen behält das Exemplar“.

*Umsetzung.*

- **Mengenlesart** (`inventar_menge_rules.dart`): `inventarMengenstand`,
  `mitInventarMenge`, `mitInventarMengeAusText`,
  `ueberfuehreInventarMengen`.
  - `saveHero` überführt Mengen vor `vergibInstanzIds`, nie beim Laden.
  - Der Abgleich vergibt keine Menge, damit er auf Bestandsdaten ein
    Fixpunkt bleibt; eine vorhandene Geschossmenge hält er mit dem Slot
    synchron.
  - `inventarMenge` gab `menge` bisher Vorrang und rechnet jetzt mit der
    wirksamen Menge.
- **Teilen** (`inventar_stapel_rules.dart`, Dialog
  `inventory_stapel_teilen.dart`) läuft frisch über `aendereHeldImEditor`.
- **Treffer:** Inventarwege treffen Einträge über
  `findeInventarEintragZurAenderung` per Instanz-ID, Altdaten über den
  Inhalt. Die Inhaltssuche übersieht die beim Speichern ergänzte Menge wie
  schon die ID.
- **Kleinfixe** (keine Befundnummer, beide still verlustbehaftet):
  - Freitext bei einem Geschoss setzte den Bestand des Bogens auf 0.
  - Der Ausrüsten-Schalter verknüpfter Einträge wurde vom Abgleich
    überschrieben; er ist jetzt gesperrt.

Commits:

- `52c717e` Release-Nachtrag
- `8612769` Menge
- `2800ece` Stapel teilen
- `37bb7d8` Ausrüsten-Schalter
- `5325c14`, `f17cab4` Abnahme

*Prüfungen.*

- Je Teil liefen die Regressionsproben zuerst rot. Gegenproben ohne
  Überführung, mit altem Editor und ohne Slot-Rückschreibung scheitern.
- Abnahme:
  - zwei gleichnamige Stapel unabhängig bearbeitbar;
  - Export und Import, überschreibend und als Kopie, erhalten
    `instanzId`/`menge`/`slotRef` ausdrücklich;
  - Zwei-Geräte-Sync S7 (`sync_zwei_geraete_inventar_test.dart`): Teilen
    kommt vollständig an, gleichzeitiges Teilen und Bearbeiten ergibt einen
    sichtbaren Konflikt, `keepLocal`/`keepRemote`/`keepBoth` ohne stillen
    Verlust;
  - Mischbetrieb mit einer Version, die nur `anzahl` ändert
    (`anzahlWieVersionOhneMenge`).
- Die Hash-Pins der Bestandshelden sind unverändert. `bestandsheld_ablauf_test`
  erlaubt für die erste Speicherung zusätzlich `inventoryEntries/i/menge` bei
  ganzzahliger Anzahl (f01, f06).
- `flutter analyze` ohne Befund; Format- und Screen-LOC-Prüfung bestehen.
  Vollständige Suite (`--concurrency=1`, eigener `DSA_MCP_DATA_DIR`): 3.678
  bestanden, 3 bestehende übersprungen.

*Verbleibende Risiken:*

1. Die Abnahme „Entfernen hinterlässt keine ungültigen Verweise“ hält
   weiter nur, weil der Abgleich den Eintrag samt ID und Eigenschaften
   löscht. Ein Slot, der entfernt und neu angelegt wird, bekommt ein neues
   Exemplar.
2. Der abgespaltene Stapel übernimmt unbekannte Felder des Originals. Bedeuten
   sie für eine neuere Version Identität, wären sie doppelt.
3. Eine Abweichung bleibt bestehen, bis jemand den Eintrag bearbeitet oder
   verbraucht. Der Hinweis steht nur im Editor, nicht in Liste oder Gefecht.
4. Startimport und Sync-Übernahme schreiben ohne Normalisierung; dort
   entstehen weder IDs noch Mengen. Das ist unverändert und unschädlich, weil
   das nächste Speichern sie ergänzt.
5. Restrisiko 3 des Teilstands vom 28.09. (Echo der veröffentlichten App)
   gilt laut Dennis als erledigt: Seit dem 6.10. läuft kein solcher Client
   mehr.

*Nächster Schritt:*

1. ~~Verweisrichtung Slot → Instanz: `inventarInstanzId` additiv an
   Waffe, Geschoss, Rüstungsstück und Nebenhand, gesetzt in `saveHero`; der
   Abgleich trifft zuerst über die Instanz.~~ *Erledigt im Teilstand
   „Verweis Slot → Instanz“ unten.*
2. ~~Ablegen und Ausrüsten behalten das Exemplar: Ein entfernter Slot
   hinterlässt einen unverknüpften Eintrag mit derselben ID.~~ *Erledigt im
   Teilstand „Ablegen und Zurückholen“ unten.*
3. Danach den Namensabgleich ablösen; Zusammenführen von Stapeln und
   Verkaufen folgen.

**Teilstand 06.10.2026 (2) — Verweis Slot → Instanz.** Schritt 1 des
vorigen Teilstands.

*Umsetzung.*

- **Feld:** `inventarInstanzId` an `MainWeaponSlot`, `RangedProjectile`,
  `ArmorPiece` und `OffhandEquipmentEntry`; additiv, in `jsonSchluessel`,
  nur bei Belegung geschrieben. Es ist abgeleitet: die Bedienung schreibt
  es nie.
- **Setzen:** `bindeSlotsAnInstanzen`
  (`rules/derived/inventar_slot_instanz_rules.dart`) läuft in `saveHero`
  nach Abgleich, Mengenüberführung und `vergibInstanzIds`. Quelle ist der
  Eintrag, der per `slotRef` auf den Slot zeigt; ohne ihn wird ein
  veralteter Verweis geleert. Laden setzt nichts, die Hash-Pins bleiben.
- **Abgleich:** `reconcileInventoryWithCombat` und
  `applyLinkedInventoryDetailsToConfig` teilen jetzt eine Paarung:
  Instanz, dann `slotRef`, dann Name. Die Instanz zählt nur bei gleicher
  Quelle und nicht, wenn der Eintrag per `slotRef` zu einem anderen
  bestehenden Slot gehört (kopierter Slot mit der Instanz seines
  Vorbilds). Neue Einträge übernehmen die Instanz des Slots nicht.
- **Abgeleitet, kein Profil:** Die Prüfungen „inzwischen geändert“
  (`kampf_aenderung_rules.dart`, `gefecht_hand_rules.dart`) und die
  Gefechts-Fingerabdrücke (Ziel-, Lade-, Bruchprofil) lassen den Verweis
  über `ohneInstanzverweise` weg. Sonst hätte das erste Speichern nach dem
  Update eine offene Kampfänderung abgewiesen oder einen gebundenen
  Ladezustand verworfen.
- **Bewusst unverändert:** `migriereInventarVerweise` (Laden) ordnet weiter
  nur über Name und Slot-ID. Einträge ohne `slotRef` mit Instanz-ID
  entstehen nur mit Versionen, die seit dem 6.10. nicht mehr laufen.

*Prüfungen.*

- Regeltests (`inventar_slot_instanz_rules_test.dart`): Bindung aller vier
  Slotarten samt gespiegelter aktiver Waffe, Fixpunkt, Leeren veralteter
  Verweise, Instanz vor Reihenfolge, veralteter `slotRef`, fremder
  bestehender Slot, Kopie vor dem Vorbild, Quellengrenze, gemeinsame
  Paarung für Markierungen, Gefechts-Fingerabdrücke.
- Ablauf über `saveHero` (`hero_actions_slot_instanz_test.dart`):
  Bindung, erneutes Speichern ohne Änderung, Umbenennen und Umsortieren
  gleichnamiger Dolche, verlorener `slotRef`, entfernter Slot.
- Kampf- und Gefechtsvergleiche ignorieren den Verweis (je ein Test).
- Gegenproben: ohne Instanzpaarung, ohne Wächter, mit übernommener
  Slot-Instanz, ohne Bindung in `saveHero` und ohne die Ausnahmen in den
  Vergleichen scheitern jeweils die zugehörigen Tests.
- `bestandsheld_ablauf_test` erlaubt für die erste Speicherung zusätzlich
  `inventarInstanzId` je benanntem Slot (`slotInstanzPfade`). Die Hash-Pins
  der Bestandshelden sind unverändert.
- `flutter analyze` ohne Befund; Format- und Screen-LOC-Prüfung bestehen.
  Vollständige Suite (`--concurrency=1`, eigener `DSA_MCP_DATA_DIR`): 3.699
  bestanden, 3 bestehende übersprungen.

Commit: `646c87c`.

*Verbleibende Risiken:*

1. Zeigen Instanz und `slotRef` auf verschiedene Slots, gewinnt die
   Instanz, sofern der Eintrag nicht zu einem anderen bestehenden Slot
   gehört. Ein dann übrig bleibender Eintrag mit passendem `slotRef`, aber
   anderer Instanz, fällt wie bisher ein Eintrag eines entfernten Slots
   weg. In eigenen Abläufen dieser Version laufen beide nie auseinander.
2. Die Restrisiken 1–4 des Teilstands „Menge und Stapel“ gelten
   unverändert; Risiko 1 (Entfernen löscht das Exemplar) löst erst
   Schritt 2.
3. Neue Fingerabdrücke über Slot-JSON müssen den Verweis ebenfalls
   weglassen (`ohneInstanzverweise`).

*Nächster Schritt:* ~~Schritt 2 oben — Ablegen und Ausrüsten behalten das
Exemplar.~~ *Erledigt im folgenden Teilstand.*

**Teilstand 06.10.2026 (3) — Ablegen und Zurückholen.** Schritt 2.

*Entscheidungen (Dennis, 6.10.2026):*

- Entfernen im Kampfbereich fragt „Nur ablegen“ oder „Ganz entfernen“ —
  für Waffen, Geschosse, Rüstungsteile, Schilde und Parierwaffen.
- Ein Geschoss bei Bestand 0 behält seinen Inventareintrag.
- Zurück kommt ein abgelegter Gegenstand über einen Knopf am
  Inventareintrag, mit den gemerkten Kampfwerten (Variante A).

*Umsetzung.*

- **Modell:** `HeroInventoryEntry.abgelegt` (`AbgelegterKampfgegenstand`,
  genau einer von Waffe, Geschoss, Rüstungsteil, Nebenhandteil; additiv,
  eigenes `jsonSchluessel`, nur bei Belegung geschrieben). Die Slots
  bewahren ihre unbekannten Felder selbst.
- **Regeln:** `rules/derived/kampfgegenstand_ablegen_rules.dart`.
  - Ablegen macht den verknüpften Eintrag zum manuellen Eintrag ohne
    Verweise, mit derselben Instanz-ID und dem Slot als Profil. Manuell,
    weil mehrere Stellen (Editor, Gefecht, Verbrauch) allein an der Quelle
    „verknüpft“ festmachen; Liste und Filter zeigen ihn über
    `anzeigeQuelleImInventar` weiter als Waffe, Geschoss usw.
  - Eine entfernte Fernkampfwaffe legt ihre Geschosse in beiden Fällen ab;
    das Profil der abgelegten Waffe enthält keine Geschosse.
  - Geschosse, die das Ergebnis des Waffeneditors nicht mehr führt, fragen
    beim Speichern der Waffe; Abbruch speichert nicht.
  - Zurückholen hängt den Slot hinten an (Name und Markierungen vom
    Eintrag, Menge bei Geschossen, Zielwaffe wählbar) und verknüpft den
    Eintrag per Namensverweis; der Abgleich paart über die Instanz.
- **Kampf-Tab:** `_aendereKampf` delegiert an `_aendereKampfUndInventar`.
  Im Bearbeitungsmodus hält der Tab einen Inventarentwurf, den
  „Speichern“ mit der Kampfkonfiguration übernimmt.
- **Inventar:** Hinweis und Knopf „In Kampfbereich übernehmen“ im Editor
  (`inventory_kampf_uebernehmen.dart`), Schreibweg `_uebernehmeInKampf`.

*Prüfungen.*

- Regeltests (`kampfgegenstand_ablegen_rules_test.dart`): Ablegen und
  ganz Entfernen je Art, Geschosse mit Bestand 0, Bogen ohne gemerkte
  Geschosse, Editor-Geschosse, Zurückholen von Waffe (umbenannt) und
  Geschoss (Menge, Zielwaffe), geänderter Eintrag, Eintrag ohne Profil.
- Widgettests: Kampf-Tab „Nur ablegen“, Abbrechen, Bearbeitungsmodus
  (`kampf_ablegen_test.dart`); Inventar „In Kampfbereich übernehmen“ für
  Waffe und Geschoss (`inventar_kampf_uebernehmen_test.dart`). Die
  bisherigen Entfernen-Tests antworten „Ganz entfernen“.
- Modelltabellen um `AbgelegterKampfgegenstand` und `abgelegt` ergänzt.
- Gegenproben: ohne Inventarentwurf beim Speichern bzw. ohne
  Neuverknüpfung scheitern die zugehörigen Tests.
- `flutter analyze` ohne Befund; Format- und Screen-LOC-Prüfung bestehen.
  Vollständige Suite (`--concurrency=1`, eigener `DSA_MCP_DATA_DIR`): 3.717
  bestanden, 3 bestehende übersprungen.

Commit: `ba43ad0`.

*Verbleibende Risiken:*

1. „Ganz entfernen“ im Inventar gibt es weiterhin nur für unverknüpfte
   Einträge; ein verknüpfter Gegenstand wird über den Kampf-Tab entfernt.
2. „In Kampfbereich übernehmen“ wirkt auf den gespeicherten Eintrag;
   ungespeicherte Änderungen im offenen Editor gehen dabei verloren.
3. Ein abgespaltener Stapel eines abgelegten Geschosses übernimmt dessen
   Profil; beide Stapel lassen sich getrennt zurückholen.
4. Abgelegte Gegenstände sind manuelle Einträge: Im Gefecht erscheinen
   abgelegte Geschosse als gewöhnliche Gegenstände („Gegenstand benutzen“),
   verschossen wird nur von einer Waffe.

*Nächster Schritt:* ~~Schritt 3 oben — den Namensabgleich ablösen;
Zusammenführen von Stapeln und Verkaufen folgen.~~ *Erledigt im folgenden
Teilstand.*

**Teilstand 07.10.2026 — Namensabgleich, Stückwerte, Zusammenführen,
Verkaufen.** Schritt 3.

*Entscheidungen (Dennis, 7.10.2026):* Wert und Gewicht gelten pro Stück.
Zusammenführen nur bei gleichem Namen, Typ, gleichen Markierungen und
Modifikatoren; die übrigen Angaben kommen vom Ziel. Verkaufspreis
vorbelegt mit dem vollen Wert, frei änderbar, auf die Dukaten.
Ausgerüstetes darf verkauft werden und verlässt dabei den Kampfbereich.

*Umsetzung (vier Commits):*

- `bc56e90` Namensabgleich abgelöst: Abgleich und Ablegen paaren nur über
  Instanz und `slotRef`; Altdaten ordnet weiter einmalig das Laden über
  den Namen zu (`migriereInventarVerweise`). Nur Slots ohne ID (allein im
  Speicher vor dem ersten Speichern) paaren noch über den Namen.
- `b5ca134` Wert und Gewicht pro Stück (`inventar_summen_rules.dart`):
  Summen und Tabellenspalten rechnen Menge × Stückwert, offene Menge = 1,
  Menge 0 = nichts; Felder in Editor und Beutedialog „pro Stück“.
- `e97a68c` Stapel zusammenführen (`inventar_stapel_rules.dart`, Dialog
  `inventory_stapel_zusammenfuehren.dart`); Editoraktionen gebündelt in
  `inventory_eintrag_aktionen.dart`. Verknüpfte Quelle gesperrt
  (zuerst ablegen), verknüpftes Ziel nur als Geschoss (Slotbestand steigt),
  Abenteuerbeute ist kein Ziel.
- `2adb23c` Verkaufen (`inventar_verkauf_rules.dart`, Dialog
  `inventory_verkaufen_dialog.dart`).

*Prüfungen.* Regeltests je Teil (`inventory_sync_rules_test`,
`inventar_summen_rules_test`, `inventar_zusammenfuehren_rules_test`,
`inventar_verkauf_rules_test`), Widgettests für Zusammenführen und
Verkaufen. `flutter analyze` ohne Befund, Format- und LOC-Prüfung bestehen.
Vollständige Suite (`--concurrency=1`): 3.750 bestanden, 3 übersprungen.

*Verbleibende Risiken:*

1. Bestehende Stapel mit Menge > 1 zeigen jetzt eine höhere Summe, falls
   ihr Wert bisher als Stapelwert eingetragen war; es wird nichts
   umgerechnet.
2. Abenteuerbeute als Quelle eines Zusammenführens oder Verkaufs sperrt
   wie ein Löschen das spätere Zurücknehmen des Abenteuers (sichtbar).
3. ~~Die letzte Waffe lässt sich weiterhin nicht entfernen, also auch nicht
   verkaufen.~~ *Behoben im Nachtrag zum Abschluss unten.*
4. Ein Verkauf wird nicht protokolliert; er ist nur über Inventar und
   Geldstand nachvollziehbar.

*Nächster Schritt:* ~~die übrige ARCH-03-Abnahme prüfen~~ *Erledigt im
Abschluss unten.*

**Abschluss 07.10.2026 — Abnahme ARCH-03.** Geprüft gegen die
Abnahmekriterien:

- *Zwei gleichnamige Waffen unabhängig:* Slot-IDs, `slotRef`, Instanz-IDs
  (Bestandsheld f06, `inventory_sync_rules_test`, `inventar_slot_instanz_*`).
- *Umbenennen ohne Verlust:* Zuordnung über Instanz und ID, nie über den
  Namen (`hero_actions_slot_instanz_test`).
- *Entfernen ohne ungültige Verweise:* Entfernen fragt „Nur ablegen“/„Ganz
  entfernen“; `bindeSlotsAnInstanzen` leert verwaiste Verweise, die
  Nebenhandbelegung rückt nach (`kampf_aenderung_rules_test`).
- *Kampfwerte und Modifikatoren auf denselben Exemplaren:* **neu** —
  Entscheidung (Dennis, 7.10.2026): Modifikatoren verknüpfter Waffen
  wirken nur in der Hand (gewählte Hauptwaffe oder Nebenhand), Schild und
  Parierwaffe nur in der Nebenhand, Rüstung nur angelegt. Bisher galt jede
  Waffe der Liste als ausgerüstet. Der Abgleich setzt `istAusgeruestet`
  entsprechend; jeder Waffenwechsel läuft über `saveHero`, die
  Modifikatoren folgen. Das erste Speichern ändert dabei einmalig
  `istAusgeruestet` nicht geführter Waffen (`bestandsheld_ablauf_test`
  erlaubt den Pfad, Hash-Pins unverändert).
- *Import/Export erhält IDs und Verknüpfungen:* Abnahmetest um einen
  abgelegten Gegenstand und die Slot-Instanzverweise erweitert.

*Abgrenzung Katalog-ID.* Das Ziel nannte eine Katalog-ID für den
Gegenstandstyp. Für Waffen ist das faktisch `weaponType` (Katalogname der
Waffenart, darüber werden Talente und Manöver aufgelöst); Rüstungsteile,
Schilde und Geschosse haben keinen Katalog. Eine zusätzliche ID brächte
heute keinen Nutzen und wurde bewusst nicht eingeführt. Sobald Ausrüstung
einen eigenen Katalog bekommt, ist sie dort nachzuziehen.

*Prüfungen.* Neue Tests „Modifikatoren wirken nur in der Hand“
(`inventory_sync_rules_test`), angepasste Bestandsheld- und B13-Proben
(der erste Abgleich ändert nur `istAusgeruestet`, ein zweiter nichts);
Gegenprobe mit „immer ausgerüstet“ scheitert.
`flutter analyze` ohne Befund; vollständige Suite (`--concurrency=1`): 3.752
bestanden, 3 übersprungen. Commit: `5d72ddd`.

*Verbleibende Risiken:* die der Teilstände oben, insbesondere: Bestandswerte
pro Stapel werden nicht umgerechnet; ein Verkauf wird nicht protokolliert.

*Nachtrag 07.10.2026 — die letzte Waffe (Wunsch Dennis).* Auch die letzte
Waffe lässt sich entfernen, ablegen und verkaufen. `ohneWaffe` führt dann in
den Zustand eines neuen Helden (keine Waffenliste, leerer Platzhalter); der
Entfernen-Knopf ist nur noch für diesen Platzhalter gesperrt, und
`mitNeuerWaffe` ersetzt ihn, statt die neue Waffe dahinter zu hängen (die
alte Macke legte bei einem neuen Helden einen leeren Slot vor die erste
Waffe). Kleinfix dabei: `_normalizeOffhandAssignment` leerte die Nebenhand,
sobald keine Hauptwaffe gewählt war (−1 = −1 galt als Doppelbelegung); ein
Schild bleibt jetzt in der Hand. Bestandsdaten ändern sich nicht (Hash-Pins
unverändert). Tests: Regeln (Entfernen, Ablegen samt Zurückholen,
Verkaufen der letzten Waffe, Schild ohne Hauptwaffe) und Kampf-Tab;
zwei Kampf-Tab-Tests erwarteten die alte Macke und sind angepasst.
`flutter analyze` ohne Befund; vollständige Suite: 3.758 bestanden,
3 übersprungen.

**Teilstand 27.09.2026 — B2/B3 behoben:** Kampf-Slots für Waffen,
Geschosse, Rüstung und Nebenhand tragen stabile IDs. Beim Laden erhalten
Bestandsdaten deterministische IDs und die Inventar-Namensverweise werden
in Slot-Reihenfolge migriert; neue Slots bekommen beim Speichern UUIDs.
Damit bleiben gleichnamige Exemplare nach Entfernen oder Umbenennen
unabhängig. Domain-Tests pinnen die einmalig geänderten Inhalts-Hashes und
prüfen den Fixpunkt, Regeltests die beiden Befunde, ein Hive-Test Neustart
und Export. `flutter analyze --no-pub` und die vollständige Flutter-Suite
waren grün (2.278 bestanden, drei übersprungen). Die vollständige
ARCH-03-Abnahme ist damit **nicht** erreicht: Das gemeinsame Gegenstandsmodell,
Katalog-IDs und die übrigen Schreibabläufe fehlen. Gemischte Bearbeitung
mit älteren App-Versionen ist wegen der neuen verschachtelten IDs nicht
abgesichert. Auch eine reine ID-Migration kann bei gleichzeitig geänderter
Cloud-Version einen sichtbaren Sync-Konflikt auslösen. Der zugehörige
Fix-Commit ist `f0c9ffc`. *(Überholt durch den Teilstand vom 28.09.2026:
Das Verweisformat ist jetzt mit der veröffentlichten App verträglich.)*

**Teilstand 28.09.2026 — Versions- und Sync-Kompatibilität der
Ausrüstungsdaten.** Umgesetzt wurde der Teilumfang „unbekannte verschachtelte
Felder“, beschränkt auf die Ausrüstung.

*Entscheidung: bewahren statt sperren.* Die Ausrüstungsmodelle sind
unveränderlich, werden per `copyWith` geändert und haben stabile Slot-IDs.
Gespeichert wird zentral, und Hash sowie Konflikt-Diff arbeiten auf
`toJson()`. Damit lassen sich unbekannte Felder verlustfrei erhalten. Eine
sichtbare Schreibsperre wäre nur für nicht-additive Formatänderungen nötig;
solche gibt es nicht. Festgehalten ist stattdessen die Formatregel „nur
additiv, eine neue Bedeutung bekommt einen neuen Schlüssel“
(technische Übersicht, Abschnitt 2.1). Die veröffentlichte App (`main`) lässt
sich nicht ändern. Das noch unveröffentlichte Verweisformat wurde deshalb so
gewählt, dass sie damit verträglich arbeitet.

Drei Commits:

- `f28cb1a` — Zehn Ausrüstungsmodelle bewahren unbekannte Felder:
  `CombatConfig`, Waffe, Fernkampfprofil, Geschoss, Distanzstufe, Rüstung,
  Rüstungsstück, Nebenhand, Inventareintrag und Modifikator. Neu aufbauende
  Wege arbeiten jetzt per `copyWith`: `_mergeEntry` sowie die Editoren für
  Nebenhand, Geschoss, Distanzstufe und Begleiterrüstung. Katalogschlüssel
  gelangen nicht in Heldendaten. Die Hash-Pins bleiben unverändert.
- `192cf41` — Befund B10: Die Sync-Basis ist der lokale Stand. Ein bloßer
  Abgleich lädt keine verkürzte Fassung mehr hoch.
- `cc8ffaa` — `sourceRef` bleibt der Namensverweis, der ID-Verweis steht
  in `slotRef`. Dabei wurde ein Fehler gefunden und behoben: Die Pfeilzahl
  des zweiten gleichnamigen Bogens landete beim ersten. Die Hash-Pins von
  f01, f02, f04 und f06 haben sich einmalig geändert.

*Prüfungen.* Getestet ist jeder Weg aus dem Auftrag: Laden, Bearbeiten
(Abgleich, Editoren, `HeroActions`), Speichern mit echtem Hive samt
Neustart, Import/Export (überschreiben und als Kopie) und der Zwei-Geräte-Sync
mit einem Stand einer neueren Version. Dazu kommen eine gleichzeitig
geänderte Cloud (sichtbarer Konfliktpfad, keepRemote/keepLocal/keepBoth ohne
stillen Verlust) und der Mischbetrieb mit einer Nachbildung der
veröffentlichten App (`test/test_support/veroeffentlichte_app.dart`). Die
Gegenproben scheitern jeweils ohne den Fix. `flutter analyze` war ohne
Befund, die volle Suite grün (2353 bestanden, 3 übersprungen).

*Verbleibende Risiken, ausdrücklich außerhalb dieses Teilumfangs:*

1. ~~Andere verschachtelte Modelle verlieren unbekannte Felder weiterhin:
   `OffhandAssignment`, `CombatSpecialRules`, `CombatManualMods`,
   `WaffenmeisterConfig`, Talente, Zauber, Rituale, die eigenen Felder von
   `HeroCompanion`, Abenteuer und Notizen. Seit B10 geschieht das erst bei
   einer echten Änderung, nicht mehr beim bloßen Abgleich. Der Konflikt-Diff
   zeigt diese Felder nicht.~~ *Erledigt im Teilstand „Alle verschachtelten
   Modelle“ unten.*
2. ~~Unbekannte **Enum-Werte** fallen auf Standardwerte zurück (`itemType`,
   `source`, `traegerTyp`, `combatType`, Nebenhand-`type`, `shieldSize`,
   Modifikator-`kind`) und werden bei einer Änderung überschrieben.~~
   *Erledigt im Teilstand „Unbekannte Aufzählungswerte“ unten.*
3. Die veröffentlichte App verwirft alles Unbekannte, Slot-IDs und
   `slotRef`, und nach jedem Upload dieser Version schreibt sie einmal
   zurück (Echo). Verknüpfungen und Inventardaten überleben; UUIDs und
   Felder neuerer Versionen nicht. Ihr eigenes B2/B3-Verhalten bleibt. Eine
   Offline-Änderung, die mit dem Echo zusammenfällt, ergibt einen sichtbaren
   Konflikt, im Vergleich auch mit geänderten IDs. Verhindern ließe sich das
   Echo nur serverseitig, etwa über Firestore-Regeln.
4. Erhaltene Felder können gegenüber hier bearbeiteten Werten veralten;
   spätere Versionen müssen sie prüfen. `mainWeapon` spiegelt nur die
   gewählte Waffe. Mehr als fünf Distanzstufen werden weiterhin gekürzt.
5. Unbekannte Felder des Transfer-Umschlags gehen verloren. Eine höhere
   `transferSchemaVersion` wird sichtbar abgelehnt.
6. Vorabdaten dieses Branches (ID in `sourceRef`), die zusätzlich die
   veröffentlichte App durchlaufen haben, können falsch zugeordnet werden.
   Das betrifft nur Entwicklergeräte.
7. B10 setzt voraus, dass Laden ein Fixpunkt ist. Die Fixture-Tests sichern
   das ab; ein Fehler wie B1 brächte je Abgleich einen stillen Upload zurück.
8. Befund B9 ist als Kleinfix behoben: `_mergeEntry` stützt sich auf den
   bestehenden Eintrag, Typ und Träger verknüpfter Einträge bleiben erhalten.

*Nächster Schritt:* das gemeinsame Gegenstandsmodell nach den
Abnahmekriterien oben. Außerdem für neue Felder und Enum-Werte die Formatregel
anwenden. Vor einem nicht-additiven Formatwechsel braucht es eine sichtbare
Schreibsperre, die ältere Versionen bereits kennen.

**Teilstand 28.09.2026 (2) — Alle verschachtelten Modelle bewahren
unbekannte Felder.** Restrisiko 1 des vorigen Teilstands ist erledigt.
Hintergrund: ARCH-02 und ARCH-03 bringen neue verschachtelte Felder, und nur
Geräte, die bereits eine Version mit diesem Schutz haben, verlieren sie
nicht. Dieser Stand muss deshalb veröffentlicht sein, bevor ein neues Format
kommt.

*Umfang.* Jedes Modell, das im JSON von `HeroSheet` oder `HeroState` steht,
trägt jetzt eigene `unbekannteFelder` und ein eigenes `jsonSchluessel`
(Liste in der technischen Übersicht, Abschnitt 2.1) — 61 Modelle
einschließlich der zehn aus `f28cb1a`. Ausgenommen ist nur `OffhandSlot`,
das nie geschrieben wird. Neuaufbauten per Konstruktor sind auf `copyWith`
umgestellt: Normalisierung der Nebenhand-Auswahl und der
Talentmodifikatoren, die Modifikator-, Ritual-, Meta-Talent-, SF-,
Zauberdetail-, Abenteuer-, Begleiter-, Übersichts- und Zaubereffekt-Dialoge,
das Abenteuerblatt, Wunden und volle Rast sowie die in `saveHero` neu
errechneten Startwerte (`Attributes.uebernimmWerte`; ohne das erbten sie die
Felder der Rohstartwerte). Objekte, die nur Felder einer neueren Version
tragen, gelten nicht mehr als leer (Text-Overrides, Effekt-Zusatzdaten,
Geburtsdatum).

Commits:

- `0512fac` — Kampf-Rest (Nebenhand-Auswahl, Kampf-SF, manuelle
  Modifikatoren, Waffenmeister samt Bonus).
- `ea8db81` — Talente, Zauber, Rituale, Sprachen, Sonderfertigkeiten.
- `a8bde70` — Begleiter, Abenteuer, Notizen, Kontakte, Gruppen,
  Reisebericht; dazu Befund B11 (Kleinfix).
- `9db8406` — Eigenschaften, Grundwerte, SE-Pools, Ressourcenschalter,
  Geburtsdatum, Bilder, Schnappschuss, Steigerungsverlauf.
- `177b4a3` — Laufzeitzustand: Zaubereffekte, Wirkungsdauer, Wunden,
  Würfelprotokoll, temporäre Modifikatoren.
- `66a7c70` — Vollständigkeitswächter über jede Objektebene.

*Prüfungen.* `zukunftsfelder.dart` deckt jetzt 71 Stellen im Helden
und 7 im Zustand ab, `veroeffentlichte_app.dart` bildet den Verlust in
allen Modellen nach. Geprüft sind Laden (Tabellentest je Modell,
Vollständigkeitswächter über jede Objektebene eines voll belegten Helden
und aller Bestandshelden), Bearbeiten über `HeroActions` und die Editoren
(Widgettests), echtes Hive mit Neustart, Import/Export überschreibend und
als Kopie, Zwei-Geräte-Sync mit Held und Zustand einer neueren Version
einschließlich gleichzeitig geänderter Cloud sowie der Mischbetrieb mit dem
Echo der veröffentlichten App. Gegenproben: Mit vorübergehend leerem
`sammleUnbekannteFelder` scheitern alle Modell- und Ablaufproben; mit
einzeln zurückgesetzten Editoren scheitert jeweils der zugehörige
Widgettest. Dabei fiel auf, dass der Sync-Test den Stand der neueren
Version bisher durch das hiesige Modell schickte und ohne Fix nicht
scheiterte; die Felder werden jetzt direkt ins JSON gesetzt. Die Hash-Pins
der Bestandshelden sind unverändert.

*Verbleibende Risiken:*

1. ~~Unbekannte **Enum-Werte** (Restrisiko 2 oben) und unbekannte
   Wundzonen. Konzept vorgelegt, Umsetzung nach Bestätigung.~~ *Erledigt im
   Teilstand „Unbekannte Aufzählungswerte“ unten.*
2. Was eine bestehende Normalisierung verwirft, verliert auch seine
   unbekannten Felder: Personen, SE-Zeilen und Beute ohne Inhalt,
   Talentmodifikatoren ohne Beschreibung, Ritualkategorien ohne oder mit
   doppelter ID, Zusatzfelder ohne Bezeichnung, ungültige Gesichtsbefunde.
3. Restrisiken 3 bis 7 des vorigen Teilstands gelten unverändert; die
   veröffentlichte App verwirft jetzt nachweislich in allen Modellen.
4. Ein Nutzer, der einen Wert bewusst zurücksetzt (Ritualkategorie auf
   Talentbezug, Zauber-Overrides auf den Katalog), nimmt die Felder des
   entfallenden Objekts mit; bleibt das Objekt bestehen, bleiben sie.

*Nächster Schritt:* unbekannte Enum-Werte nach bestätigtem Konzept (siehe
folgenden Teilstand).

**Teilstand 28.09.2026 (3) — Unbekannte Aufzählungswerte.** Restrisiko 2
des ersten und Restrisiko 1 des zweiten Teilstands sind erledigt. Damit
bewahrt diese Version alles, was eine neuere Version in Held und Zustand
schreibt, soweit es kein bestehendes Normalisieren verwirft (Restrisiko 2
des zweiten Teilstands).

*Konzept (bestätigt).* Kennt diese Version einen Aufzählungswert nicht,
rechnet sie wie bisher mit dem Ersatzwert. Den Rohwert merkt sich das Modell
in `unbekannteEnumWerte` (JSON-Schlüssel → Rohwert, eine eigene Map neben
`unbekannteFelder`) und schreibt ihn in `toJson` anstelle des Ersatzes
zurück. Fehlende und leere Angaben gelten wie bisher als fehlend, es wird
nichts geschrieben, was vorher nicht dastand; Laden bleibt ein Fixpunkt, die
Hash-Pins der Bestandshelden sind unverändert. Änderungsregel: Ein `copyWith`
mit einem **anderen** Wert überschreibt den Rohwert, derselbe Wert (etwa
ein Dialog, der alle Felder neu durchreicht) lässt ihn stehen. Werkzeuge in
`unbekannte_json_felder.dart`: `leseEnumWert`, `enumNachName`,
`festeEnumWerte`, `mitUnbekanntenEnumWerten`, `ohneGeaenderteEnumWerte`.

*Umfang.* 18 Felder in 14 Modellen: Inventareintrag (`itemType`, `source`,
`traegerTyp`), Inventarmodifikator (`kind`), Waffenslot (`combatType`),
Nebenhand (`type`, `shieldSize`), Waffenmeister-Bonus (`type`),
Ritualkategorie (`knowledgeMode`) und ihr Zusatzfeld (`type`), Begleiter
(`typ`), Abenteuer (`status`) mit SE-Belohnung (`targetType`) und Beute
(`itemType`), Wirkungsdauer (`unit`), Würfelprotokoll (`type`,
`automaticOutcome`) und der Monat des aventurischen Datums. Unbekannte
Wundzonen hält `WundZustand.unbekannteZonen`: Sie zählen nicht mit, bleiben
beim Bearbeiten bekannter Zonen stehen und heilen bei der vollen Rast.
Dazu die Befunde B12 und B13 als Kleinfixe (Befundtabelle unten): beide
hätten sonst mit dem Ersatzwert Daten verloren bzw. verdoppelt.

Commit: `9d2aeaa`.

*Prüfungen.* `zukunftsfelder.dart` setzt zusätzlich an 15 Stellen im Helden
und 4 im Zustand einen unbekannten Wert (`zukunftsWert`, eine Wundzone
`zukunftsZone`); `veroeffentlichte_app.dart` schreibt dort wie die
veröffentlichte App den Ersatz. Ein Tabellentest je Feld prüft Ersatz,
Rohwert, Fixpunkt, beide Zweige der Änderungsregel und unverändertes
Verhalten bekannter, fehlender und leerer Werte. Die Ablauf-, Hive-,
Import/Export- und Zwei-Geräte-Proben aus Teilstand (2) laufen mit denselben
Helden und decken die Aufzählungen dadurch mit ab. Gegenproben: Ohne das
Merken in `leseEnumWert` scheitern 40 Tabellen- und Sync-Proben sowie die
Ablaufprobe; ohne `unbekannteZonen` die Wundprobe, der Sync und der Ablauf;
ohne B12- bzw. B13-Fix die jeweilige Abgleichprobe (B13 auch der Ablauf).
Eine Änderungsregel „nie überschreiben“ bzw. „immer löschen“ lässt je 16
Proben scheitern (das Würfelprotokoll hat kein `copyWith`). Die Hash-Pins
der Bestandshelden sind unverändert; `flutter analyze --no-pub` und die
volle Suite sind grün (2673 bestanden, 3 übersprungen).

*Verbleibende Risiken:*

1. Regeln rechnen mit dem Ersatz. Ein Modifikator unbekannter Art wirkt
   etwa als Eigenschaftsmodifikator (`stat`) auf sein `targetId`, eine
   unbekannte Kampfart als Nahkampf, ein unbekannter Abenteuerstatus als
   laufend. Die Anzeige zeigt den Ersatz, nicht den Rohwert.
2. Verknüpfte Inventareinträge übernehmen `itemType` und `source` bei jedem
   Abgleich aus ihrem Slot; ein unbekannter Typ dort wird deshalb durch
   den Slottyp ersetzt. Ein verknüpfter Eintrag mit unbekannter Quelle
   bleibt nach B12 unverändert, folgt aber auch keinen Slotänderungen mehr.
3. Abgedeckt sind alle Stellen, an denen Held und Zustand einen
   Aufzählungswert parsen; ausgenommen bleiben das nur gelesene
   `OffhandSlot.mode` und die Steigerungsart, die B5 schon bewahrt.
   Eigenschaftskürzel, Repräsentationen und ähnliche Kennungen liegen als
   Text im Modell und bleiben ohnehin roh. Zahlen, die beim Laden begrenzt
   werden (etwa Zoom und Fokus der Bilder), zählen zu den Normalisierungen
   aus Restrisiko 2 des zweiten Teilstands.
4. Restrisiken 2 bis 4 des zweiten Teilstands gelten unverändert.

*Nächster Schritt:* das gemeinsame Gegenstandsmodell nach den
Abnahmekriterien oben. Dieser Stand muss vorher veröffentlicht sein.
