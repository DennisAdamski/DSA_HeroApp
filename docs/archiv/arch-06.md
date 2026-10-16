# Archiv — ARCH-06 Zusammengehörige Änderungen speichern und synchronisieren

Archiv der Architektur-Roadmap, Stand 16.10.2026. Dies ist der unveränderte Wortlaut des früheren Roadmap-Abschnitts; die Roadmap ([architecture_roadmap.md](../architecture_roadmap.md)) führt nur noch Status und offene Punkte. Verweise wie „Teilstand (3)“ in Code, CLAUDE.md und anderen Dokumenten beziehen sich auf diesen Text.

---

## ARCH-06 — Zusammengehörige Änderungen gemeinsam speichern und synchronisieren

**Teilstand 3, 12.10.2026 — dauerhafter Wiederanlauf von Konfliktentscheidungen.**
Entscheidungen über Held und gebundenen Zustand („Nur Lokal“, „Nur Online“,
„Beide behalten“, „Automatisch“) werden vor dem ersten Schreibzugriff als
`SyncKonfliktVorgang` im Profiljournal gesichert und über `KonfliktWiederanlauf`
inhaltsgeprüft zu Ende geführt; betroffene IDs sind für normalen Sync gesperrt,
neue Änderungen halten den Vorgang an und stellen den Konflikt mit Hinweis neu.
Beide Abbruchlücken der Abnahme sind behoben und als Regressionstests
(`test/data/sync_konflikt_wiederanlauf_test.dart`, echter Hive-Neustart)
aufgenommen. Nachweis: `flutter analyze` ohne Befund, vollständige serielle Suite
mit 4561 bestandenen und 3 übersprungenen Tests. Nicht durchgeführt: Geräte- und
Live-Firebase-Prüfung. Bekannte Grenzen: Bogen und Zustand liegen online in zwei
getrennten Schreibzugriffen (kurz sichtbare Zwischenfassung auf anderen Geräten);
Online-Tombstone mit „Nur Online“, Löschkonflikte, Offline-Helden, eigenständige
Zustandskonflikte, `deleteHero` während eines offenen Vorgangs, Avatare.
Details: [Abnahmeprüfung](../arch06_abnahme.md) und Speichervertrag.

**Abnahmeprüfung 10.10.2026 (überholt durch Teilstand 3):** Der Hauptpunkt blieb damals offen. Analyse ohne
Befund und 101 vorhandene Ablauf-/Sync-/Widgettests bestanden; zwei zusätzliche
Abbruchproben zeigen Lücken bei der Konfliktauflösung: „Nur Lokal“ verliert nach
dem Heldenupload und Neustart seine Zustandsentscheidung, „Beide behalten“
kann den Zustand der lokalen Kopie verlieren. Nachweise und nächster
Teilumfang stehen in [ARCH-06: technische Abnahmeprüfung](../arch06_abnahme.md).
Die drei abgehakten Unterpunkte beschreiben die gelieferten Teilstände;
sie sind keine bestandene Gesamtabnahme. Nächster Schritt ist der dauerhafte
Wiederanlauf zusammengehöriger Konfliktentscheidungen.

**Entwurfsstand 10.10.2026:** Nach Freigabe der Ausarbeitung liegt der
[Wiederanlaufvertrag](../superpowers/specs/2026-10-10-arch06-konflikt-wiederanlauf-design.md)
zur Nutzerprüfung vor. Er sichert die einmal gewählte Fassung und Kopie-ID im
vorhandenen Profiljournal, reserviert betroffene IDs gegenüber normalem Sync
und macht neue Änderungen ausdrücklich entscheidbar. Produktiver Code ist
unverändert; der Entwurf ist noch nicht umgesetzt. Implementierungsplanung
folgt nach Prüfung des schriftlichen Vertrags.

**Ist-Zustand:** Heldenblatt und Spielzustand werden getrennt gespeichert und
synchronisiert. Steigerungsrunden bündeln bereits Werte, AP/SE und Historie im
Heldenblatt. Die Sync-Logik bindet zugehörige Zustandskonflikte an Heldenkonflikte;
diese Schutzmechanismen müssen erhalten bleiben.

**Ziel:** Fachlich zusammengehörige Änderungen als Einheit behandeln, auch bei
Abbruch oder Neustart. Ein Änderungsprotokoll und eine dauerhafte Warteschlange
machen lokale Änderungen, ausstehenden Sync und Korrekturen nachvollziehbar.
Der Betrieb ohne Konto oder Netzwerk bleibt möglich.

**Einstieg:** `lib/data/hero_repository.dart`, `lib/data/hive_hero_repository.dart`,
`lib/data/syncing_hero_repository.dart`, `lib/data/sync/`,
`lib/domain/sync_models.dart`, `lib/domain/hero_advancement_entry.dart` und
`lib/ui/screens/sync_conflict_gate.dart`.

- [x] Für die Abläufe aus ARCH-05 festlegen, welche Daten gemeinsam verbindlich
  werden müssen, und einen geeigneten Speichervertrag mit Wiederanlauf definieren.
- [x] Lokale Änderung und ausstehenden Sync dauerhaft zusammen erfassen;
  wiederholte Übertragung darf eine Aktion nicht erneut anwenden.
- [x] Änderungsprotokoll und fachlich gültige Korrekturaktionen ergänzen.
  Unabhängige Änderungen nur nach definierten Konfliktregeln zusammenführen;
  widersprüchliche Änderungen bleiben sichtbar entscheidbar.

**Abnahme:** Ein Abbruch hinterlässt keine halbe fachliche Buchung. Ein Neustart
verliert keinen ausstehenden Abgleich. Wiederholungen buchen keine AP und keinen
Schaden doppelt. Heldenblatt und zugehöriger Zustand werden bei Konflikten nicht
unbemerkt aus widersprüchlichen Versionen kombiniert. Korrekturen bleiben im
Verlauf erkennbar; bereits übernommene Steigerungshistorie wird nicht gelöscht.

**Prüfung:** Fehler- und Wiederanlauftests in `test/data/`, insbesondere
`syncing_hero_repository_test.dart`, Gateway-/Transporttests sowie
`test/ui/screens/sync_conflict_gate_test.dart`. Zwei simulierte Geräte mit
gemeinsamer Ausgangsversion und unabhängigen bzw. konkurrierenden Änderungen prüfen.

**Abhängigkeiten / offene Entscheidungen:** ARCH-05 definiert die Einheiten;
ARCH-02/03/04 beeinflussen gespeicherte Referenzen. Speichertechnik, Remote-Protokoll,
Granularität der Zusammenführung und zulässige Korrekturen gesondert entscheiden.
Ein Datenbankwechsel ist mit dieser Liste nicht beschlossen. Die vorhandenen
nativen und REST-Sync-Pfade berücksichtigen.

**Entscheidungen 07.10.2026 (Nutzer).** Der Abgleich bleibt
dokumentbasiert: Bogen und Zustand werden als ganze Dokumente mit Revision
übertragen; ausstehend ist, was vom gemerkten Hash abweicht. Eine
Operations-Warteschlange wird nicht gebaut. Zuerst kommen Speichervertrag,
Vorgangsjournal und Wiederanlauf (Teilstand 1), danach Buchungsprotokoll und
Rücknahme für „Schaden erhalten“ (Teilstand 2). Die Rücknahme ist eine
Gegenbuchung auf den aktuellen Stand: LeP/AuP steigen um den tatsächlich
abgezogenen Betrag, ohne Obergrenze; Wunden der Buchung werden entfernt,
soweit noch vorhanden; eine Buchung lässt sich nur einmal zurücknehmen.

**Teilstand 1, 07.10.2026 — Speichervertrag, Vorgangsjournal,
Wiederanlauf.** Branch `task/2026-10-07-arch06`, Commit `07e7d8c`.

- *Speichervertrag:* Tabelle je Einheit in
  [schreibpfade_inventar.md](../schreibpfade_inventar.md#speichervertrag-arch-06).
  Bis auf den Import schreiben alle ARCH-05-Abläufe genau ein Dokument.
  Anlegen und Startimport werden durch Nachsehen vollständig: Ein fehlender
  Zustand gilt als leer bzw. wird nachgetragen (`uebernimmStartheld`).
  `createHero` schreibt den Zustand jetzt eingereiht und gestempelt.
- *Vorgangsjournal:* `Vorgangsjournal` (`lib/data/vorgangsjournal.dart`, reine
  Schnittstelle, im Wächter `test/ablaeufe/abhaengigkeiten_test.dart`
  zugelassen), `HiveVorgangsjournal` (Box `vorgaenge_v1` im Profilpfad),
  `vorgangsjournalProvider`. `HeldImportieren` vermerkt Ziel, abgelegte
  Bilder, Hash des vorigen Helden und den Exportzustand
  (`ImportVorgang`).
- *Wiederanlauf:* `VorgaengeWiederaufnehmen` führt einen Import zu Ende
  (Zustand nachtragen), sobald der Held gespeichert ist, sonst gleicht er aus
  (unbenutzte Bilder lokal und in der Cloud löschen). `AppStartupGate`
  ruft ihn nach dem Öffnen von Hive und vor Startimport und `syncNow` auf;
  der Abgleich lädt Nachgetragenes per Hash hoch. Ein gescheiterter
  Importschritt nutzt denselben Weg sofort.
- *Nachweise:* `test/ablaeufe/vorgaenge_wiederaufnehmen_test.dart`
  simuliert Abstürze als nie endende Schritte und nimmt danach auf demselben
  Speicher wieder auf (Bild 2, vor und nach dem Bogen, beim Zustand,
  überschreibender Import, zweiter Lauf, scheiterndes Löschen, unbekannte
  Einträge). `held_importieren_test.dart` prüft Journal und sofortigen
  Ausgleich. `hive_vorgangsjournal_test.dart` prüft das Schließen und
  Wiederöffnen der Box, `startup_hero_importer_test.dart` das
  Nachtragen. `sync_speichervertrag_test.dart` belegt den Sync-Vertrag mit
  zwei Geräten: Ein offline geänderter Zustand übersteht den Neustart (auch
  mit echtem Hive) und wird genau einmal übertragen. Eine verlorene Antwort
  schreibt einmal und erzeugt keinen Konflikt. Ein abgebrochener Import wird
  beim Neustart vor dem Abgleich vollständig und einmal hochgeladen.
- *Restrisiken:* siehe Speichervertrag (Absturz zwischen Bild und Vermerk,
  Cloud beim Wiederanlauf nicht erreichbar, überschriebene Bilder beim
  Re-Import, Journal je Profil). Löschen, Avatar-Operationen und
  Konfliktauflösung laufen ohne Journal. Die fachliche Wiederholung
  (dieselbe Buchung zweimal) schützt erst die Buchungs-ID aus Teilstand 2.

**Teilstand 2, 07.10.2026 — Buchungsprotokoll und Schaden-Rücknahme.**

- *Buchungsprotokoll:* `HeroState.buchungen` (`ZustandsBuchung`,
  `lib/domain/zustands_buchung.dart`, höchstens 50, nur bei Belegung im JSON —
  die Hash-Pins der Bestandshelden bleiben). Eine Buchung hält die
  tatsächlichen Änderungen eines Treffers fest; der Protokolleintrag trägt
  dieselbe `buchungId`. Unbekannte Felder, Art und Zone bleiben erhalten
  (Vollständigkeitswächter ergänzt).
- *Keine Doppelbuchung:* Der Schadensdialog vergibt beim ersten Übernehmen
  eine Vorgangs-ID und behält sie bis zum Schließen. `SchadenErhalten`
  speichert eine schon gebuchte ID nicht erneut;
  `aendereGespeichertenZustand` speichert nichts, wenn die Änderung den
  gespeicherten Zustand unverändert (dieselbe Instanz) zurückgibt; ein
  fehlender Zustand wird immer geschrieben. Die anschließende Wundunterdrückung vermerkt sich im
  selben Speichervorgang an der Buchung.
- *Korrekturaktion:* `SchadenZuruecknehmen`
  (`lib/ablaeufe/schaden_zuruecknehmen.dart`) mit den Regeln
  `schaden_ruecknahme_rules.dart` bucht die Gegenbuchung auf den frischen
  Zustand, wie entschieden ohne Obergrenze. Sie ist nur einmal je Buchung
  möglich und erscheint als eigener Protokolleintrag; der ursprüngliche
  Eintrag bleibt mit der Marke „zurückgenommen“. Bedienung: „Zurücknehmen“ am
  Würfelprotokoll beider Oberflächen samt Rückfrage mit Plan
  (`schaden_ruecknahme.dart`).
- *Zusammenführung:* bleibt dokumentbasiert. Buchen zwei Geräte offline,
  entsteht wie bisher ein sichtbarer Konflikt; jede gewählte Fassung ist in
  sich stimmig (LeP passen zu ihren Buchungen). Ein automatisches
  Zusammenführen unabhängiger Buchungen gibt es nicht; deshalb bleibt der
  dritte Unterpunkt offen. *(Nachgeholt in Teilstand 3.)*
- *Nachweise:* `test/rules/schaden_ruecknahme_rules_test.dart`
  (tatsächliche Deltas, AuP-Untergrenze, Zusatzschaden, geheilte und fremde
  Wunden, vermerkte Unterdrückung, Kopf-INI, unbekannte Zone und Art,
  verdrängtes Original, LeP über dem Maximum),
  `test/ablaeufe/schaden_erhalten_test.dart` und
  `schaden_zuruecknehmen_test.dart` (Wiederholung, parallele Rücknahmen,
  zwischenzeitliche Heilung, Fehler), `test/domain/zustands_buchung_test.dart`,
  Widgettests `test/ui/workspace/schaden_ruecknahme_test.dart`,
  `schaden_dialog_test.dart` (erneuter Versuch nach verlorener Antwort) und
  `test/ui2/spielen/karto_spielverlauf_test.dart`, Zwei-Geräte-Fälle in
  `test/data/sync_speichervertrag_test.dart` (verlorene Antwort, Rücknahme
  auf dem anderen Gerät, offline auf beiden Geräten mit `keepLocal` und
  `keepRemote`).
- *Restrisiken:* Eine ältere App ohne Feldschutz verwirft `buchungen`; die
  Rücknahme ist dann „nicht mehr verfügbar“. Ändert der Nutzer nach einem
  gescheiterten Versuch die Eingaben, bleibt die Vorgangs-ID; hatte der erste
  Versuch doch gespeichert, gilt dessen Buchung. Rast und andere
  Zustandsänderungen sind noch nicht zurücknehmbar.

**Teilstand 3, 07.10.2026 — Konflikte nur für echte Widersprüche.**
Nutzerentscheidung: Gleichzeitiges Spielen an zwei Geräten ist die
Ausnahme, Laufzeitwerte sind unkritisch, wichtig sind AP, Talente, Inventar
und Co. Sichtbar werden sollen nur tatsächliche Konflikte, entschieden wird
„Nur Online“, „Nur Lokal“, „Beide“ oder „Automatisch“. Bleibt bei
„Automatisch“ etwas offen, wird je Wert nach Online oder Lokal gefragt.

- *Basisstand:* Der Sync legt nach jedem Abgleich den Inhalt des
  abgeglichenen Stands mit seiner Revision ab (`SyncBasisStore`,
  `HiveSyncBasisStore`, Box `sync_basis_v1`). Die Basis wird vor den
  Metadaten geschrieben und gilt nur, wenn ihre Revision zur gemerkten passt.
  Bestandsabgleiche bekommen sie beim nächsten Abgleich ohne lokale Änderung.
- *Zusammenführungsregel:* `fuehreSyncZusammen`
  (`lib/domain/sync_zusammenfuehrung.dart`). Was nur eine Seite geändert
  hat, wird übernommen; ein echter Konflikt ist nur ein Wert, den beide
  verschieden geändert haben. Maps werden je Schlüssel verglichen, Listen
  über `id`/`instanzId` je Element (Inventar, Kampfslots, Verlauf, Abenteuer,
  Buchungen); legen beide Seiten ein Feld neu an, gilt die Basis als leer.
  Fachregeln: AP und Ressourcen/Erschöpfung sind Zähler, Stufe und
  Zeitstempel nehmen den höheren Wert, das Würfelprotokoll ist eine
  Vereinigung, Protokoll und Buchungen bleiben auf 50 begrenzt.
- *Sync:* Ohne Widerspruch führt der Sync still zusammen, schreibt online
  auf die gelesene Revision und lokal und merkt die neue Basis. Hat der
  Nutzer zwischendurch lokal gespeichert, wird nichts überschrieben, dann
  entsteht der Konflikt. Ein Zustand an einem offenen Helden-Konflikt wird
  nicht still zusammengeführt, er folgt der Entscheidung zum Helden.
  `konfliktVorschau` und `resolveConflictAutomatisch` (am `AppSyncController`)
  rechnen mit dem frischen lokalen Stand; ändert sich online während der
  Entscheidung etwas, wird der Konflikt wie bisher neu gestellt.
- *Oberfläche:* `SyncKonfliktKarte` ersetzt die beiden Kartenvarianten in
  Gate und Einstellungen. Mit Basis nennt sie, wie viele Änderungen
  „Automatisch“ von jeder Seite übernimmt, und zeigt nur die
  widersprüchlichen Werte, sofort aufgeklappt. Die Knöpfe stehen in der
  Reihenfolge der Spalten: „Nur Online“, „Nur Lokal“, „Beide behalten“,
  „Automatisch“. Für übrige Widersprüche fragt ein Dialog je Wert („Alle:
  Online/Lokal“ als Abkürzung).
- *Nachweise:* `test/domain/sync_zusammenfuehrung_test.dart` (Regel),
  `test/data/sync_zusammenfuehrung_repository_test.dart` (stilles
  Zusammenführen, fehlende und nachgetragene Basis, „Automatisch“ samt
  Zustand, Online-Änderung während der Entscheidung, Hive-Basis),
  `sync_zwei_geraete_inventar_test.dart` (Teilen und Beschreiben
  gleichnamiger Stapel ohne Konflikt; echter Widerspruch mit allen vier
  Entscheidungen), `sync_app_versionen_test.dart` (Felder einer neueren
  Version bleiben beim Zusammenführen), `sync_speichervertrag_test.dart`
  (Treffer beider Geräte ohne Konflikt) und die Gate-Tests
  (Knopfreihenfolge, Vorschau, Feldauswahl, Fehler).
- *Grenzen:* Listen ohne stabile ID (Notizen, Kontakte) sind unteilbar.
  Offline-Helden- und Löschkonflikte bleiben ohne „Automatisch“. Die Stufe
  folgt erst beim nächsten Speichern exakt den zusammengeführten AP.
